// Rewrites the `expected` value of every case in CompoundUnitTests/Fixtures/coach-parity.json
// from functions/coach-maths.js. Run it after changing the maths in both languages:
//
//   node scripts/coach-parity-expected.mjs
//
// The JS is a line-for-line port of the Swift, and CoachParityTests.swift checks the Swift against
// the same values, so a Swift change the port has not followed still fails there.
import { readFileSync, writeFileSync } from "node:fs";

const root = new URL("..", import.meta.url).pathname;
const m = await import(`${root}functions/coach-maths.js`);
const path = `${root}CompoundUnitTests/Fixtures/coach-parity.json`;
const fixture = JSON.parse(readFileSync(path, "utf8"));

// The same runners as functions/coach-maths.test.js.
const shape = (sessions) => sessions.map((s) => ({ ...s, at: Date.parse(`${s.day}T12:00:00Z`) + s.order * 1000 }));
const runners = {
    expenditureEngine: (c) => m.expenditureHistory({ samples: c.samples, priorKcal: c.priorKcal, settings: c.settings, today: c.today, kcalPerKg: c.kcalPerKg }),
    expenditureSamples: (c) => m.expenditureSamples(c),
    tdee: (c) => m.estimateTDEE(c.profile, { equation: c.equation, bodyFatPercentage: c.bodyFatPercentage }),
    weightTrend: (c) => m.weightTrend(c.values, c.days ?? null),
    oneRepMax: (c) => Object.fromEntries(Object.entries(m.exerciseOneRM(shape(c.sessions))).map(([id, a]) => [id, {
        name: a.name, latest1RM: a.latest1RM, last7Workouts: a.last7Workouts,
    }])),
    weeklyMuscleSets: (c) => m.weeklyMuscleSets(shape(c.sessions), c.templates, c.endDay, c.weeks, Object.keys(c.expected)),
    pairedSetCount: (c) => m.pairedSetCount(c.sides.map((side) => ({ side }))),
};

for (const [key, run] of Object.entries(runners)) for (const testCase of fixture[key]) testCase.expected = run(testCase);

const sortKeys = (v) => (Array.isArray(v) ? v.map(sortKeys)
    : v && typeof v === "object" ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys(v[k])])) : v);
writeFileSync(path, JSON.stringify(sortKeys(fixture), null, 2) + "\n");
