// The JS port against the fixture the Swift wrote; CoachParityTests.swift checks the other side.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
    expenditureHistory, expenditureSamples, estimateTDEE, weightTrend, exerciseOneRM, weeklyMuscleSets, pairedSetCount,
    estimated1RM, hardSets, energyDensityKcalPerKg,
} from "./coach-maths.js";

const fixture = JSON.parse(readFileSync(new URL("../CompoundUnitTests/Fixtures/coach-parity.json", import.meta.url), "utf8"));

// Equal JSON values, numbers within a millionth: the two languages round the last bit apart.
function assertMatches(actual, expected, path) {
    if (expected === null || typeof expected !== "object") {
        if (typeof expected === "number") {
            assert.equal(typeof actual, "number", `${path}: expected a number, got ${actual}`);
            assert.ok(Math.abs(actual - expected) <= 1e-6 * Math.max(1, Math.abs(expected)), `${path}: ${actual} != ${expected}`);
        } else {
            assert.equal(actual, expected, path);
        }
        return;
    }
    if (Array.isArray(expected)) {
        assert.ok(Array.isArray(actual), `${path}: expected an array`);
        assert.equal(actual.length, expected.length, `${path}: length`);
        expected.forEach((value, i) => assertMatches(actual[i], value, `${path}[${i}]`));
        return;
    }
    assert.deepEqual(Object.keys(actual ?? {}).sort(), Object.keys(expected).sort(), `${path}: keys`);
    for (const key of Object.keys(expected)) assertMatches(actual[key], expected[key], `${path}.${key}`);
}

// Sessions as the server shapes them: `at` orders them as the Swift's end times do (noon plus
// `order` seconds on their day).
const shapeSessions = (sessions) => sessions.map((s) => ({ ...s, at: Date.parse(`${s.day}T12:00:00Z`) + s.order * 1000 }));

const runners = {
    expenditureEngine: (c) => expenditureHistory({ samples: c.samples, priorKcal: c.priorKcal, settings: c.settings, today: c.today, kcalPerKg: c.kcalPerKg }),
    expenditureSamples: (c) => expenditureSamples(c),
    tdee: (c) => estimateTDEE(c.profile, { equation: c.equation, bodyFatPercentage: c.bodyFatPercentage }),
    weightTrend: (c) => weightTrend(c.values, c.days ?? null),
    oneRepMax: (c) => Object.fromEntries(Object.entries(exerciseOneRM(shapeSessions(c.sessions))).map(([id, a]) => [id, {
        name: a.name, latest1RM: a.latest1RM, last7Workouts: a.last7Workouts,
    }])),
    weeklyMuscleSets: (c) => weeklyMuscleSets(shapeSessions(c.sessions), c.templates, c.endDay, c.weeks, Object.keys(c.expected)),
    pairedSetCount: (c) => pairedSetCount(c.sides.map((side) => ({ side }))),
};

for (const [key, run] of Object.entries(runners)) {
    test(`coach maths match the Swift: ${key}`, () => {
        assert.ok(fixture[key]?.length > 0, `${key} has cases`);
        for (const testCase of fixture[key]) assertMatches(run(testCase), testCase.expected, `${key}/${testCase.name}`);
    });
}

// The rules ExerciseOneRMAggregatorTests.swift checks on the Swift side.
test("estimated 1RM: a single is the weight, reps in reserve count, nothing past ten reps to failure", () => {
    assert.equal(estimated1RM(100, 1), 100);
    assert.equal(estimated1RM(100, 1, 10), 100);
    assert.ok(Math.abs(estimated1RM(100, 6) - 120) < 1e-9);
    // 8 reps at RPE 8 is 10 reps to failure.
    assert.ok(Math.abs(estimated1RM(100, 8, 8) - 100 * (1 + 10 / 30)) < 1e-9);
    assert.equal(estimated1RM(100, 10), 100 * (1 + 10 / 30));
    assert.equal(estimated1RM(100, 11), null);
    assert.equal(estimated1RM(100, 9, 8), null);
    assert.equal(estimated1RM(0, 5), null);
});

// The hard-set rule MuscleVolumeTests (MuscleBalanceTests.swift) checks on the Swift side.
test("hard sets: easy sets drop out, sets without RPE count, drops and mini-sets add half up to two", () => {
    const set = (extra) => ({ isWarmup: false, completed: true, side: null, parentSetId: null, ...extra });
    assert.equal(hardSets({ sets: [set({ rpe: 8 }), set({ rpe: 5.5 }), set({}), set({ isWarmup: true }), set({ completed: false })] }), 2);
    assert.equal(hardSets({ sets: [set({ rpe: 6 })] }), 1);
    // A drop set with two drops: 1 + 0.5 + 0.5.
    assert.equal(hardSets({ sets: [set({ id: "a", kind: "drop" }), set({ id: "b", kind: "drop", parentSetId: "a" }), set({ id: "c", kind: "drop", parentSetId: "a" })] }), 2);
    // Capped at two however many mini-sets.
    const myo = [set({ id: "m", kind: "myo" }), ...[1, 2, 3, 4].map((i) => set({ id: `m${i}`, parentSetId: "m" }))];
    assert.equal(hardSets({ sets: myo }), 2);
    // A cluster's pieces are one set split up.
    assert.equal(hardSets({ sets: [set({ id: "k", kind: "cluster" }), set({ id: "k1", parentSetId: "k" })] }), 1);
    // A left/right pair is one set; with a drop on one side, worth its better half.
    assert.equal(hardSets({ sets: [set({ id: "l", side: "left" }), set({ id: "r", side: "right" })] }), 1);
    assert.equal(hardSets({ sets: [set({ id: "l", side: "left", kind: "drop" }), set({ id: "r", side: "right", kind: "drop" }), set({ id: "ld", side: "left", kind: "drop", parentSetId: "l" })] }), 1.5);
    // An easy left half leaves the right half to count.
    assert.equal(hardSets({ sets: [set({ id: "l", side: "left", rpe: 4 }), set({ id: "r", side: "right", rpe: 7 })] }), 1);
});

// The formula prior FormulaExpenditureTests.swift checks on the Swift side: Mifflin × a PAL from the
// FAO/WHO/UNU bands, no exercise-frequency term, Cunningham for the stored "katchMcArdle", the
// midpoint for a missing sex.
test("formula expenditure: PAL table, no frequency add-on, Cunningham, neutral sex", () => {
    const man = { gender: "male", weightKg: 80, heightCm: 180, ageYears: 36 };
    // Mifflin: 800 + 1125 − 180 + 5 = 1750.
    const pal = { sedentary: 1.4, light: 1.55, moderate: 1.7, active: 1.85, very_active: 2.0 };
    for (const [activity, multiplier] of Object.entries(pal)) {
        assert.ok(Math.abs(estimateTDEE({ ...man, activity }) - 1750 * multiplier) < 1e-9);
    }
    assert.equal(estimateTDEE({ ...man, activity: "moderate", exerciseFrequency: "daily" }), estimateTDEE({ ...man, activity: "moderate", exerciseFrequency: "never" }));
    // 80 kg at 20% body fat is 64 kg fat-free: 500 + 22 × 64 = 1908.
    assert.ok(Math.abs(estimateTDEE({ ...man, activity: "moderate" }, { equation: "katchMcArdle", bodyFatPercentage: 20 }) - 1908 * 1.7) < 1e-9);
    const unstated = estimateTDEE({ ...man, gender: undefined, activity: "moderate" });
    assert.ok(Math.abs(unstated - (1750 - 83) * 1.7) < 1e-9);
});

// MARK: - Weight trend and the expenditure filter (ExpenditureEngineTests / WeightTrendCalculatorTests
// check the same rules on the Swift side)

const DAY0 = "2026-03-01";
const dayAt = (i) => {
    const date = new Date(Date.UTC(2026, 2, 1) + i * 86_400_000);
    return date.toISOString().slice(0, 10);
};
// A small deterministic generator, so the noisy cases are the same every run.
function gaussians(seed) {
    let state = seed;
    const uniform = () => { state = (state * 16807) % 2147483647; return state / 2147483647; };
    return () => Math.sqrt(-2 * Math.log(uniform())) * Math.cos(2 * Math.PI * uniform());
}
const samplesFor = (n, intake, weight) => Array.from({ length: n }, (_, i) => ({
    day: dayAt(i), intakeKcal: intake(i), weightKg: weight(i), steps: null, isExcluded: false,
}));
const historyFor = (samples, prior = 2500, extra = {}) => expenditureHistory({ samples, priorKcal: prior, settings: {}, today: dayAt(samples.length), ...extra });

test("weight trend: a flat series stays flat, an outlier is ignored, the real gap in days counts", () => {
    assert.deepEqual(weightTrend([]), []);
    assert.deepEqual(weightTrend([72.4]), [72.4]);
    for (const v of weightTrend(Array(10).fill(72))) assert.ok(Math.abs(v - 72) < 1e-9);
    // A 90 among 72s is more than max(3 kg, 4%) off and nothing confirms it.
    for (const v of weightTrend([72, 72, 72, 90, 72, 72])) assert.ok(Math.abs(v - 72) < 1e-9);
    // A smaller spike is down-weighted, not clamped: it moves the trend, but by well under its size.
    const spiked = weightTrend([80, 80, 80, 80, 82.5, 80, 80, 80]);
    assert.ok(spiked[4] - 80 > 0 && spiked[4] - 80 < 0.5);
    // Two readings off the same way confirm a real shift.
    const shifted = weightTrend([80, 80, 80, 84, 84.1, 84]);
    assert.ok(shifted[5] > 83.5);
    // The same readings a week apart move further per reading than a day apart.
    const daily = weightTrend([80, 79.5, 79, 78.5, 78], null);
    const weekly = weightTrend([80, 79.5, 79, 78.5, 78], [0, 7, 14, 21, 28].map(dayAt));
    assert.ok(Math.abs(weekly[4] - 78) <= Math.abs(daily[4] - 78) + 1e-9);
    // Only the first weigh-in of a day counts.
    const sameDay = weightTrend([80, 85, 80, 80], [DAY0, DAY0, dayAt(1), dayAt(2)]);
    assert.ok(Math.abs(sameDay[3] - 80) < 1e-9);
});

test("energy density: Forbes-partitioned with body fat, 7,700 without", () => {
    assert.equal(energyDensityKcalPerKg(80, null), 7700);
    assert.equal(energyDensityKcalPerKg(null, 20), 7700);
    const fat = 25;
    const share = fat / (fat + 10.4);
    assert.ok(Math.abs(energyDensityKcalPerKg(100, 25) - (share * 9440 + (1 - share) * 1816)) < 1e-9);
});

test("expenditure filter: converges on the true expenditure through noise", () => {
    const noise = gaussians(7);
    // True expenditure 2,700: eating 2,200 ± 400 and losing 500/7700 kg a day, scale noise 0.5%.
    const samples = samplesFor(90, () => 2200 + 400 * noise(), (i) => 85 - (500 / 7700) * i + 0.005 * 85 * noise());
    const last = historyFor(samples, 2300).at(-1);
    assert.equal(last.source, "adaptive");
    assert.ok(Math.abs(last.kcal - 2700) < 1.28 * last.sdKcal + 50, `${last.kcal} ± ${last.sdKcal}`);
    assert.ok(last.sdKcal < 150);
    assert.ok(Math.abs(last.weeklyTrendChangeKg + 500 * 7 / 7700) < 0.15);
});

test("expenditure filter: calibrating until 21 days and 14 weigh-ins, then adaptive", () => {
    const history = historyFor(samplesFor(40, () => 2400, () => 80));
    assert.ok(history.slice(0, 21).every((e) => e.isProvisional && e.source === "prior" && e.kcal === 2500));
    assert.equal(history[21].source, "adaptive");
    assert.ok(Math.abs(history.at(-1).kcal - 2400) < 15);
    // Weigh-ins alone never calibrate: without food logs only the slope is known.
    const weightsOnly = historyFor(samplesFor(60, () => null, (i) => 80 - 0.05 * i));
    assert.ok(weightsOnly.every((e) => e.isProvisional));
    assert.ok(weightsOnly.at(-1).weeklyTrendChangeKg < -0.2);
});

test("expenditure filter: unlogged days only widen the uncertainty", () => {
    const logged = historyFor(samplesFor(40, () => 2400, () => 80));
    // Weigh-ins carry on without food logs: less certain than logging, never imputed.
    const unlogged = historyFor(samplesFor(40, (i) => (i >= 33 ? null : 2400), () => 80));
    assert.ok(unlogged.at(-1).sdKcal > logged.at(-1).sdKcal);
    // Nothing at all for a week: the filter only predicts, and the SD grows every day.
    const silent = historyFor(samplesFor(40, (i) => (i >= 33 ? null : 2400), (i) => (i >= 33 ? null : 80)));
    for (let i = 35; i <= 40; i++) assert.ok(silent[i].sdKcal > silent[i - 1].sdKcal);
    assert.ok(Math.abs(silent.at(-1).trendWeightKg - silent[33].trendWeightKg) < 0.05);
});

test("expenditure filter: a partial day is skipped unless it was a fast", () => {
    const base = samplesFor(40, () => 2400, () => 80);
    const partial = base.map((s, i) => (i === 35 ? { ...s, intakeKcal: 300 } : s));
    assert.deepEqual(historyFor(partial).at(-1).kcal, historyFor(base).at(-1).kcal);
    const fasted = partial.map((s, i) => (i === 35 ? { ...s, isFastingDay: true } : s));
    assert.ok(historyFor(fasted).at(-1).kcal < historyFor(base).at(-1).kcal);
});

test("expenditure filter: fixed mode holds the prior and still tracks the trend", () => {
    const history = historyFor(samplesFor(40, () => 2400, () => 80), 2500, { settings: { calculationMode: "fixed" } });
    assert.ok(history.every((e) => e.kcal === 2500 && e.source === "fixed" && !e.isProvisional && e.sdKcal === null));
    assert.ok(Math.abs(history.at(-1).trendWeightKg - 80) < 0.05);
});
