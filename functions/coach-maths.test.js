// The JS port against the fixture the Swift wrote; CoachParityTests.swift checks the other side.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
    expenditureHistory, expenditureSamples, estimateTDEE, weightTrend, exerciseOneRM, weeklyMuscleSets, pairedSetCount,
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
    expenditureEngine: (c) => expenditureHistory({ samples: c.samples, priorKcal: c.priorKcal, settings: c.settings, today: c.today }),
    expenditureSamples: (c) => expenditureSamples(c),
    tdee: (c) => estimateTDEE(c.profile, { equation: c.equation, bodyFatPercentage: c.bodyFatPercentage }),
    weightTrend: (c) => weightTrend(c.values),
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
