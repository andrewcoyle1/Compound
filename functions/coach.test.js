// The coach's pure parts: the request, consent, quota, premium, chats, every tool against the
// fixture accounts, and the walls around what the model can read.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
    validateCoachRequest, hasCoachConsent, planCoachQuota, isCoachPremium, chatTitle, appendChatMessages, historyForModel,
    fixtureSource, firestoreSource, coachEnvironment, COACH_TOOLS, coachSystemPrompt, mesocycleProgress,
    COACH_DAILY_LIMIT, COACH_BURST_LIMIT, COACH_MAX_STORED_MESSAGES, MUSCLES,
} from "./coach.js";
import { FIXTURE_ACCOUNTS, FIXTURE_NOW } from "./coach-fixtures.js";

const envFor = async (name) => {
    const source = fixtureSource(FIXTURE_ACCOUNTS[name]);
    return { source, env: await coachEnvironment(source, FIXTURE_NOW) };
};

// MARK: - Request

test("coach requests are checked at the boundary", () => {
    assert.deepEqual(validateCoachRequest({ message: "  How am I doing?  " }), { chatId: null, message: "How am I doing?", context: null });
    assert.deepEqual(validateCoachRequest({ chatId: "abc_1-2", message: "hi", context: { kind: "exercise", id: "system-barbell-bench-press" } }).context,
        { kind: "exercise", id: "system-barbell-bench-press", date: null });
    assert.equal(validateCoachRequest({ message: "x", context: { kind: "nutrition_day", date: "2026-10-01" } }).context.date, "2026-10-01");
    for (const bad of [
        {}, { message: "   " }, { message: "x".repeat(2001) }, { message: 3 },
        { message: "x", chatId: "../other" }, { message: "x", chatId: 7 },
        { message: "x", context: { kind: "strava" } }, { message: "x", context: { kind: "nutrition_day", date: "Oct 1" } },
        { message: "x", context: { kind: "exercise", id: "x".repeat(200) } },
    ]) {
        assert.throws(() => validateCoachRequest(bad), { code: "invalid-argument" }, JSON.stringify(bad).slice(0, 60));
    }
});

test("consent is the boolean, so withdrawing it closes the coach though the timestamp stays", () => {
    assert.equal(hasCoachConsent({ coach_consent: true }), true);
    assert.equal(hasCoachConsent({ coach_consent: false, coach_consent_at: new Date() }), false);
    assert.equal(hasCoachConsent({ coach_consent_at: new Date() }), false);
    assert.equal(hasCoachConsent(null), false);
});

// MARK: - Quota

test("the quota counts per day, rolls over and refuses past the limit", () => {
    const first = planCoachQuota(undefined, { day: "2026-10-05", nowMs: 0 });
    assert.deepEqual(first, { allowed: true, remaining: COACH_DAILY_LIMIT - 1, next: { day: "2026-10-05", count: 1, recent: [0] } });

    const full = planCoachQuota({ day: "2026-10-05", count: COACH_DAILY_LIMIT, recent: [] }, { day: "2026-10-05", nowMs: 1e9 });
    assert.deepEqual(full, { allowed: false, reason: "quota", remaining: 0 });

    const nextDay = planCoachQuota({ day: "2026-10-05", count: COACH_DAILY_LIMIT, recent: [] }, { day: "2026-10-06", nowMs: 1e9 });
    assert.equal(nextDay.allowed, true);
    assert.equal(nextDay.next.count, 1);
});

test("a burst of messages in one minute is refused, and the minute passes", () => {
    const recent = Array.from({ length: COACH_BURST_LIMIT }, (_, i) => 1000 + i);
    assert.equal(planCoachQuota({ day: "d", count: 5, recent }, { day: "d", nowMs: 30_000 }).reason, "burst");
    const later = planCoachQuota({ day: "d", count: 5, recent }, { day: "d", nowMs: 62_000 });
    assert.equal(later.allowed, true);
    assert.deepEqual(later.next.recent, [62_000]);
});

// MARK: - Premium

test("premium is any active entitlement; a yes is cached and a no is not", async () => {
    const calls = [];
    const reply = (status, body) => async (url, init) => { calls.push({ url, init }); return new Response(JSON.stringify(body), { status }); };
    const cache = new Map();
    const options = { projectId: "proj1", apiKey: "sk", cache, nowMs: 0 };

    assert.equal(await isCoachPremium("u1", { ...options, fetchImpl: reply(200, { items: [{ entitlement_id: "e" }] }) }), true);
    assert.equal(calls[0].url, "https://api.revenuecat.com/v2/projects/proj1/customers/u1/active_entitlements");
    assert.equal(calls[0].init.headers.Authorization, "Bearer sk");
    assert.equal(await isCoachPremium("u1", { ...options, fetchImpl: reply(500, {}) }), true, "cached");
    assert.equal(await isCoachPremium("u1", { ...options, nowMs: 10 * 60_000, fetchImpl: reply(200, { items: [] }) }), false, "expired cache");

    assert.equal(await isCoachPremium("u2", { ...options, fetchImpl: reply(404, { message: "not found" }) }), false, "unknown customer");
    await assert.rejects(isCoachPremium("u3", { ...options, fetchImpl: reply(401, {}) }), { code: "unavailable" });
    await assert.rejects(isCoachPremium("u3", { ...options, fetchImpl: async () => { throw new Error("down"); } }), { code: "unavailable" });
    await assert.rejects(isCoachPremium("u3", { ...options, apiKey: "" }), { code: "unavailable" });
});

// MARK: - Chats

test("chat titles, the stored cap and the model's history window", () => {
    assert.equal(chatTitle("  How is   my bench?\n"), "How is my bench?");
    assert.equal(chatTitle("x".repeat(80)).length, 60);

    const many = Array.from({ length: COACH_MAX_STORED_MESSAGES }, (_, i) => ({ id: `${i}`, role: i % 2 ? "assistant" : "user", text: "t" }));
    const appended = appendChatMessages(many, [{ id: "new", role: "user", text: "q" }]);
    assert.equal(appended.length, COACH_MAX_STORED_MESSAGES);
    assert.equal(appended.at(-1).id, "new");
    assert.equal(appended[0].id, "1");

    const turns = [
        { role: "user", text: "a".repeat(50) }, { role: "assistant", text: "b".repeat(50) },
        { role: "user", text: "c".repeat(50) }, { role: "assistant", text: "d".repeat(50) },
    ];
    const window = historyForModel(turns, 120);
    assert.deepEqual(window.map((m) => m.role), ["user", "model"], "budget keeps the newest turns, opening with the user");
    assert.equal(window[0].content[0].text[0], "c");
    assert.deepEqual(historyForModel(undefined), []);
});

// MARK: - Tools

test("the environment carries the user's zone, today and units", async () => {
    assert.deepEqual(
        (({ timeZone, today, weightUnit, distanceUnit }) => ({ timeZone, today, weightUnit, distanceUnit }))((await envFor("bulking")).env),
        { timeZone: "America/New_York", today: "2026-10-05", weightUnit: "lb", distanceUnit: "mi" },
    );
    const { env } = await envFor("cutting");
    assert.equal(env.weightUnit, "kg");
    const unknownZone = await coachEnvironment(fixtureSource({ privateSettings: { timezone: "Mars/Olympus" } }), FIXTURE_NOW);
    assert.equal(unknownZone.timeZone, "UTC");
});

test("profile and targets read the goal, plan and today's target in the user's units", async () => {
    const { source, env } = await envFor("cutting");
    const profile = await COACH_TOOLS.get_profile_and_targets(source, env);
    assert.equal(profile.goal.objective, "loseWeight");
    assert.equal(profile.goal.plannedWeeklyChange, -0.5);
    assert.deepEqual(profile.dietPlan.todaysTarget, { calories: 2200, proteinG: 180, carbsG: 220, fatG: 70 });
    assert.equal(profile.weeklySessionGoal, 4);
    assert.equal(profile.ageYears, 32);

    const bulk = await envFor("bulking");
    const bulkProfile = await COACH_TOOLS.get_profile_and_targets(bulk.source, bulk.env);
    assert.equal(bulkProfile.goal.targetWeight, 141.1, "64 kg in pounds");
});

test("workout history lists sets, filters by exercise and leaves rest days out", async () => {
    const { source, env } = await envFor("cutting");
    const history = await COACH_TOOLS.get_workout_history(source, env, { days: 7 });
    assert.equal(history.sessionCount, 4);
    const benchOnly = await COACH_TOOLS.get_workout_history(source, env, { days: 14, exercise: "bench" });
    assert.ok(benchOnly.sessions.every((s) => s.exercises.every((e) => /Bench/.test(e.name))));
    assert.match(benchOnly.sessions[0].exercises[0].sets[0], /warm-up/);
    assert.equal(benchOnly.sessions[0].exercises[0].workingSetsCompleted, 3);
});

test("exercise progress gives the app's estimated 1RM and marks new bests", async () => {
    const { source, env } = await envFor("cutting");
    const progress = await COACH_TOOLS.get_exercise_progress(source, env, { exercise: "system-barbell-bench-press", weeks: 12 });
    assert.equal(progress.sessions.length, 8);
    assert.equal(progress.sessions.at(-1).estimated1RM, Math.round(107.5 * (1 + 5 / 30) * 10) / 10);
    assert.ok(progress.sessions.every((s) => s.newBestInRange), "bench went up every week");
    const stalled = await envFor("stalled");
    const flat = await COACH_TOOLS.get_exercise_progress(stalled.source, stalled.env, { exercise: "bench" });
    assert.equal(flat.sessions.filter((s) => s.newBestInRange).length, 1, "only the first session sets a best");
    assert.deepEqual(await COACH_TOOLS.get_exercise_progress(source, env, {}), { error: "Name the exercise." });
});

test("training volume counts working sets per muscle against the recommended range", async () => {
    const { source, env } = await envFor("cutting");
    const volume = await COACH_TOOLS.get_training_volume(source, env, { weeks: 2 });
    assert.deepEqual(Object.keys(volume.muscles).sort(), [...MUSCLES].sort());
    assert.deepEqual(volume.muscles.chest.weeklySets, [3, 3]);
    assert.equal(volume.muscles.chest.lastWeek, "below");
    // The single-arm row's left/right pair is one set for the lats.
    assert.ok(volume.muscles.lats.weeklySets.every((v) => v > 0));
});

test("nutrition shows each day against its target, with meals for short ranges only", async () => {
    const { source, env } = await envFor("stalled");
    const week = await COACH_TOOLS.get_nutrition(source, env, { days: 7 });
    assert.equal(week.days.length, 7);
    assert.equal(week.days.at(-1).day, "2026-10-05");
    assert.ok(week.days.some((d) => d.partiallyLogged), "the partial day is marked");
    assert.ok(week.days.some((d) => !d.logged), "skipped days stay unlogged");
    assert.ok(Array.isArray(week.days[0].meals));
    const month = await COACH_TOOLS.get_nutrition(source, env, { days: 30 });
    assert.equal(month.days[0].meals, undefined);
});

test("body metrics give weigh-ins with the app's trend", async () => {
    const { source, env } = await envFor("cutting");
    const body = await COACH_TOOLS.get_body_metrics(source, env, { days: 28 });
    assert.equal(body.weighIns.at(-1).day, "2026-10-05");
    assert.ok(body.trendChangeInRange < 0);
    const empty = await envFor("brandNew");
    assert.deepEqual((await COACH_TOOLS.get_body_metrics(empty.source, empty.env)).weighIns, []);
});

test("expenditure is adaptive with enough data and the formula estimate without", async () => {
    const { source, env } = await envFor("cutting");
    const expenditure = await COACH_TOOLS.get_expenditure(source, env, { days: 7 });
    assert.equal(expenditure.current.source, "adaptive");
    assert.equal(expenditure.history.length, 7);
    assert.equal(expenditure.current.day, "2026-10-05");

    const fresh = await envFor("brandNew");
    const prior = await COACH_TOOLS.get_expenditure(fresh.source, fresh.env);
    assert.equal(prior.current.source, "prior");
    assert.equal(prior.current.kcal, prior.formulaEstimateKcal);
});

test("an open logging break freezes expenditure on the day it began", async () => {
    const account = { ...FIXTURE_ACCOUNTS.cutting, loggingBreak: { start_date: new Date("2026-10-01T00:00:00+01:00"), end_date: null } };
    const source = fixtureSource(account);
    const env = await coachEnvironment(source, FIXTURE_NOW);
    const expenditure = await COACH_TOOLS.get_expenditure(source, env);
    assert.equal(expenditure.frozenByOpenLoggingBreak, true);
    assert.equal(expenditure.current.day, "2026-10-01");
});

test("steps, the plan and check-ins", async () => {
    const { source, env } = await envFor("cutting");
    const steps = await COACH_TOOLS.get_steps(source, env, { days: 7 });
    assert.equal(steps.dailyGoal, 10000);
    assert.ok(steps.days.length >= 6);
    const plan = await COACH_TOOLS.get_plan(source, env);
    assert.equal(plan.activeMesocycle.currentMicrocycle, 9);
    assert.equal(plan.activeMesocycle.nextWorkout.name, "Upper A");
    assert.equal(plan.macrocycle.name, "Autumn Strength");
    assert.deepEqual(await COACH_TOOLS.get_plan(fixtureSource(FIXTURE_ACCOUNTS.brandNew), env), { activeMesocycle: null });
    const checkIns = await COACH_TOOLS.get_check_ins(source, env);
    assert.equal(checkIns.checkInWeekday, "Monday");
});

test("the schedule fills each day's slot in the lowest open microcycle and honours skips", () => {
    const mesocycle = { id: "m", num_microcycles: 2, workout_templates: [
        { workout_id: "a", name: "A", exercises: [{}] }, { workout_id: "r", name: "Rest", exercises: [] }, { workout_id: "b", name: "B", exercises: [{}] },
    ] };
    const done = (templateId, at) => ({ mesocycleId: "m", templateId, name: "", at });
    assert.equal(mesocycleProgress(mesocycle, [], null).next.workout_id, "a");
    assert.equal(mesocycleProgress(mesocycle, [done("a", 1)], null).next.workout_id, "b");
    // B before A leaves A next; two As fill both microcycles.
    assert.equal(mesocycleProgress(mesocycle, [done("b", 1)], null).next.workout_id, "a");
    const both = mesocycleProgress(mesocycle, [done("a", 1), done("b", 2), done("a", 3)], null);
    assert.deepEqual([both.currentCycle, both.next.workout_id], [1, "b"]);
    const skipped = mesocycleProgress(mesocycle, [done("a", 1)], { mesocycle_index: 0, skips: [{ mesocycle_index: 0, cycle_index: 0, position: 2, template_id: "b" }] });
    assert.deepEqual([skipped.currentCycle, skipped.next.workout_id], [1, "a"]);
    assert.equal(mesocycleProgress(mesocycle, [done("a", 1), done("b", 2), done("a", 3), done("b", 4)], null).next, null);
});

// MARK: - The walls

// Every read goes through one of these methods, each bound to one allowed area. There is no way
// for a tool, or the model, to name a path.
const ALLOWED_SOURCE_METHODS = [
    "analyticsSettings", "annotations", "checkInRecord", "dietPlan", "goals", "loggingBreak", "macrocycles", "meals",
    "measurements", "mesocycles", "privateSettings", "sessions", "steps", "strategySettings", "user", "userExercises",
];

test("the data source has no way to reach Strava, photos or other people", () => {
    assert.deepEqual(Object.keys(fixtureSource({})).sort(), ALLOWED_SOURCE_METHODS);
    const paths = [];
    const ref = (path) => ({
        path,
        collection: (name) => ref(`${path}/${name}`),
        doc: (id) => ref(`${path}/${id}`),
        where: () => ref(path),
        get: async () => { paths.push(path); return { docs: [], exists: false }; },
    });
    const db = { collection: (name) => ref(name) };
    const source = firestoreSource(db, "u");
    assert.deepEqual(Object.keys(source).sort(), ALLOWED_SOURCE_METHODS);
    return Promise.all(Object.values(source).map((fn) => fn(null))).then(() => {
        for (const path of paths) {
            assert.ok(/^users\/u(\/|$)|^diet_plans\/u$|^exercise_templates$/.test(path), `unexpected read of ${path}`);
            assert.doesNotMatch(path, /strava|progress_photos|followers|following|notifications|comments|challenges/);
        }
    });
});

test("every tool reads only through the allowed methods", async () => {
    const touched = new Set();
    const base = fixtureSource(FIXTURE_ACCOUNTS.cutting);
    const guarded = new Proxy(base, {
        get(target, name) {
            if (!ALLOWED_SOURCE_METHODS.includes(name)) throw new Error(`tool asked for ${String(name)}`);
            touched.add(name);
            return target[name];
        },
    });
    const env = await coachEnvironment(base, FIXTURE_NOW);
    for (const [name, tool] of Object.entries(COACH_TOOLS)) await tool(guarded, env, name === "get_exercise_progress" ? { exercise: "bench" } : {});
    assert.ok(touched.size > 10);
});

test("the system prompt carries the rules and the context the user came from", () => {
    const env = { today: "2026-10-05", timeZone: "Europe/London", weightUnit: "kg", distanceUnit: "km", lengthUnit: "cm", firstName: "Sam" };
    const prompt = coachSystemPrompt(env, { kind: "exercise", id: "system-barbell-bench-press" });
    for (const rule of [/must come from a tool result/, /calorie floor/, /qualified professional/, /cannot log, edit, delete/, /no access to Strava/, /2026-10-05/, /kg for weight/, /Sam/]) {
        assert.match(prompt, rule);
    }
    assert.match(prompt, /exercise id "system-barbell-bench-press"/);
    assert.doesNotMatch(coachSystemPrompt(env, null), /Context:/);
});

test("the built-in exercise data is the app's own file, unchanged", () => {
    const app = readFileSync(new URL("../Compound/SupportingFiles/Resources/PrebuiltExercises.json", import.meta.url));
    const copy = readFileSync(new URL("./data/PrebuiltExercises.json", import.meta.url));
    assert.ok(app.equals(copy), "functions/data/PrebuiltExercises.json differs from the app's; copy it again");
});
