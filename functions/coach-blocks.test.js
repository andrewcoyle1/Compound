// Generative UI blocks: the arguments the model may give, what each block builds from the fixture
// accounts, the cap, the walls, storage and history, and the whole loop through real Genkit with a
// scripted model in place of Gemini.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { genkit } from "genkit";
import {
    fixtureSource, coachEnvironment, COACH_TOOLS, coachSystemPrompt, historyForModel, defineCoachTools, runCoach,
    validateCoachRequest,
} from "./coach.js";
import {
    coachBlocks, parseBlockArgs, defineShowBlockTool, blockChunk, storedBlock, fitStoredBlocks,
    COACH_MAX_BLOCKS, A2UI_VERSION, COACH_CATALOG_ID,
} from "./coach-blocks.js";
import { FIXTURE_ACCOUNTS, FIXTURE_NOW } from "./coach-fixtures.js";

const scope = async (name, account = FIXTURE_ACCOUNTS[name]) => {
    const source = fixtureSource(account);
    return { source, env: await coachEnvironment(source, FIXTURE_NOW), cache: new Map() };
};
// Shows one block on a fresh reply and returns what the model is told and the block.
const show = async (name, args) => {
    const blocks = coachBlocks({ messageId: "msg" });
    const told = await blocks.add(args, await scope(name));
    return { told, block: blocks.list[0], data: blocks.list[0]?.messages[2].updateDataModel.value };
};
const rootOf = (block) => block.messages[1].updateComponents.components[0];
const BLOCK_ARGS = {
    trend_chart: { kind: "trend_chart", metric: "weight", rangeDays: 28 },
    target_bars: { kind: "target_bars", day: "today" },
    stat_row: { kind: "stat_row", stats: ["weight_trend", "expenditure"] },
    actions: { kind: "actions", actions: [{ kind: "log_weight" }, { kind: "open_exercise", exerciseId: "system-barbell-bench-press" }] },
    follow_ups: { kind: "follow_ups", questions: ["How is my squat going?"] },
};

// MARK: - Request

test("ui is catalog 1 or nothing: an unknown catalog version gets today's text-only coach", () => {
    // iOS's callable SDK can send the app's 1 as true, so 1, true and "1" all mean catalog 1.
    for (const ui of [1, true, "1"]) assert.equal(validateCoachRequest({ message: "hi", ui }).ui, 1, String(ui));
    for (const ui of [undefined, null, 0, false, 2, "2", 1.5]) assert.equal(validateCoachRequest({ message: "hi", ui }).ui, null, String(ui));
});

// MARK: - Each kind

test("trend_chart weight: the weigh-ins and the app's trend, bound by path, in the user's units", async () => {
    const { told, block, data } = await show("cutting", { kind: "trend_chart", metric: "weight", rangeDays: 28 });
    assert.deepEqual(block.messages.map((m) => Object.keys(m)), [["version", "createSurface"], ["version", "updateComponents"], ["version", "updateDataModel"]]);
    assert.deepEqual(block.messages[0], { version: A2UI_VERSION, createSurface: { surfaceId: "msg-0", catalogId: COACH_CATALOG_ID } });
    assert.deepEqual(block.messages[1].updateComponents, { surfaceId: "msg-0", components: [
        { id: "root", component: "TrendChart", metric: "weight", points: { path: "/points" }, trend: { path: "/trend" }, unit: { path: "/unit" } },
    ] });
    assert.deepEqual(block.messages[2].updateDataModel.path, "/");
    const body = await COACH_TOOLS.get_body_metrics(...Object.values(await scope("cutting")).slice(0, 2), { days: 28 });
    assert.deepEqual(data, { points: body.weighIns.map((w) => ({ x: w.day, y: w.weight })), trend: body.weighIns.map((w) => ({ x: w.day, y: w.trend })), unit: "kg" });
    assert.deepEqual([block.surfaceId, block.kind, block.asOf], ["msg-0", "trend_chart", "2026-10-05"]);
    assert.equal(block.fallback, "Weight trend, 2026-09-08 to 2026-10-05: 81.7 → 79.8 kg.");
    assert.deepEqual(told, { shown: true, shows: block.fallback });
});

test("trend_chart weight cut short by the 60 weigh-in cap covers, and says, only the days shown", async () => {
    // Cutting weighs in daily for 61 days: a 90-day chart gets the latest 60.
    const { block, data } = await show("cutting", { kind: "trend_chart", metric: "weight", rangeDays: 90 });
    assert.equal(data.points.length, 60);
    assert.deepEqual([data.points[0].x, data.points.at(-1).x], ["2026-08-07", "2026-10-05"]);
    assert.match(block.fallback, /^Weight trend, 2026-08-07 to 2026-10-05: [\d.]+ → [\d.]+ kg \(the latest 60 weigh-ins\)\.$/);
    // A range the weigh-ins fit is not marked.
    assert.doesNotMatch((await show("cutting", { kind: "trend_chart", metric: "weight", rangeDays: 60 })).block.fallback, /latest/);
});

test("trend_chart exercise_e1rm: the app's estimated 1RM per session, named, in pounds for a pounds user", async () => {
    const { block, data } = await show("cutting", { kind: "trend_chart", metric: "exercise_e1rm", exerciseId: "system-barbell-bench-press", rangeDays: 56 });
    assert.deepEqual(rootOf(block), { id: "root", component: "TrendChart", metric: "exercise_e1rm", points: { path: "/points" }, unit: { path: "/unit" }, exerciseName: { path: "/exerciseName" } });
    assert.equal(data.exerciseName, "Barbell Bench Press");
    assert.equal(data.points.length, 8);
    assert.deepEqual(data.points.at(-1), { x: "2026-09-29", y: 125.4 });
    assert.equal(block.fallback, "Estimated 1RM, Barbell Bench Press, 2026-08-11 to 2026-09-29: 105 → 125.4 kg.");

    const bulk = await show("bulking", { kind: "trend_chart", metric: "exercise_e1rm", exerciseId: "system-barbell-squat", rangeDays: 28 });
    assert.equal(bulk.data.unit, "lb");
    assert.equal(bulk.data.points.length, 4, "only the sessions inside the range");
});

test("trend_chart expenditure and steps", async () => {
    const expenditure = await show("bulking", { kind: "trend_chart", metric: "expenditure", rangeDays: 14 });
    assert.deepEqual(rootOf(expenditure.block), { id: "root", component: "TrendChart", metric: "expenditure", points: { path: "/points" }, unit: { path: "/unit" } });
    assert.equal(expenditure.data.unit, "kcal");
    assert.equal(expenditure.data.points.length, 14);
    assert.equal(expenditure.block.fallback, "Expenditure, 2026-09-22 to 2026-10-05: 2,311 → 2,287 kcal.");

    const steps = await show("bulking", { kind: "trend_chart", metric: "steps", rangeDays: 7 });
    assert.equal(steps.data.unit, "steps");
    assert.equal(steps.block.fallback, "Steps, 2026-09-29 to 2026-10-04: 6,666 steps a day on average.");
});

test("target_bars: a day's totals against its targets, null where nothing is logged", async () => {
    const stalled = await show("stalled", { kind: "target_bars", day: "2026-10-01" });
    assert.deepEqual(rootOf(stalled.block), { id: "root", component: "TargetBars", rows: { path: "/rows" }, day: { path: "/day" } });
    assert.deepEqual(stalled.data, { day: "2026-10-01", rows: [
        { nutrient: "calories", value: 2469, target: 2200, unit: "kcal" },
        { nutrient: "protein", value: 185, target: 180, unit: "g" },
        { nutrient: "carbs", value: 278, target: 210, unit: "g" },
        { nutrient: "fat", value: 69, target: 70, unit: "g" },
    ] });
    assert.equal(stalled.block.fallback, "Food on 2026-10-01 (partly logged): 2,469 of 2,200 kcal, 185 of 180 g protein, 278 of 210 g carbs, 69 of 70 g fat.");

    const today = await show("cutting", { kind: "target_bars", day: "today" });
    assert.equal(today.data.day, "2026-10-05");
    assert.deepEqual(today.data.rows.map((r) => r.value), [null, null, null, null]);
    assert.equal(today.block.fallback, "Food on 2026-10-05: nothing logged; targets 2,200 kcal, 180 g protein, 220 g carbs, 70 g fat.");
});

test("stat_row: each stat from its tool, with its unit kind; a figure the tools lack is null", async () => {
    const cutting = await show("cutting", { kind: "stat_row", stats: ["weight_trend", "weight_rate_per_week", "exercise_e1rm:system-barbell-bench-press"] });
    assert.deepEqual(rootOf(cutting.block), { id: "root", component: "StatRow", stats: { path: "/stats" } });
    assert.deepEqual(cutting.data.stats, [
        { key: "weight_trend", value: 79.8, unit: "kg" },
        { key: "weight_rate_per_week", value: -0.5, unit: "kg_per_week" },
        { key: "exercise_e1rm:system-barbell-bench-press", value: 125.4, unit: "kg", exerciseName: "Barbell Bench Press" },
    ]);
    assert.equal(cutting.block.fallback, "Trend weight: 79.8 kg; Weekly change: −0.5 kg/wk; Barbell Bench Press estimated 1RM: 125.4 kg.");

    const bulking = await show("bulking", { kind: "stat_row", stats: ["goal_weight", "expenditure", "steps_average"] });
    assert.deepEqual(bulking.data.stats.map((s) => [s.key, s.unit]), [["goal_weight", "lb"], ["expenditure", "kcal"], ["steps_average", "steps"]]);
    assert.equal(bulking.data.stats[0].value, 141.1);

    const fresh = await show("brandNew", { kind: "stat_row", stats: ["weight_trend", "today_protein", "calorie_target"] });
    assert.deepEqual(fresh.data.stats.map((s) => s.value), [null, null, null]);
    assert.equal(fresh.block.fallback, "Trend weight: not available; Protein today: not available; Calorie target today: not available.");
});

test("actions open screens, named from the user's own sessions; follow-ups are plain questions", async () => {
    const actions = await show("cutting", { kind: "actions", actions: [{ kind: "log_weight" }, { kind: "open_exercise", exerciseId: "system-barbell-bench-press" }, { kind: "open_metric", metric: "expenditure" }] });
    assert.deepEqual(rootOf(actions.block), { id: "root", component: "Actions", actions: { path: "/actions" } });
    assert.deepEqual(actions.data.actions, [
        { kind: "log_weight" },
        { kind: "open_exercise", exerciseId: "system-barbell-bench-press", exerciseName: "Barbell Bench Press" },
        { kind: "open_metric", metric: "expenditure" },
    ]);
    assert.equal(actions.block.fallback, "You can: Log weight; Open Barbell Bench Press; Open expenditure.");

    const followUps = await show("cutting", { kind: "follow_ups", questions: [" How is my squat going? ", "What should I eat tonight?"] });
    assert.deepEqual(rootOf(followUps.block), { id: "root", component: "FollowUps", questions: { path: "/questions" } });
    assert.deepEqual(followUps.data, { questions: ["How is my squat going?", "What should I eat tonight?"] });
});

// MARK: - Arguments

test("arguments are checked strictly; a bad block is not shown and the model is told why", async () => {
    const { env } = await scope("cutting");
    const bad = [
        [{}, /kind must be one of/],
        [{ kind: "pie_chart" }, /kind must be one of/],
        [{ kind: "trend_chart", metric: "weight", rangeDays: 28, colour: "red" }, /trend_chart takes no colour/],
        [{ kind: "trend_chart", metric: "body_fat", rangeDays: 28 }, /metric must be one of/],
        [{ kind: "trend_chart", metric: "weight", rangeDays: 6 }, /rangeDays/],
        [{ kind: "trend_chart", metric: "weight", rangeDays: 366 }, /rangeDays/],
        [{ kind: "trend_chart", metric: "weight", rangeDays: 28.5 }, /rangeDays/],
        [{ kind: "trend_chart", metric: "weight", rangeDays: 28, exerciseId: "x" }, /only exercise_e1rm/],
        [{ kind: "trend_chart", metric: "exercise_e1rm", rangeDays: 28 }, /needs the exerciseId/],
        [{ kind: "trend_chart", metric: "exercise_e1rm", rangeDays: 28, exerciseId: "../users/other" }, /needs the exerciseId/],
        [{ kind: "target_bars", day: "yesterday" }, /day must be/],
        [{ kind: "target_bars", day: "2026-02-30" }, /day must be/],
        [{ kind: "target_bars", day: "2026-10-06" }, /within the last 90 days/],
        [{ kind: "target_bars", day: "2026-07-01" }, /within the last 90 days/],
        [{ kind: "stat_row", stats: [] }, /1 to 3/],
        [{ kind: "stat_row", stats: ["expenditure", "expenditure"] }, /different/],
        [{ kind: "stat_row", stats: ["a", "b", "c", "d"] }, /1 to 3/],
        [{ kind: "stat_row", stats: ["body_fat"] }, /unknown stat body_fat/],
        [{ kind: "stat_row", stats: ["exercise_e1rm:"] }, /unknown stat/],
        [{ kind: "actions", actions: [{ kind: "delete_workout" }] }, /action kind/],
        [{ kind: "actions", actions: [{ kind: "log_meal", metric: "weight" }] }, /open_metric, and only it/],
        [{ kind: "actions", actions: [{ kind: "open_metric", metric: "sleep" }] }, /open_metric, and only it/],
        [{ kind: "actions", actions: [{ kind: "open_exercise" }] }, /open_exercise, and only it/],
        [{ kind: "actions", actions: [{ kind: "log_weight", calories: 500 }] }, /takes no calories/],
        [{ kind: "actions", actions: [null] }, /action kind/],
        [{ kind: "follow_ups", questions: ["x".repeat(81)] }, /80 characters/],
        ...[
            "Why did I eat 2400 kcal?", "Why did I eat 2,400 yesterday?", "Is 82.5 a good target?", "Should I drop to 80 kg?",
            "Is 150g of protein enough?", "Can I lose 1% a week?", "Why only 6000 steps?", "Should I run 5 km more?",
            "Why am I eating more than 2 meals late?", "Is 80 → 78 too fast?", "Bench 100 vs 110?",
        ].map((q) => [{ kind: "follow_ups", questions: [q] }, /must not state figures/]),
        [{ kind: "follow_ups", questions: "Why?" }, /1 to 3/],
    ];
    for (const [args, reason] of bad) {
        const parsed = parseBlockArgs(args, env);
        assert.match(parsed.error ?? "", reason, JSON.stringify(args));
        const blocks = coachBlocks({ messageId: "m" });
        const told = await blocks.add(args, await scope("cutting"));
        assert.equal(told.shown, false);
        assert.match(told.reason, /^Not shown: /);
        assert.equal(blocks.list.length, 0);
    }
    // Asking is fine: small counts and 1RM are not figures about the user.
    for (const q of ["What's my squat 1RM?", "How was the last 4 weeks?", "How is my e1RM trending?", "What should I do in week 3?", "How do I hit my protein target?"]) {
        assert.deepEqual(parseBlockArgs({ kind: "follow_ups", questions: [q] }, env), { kind: "follow_ups", questions: [q] }, q);
    }
    // A null setting is absent, as Gemini sends unset optional fields.
    assert.deepEqual(parseBlockArgs({ kind: "trend_chart", metric: "weight", rangeDays: 28, exerciseId: null }, env), { kind: "trend_chart", metric: "weight", rangeDays: 28 });
});

test("a block with nothing to show, or an exercise the user never did, is dropped with the reason", async () => {
    for (const [name, args, reason] of [
        ["brandNew", { kind: "trend_chart", metric: "weight", rangeDays: 30 }, /no weight data in the last 30 days/],
        ["brandNew", { kind: "target_bars", day: "today" }, /nothing is logged and there are no targets/],
        ["cutting", { kind: "trend_chart", metric: "exercise_e1rm", exerciseId: "bench", rangeDays: 56 }, /no exercise_e1rm data/],
        ["cutting", { kind: "stat_row", stats: ["exercise_e1rm:system-unknown"] }, /no logged sessions for exercise_e1rm:system-unknown/],
        ["cutting", { kind: "actions", actions: [{ kind: "open_exercise", exerciseId: "system-unknown" }] }, /no logged sessions for exercise system-unknown/],
    ]) {
        const { told, block } = await show(name, args);
        assert.equal(told.shown, false, JSON.stringify(args));
        assert.match(told.reason, reason);
        assert.equal(block, undefined);
    }
});

test("a tool that fails drops the block without ending the reply", async () => {
    const broken = await scope("cutting");
    broken.source = { ...broken.source, measurements: async () => { throw new Error("offline"); } };
    const blocks = coachBlocks({ messageId: "m" });
    assert.deepEqual(await blocks.add(BLOCK_ARGS.trend_chart, broken), { shown: false, reason: "Not shown: it could not be built." });
    assert.equal((await blocks.add(BLOCK_ARGS.follow_ups, broken)).shown, true, "the queue goes on");
    assert.equal(blocks.list[0].surfaceId, "m-0");
});

// MARK: - The cap and the order

test("at most four blocks a reply, even asked for all at once; ids and the stream follow the order", async () => {
    const streamed = [];
    const blocks = coachBlocks({ messageId: "m", onBlock: (block) => streamed.push(blockChunk(block)) });
    const coach = await scope("cutting");
    const told = await Promise.all([...Object.values(BLOCK_ARGS), BLOCK_ARGS.follow_ups].map((args) => blocks.add(args, coach)));
    assert.deepEqual(told.map((t) => t.shown), [true, true, true, true, false, false]);
    assert.match(told[4].reason, /at most 4 blocks/);
    assert.equal(blocks.list.length, COACH_MAX_BLOCKS);
    assert.deepEqual(blocks.list.map((b) => b.surfaceId), ["m-0", "m-1", "m-2", "m-3"]);
    assert.deepEqual(blocks.list.map((b) => b.kind), ["trend_chart", "target_bars", "stat_row", "actions"]);
    // Every chunk keeps a text key: clients from before blocks throw without one.
    assert.deepEqual(streamed.map((c) => [typeof c.text, c.text, c.block.surfaceId]), blocks.list.map((b) => ["string", "", b.surfaceId]));
});

// MARK: - No literal values in components

test("components hold only bindings: every user value is in the data model", async () => {
    const blocks = coachBlocks({ messageId: "m" });
    const coach = await scope("cutting");
    for (const args of [BLOCK_ARGS.trend_chart, { kind: "trend_chart", metric: "exercise_e1rm", exerciseId: "system-barbell-bench-press", rangeDays: 28 },
        BLOCK_ARGS.stat_row, BLOCK_ARGS.actions]) await blocks.add(args, coach);
    const more = coachBlocks({ messageId: "n" });
    for (const args of [BLOCK_ARGS.target_bars, BLOCK_ARGS.follow_ups]) await more.add(args, coach);
    const components = [...blocks.list, ...more.list].flatMap((b) => b.messages[1].updateComponents.components);
    assert.equal(components.length, 6);
    const ENUM_PROPS = { id: ["root"], component: ["TrendChart", "TargetBars", "StatRow", "Actions", "FollowUps"], metric: ["weight", "exercise_e1rm", "expenditure", "steps"] };
    for (const component of components) {
        for (const [prop, value] of Object.entries(component)) {
            if (ENUM_PROPS[prop]) { assert.ok(ENUM_PROPS[prop].includes(value), `${prop}: ${value}`); continue; }
            assert.deepEqual(Object.keys(value), ["path"], `${component.component}.${prop} is not a binding`);
            assert.match(value.path, /^\/[a-zA-Z]+$/);
        }
        // Walk the whole tree: nothing numeric, no user text.
        const walk = (node) => {
            assert.notEqual(typeof node, "number", `a number in ${component.component}`);
            if (node && typeof node === "object") Object.values(node).forEach(walk);
        };
        walk(component);
        assert.doesNotMatch(JSON.stringify({ ...component, metric: null }), /Bench|kg|lb|kcal|\d/);
    }
    // And every binding resolves in that block's data model.
    for (const block of [...blocks.list, ...more.list]) {
        const data = block.messages[2].updateDataModel.value;
        for (const [prop, value] of Object.entries(rootOf(block))) if (value?.path) assert.ok(value.path.slice(1) in data, `${block.kind} binds ${value.path}`);
    }
});

// MARK: - The walls

test("blocks read only through the ten tools, so they reach nothing the tools cannot", async () => {
    const base = await scope("cutting");
    const allowed = Object.keys(base.source);
    const asked = new Set();
    const guarded = new Proxy(base.source, {
        get(target, name) {
            if (!allowed.includes(name)) throw new Error(`a block asked for ${String(name)}`);
            asked.add(name);
            return target[name];
        },
    });
    const coach = { ...base, source: guarded };
    for (const args of [...Object.values(BLOCK_ARGS),
        { kind: "trend_chart", metric: "exercise_e1rm", exerciseId: "system-barbell-bench-press", rangeDays: 365 },
        { kind: "trend_chart", metric: "expenditure", rangeDays: 365 }, { kind: "trend_chart", metric: "steps", rangeDays: 365 },
        { kind: "stat_row", stats: ["weight_rate_per_week", "goal_weight", "calorie_target"] },
        { kind: "stat_row", stats: ["protein_target", "today_calories", "today_protein"] },
        { kind: "stat_row", stats: ["steps_average", "exercise_e1rm:system-barbell-squat"] }]) {
        assert.equal((await coachBlocks({ messageId: "m" }).add(args, coach)).shown, true, JSON.stringify(args));
    }
    // Every read went through a tool, by its name.
    const tools = new Set([...coach.cache.keys()].map((key) => key.split(":")[0]));
    assert.ok([...tools].every((name) => name in COACH_TOOLS), [...tools].join());
    assert.ok(asked.size > 5);
    // And the module itself has no way to a document: no source method, path or Firestore call.
    const code = readFileSync(new URL("./coach-blocks.js", import.meta.url), "utf8").replace(/\/\/.*$/gm, "");
    assert.doesNotMatch(code, /\.source\b|source\.|collection\(|\.doc\(|firestore|strava|photo|follow(er|ing)/i);
});

// MARK: - Storage and history

test("a stored block is the streamed one with as_of, and is Firestore-safe", async () => {
    const blocks = coachBlocks({ messageId: "m" });
    const coach = await scope("cutting");
    for (const args of Object.values(BLOCK_ARGS).slice(0, 4)) await blocks.add(args, coach);
    for (const block of blocks.list) {
        const stored = storedBlock(block);
        assert.deepEqual(Object.keys(stored), ["surfaceId", "kind", "as_of", "fallback", "messages"]);
        assert.equal(stored.as_of, block.asOf);
        assert.deepEqual(stored.messages, block.messages);
        // Firestore takes no undefined and no array directly inside an array.
        const walk = (node, inArray) => {
            assert.notEqual(node, undefined);
            if (Array.isArray(node)) { assert.ok(!inArray, "nested array"); node.forEach((n) => walk(n, true)); } else if (node && typeof node === "object") Object.values(node).forEach((n) => walk(n, false));
        };
        walk(stored, false);
    }
});

test("blocks are emptied, oldest first, before a chat outgrows its document; the rest are kept", () => {
    const block = (n) => ({ surfaceId: `m${n}-0`, kind: "trend_chart", as_of: "2026-10-05", fallback: `Chart ${n}`, messages: [{ version: "v0.9", updateDataModel: { value: "x".repeat(1000) } }] });
    const messages = [0, 1, 2].flatMap((n) => [{ id: `u${n}`, role: "user", text: "q" }, { id: `m${n}`, role: "assistant", text: "a", blocks: [block(n)] }]);
    assert.equal(fitStoredBlocks(messages), messages, "under the budget, untouched");
    const fitted = fitStoredBlocks(messages, JSON.stringify(messages).length - 1500);
    assert.deepEqual(fitted.filter((m) => m.blocks).map((m) => m.blocks[0].messages.length), [0, 0, 1]);
    assert.deepEqual(fitted.filter((m) => m.blocks).map((m) => m.blocks[0].fallback), ["Chart 0", "Chart 1", "Chart 2"]);
});

test("the model's history reads each block as one [Shown: …] line after its reply", () => {
    const turns = [
        { role: "user", text: "Am I on track?" },
        { role: "assistant", text: "Yes, right on pace.", blocks: [{ fallback: "Weight trend, 2026-09-08 to 2026-10-05: 81.7 → 79.8 kg." }, { fallback: "You can: Log weight." }] },
        { role: "user", text: "And protein?" },
    ];
    assert.deepEqual(historyForModel(turns).map((m) => m.content[0].text), [
        "Am I on track?",
        "Yes, right on pace.\n[Shown: Weight trend, 2026-09-08 to 2026-10-05: 81.7 → 79.8 kg.]\n[Shown: You can: Log weight.]",
        "And protein?",
    ]);
    // Without blocks, exactly as before.
    assert.deepEqual(historyForModel([{ role: "user", text: "hi" }, { role: "assistant", text: "hello" }]).map((m) => m.content), [[{ text: "hi" }], [{ text: "hello" }]]);
});

// MARK: - The whole loop, through Genkit

/// A Genkit instance whose model follows a script: each turn returns the next step's tool calls,
/// or its text, and every request it got is kept.
function scripted(steps) {
    const ai = genkit({});
    const requests = [];
    const model = ai.defineModel({ name: "scripted", supports: { tools: true, multiturn: true, systemRole: true } }, async (request, send) => {
        requests.push(request);
        const step = steps[requests.length - 1];
        if (step.text) send?.({ content: [{ text: step.text }] });
        return {
            message: { role: "model", content: step.text ? [{ text: step.text }] : step.calls.map(([name, input], i) => ({ toolRequest: { name, ref: `${i}`, input } })) },
            finishReason: "stop",
        };
    });
    return { ai, model, requests, tools: defineCoachTools(ai), blockTool: defineShowBlockTool(ai) };
}

test("with ui, the model gets show_block and its guidance, and blocks are built from the cached tool results", async () => {
    const run = scripted([
        { calls: [["get_body_metrics", { days: 28 }], ["show_block", BLOCK_ARGS.trend_chart], ["show_block", { kind: "stat_row", stats: ["body_fat"] }]] },
        { text: "You're on track." },
    ]);
    const { source, env } = await scope("cutting");
    const streamed = [];
    const blocks = coachBlocks({ messageId: "msg", onBlock: (block) => streamed.push(blockChunk(block)) });
    const text = await runCoach({ ...run, config: {}, source, env, history: [], message: "Am I on track?", context: null, blocks, onChunk: (t) => streamed.push({ text: t }) });

    assert.equal(text, "You're on track.");
    assert.ok(run.requests[0].tools.some((t) => t.name === "show_block"));
    assert.match(run.requests[0].messages[0].content[0].text, /show_block puts a card/);
    const responses = run.requests[1].messages.at(-1).content.map((part) => part.toolResponse);
    assert.deepEqual(responses[1].output, { shown: true, shows: "Weight trend, 2026-09-08 to 2026-10-05: 81.7 → 79.8 kg." });
    assert.match(responses[2].output.reason, /unknown stat body_fat/);
    // The chart is the tool result the model read, point for point.
    assert.deepEqual(blocks.list[0].messages[2].updateDataModel.value.points, responses[0].output.weighIns.map((w) => ({ x: w.day, y: w.weight })));
    assert.deepEqual(streamed.map((c) => Object.keys(c)), [["text", "block"], ["text"]]);
});

test("without ui the request is the text-only one: no show_block, no guidance, eight turns", async () => {
    const run = scripted([{ calls: [["get_profile_and_targets", {}]] }, { text: "Hi." }]);
    const { source, env } = await scope("cutting");
    const context = { kind: "weight_trend", id: null, date: null };
    assert.equal(await runCoach({ ...run, config: {}, source, env, history: [], message: "Hello", context, onChunk: null }), "Hi.");
    const [request] = run.requests;
    assert.deepEqual(request.tools.map((t) => t.name).sort(), Object.keys(COACH_TOOLS).sort());
    assert.equal(request.messages[0].content[0].text, coachSystemPrompt(env, context));
    assert.doesNotMatch(coachSystemPrompt(env, context), /show_block|Blocks:/);
    assert.equal(coachSystemPrompt(env, context, null), coachSystemPrompt(env, context));
    assert.equal(coachSystemPrompt(env, context, 2), coachSystemPrompt(env, context));
    // Offering show_block to a text-only reply cannot happen by accident: the tool says so.
    const lone = scripted([{ calls: [["show_block", BLOCK_ARGS.follow_ups]] }, { text: "ok" }]);
    await runCoach({ ...lone, tools: [...lone.tools, lone.blockTool], config: {}, source, env, history: [], message: "x", context: null });
    assert.match(lone.requests[1].messages.at(-1).content[0].toolResponse.output.reason, /blocks are off/);
});
