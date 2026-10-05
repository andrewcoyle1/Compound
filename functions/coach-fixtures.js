// Four accounts in Firestore's own shapes, for the coach's tests and its evaluation: cutting,
// bulking, stalled and brand new. Generated from a seed, ending at FIXTURE_NOW, so every run sees
// the same data.

export const FIXTURE_NOW = new Date("2026-10-05T17:00:00Z");

let seed = 11;
const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
const noise = (spread) => (rnd() - 0.5) * spread;
const at = (daysAgo, hour = 8) => new Date(Date.UTC(2026, 9, 5 - daysAgo, hour, 0, 0));
const dayKey = (date) => date.toISOString().slice(0, 10);

function set(reps, weightKg, done = true, extra = {}) {
    return { reps, weight_kg: weightKg, isWarmup: false, completed_at: done ? new Date(0) : null, ...extra };
}

function session(id, daysAgo, name, exercises, extra = {}) {
    const start = at(daysAgo, 18);
    return {
        id, author_id: "u", name, date_created: start, ended_at: new Date(start.getTime() + 60 * 60_000),
        exercises, is_rest_day: false, deleted_at: null, ...extra,
    };
}

const exercise = (templateId, name, sets) => ({ template_id: templateId, name, sets });

function meals(days, perDay, { protein = 0.3, skipEvery = 0, notes = {} } = {}) {
    const out = [];
    for (let i = days; i >= 1; i--) {
        if (skipEvery && i % skipEvery === 0) continue;
        const total = perDay + noise(400);
        for (const [hour, share] of [[8, 0.25], [13, 0.35], [19, 0.4]]) {
            const kcal = total * share;
            out.push({
                id: `m${i}-${hour}`, meal_id: `m${i}-${hour}`, author_id: "u", day_key: dayKey(at(i)), date: at(i, hour),
                items: [{ itemId: `i${i}-${hour}`, displayName: hour === 8 ? "Oats and whey" : hour === 13 ? "Chicken rice bowl" : "Salmon, potatoes and greens", nutrients: { calories: kcal, protein: (kcal * protein) / 4, carbs: (kcal * 0.45) / 4, fat_total: (kcal * 0.25) / 9 } }],
                notes: notes[i] ?? null,
            });
        }
    }
    return out;
}

function weighIns(days, startKg, perDay, { every = 1 } = {}) {
    const out = [];
    for (let i = days; i >= 0; i -= every) {
        out.push({ id: `w${i}`, author_id: "u", weight_kg: Math.round((startKg + perDay * (days - i) + noise(0.8)) * 10) / 10, date: at(i, 7), deleted_at: null });
    }
    return out;
}

function stepsFor(days, base) {
    return Array.from({ length: days }, (_, k) => ({ id: `s${k}`, author_id: "u", number: Math.round(base + noise(3000)), date: at(days - k, 21), deleted_at: null, source: "healthkit" }));
}

const flatPlan = (calories, protein, carbs, fat) => ({
    planId: "u", userId: "u", tdeeEstimate: calories + 500, preferredDiet: "balanced", calorieFloor: "standard",
    trainingType: "strength", calorieDistribution: "even", proteinIntake: "high",
    days: Array.from({ length: 7 }, () => ({ calories, proteinGrams: protein, carbGrams: carbs, fatGrams: fat })),
});

const dayPlan = (id, name, exercises) => ({ workout_id: id, name, exercises: exercises.map((e) => ({ exercise: { name: e }, set_targets: [{}, {}, {}] })) });

function upperLower(weeks, benchStart, benchStep, squatStart, squatStep, { stallBench = false } = {}) {
    const out = [];
    for (let w = weeks - 1; w >= 0; w--) {
        const k = weeks - 1 - w;
        const bench = stallBench ? benchStart : benchStart + benchStep * k;
        const squat = squatStart + squatStep * k;
        out.push(session(`up-a-${k}`, w * 7 + 6, "Upper A", [
            exercise("system-barbell-bench-press", "Barbell Bench Press", [set(8, bench * 0.6, true, { isWarmup: true }), set(5, bench), set(5, bench), set(stallBench ? 4 : 5, bench)]),
            exercise("system-seated-row", "Seated Row", [set(10, 60), set(10, 60), set(9, 60)]),
            exercise("system-single-arm-row", "Single Arm Row", [set(10, 30, true, { side: "left" }), set(10, 30, true, { side: "right" })]),
        ], { mesocycle_id: "meso", workout_template_id: "dp-upper-a" }));
        out.push(session(`lo-a-${k}`, w * 7 + 5, "Lower A", [
            exercise("system-barbell-squat", "Barbell Squat", [set(5, squat), set(5, squat), set(5, squat)]),
            exercise("system-lying-leg-curl", "Lying Leg Curl", [set(12, 40), set(12, 40)]),
        ], { mesocycle_id: "meso", workout_template_id: "dp-lower-a", notes: k === weeks - 1 ? "Knees felt fine, depth good." : null }));
        out.push(session(`up-b-${k}`, w * 7 + 3, "Upper B", [
            exercise("system-dumbbell-seated-shoulder-press", "Dumbbell Seated Shoulder Press", [set(10, 22), set(10, 22), set(8, 22)]),
            exercise("system-cable-neutral-grip-lat-pulldown", "Neutral Grip Lat Pulldown", [set(10, 55), set(10, 55), set(10, 55)]),
        ], { mesocycle_id: "meso", workout_template_id: "dp-upper-b" }));
        out.push(session(`lo-b-${k}`, w * 7 + 1, "Lower B", [
            exercise("system-barbell-romanian-deadlift", "Barbell Romanian Deadlift", [set(8, squat * 0.8), set(8, squat * 0.8), set(8, squat * 0.8)]),
            exercise("system-seated-plate-loaded-machine-calf-raise", "Seated Calf Raise", [set(15, 40), set(15, 40)]),
        ], { mesocycle_id: "meso", workout_template_id: "dp-lower-b" }));
    }
    return out;
}

const mesocycle = {
    id: "meso", author_id: "u", name: "Upper / Lower Strength", num_microcycles: 10, deload: "end", periodisation: false,
    workout_templates: [
        dayPlan("dp-upper-a", "Upper A", ["Barbell Bench Press", "Seated Row", "Single Arm Row"]),
        dayPlan("dp-lower-a", "Lower A", ["Barbell Squat", "Lying Leg Curl"]),
        dayPlan("dp-rest", "Rest", []),
        dayPlan("dp-upper-b", "Upper B", ["Dumbbell Seated Shoulder Press", "Neutral Grip Lat Pulldown"]),
        dayPlan("dp-lower-b", "Lower B", ["Barbell Romanian Deadlift", "Seated Calf Raise"]),
    ],
};

const macrocycle = (weeks) => ({
    id: "macro", author_id: "u", name: "Autumn Strength", mesocycle_ids: ["meso"], status: "active", mesocycle_index: 0,
    mesocycle_started_at: at(weeks * 7 + 7), start_microcycle_index: 0, skips: [], date_modified: at(weeks * 7 + 7),
});

const baseUser = (over) => ({
    user_id: "u", submitted_first_name: "Sam", submitted_gender: "male", submitted_height_centimeters: 180,
    submitted_weight_kilograms: 84, submitted_date_of_birth: new Date("1994-04-02T00:00:00Z"),
    submitted_daily_activity_level: "moderate", submitted_exercise_frequency: "3-4",
    submitted_weight_unit_preference: "kilograms", submitted_distance_unit_preference: "kilometers",
    submitted_active_mesocycle_id: "meso", weekly_session_goal: 4, ...over,
});

const settings = { timezone: "Europe/London", coach_consent: true, coach_consent_at: new Date("2026-10-01T09:00:00Z") };

export const FIXTURE_ACCOUNTS = {
    cutting: {
        user: baseUser({}),
        privateSettings: settings,
        analyticsSettings: { daily_step_goal: 10000 },
        goals: [{ user_id: "u", objective: "loseWeight", starting_weight_kg: 84, target_weight_kg: 78, weekly_change_kg: 0.5, created_at: at(60), status: "active" }],
        dietPlan: flatPlan(2200, 180, 220, 70),
        strategySettings: { calculation_mode: "dynamic", step_informed_updates: true, check_in_weekday: 2 },
        sessions: upperLower(8, 90, 2.5, 120, 5),
        meals: meals(60, 2150, { notes: { 2: "Ate out, guessed the portions." } }),
        measurements: weighIns(60, 84, -0.07),
        steps: stepsFor(60, 10500),
        mesocycles: [mesocycle],
        macrocycles: [macrocycle(8)],
        checkInRecord: { last_completed_week_start: at(7) },
    },
    bulking: {
        user: baseUser({ submitted_first_name: "Alex", submitted_gender: "female", submitted_height_centimeters: 167, submitted_weight_kilograms: 60, submitted_weight_unit_preference: "pounds", submitted_distance_unit_preference: "miles", weekly_session_goal: 4 }),
        privateSettings: { ...settings, timezone: "America/New_York" },
        goals: [{ user_id: "u", objective: "gainWeight", starting_weight_kg: 60, target_weight_kg: 64, weekly_change_kg: 0.25, created_at: at(56), status: "active" }],
        dietPlan: flatPlan(2550, 130, 330, 80),
        strategySettings: { calculation_mode: "dynamic", step_informed_updates: false },
        sessions: upperLower(8, 45, 1.25, 70, 2.5),
        meals: meals(56, 2550, { protein: 0.2 }),
        measurements: weighIns(56, 60, 0.035),
        steps: stepsFor(56, 7000),
        mesocycles: [mesocycle],
        macrocycles: [macrocycle(8)],
    },
    stalled: {
        user: baseUser({ submitted_first_name: "Jordan", submitted_weight_kilograms: 90 }),
        privateSettings: settings,
        goals: [{ user_id: "u", objective: "loseWeight", starting_weight_kg: 91, target_weight_kg: 84, weekly_change_kg: 0.5, created_at: at(70), status: "active" }],
        dietPlan: flatPlan(2200, 180, 210, 70),
        strategySettings: { calculation_mode: "dynamic", step_informed_updates: false },
        annotations: [{ day_key: dayKey(at(4)), is_partially_logged: true }],
        sessions: upperLower(6, 100, 0, 140, 0, { stallBench: true }),
        meals: meals(56, 2650, { skipEvery: 3 }),
        measurements: weighIns(56, 90, 0, { every: 2 }),
        steps: stepsFor(56, 5500),
        mesocycles: [mesocycle],
        macrocycles: [macrocycle(6)],
    },
    brandNew: {
        user: baseUser({ submitted_first_name: "Riley", submitted_active_mesocycle_id: null, submitted_weight_kilograms: 75, submitted_gender: "female", submitted_height_centimeters: 170 }),
        privateSettings: settings,
    },
};
