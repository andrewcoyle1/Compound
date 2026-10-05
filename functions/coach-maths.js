// The figures the app computes, ported for the coach so its answers match the screens.
//
// The Swift originals are the reference; CompoundUnitTests/Fixtures/coach-parity.json holds cases
// both CoachParityTests.swift and coach-maths.test.js check, so the two copies cannot drift apart
// unnoticed. Everything here works on day keys ("YYYY-MM-DD") in the user's own time zone: the
// caller turns Firestore timestamps into day keys once, and the arithmetic below never meets a
// time zone or a clock.
//
// Sources: ExpenditureEngine.swift, ExpenditureWindowStats.swift, ExpenditureSampleBuilder.swift,
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

// A left/right pair is one set: a right row straight after a left one folds into it.
export function pairedSetCount(sets) {
    let count = 0;
    let previousSide = null;
    for (const set of sets) {
        if (!(set.side === "right" && previousSide === "left")) count += 1;
        previousSide = set.side ?? null;
    }
    return count;
}

export function completedWorkingSets(exercise) {
    return pairedSetCount((exercise.sets ?? []).filter((set) => !set.isWarmup && set.completed));
}

// MARK: - Estimated one-rep max

// Epley, as ExerciseOneRMAggregator: a single rep is the weight itself.
export function estimated1RM(weightKg, reps) {
    if (reps <= 1) return weightKg;
    return weightKg * (1 + reps / 30);
}

// The best estimated 1RM per session for each exercise, newest first, the seven most recent.
// `sessions` carry `day` and `at` (the session's end, else start, as epoch ms) and exercises with
// `templateId`.
export function exerciseOneRM(sessions) {
    const sorted = [...sessions].sort((a, b) => b.at - a.at);
    const result = {};
    for (const session of sorted) {
        for (const exercise of session.exercises ?? []) {
            const best = Math.max(0, ...(exercise.sets ?? [])
                .filter((set) => !set.isWarmup && set.completed && set.weightKg > 0)
                .map((set) => estimated1RM(set.weightKg, Math.max(1, set.reps ?? 1))));
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

// Weighted working sets per muscle in `weeks` rolling seven-day windows ending on `endDay`, oldest
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
            const sets = completedWorkingSets(exercise);
            if (sets <= 0) continue;
            for (const [muscle, target] of Object.entries(groups)) {
                result[muscle] ??= Array(weeks).fill(0);
                result[muscle][bucket] += sets * muscleFactor(target);
            }
        }
    }
    return result;
}

// MARK: - Weight trend (the Weight Trend screen)

export const WEIGHT_TREND_ALPHA = 2 / 8;

// Exponential moving average over weigh-ins sorted by time, one value per weigh-in.
export function weightTrend(values, alpha = WEIGHT_TREND_ALPHA) {
    if (values.length === 0) return [];
    let ema = values[0];
    return values.map((value, index) => {
        if (index > 0) ema = alpha * value + (1 - alpha) * ema;
        return ema;
    });
}

// MARK: - Formula expenditure (the prior)

const ACTIVITY_BASE = { sedentary: 1.2, light: 1.35, moderate: 1.5, active: 1.7, very_active: 1.9 };
const EXERCISE_ADJUSTMENT = { never: 0, "1-2": 0.05, "3-4": 0.1, "5-6": 0.15, daily: 0.2 };
const MIFFLIN_SEX = { male: 5, female: -161, prefer_not_to_say: -78 };

// NutritionManager.estimateTDEE. `ageYears` is the caller's: the app counts whole years from the
// date of birth to now, 30 without one, never under 14.
export function estimateTDEE({ gender, weightKg, heightCm, ageYears, activity, exerciseFrequency }, { equation = "mifflinStJeor", bodyFatPercentage = null } = {}) {
    const sex = MIFFLIN_SEX[gender] !== undefined ? gender : "male";
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
        bmr = 370 + 21.6 * (weight * (1 - bodyFatPercentage / 100));
    }

    const multiplier = (ACTIVITY_BASE[activity] ?? 1.5) + (EXERCISE_ADJUSTMENT[exerciseFrequency] ?? 0.1);
    return Math.max(1000, bmr * multiplier);
}

// NutritionStrategySettings.resolvedBMREquation.
export function resolvedBMREquation(settings, bodyFatPercentage) {
    const equation = settings?.bmr_equation ?? "mifflinStJeor";
    if (settings?.estimation_method !== "bodyFatAware" || !(bodyFatPercentage > 0 && bodyFatPercentage < 100)) return equation;
    return "katchMcArdle";
}

// MARK: - Expenditure samples

// ExpenditureSampleBuilder.samples: one sample per day from the first day with data to yesterday.
// meals: [{ dayKey, calories }]; measurements: [{ day, weightKg, deleted }]; steps: [{ day, number,
// deleted }]; annotations: [{ dayKey, isPartiallyLogged, isFastingDay }]; loggingBreak: { startDay,
// endDay|null } with startDay the first whole day inside it.
export function expenditureSamples({ meals = [], measurements = [], steps = [], annotations = [], loggingBreak = null, today }) {
    const intake = {};
    for (const meal of meals) intake[meal.dayKey] = (intake[meal.dayKey] ?? 0) + (meal.calories ?? 0);

    const weightTotals = {};
    for (const entry of measurements) {
        if (entry.deleted || !(Number.isFinite(entry.weightKg) && entry.weightKg > 0)) continue;
        const total = weightTotals[entry.day] ?? { sum: 0, count: 0 };
        total.sum += entry.weightKg;
        total.count += 1;
        weightTotals[entry.day] = total;
    }
    const weights = Object.fromEntries(Object.entries(weightTotals).map(([day, t]) => [day, t.sum / t.count]));

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
        });
    }
    return result;
}

// MARK: - Expenditure engine (v1)

export const EXPENDITURE = {
    kcalPerKg: 7700,
    trendAlpha: 0.10,
    outlierFraction: 0.025,
    windowDays: 28,
    minWindowDays: 14,
    minLoggedFraction: 0.5,
    minWeighIns: 4,
    minWeighInSpanDays: 7,
    blendAlpha: 0.30,
    maxDailyStepKcal: 150,
    priorBoundLow: 0.60,
    priorBoundHigh: 1.60,
    kcalPerStepPerKg: 0.0005,
    maxStepNowcastKcal: 300,
    nowcastRecentDays: 7,
    trendSeedWeighIns: 7,
};

function priorEstimate(day, kcal, fixed = false) {
    return {
        day, kcal: roundHalfAway(kcal), source: fixed ? "fixed" : "prior", isProvisional: !fixed,
        trendWeightKg: null, weeklyTrendChangeKg: null, loggedDays: 0, weighInCount: 0, windowDays: 0, stepAdjustmentKcal: 0,
    };
}

function trendWeights(samples) {
    const weighIns = samples.filter((s) => s.weightKg != null);
    if (weighIns.length === 0) return {};
    const seed = weighIns.slice(0, EXPENDITURE.trendSeedWeighIns).map((s) => s.weightKg);
    let trend = seed.reduce((a, b) => a + b, 0) / seed.length;
    const result = {};
    let seeded = false;
    for (const sample of samples) {
        if (sample.weightKg != null) {
            if (seeded) {
                const clamped = Math.min(Math.max(sample.weightKg, trend * (1 - EXPENDITURE.outlierFraction)), trend * (1 + EXPENDITURE.outlierFraction));
                trend += EXPENDITURE.trendAlpha * (clamped - trend);
            } else if (sample.day === weighIns[0].day) {
                seeded = true;
            }
        }
        if (seeded) result[sample.day] = trend;
    }
    return result;
}

function windowStats(window, trend) {
    const loggedDays = window.filter((s) => s.intakeKcal != null && !s.isExcluded).length;
    const weighIns = window.filter((s) => s.weightKg != null);
    const daysPresent = window.length;
    const trendWeightKg = window.length > 0 ? (trend[window[window.length - 1].day] ?? null) : null;
    const weighInSpanDays = weighIns.length > 0 ? daysBetween(weighIns[0].day, weighIns[weighIns.length - 1].day) : 0;

    const isSufficient = (daysSinceFirst) => daysSinceFirst >= EXPENDITURE.minWindowDays
        && loggedDays >= EXPENDITURE.minLoggedFraction * daysPresent
        && weighIns.length >= EXPENDITURE.minWeighIns
        && weighInSpanDays >= EXPENDITURE.minWeighInSpanDays;

    const energyBalance = () => {
        const intakes = window.filter((s) => !s.isExcluded && s.intakeKcal != null).map((s) => s.intakeKcal);
        if (intakes.length === 0) return null;
        const meanIntake = intakes.reduce((a, b) => a + b, 0) / intakes.length;
        const trendDays = window.map((s) => s.day).filter((d) => trend[d] !== undefined);
        if (trendDays.length === 0) return null;
        const span = daysBetween(trendDays[0], trendDays[trendDays.length - 1]);
        if (span <= 0) return null;
        const delta = trend[trendDays[trendDays.length - 1]] - trend[trendDays[0]];
        const raw = meanIntake - (delta * EXPENDITURE.kcalPerKg) / span;
        if (!Number.isFinite(raw)) return null;
        return { rawExpenditure: raw, weeklyTrendChangeKg: (delta * 7) / span };
    };

    const stepNowcast = () => {
        const stepDays = window.filter((s) => s.steps != null);
        if (!(stepDays.length * 2 >= daysPresent) || stepDays.length === 0 || trendWeightKg == null) return 0;
        const recent = stepDays.slice(-EXPENDITURE.nowcastRecentDays).map((s) => s.steps);
        const recentMean = recent.reduce((a, b) => a + b, 0) / recent.length;
        const windowMean = stepDays.reduce((a, s) => a + s.steps, 0) / stepDays.length;
        const raw = (recentMean - windowMean) * EXPENDITURE.kcalPerStepPerKg * trendWeightKg;
        return clamp(raw, -EXPENDITURE.maxStepNowcastKcal, EXPENDITURE.maxStepNowcastKcal, 0);
    };

    const estimate = (day, kcal, source, isProvisional, weeklyTrendChangeKg = null, stepAdjustmentKcal = 0) => ({
        day, kcal: roundHalfAway(kcal), source, isProvisional, trendWeightKg, weeklyTrendChangeKg,
        loggedDays, weighInCount: weighIns.length, windowDays: daysPresent, stepAdjustmentKcal,
    });

    return { isSufficient, energyBalance, stepNowcast, estimate };
}

function blend(running, raw, prior) {
    const step = clamp(EXPENDITURE.blendAlpha * (raw - running), -EXPENDITURE.maxDailyStepKcal, EXPENDITURE.maxDailyStepKcal, 0);
    const blended = running + step;
    if (!(prior > 0)) return blended;
    return clamp(blended, prior * EXPENDITURE.priorBoundLow, prior * EXPENDITURE.priorBoundHigh, prior);
}

// ExpenditureEngine.history: one estimate per day from the first usable sample through `today`.
// settings: { calculationMode: "dynamic"|"fixed", calculationStartDay|null, stepInformedUpdates }.
export function expenditureHistory({ samples, priorKcal, settings = {}, today }) {
    const prior = Number.isFinite(priorKcal) ? priorKcal : 0;
    const fixed = settings.calculationMode === "fixed";
    const usable = samples
        .filter((s) => s.day < today && (settings.calculationStartDay == null || s.day >= settings.calculationStartDay))
        .sort((a, b) => (a.day < b.day ? -1 : a.day > b.day ? 1 : 0));
    if (usable.length === 0) return [priorEstimate(today, prior, fixed)];

    const byDay = {};
    for (const sample of usable) byDay[sample.day] = sample;
    const trend = trendWeights(usable);
    const firstDay = usable[0].day;
    let running = prior;
    const estimates = [];

    for (let day = firstDay; day <= today; day = addDays(day, 1)) {
        const window = [];
        for (let offset = -EXPENDITURE.windowDays; offset <= -1; offset++) {
            const sample = byDay[addDays(day, offset)];
            if (sample) window.push(sample);
        }
        const stats = windowStats(window, trend);
        if (fixed) {
            estimates.push(stats.estimate(day, prior, "fixed", false));
            continue;
        }
        const balance = stats.isSufficient(daysBetween(firstDay, day)) ? stats.energyBalance() : null;
        if (!balance) {
            estimates.push(stats.estimate(day, running, "prior", true));
            continue;
        }
        running = blend(running, balance.rawExpenditure, prior);
        const nowcast = settings.stepInformedUpdates ? stats.stepNowcast() : 0;
        estimates.push(stats.estimate(day, running + nowcast, "adaptive", false, balance.weeklyTrendChangeKg, nowcast));
    }
    return estimates;
}
