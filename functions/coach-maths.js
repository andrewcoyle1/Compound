// The figures the app computes, ported for the coach so its answers match the screens.
//
// The Swift originals are the reference; CompoundUnitTests/Fixtures/coach-parity.json holds cases
// both CoachParityTests.swift and coach-maths.test.js check, so the two copies cannot drift apart
// unnoticed. Everything here works on day keys ("YYYY-MM-DD") in the user's own time zone: the
// caller turns Firestore timestamps into day keys once, and the arithmetic below never meets a
// time zone or a clock.
//
// Sources: ExpenditureEngine.swift, ExpenditureFilter.swift, ExpenditureWindowStats.swift, ExpenditureSampleBuilder.swift,
// NutritionManager.estimateTDEE, WeightTrendCalculator.swift, ExerciseOneRMAggregator.swift,
// MuscleVolume.swift and WorkoutSetPairing.swift.

// MARK: - Day keys

const DAY_MS = 86_400_000;

export function addDays(dayKey, days) {
    const [y, m, d] = dayKey.split("-").map(Number);
    return new Date(Date.UTC(y, m - 1, d) + days * DAY_MS).toISOString().slice(0, 10);
}

export function daysBetween(from, to) {
    const ms = (key) => { const [y, m, d] = key.split("-").map(Number); return Date.UTC(y, m - 1, d); };
    return Math.round((ms(to) - ms(from)) / DAY_MS);
}

// Swift's `.rounded()`: half away from zero, where Math.round rounds half up.
export function roundHalfAway(value) {
    return Math.sign(value) * Math.round(Math.abs(value));
}

const clamp = (value, low, high, whenNotFinite) => (Number.isFinite(value) ? Math.min(Math.max(value, low), high) : whenNotFinite);

// MARK: - Sets

// A left/right pair is one set: a right row straight after a left one folds into it. A sub-set (a
// drop or mini-set, carrying `parentSetId`) is part of its parent and adds nothing.
export function pairedSetCount(sets) {
    let count = 0;
    let previousSide = null;
    for (const set of sets) {
        if (set.parentSetId != null) continue;
        if (!(set.side === "right" && previousSide === "left")) count += 1;
        previousSide = set.side ?? null;
    }
    return count;
}

export function completedWorkingSets(exercise) {
    return pairedSetCount((exercise.sets ?? []).filter((set) => !set.isWarmup && set.completed));
}

// MARK: - Estimated one-rep max

// As ExerciseOneRMAggregator.estimated1RM: Epley's form on reps to failure (reps + RIR, RIR =
// 10 − RPE when an RPE was logged, else no reserve), the weight itself at one rep to failure, and
// no estimate past ten reps to failure (Reynolds 2006).
export const MAX_REPS_TO_FAILURE = 10;

export function repsToFailure(reps, rpe) {
    const reserve = rpe == null ? 0 : Math.max(0, 10 - rpe);
    return reps + reserve;
}

export function estimated1RM(weightKg, reps, rpe = null) {
    if (!(weightKg > 0) || !(reps >= 1)) return null;
    const toFailure = repsToFailure(reps, rpe);
    if (toFailure > MAX_REPS_TO_FAILURE) return null;
    if (toFailure <= 1) return weightKg;
    return weightKg * (1 + toFailure / 30);
}

// One logged set's estimate; a weight with no reps reads as a single.
export function setEstimated1RM(set) {
    if (!(set.weightKg > 0)) return null;
    return estimated1RM(set.weightKg, Math.max(1, set.reps ?? 1), set.rpe ?? null);
}

// The best estimated 1RM per session for each exercise, newest first, the seven most recent.
// `sessions` carry `day` and `at` (the session's end, else start, as epoch ms) and exercises with
// `templateId`.
export function exerciseOneRM(sessions) {
    const sorted = [...sessions].sort((a, b) => b.at - a.at);
    const result = {};
    for (const session of sorted) {
        for (const exercise of session.exercises ?? []) {
            // A drop or mini-set is part of its set, as in the Swift.
            const best = Math.max(0, ...(exercise.sets ?? [])
                .filter((set) => !set.isWarmup && set.completed && set.parentSetId == null)
                .map(setEstimated1RM)
                .filter((value) => value != null));
            if (!(best > 0)) continue;
            const current = result[exercise.templateId] ?? { name: exercise.name, last7Workouts: [], latest1RM: 0 };
            if (current.last7Workouts.length >= 7) continue;
            current.last7Workouts.push({ day: session.day, value: best });
            current.latest1RM = Math.max(current.latest1RM, best);
            result[exercise.templateId] = current;
        }
    }
    return result;
}

// MARK: - Muscle volume

const muscleFactor = (target) => (target === "secondary" ? 0.5 : 1);

// Hard sets, as MuscleVolume.hardSets: finished, not warm-ups, not logged below RPE 6 (a set with
// no RPE counts); each finished drop, or mini-set of a myo-rep or rest-pause set, adds 0.5, up to
// 2 a set; a left/right pair is one set, worth its better half. Sub-sets find their parent by
// `parentSetId` against the set's `id`.
export const MIN_HARD_SET_RPE = 6;
export const MINI_SET_CREDIT = 0.5;
export const MAX_CREDIT_PER_SET = 2;

export const isHardSet = (set) => !set.isWarmup && set.completed && (set.rpe == null || set.rpe >= MIN_HARD_SET_RPE);

function setCredit(set, sets) {
    const extras = sets.filter((piece) => piece.parentSetId != null && piece.parentSetId === set.id
        && !piece.isWarmup && piece.completed
        && (piece.kind === "drop" || set.kind === "myo" || set.kind === "restPause")).length;
    return Math.min(MAX_CREDIT_PER_SET, 1 + MINI_SET_CREDIT * extras);
}

export function hardSets(exercise) {
    const sets = exercise.sets ?? [];
    let total = 0;
    let previous = null;
    for (const set of sets) {
        if (!isHardSet(set) || set.parentSetId != null) continue;
        const value = setCredit(set, sets);
        if (set.side === "right" && previous?.side === "left") {
            total += Math.max(0, value - previous.credit);
        } else {
            total += value;
        }
        previous = { side: set.side ?? null, credit: value };
    }
    return total;
}

// Weighted hard sets per muscle in `weeks` rolling seven-day windows ending on `endDay`, oldest
// first. `templates` maps template id to its `muscleGroups` ({ chest: "primary", ... }).
export function weeklyMuscleSets(sessions, templates, endDay, weeks = 12, muscles = []) {
    const result = Object.fromEntries(muscles.map((muscle) => [muscle, Array(weeks).fill(0)]));
    for (const session of sessions) {
        const daysAgo = daysBetween(session.day, endDay);
        if (daysAgo < 0 || daysAgo >= weeks * 7) continue;
        const bucket = weeks - 1 - Math.floor(daysAgo / 7);
        for (const exercise of session.exercises ?? []) {
            const groups = templates[exercise.templateId];
            if (!groups) continue;
            const sets = hardSets(exercise);
            if (sets <= 0) continue;
            for (const [muscle, target] of Object.entries(groups)) {
                result[muscle] ??= Array(weeks).fill(0);
                result[muscle][bucket] += sets * muscleFactor(target);
            }
        }
    }
    return result;
}

// MARK: - Weight trend (one filter for the chart and the engine)

// WeightTrendCalculator.swift. Weigh-in noise and the robust update are shared with the expenditure
// filter below, so the chart and the engine read the scale the same way.
export const WEIGH_IN = {
    // R_W = (0.5% of body weight)², from a 0.53% day-to-day SD (Schneditz 2023).
    noiseFraction: 0.005,
    // Design choice — tune by replay: the noise never drops below (0.3 kg)².
    noiseFloorKg: 0.3,
    // Design choice — tune by replay: q_L, real level shifts (water) per day.
    levelNoiseKgPerDay: 0.05,
    // Design choice — tune by replay: Huber threshold in innovation SDs.
    huberK: 2.5,
    // Design choice — tune by replay: a reading this far from the trend waits for confirmation.
    grossErrorKg: 3,
    grossErrorFraction: 0.04,
    // The trend starts at the median of this many first weigh-ins.
    seedWeighIns: 3,
};

export const WEIGHT_TREND = {
    // Design choice — tune by replay: slope random walk, about (q_E + q_T)/ρ² of the engine.
    slopeNoiseKgPerDay: 0.004,
    initialSlopeSDKgPerDay: 0.1,
};

export function weighInVariance(levelKg) {
    return Math.max((WEIGH_IN.noiseFraction * levelKg) ** 2, WEIGH_IN.noiseFloorKg ** 2);
}

export function isGrossWeighIn(innovation, levelKg) {
    return Math.abs(innovation) > Math.max(WEIGH_IN.grossErrorKg, WEIGH_IN.grossErrorFraction * levelKg);
}

// Huber-type robust update: an innovation beyond huberK predicted SDs has its variance inflated by
// the square of how far beyond it is, so it pulls the trend no harder than one at the threshold.
export function robustWeighInVariance(innovation, predictedVariance, levelKg) {
    const r = weighInVariance(levelKg);
    const ratio = Math.abs(innovation) / (WEIGH_IN.huberK * Math.sqrt(predictedVariance + r));
    return r * Math.max(1, ratio * ratio);
}

export function median(values) {
    const sorted = [...values].sort((a, b) => a - b);
    const mid = Math.floor(sorted.length / 2);
    return sorted.length % 2 === 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

// A local-linear-trend Kalman filter over weigh-ins (level L, slope b per day) with the true gap in
// days between them, a robust update, and a Rauch-Tung-Striebel pass so past points use later data.
// `values` are weigh-ins sorted by time; `days` their day keys (one per value), or null for one a
// day. Only the first weigh-in of a day updates the trend. One trend value per input.
export function weightTrend(values, days = null) {
    const n = values.length;
    if (n === 0) return [];
    const dayIndex = (i) => (days ? daysBetween(days[0], days[i]) : i);
    const isFirstOfDay = (i) => i === 0 || dayIndex(i) !== dayIndex(i - 1);

    const seed = [];
    for (let i = 0; i < n && seed.length < WEIGH_IN.seedWeighIns; i++) if (isFirstOfDay(i)) seed.push(values[i]);
    let level = median(seed);
    let slope = 0;
    let p = [weighInVariance(level), 0, WEIGHT_TREND.initialSlopeSDKgPerDay ** 2]; // [P_LL, P_Lb, P_bb]
    const qb = WEIGHT_TREND.slopeNoiseKgPerDay ** 2;
    const qL = WEIGH_IN.levelNoiseKgPerDay ** 2;

    const filtered = [];
    const predicted = [];
    const gaps = [];
    let held = null;
    let lastDay = dayIndex(0);
    for (let i = 0; i < n; i++) {
        const dt = dayIndex(i) - lastDay;
        lastDay = dayIndex(i);
        level += slope * dt;
        p = [
            p[0] + 2 * dt * p[1] + dt * dt * p[2] + qb * dt * dt * dt / 3 + qL * dt,
            p[1] + dt * p[2] + qb * dt * dt / 2,
            p[2] + qb * dt,
        ];
        predicted.push({ level, slope, p });
        gaps.push(dt);

        if (i > 0 && isFirstOfDay(i)) {
            const innovation = values[i] - level;
            let r = null;
            if (!isGrossWeighIn(innovation, level)) {
                held = null;
                r = robustWeighInVariance(innovation, p[0], level);
            } else if (held != null && Math.sign(held) === Math.sign(innovation)) {
                // A second reading off the same way confirms a real shift: open the level up to it,
                // as process noise, so the smoother does not drag earlier points across the step.
                held = null;
                p = [p[0] + innovation * innovation, p[1], p[2]];
                predicted[i] = { level, slope, p };
                r = weighInVariance(level);
            } else {
                held = innovation;
            }
            if (r != null) {
                const s = p[0] + r;
                const k0 = p[0] / s;
                const k1 = p[1] / s;
                level += k0 * innovation;
                slope += k1 * innovation;
                p = [(1 - k0) * p[0], (1 - k0) * p[1], p[2] - k1 * p[1]];
            }
        }
        filtered.push({ level, slope, p });
    }

    const smoothed = filtered.map((x) => x.level);
    let next = { level: filtered[n - 1].level, slope: filtered[n - 1].slope };
    for (let i = n - 2; i >= 0; i--) {
        const f = filtered[i];
        const pr = predicted[i + 1];
        const dt = gaps[i + 1];
        // C = P_f Fᵀ P_pred⁻¹ with F = [[1, dt], [0, 1]].
        const a = [f.p[0] + dt * f.p[1], f.p[1], f.p[1] + dt * f.p[2], f.p[2]];
        const det = pr.p[0] * pr.p[2] - pr.p[1] * pr.p[1];
        if (!(det > 0)) {
            next = { level: f.level, slope: f.slope };
            continue;
        }
        const inv = [pr.p[2] / det, -pr.p[1] / det, -pr.p[1] / det, pr.p[0] / det];
        const c = [a[0] * inv[0] + a[1] * inv[2], a[0] * inv[1] + a[1] * inv[3], a[2] * inv[0] + a[3] * inv[2], a[2] * inv[1] + a[3] * inv[3]];
        const dl = next.level - pr.level;
        const ds = next.slope - pr.slope;
        next = { level: f.level + c[0] * dl + c[1] * ds, slope: f.slope + c[2] * dl + c[3] * ds };
        smoothed[i] = next.level;
    }
    return smoothed;
}

// MARK: - Formula expenditure (the prior)

// FormulaExpenditure.activityMultiplier: one PAL per activity answer, inside the FAO/WHO/UNU 2004
// bands, with no extra term for training frequency (the answer is still stored, but not read).
const ACTIVITY_PAL = { sedentary: 1.4, light: 1.55, moderate: 1.7, active: 1.85, very_active: 2.0 };
const MIFFLIN_SEX = { male: 5, female: -161, prefer_not_to_say: -78 };

// NutritionManager.estimateTDEE → FormulaExpenditure.estimate. `ageYears` is the caller's: the app
// counts whole years from the date of birth to now, 30 without one, never under 14. A missing sex
// reads as the midpoint. The stored equation "katchMcArdle" is BMREquation.cunningham, which runs
// Cunningham 1980 (500 + 22 × fat-free mass) when a body fat percentage is known.
export function estimateTDEE({ gender, weightKg, heightCm, ageYears, activity }, { equation = "mifflinStJeor", bodyFatPercentage = null } = {}) {
    const sex = MIFFLIN_SEX[gender] !== undefined ? gender : "prefer_not_to_say";
    const weight = clamp(weightKg ?? 70, 30, 500, 70);
    const height = clamp(heightCm ?? 175, 120, 260, 175);
    const age = ageYears ?? 30;
    const mifflin = 10 * weight + 6.25 * height - 5 * age + MIFFLIN_SEX[sex];

    let bmr = mifflin;
    if (equation === "harrisBenedict") {
        const male = 88.362 + 13.397 * weight + 4.799 * height - 5.677 * age;
        const female = 447.593 + 9.247 * weight + 3.098 * height - 4.330 * age;
        bmr = sex === "male" ? male : sex === "female" ? female : (male + female) / 2;
    } else if (equation === "katchMcArdle" && bodyFatPercentage > 0 && bodyFatPercentage < 100) {
        bmr = 500 + 22 * (weight * (1 - bodyFatPercentage / 100));
    }

    const multiplier = ACTIVITY_PAL[activity] ?? ACTIVITY_PAL.moderate;
    return Math.max(1000, bmr * multiplier);
}

// NutritionStrategySettings.resolvedBMREquation. "katchMcArdle" is the stored value of Cunningham.
export function resolvedBMREquation(settings, bodyFatPercentage) {
    const equation = settings?.bmr_equation ?? "mifflinStJeor";
    if (settings?.estimation_method !== "bodyFatAware" || !(bodyFatPercentage > 0 && bodyFatPercentage < 100)) return equation;
    return "katchMcArdle";
}

// MARK: - Expenditure samples

// ExpenditureSampleBuilder.samples: one sample per day from the first day with data to yesterday.
// meals: [{ dayKey, calories }]; measurements: [{ day, weightKg, deleted, at? }]; steps: [{ day, number,
// deleted }]; annotations: [{ dayKey, isPartiallyLogged, isFastingDay }]; loggingBreak: { startDay,
// endDay|null } with startDay the first whole day inside it.
export function expenditureSamples({ meals = [], measurements = [], steps = [], annotations = [], loggingBreak = null, today }) {
    const intake = {};
    for (const meal of meals) intake[meal.dayKey] = (intake[meal.dayKey] ?? 0) + (meal.calories ?? 0);

    // The first weigh-in of each day (by `at` when given, else as listed) is the day's reading.
    const earliest = {};
    measurements.forEach((entry, order) => {
        if (entry.deleted || !(Number.isFinite(entry.weightKg) && entry.weightKg > 0)) return;
        const at = entry.at ?? 0;
        const current = earliest[entry.day];
        if (current && (current.at < at || (current.at === at && current.order < order))) return;
        earliest[entry.day] = { at, order, weightKg: entry.weightKg };
    });
    const weights = Object.fromEntries(Object.entries(earliest).map(([day, e]) => [day, e.weightKg]));

    const stepCounts = {};
    for (const record of steps) {
        if (record.deleted) continue;
        stepCounts[record.day] = Math.max(stepCounts[record.day] ?? 0, record.number);
    }
    const annotationByDay = Object.fromEntries(annotations.map((a) => [a.dayKey, a]));

    const days = [...new Set([...Object.keys(intake), ...Object.keys(weights), ...Object.keys(stepCounts)])].filter((d) => d < today).sort();
    const last = addDays(today, -1);
    if (days.length === 0 || days[0] > last) return [];

    const inBreak = (day) => loggingBreak != null && day >= loggingBreak.startDay && (loggingBreak.endDay == null || day <= loggingBreak.endDay);
    const result = [];
    for (let day = days[0]; day <= last; day = addDays(day, 1)) {
        const annotation = annotationByDay[day];
        const fastingWithNoLogs = (annotation?.isFastingDay ?? false) && intake[day] === undefined;
        result.push({
            day,
            intakeKcal: fastingWithNoLogs ? 0 : (intake[day] ?? null),
            weightKg: weights[day] ?? null,
            steps: stepCounts[day] ?? null,
            isExcluded: (annotation?.isPartiallyLogged ?? false) || inBreak(day),
            isFastingDay: annotation?.isFastingDay ?? false,
        });
    }
    return result;
}

// MARK: - Energy density (EnergyDensity.swift)

// kcal per kg of weight change: Forbes' partition of a change into fat and fat-free mass (Forbes
// 1987; Hall 2007) times their energy densities (9,440 and 1,816 kcal/kg, Hall 2008/2011); 7,700
// when body fat is unknown.
export const ENERGY_DENSITY = { conventionalKcalPerKg: 7700, fatKcalPerKg: 9440, leanKcalPerKg: 1816, forbesConstantKg: 10.4 };

export function energyDensityKcalPerKg(weightKg, bodyFatPercent) {
    if (!(Number.isFinite(weightKg) && Number.isFinite(bodyFatPercent) && bodyFatPercent > 0 && bodyFatPercent < 100)) {
        return ENERGY_DENSITY.conventionalKcalPerKg;
    }
    const fatMassKg = (weightKg * bodyFatPercent) / 100;
    if (!(fatMassKg > 0)) return ENERGY_DENSITY.conventionalKcalPerKg;
    const fatShare = fatMassKg / (fatMassKg + ENERGY_DENSITY.forbesConstantKg);
    return fatShare * ENERGY_DENSITY.fatKcalPerKg + (1 - fatShare) * ENERGY_DENSITY.leanKcalPerKg;
}

// MARK: - Expenditure engine (the [L, E, T] filter)

// ExpenditureEngine.swift and ExpenditureFilter.swift. One Kalman filter, run a day at a time, whose
// state is the trend weight L (kg), habitual intake E and expenditure T (kcal/day on the scale the
// user logs). Weigh-ins observe L, complete logged days observe E, and L moves by (E − T)/ρ a day.
export const EXPENDITURE = {
    // Energy density used when none is passed: the conventional figure (EnergyDensity.swift).
    kcalPerKg: 7700,
    windowDays: 28,
    // Calibrating until all four hold (design choice — tune by replay; Hall & Chow 2011 for the
    // order of magnitude): 21 days, 14 weigh-ins, SD below 200 kcal and 80% of the window logged.
    minDays: 21,
    minWeighIns: 14,
    maxCalibratedSDKcal: 200,
    calibratedLoggedFraction: 0.8,
    // Design choice — tune by replay: below 60% logged, a logged day is trusted half as much.
    inflatedNoiseBelowLoggedFraction: 0.6,
    intakeNoiseInflation: 2,
    // Design choice: a logged day below half the current estimate is read as partly logged.
    partialDayFraction: 0.5,
    // σ_I: the user's own SD of logged intake, held inside 300–500 kcal (design choice).
    intakeNoiseMinKcal: 300,
    intakeNoiseMaxKcal: 500,
    intakeNoiseDefaultKcal: 400,
    intakeNoiseMinDays: 7,
    // Process noise per day (design choice — tune by replay): q_E and q_T.
    intakeDriftKcalPerDay: 30,
    expenditureDriftKcalPerDay: 13,
    // Prior on T: the formula, SD the larger of 15% and 340 kcal (NASEM 2023 RMSE).
    priorSDFraction: 0.15,
    priorSDFloorKcal: 340,
    // Design choice: E starts at the prior with SD 500 kcal.
    initialIntakeSDKcal: 500,
    // Guard only: the figure shown never leaves 60–160% of the formula.
    priorBoundLow: 0.6,
    priorBoundHigh: 1.6,
    // Step nowcast: net walking cost (ACSM equation, ≈0.0004 kcal per step per kg).
    kcalPerStepPerKg: 0.0004,
    maxStepNowcastKcal: 300,
    nowcastRecentDays: 7,
    // The adherence check averages this many days of logged intake.
    recentIntakeDays: 7,
};

// 3×3 matrices as row-major arrays of nine.
const mat = {
    mul: (a, b) => Array.from({ length: 9 }, (_, i) => {
        const r = Math.floor(i / 3), c = i % 3;
        return a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c];
    }),
    transpose: (a) => [a[0], a[3], a[6], a[1], a[4], a[7], a[2], a[5], a[8]],
};

// ExpenditureFilter: predict one day, then observe a weigh-in (index 0) or an intake (index 1).
export function expenditureFilterStart({ levelKg, priorKcal }) {
    const priorSD = Math.max(EXPENDITURE.priorSDFloorKcal, EXPENDITURE.priorSDFraction * priorKcal);
    return {
        x: [levelKg, priorKcal, priorKcal],
        p: [weighInVariance(levelKg), 0, 0, 0, EXPENDITURE.initialIntakeSDKcal ** 2, 0, 0, 0, priorSD ** 2],
        held: null,
    };
}

export function expenditureFilterPredict(state, kcalPerKg) {
    const a = 1 / kcalPerKg;
    const f = [1, a, -a, 0, 1, 0, 0, 0, 1];
    const [l, e, t] = state.x;
    const p = mat.mul(mat.mul(f, state.p), mat.transpose(f));
    p[0] += WEIGH_IN.levelNoiseKgPerDay ** 2;
    p[4] += EXPENDITURE.intakeDriftKcalPerDay ** 2;
    p[8] += EXPENDITURE.expenditureDriftKcalPerDay ** 2;
    return { ...state, x: [l + (e - t) * a, e, t], p };
}

function observe(state, index, value, variance) {
    const innovation = value - state.x[index];
    const s = state.p[index * 4] + variance;
    if (!(s > 0) || !Number.isFinite(s)) return state;
    const gain = [state.p[index], state.p[3 + index], state.p[6 + index]].map((v) => v / s);
    const x = state.x.map((v, i) => v + gain[i] * innovation);
    const p = state.p.map((v, i) => v - gain[Math.floor(i / 3)] * state.p[index * 3 + (i % 3)]);
    return { ...state, x, p };
}

// Returns the new state and whether the reading was used (false while it is held).
export function expenditureFilterWeighIn(state, weightKg) {
    const level = state.x[0];
    const innovation = weightKg - level;
    if (!isGrossWeighIn(innovation, level)) {
        return { state: observe({ ...state, held: null }, 0, weightKg, robustWeighInVariance(innovation, state.p[0], level)), used: true };
    }
    if (state.held != null && Math.sign(state.held) === Math.sign(innovation)) {
        const p = [...state.p];
        p[0] += innovation * innovation;
        return { state: observe({ ...state, p, held: null }, 0, weightKg, weighInVariance(level)), used: true };
    }
    return { state: { ...state, held: innovation }, used: false };
}

export function expenditureFilterIntake(state, intakeKcal, sdKcal) {
    return observe(state, 1, intakeKcal, sdKcal * sdKcal);
}

function priorEstimate(day, kcal, fixed = false) {
    return {
        day, kcal: roundHalfAway(kcal), source: fixed ? "fixed" : "prior", isProvisional: !fixed,
        trendWeightKg: null, weeklyTrendChangeKg: null, loggedDays: 0, weighInCount: 0, windowDays: 0, stepAdjustmentKcal: 0,
        sdKcal: null, weeklyTrendChangeSDKg: null, recentIntakeKcal: null,
    };
}

const mean = (values) => values.reduce((a, b) => a + b, 0) / values.length;

function standardDeviation(values) {
    const m = mean(values);
    return Math.sqrt(values.reduce((a, v) => a + (v - m) ** 2, 0) / (values.length - 1));
}

// The window's counts and the step nowcast (ExpenditureWindowStats). `usedIntake` marks the days
// whose intake the filter read: logged, not excluded, not partial.
function windowStats(window, usedIntake, trendWeightKg) {
    const loggedDays = window.filter((s) => usedIntake.has(s.day)).length;
    const weighInCount = window.filter((s) => s.weightKg != null).length;
    const daysPresent = window.length;
    const recent = window.slice(-EXPENDITURE.recentIntakeDays).filter((s) => usedIntake.has(s.day)).map((s) => s.intakeKcal);

    const stepNowcast = () => {
        const stepDays = window.filter((s) => s.steps != null);
        if (!(stepDays.length * 2 >= daysPresent) || stepDays.length === 0 || trendWeightKg == null) return 0;
        const recentSteps = stepDays.slice(-EXPENDITURE.nowcastRecentDays).map((s) => s.steps);
        const raw = (mean(recentSteps) - mean(stepDays.map((s) => s.steps))) * EXPENDITURE.kcalPerStepPerKg * trendWeightKg;
        return clamp(raw, -EXPENDITURE.maxStepNowcastKcal, EXPENDITURE.maxStepNowcastKcal, 0);
    };
    return {
        loggedDays, weighInCount, daysPresent, stepNowcast,
        loggedFraction: daysPresent > 0 ? loggedDays / daysPresent : 0,
        recentIntakeKcal: recent.length > 0 ? mean(recent) : null,
    };
}

// σ_I for a logged day: the SD of the complete logged days in the 28 days ending on it, held
// inside 300–500 kcal, doubled when under 60% of those days are logged.
function intakeNoise(day, byDay, usedIntake) {
    const values = [];
    let present = 0;
    for (let offset = -(EXPENDITURE.windowDays - 1); offset <= 0; offset++) {
        const d = addDays(day, offset);
        if (!byDay[d]) continue;
        present += 1;
        if (usedIntake.has(d)) values.push(byDay[d].intakeKcal);
    }
    const sd = values.length >= EXPENDITURE.intakeNoiseMinDays
        ? clamp(standardDeviation(values), EXPENDITURE.intakeNoiseMinKcal, EXPENDITURE.intakeNoiseMaxKcal, EXPENDITURE.intakeNoiseDefaultKcal)
        : EXPENDITURE.intakeNoiseDefaultKcal;
    return values.length < EXPENDITURE.inflatedNoiseBelowLoggedFraction * present ? sd * EXPENDITURE.intakeNoiseInflation : sd;
}

// ExpenditureEngine.history: one estimate per day from the first usable sample through `today`.
// settings: { calculationMode: "dynamic"|"fixed", calculationStartDay|null, stepInformedUpdates }.
// kcalPerKg: the energy density of a kilogram of change (EnergyDensity), 7700 when not given.
export function expenditureHistory({ samples, priorKcal, settings = {}, today, kcalPerKg = EXPENDITURE.kcalPerKg }) {
    const prior = Number.isFinite(priorKcal) ? priorKcal : 0;
    const rho = Number.isFinite(kcalPerKg) && kcalPerKg > 0 ? kcalPerKg : EXPENDITURE.kcalPerKg;
    const fixed = settings.calculationMode === "fixed";
    const usable = samples
        .filter((s) => s.day < today && (settings.calculationStartDay == null || s.day >= settings.calculationStartDay))
        .sort((a, b) => (a.day < b.day ? -1 : a.day > b.day ? 1 : 0));
    if (usable.length === 0) return [priorEstimate(today, prior, fixed)];

    const byDay = {};
    for (const sample of usable) byDay[sample.day] = sample;
    const firstDay = usable[0].day;
    const weighIns = usable.filter((s) => s.weightKg != null);
    const seed = median(weighIns.slice(0, WEIGH_IN.seedWeighIns).map((s) => s.weightKg));
    const usedIntake = new Set();
    let state = null;
    let weighInsUsed = 0;
    const estimates = [];

    for (let day = firstDay; day <= today; day = addDays(day, 1)) {
        estimates.push(estimateFor(day));
        if (day < today) process(day);
    }
    return estimates;

    function process(day) {
        const sample = byDay[day];
        let isFirstFilterDay = false;
        if (state) {
            state = expenditureFilterPredict(state, rho);
        } else if (sample?.weightKg != null) {
            // The filter starts on the first weigh-in, at the median of the first few.
            state = expenditureFilterStart({ levelKg: seed, priorKcal: prior });
            weighInsUsed = 1;
            isFirstFilterDay = true;
        }
        if (!sample) return;
        if (state && !isFirstFilterDay && sample.weightKg != null) {
            const result = expenditureFilterWeighIn(state, sample.weightKg);
            state = result.state;
            if (result.used) weighInsUsed += 1;
        }

        if (sample.intakeKcal == null || sample.isExcluded) return;
        // A logged day far below what the body spends is read as partly logged, unless it was a fast.
        const expenditure = state ? state.x[2] : prior;
        if (!sample.isFastingDay && sample.intakeKcal < EXPENDITURE.partialDayFraction * expenditure) return;
        usedIntake.add(day);
        if (state) state = expenditureFilterIntake(state, sample.intakeKcal, intakeNoise(day, byDay, usedIntake));
    }

    function estimateFor(day) {
        const window = [];
        for (let offset = -EXPENDITURE.windowDays; offset <= -1; offset++) {
            const sample = byDay[addDays(day, offset)];
            if (sample) window.push(sample);
        }
        const trendWeightKg = state ? state.x[0] : null;
        const stats = windowStats(window, usedIntake, trendWeightKg);
        const base = {
            day, trendWeightKg, loggedDays: stats.loggedDays, weighInCount: stats.weighInCount, windowDays: stats.daysPresent,
            recentIntakeKcal: stats.recentIntakeKcal,
        };
        const daysOfData = daysBetween(firstDay, day);
        const enoughWeighIns = state != null && daysOfData >= EXPENDITURE.minDays && weighInsUsed >= EXPENDITURE.minWeighIns;
        const rateVariance = state ? state.p[4] + state.p[8] - 2 * state.p[5] : null;
        const rate = enoughWeighIns
            ? { weeklyTrendChangeKg: ((state.x[1] - state.x[2]) * 7) / rho, weeklyTrendChangeSDKg: (Math.sqrt(Math.max(0, rateVariance)) * 7) / rho }
            : { weeklyTrendChangeKg: null, weeklyTrendChangeSDKg: null };
        const sdKcal = state ? Math.sqrt(Math.max(0, state.p[8])) : null;

        if (fixed) {
            return { ...base, ...rate, kcal: roundHalfAway(prior), source: "fixed", isProvisional: false, stepAdjustmentKcal: 0, sdKcal: null };
        }
        const calibrated = enoughWeighIns
            && sdKcal < EXPENDITURE.maxCalibratedSDKcal
            && stats.loggedFraction >= EXPENDITURE.calibratedLoggedFraction;
        if (!calibrated) {
            return { ...base, ...rate, kcal: roundHalfAway(prior), source: "prior", isProvisional: true, stepAdjustmentKcal: 0, sdKcal };
        }
        const bounded = prior > 0
            ? clamp(state.x[2], prior * EXPENDITURE.priorBoundLow, prior * EXPENDITURE.priorBoundHigh, prior)
            : state.x[2];
        const nowcast = settings.stepInformedUpdates ? stats.stepNowcast() : 0;
        return { ...base, ...rate, kcal: roundHalfAway(bounded + nowcast), source: "adaptive", isProvisional: false, stepAdjustmentKcal: nowcast, sdKcal };
    }
}
