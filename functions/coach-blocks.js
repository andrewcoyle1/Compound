// Generative UI v1: the blocks the coach shows beside its answer (docs/specs/ai-coach.md,
// "Generative UI (v1)").
//
// The model only picks a block and its settings, through `show_block`. Every value in a block comes
// from the same tool code the model reads, through the request's tool cache, and the server lays it
// out as A2UI v0.9 messages for the app's own catalog: one surface per block, a single root
// component whose data props are all `{ path }` bindings, and a data model of raw numbers and unit
// kinds in the user's units. Blocks show and navigate; they never write. They read only through the
// ten tools, so nothing new is reachable.

import { z } from "genkit";
import { daysBetween, addDays } from "./coach-maths.js";
import { callCoachTool, WEIGH_IN_LIMIT } from "./coach.js";

export const COACH_MAX_BLOCKS = 4;
export const A2UI_VERSION = "v0.9";
export const COACH_CATALOG_ID = "compound.coach.v1";
const MAX_FOLLOW_UP_CHARS = 80;
const NUTRITION_MAX_DAYS = 90; // get_nutrition's longest range

const TREND_METRICS = ["weight", "exercise_e1rm", "expenditure", "steps"];
const STAT_KEYS = [
    "weight_trend", "weight_rate_per_week", "goal_weight", "expenditure", "calorie_target", "protein_target",
    "today_calories", "today_protein", "steps_average",
];
const ACTION_KINDS = ["log_weight", "log_meal", "start_workout", "open_exercise", "open_metric", "open_check_in", "open_diet_plan"];
const ACTION_METRICS = ["weight", "expenditure", "steps"];
const BLOCK_KEYS = {
    trend_chart: ["metric", "exerciseId", "rangeDays"],
    target_bars: ["day"],
    stat_row: ["stats"],
    actions: ["actions"],
    follow_ups: ["questions"],
};

// MARK: - Arguments

const isId = (value) => typeof value === "string" && /^[A-Za-z0-9_.:-]{1,128}$/.test(value);
const isDayKey = (value) => typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value) && addDays(value, 0) === value;
const present = (object) => Object.keys(object).filter((key) => object[key] != null);
const unique = (values) => new Set(values.map((v) => JSON.stringify(v))).size === values.length;
// A question that states a figure about the user, rather than asking: "2.5", "2,400", "80 kg",
// "15%", "more than 3", "2400". Plain small counts ("the last 4 weeks") and 1RM/e1RM are fine.
const FIGURE_PATTERNS = [
    /\d[.,]\d/,
    /\d\s*(%|(kg|kgs|lb|lbs|pounds?|kilos?|kcal|cal|calories|g|grams?|steps|km|mi|miles)\b)/i,
    /\b(more|less|fewer|over|under|above|below|than|vs|versus)\.?\s+\d|\d\s*(→|->|vs\b|versus\b)/i,
    /\d{3,}/,
];
const statesAFigure = (question) => FIGURE_PATTERNS.some((pattern) => pattern.test(question.replace(/\be?1RM\b/gi, "")));
const listOf = (value, min, max) => Array.isArray(value) && value.length >= min && value.length <= max;

const PARSERS = {
    trend_chart({ metric, exerciseId, rangeDays }) {
        if (!TREND_METRICS.includes(metric)) return { error: `metric must be one of ${TREND_METRICS.join(", ")}` };
        if (!Number.isInteger(rangeDays) || rangeDays < 7 || rangeDays > 365) return { error: "rangeDays must be a whole number from 7 to 365" };
        if (metric === "exercise_e1rm" && !isId(exerciseId)) return { error: "exercise_e1rm needs the exerciseId exactly as a tool returned it" };
        if (metric !== "exercise_e1rm" && exerciseId != null) return { error: "only exercise_e1rm takes an exerciseId" };
        return { metric, rangeDays, ...(metric === "exercise_e1rm" ? { exerciseId } : {}) };
    },
    target_bars({ day }, env) {
        const key = day === "today" ? env.today : day;
        if (!isDayKey(key)) return { error: "day must be \"today\" or YYYY-MM-DD" };
        const back = daysBetween(key, env.today);
        if (back < 0 || back >= NUTRITION_MAX_DAYS) return { error: `day must be today or within the last ${NUTRITION_MAX_DAYS} days` };
        return { day: key };
    },
    stat_row({ stats }) {
        if (!listOf(stats, 1, 3) || !unique(stats)) return { error: "stats must be 1 to 3 different stat keys" };
        const bad = stats.filter((s) => !STAT_KEYS.includes(s) && !(typeof s === "string" && s.startsWith("exercise_e1rm:") && isId(s.slice(14))));
        if (bad.length) return { error: `unknown stat ${bad.map(String).join(", ")}; use ${STAT_KEYS.join(", ")} or exercise_e1rm:<exerciseId>` };
        return { stats };
    },
    actions({ actions }) {
        if (!listOf(actions, 1, 3) || !unique(actions)) return { error: "actions must be 1 to 3 different actions" };
        const out = [];
        for (const action of actions) {
            const { kind, exerciseId, metric } = action ?? {};
            if (!ACTION_KINDS.includes(kind)) return { error: `action kind must be one of ${ACTION_KINDS.join(", ")}` };
            const extra = present(action ?? {}).filter((k) => !["kind", "exerciseId", "metric"].includes(k));
            if (extra.length) return { error: `an action takes no ${extra.join(", ")}` };
            if (kind === "open_exercise" ? !isId(exerciseId) : exerciseId != null) return { error: "open_exercise, and only it, takes the exerciseId a tool returned" };
            if (kind === "open_metric" ? !ACTION_METRICS.includes(metric) : metric != null) return { error: `open_metric, and only it, takes a metric: ${ACTION_METRICS.join(", ")}` };
            out.push({ kind, ...(exerciseId != null ? { exerciseId } : {}), ...(metric != null ? { metric } : {}) });
        }
        return { actions: out };
    },
    follow_ups({ questions }) {
        const trimmed = Array.isArray(questions) ? questions.map((q) => (typeof q === "string" ? q.trim() : "")) : null;
        if (!listOf(trimmed, 1, 3) || !unique(trimmed)) return { error: "questions must be 1 to 3 different questions" };
        if (trimmed.some((q) => q.length < 1 || q.length > MAX_FOLLOW_UP_CHARS)) return { error: `each question must be 1 to ${MAX_FOLLOW_UP_CHARS} characters` };
        // Suggested prompts, not facts: a figure in one would be a number the tools never gave.
        if (trimmed.some(statesAFigure)) return { error: "questions must not state figures (decimals, amounts with a unit, numbers over 99, or comparisons)" };
        return { questions: trimmed };
    },
};

/// The model's `show_block` arguments, checked strictly: `{ kind, ...settings }` with nothing
/// else, or `{ error }` saying why the block cannot be shown. A null setting counts as absent.
export function parseBlockArgs(input, env) {
    const { kind, ...settings } = input ?? {};
    if (!BLOCK_KEYS[kind]) return { error: `kind must be one of ${Object.keys(BLOCK_KEYS).join(", ")}` };
    const extra = present(settings).filter((key) => !BLOCK_KEYS[kind].includes(key));
    if (extra.length) return { error: `${kind} takes no ${extra.join(", ")}` };
    const parsed = PARSERS[kind](settings, env);
    return parsed.error ? parsed : { kind, ...parsed };
}

// MARK: - Fallback text

const UNIT_LABELS = { kg_per_week: "kg/wk", lb_per_week: "lb/wk" };
const number = (value) => value.toLocaleString("en-US", { maximumFractionDigits: 1 });
function quantity(value, unit) {
    if (value == null) return "not available";
    const label = UNIT_LABELS[unit] ?? unit;
    const signed = unit.endsWith("_per_week") && value !== 0 ? `${value > 0 ? "+" : "−"}${number(Math.abs(value))}` : number(value);
    return `${signed} ${label}`;
}

// MARK: - Builders (cached tool results in; component, data and fallback out)

const bind = (name) => ({ path: `/${name}` });
const tool = (coach, name, input) => callCoachTool(coach, name, input);

function series(label, points, unit) {
    const first = points[0];
    const last = points[points.length - 1];
    return points.length === 1
        ? `${label}, ${first.x}: ${quantity(first.y, unit)}.`
        : `${label}, ${first.x} to ${last.x}: ${number(first.y)} → ${quantity(last.y, unit)}.`;
}

const TREND_SOURCES = {
    async weight(coach, { rangeDays }) {
        const body = await tool(coach, "get_body_metrics", { days: rangeDays });
        const unit = coach.env.weightUnit;
        const points = body.weighIns.map((w) => ({ x: w.day, y: w.weight }));
        const trend = body.weighIns.filter((w) => w.trend != null).map((w) => ({ x: w.day, y: w.trend }));
        // get_body_metrics keeps only the latest weigh-ins, so a long range of frequent weigh-ins is
        // cut short: the chart's points and fallback cover what was shown, never the range asked.
        const cut = points.length >= WEIGH_IN_LIMIT && daysBetween(points[0].x, coach.env.today) < rangeDays - 1;
        const fallback = trend.length ? `${series("Weight trend", trend, unit).slice(0, -1)}${cut ? ` (the latest ${WEIGH_IN_LIMIT} weigh-ins)` : ""}.` : null;
        return { points, value: { points, trend, unit }, fallback };
    },
    async exercise_e1rm(coach, { exerciseId, rangeDays }) {
        const progress = await tool(coach, "get_exercise_progress", { exercise: exerciseId, weeks: Math.ceil(rangeDays / 7) });
        const sessions = (progress.sessions ?? [])
            .filter((s) => s.exerciseId === exerciseId && s.estimated1RM != null && daysBetween(s.day, coach.env.today) < rangeDays);
        const points = sessions.map((s) => ({ x: s.day, y: s.estimated1RM }));
        const exerciseName = sessions[0]?.exercise ?? null;
        const unit = coach.env.weightUnit;
        return { points, value: { points, unit, exerciseName }, fallback: points.length ? series(`Estimated 1RM, ${exerciseName}`, points, unit) : null };
    },
    async expenditure(coach, { rangeDays }) {
        const expenditure = await tool(coach, "get_expenditure", { days: rangeDays });
        const points = expenditure.history.filter((h) => h.kcal != null).map((h) => ({ x: h.day, y: h.kcal }));
        return { points, value: { points, unit: "kcal" }, fallback: points.length ? series("Expenditure", points, "kcal") : null };
    },
    async steps(coach, { rangeDays }) {
        const steps = await tool(coach, "get_steps", { days: rangeDays });
        const points = steps.days.map((d) => ({ x: d.day, y: d.steps }));
        const fallback = points.length
            ? `Steps, ${points[0].x} to ${points[points.length - 1].x}: ${quantity(steps.averagePerRecordedDay, "steps")} a day on average.`
            : null;
        return { points, value: { points, unit: "steps" }, fallback };
    },
};

const NUTRIENTS = [["calories", "calories", "kcal"], ["protein", "proteinG", "g"], ["carbs", "carbsG", "g"], ["fat", "fatG", "g"]];

const STATS = {
    weight_trend: async (c) => ({ label: "Trend weight", unit: c.env.weightUnit, value: (await tool(c, "get_body_metrics", {})).weighIns.at(-1)?.trend ?? null }),
    weight_rate_per_week: async (c) => ({ label: "Weekly change", unit: `${c.env.weightUnit}_per_week`, value: (await tool(c, "get_expenditure", {})).current?.weeklyTrendChange ?? null }),
    goal_weight: async (c) => ({ label: "Goal weight", unit: c.env.weightUnit, value: (await tool(c, "get_profile_and_targets", {})).goal?.targetWeight ?? null }),
    expenditure: async (c) => ({ label: "Expenditure", unit: "kcal", value: (await tool(c, "get_expenditure", {})).current?.kcal ?? null }),
    calorie_target: async (c) => ({ label: "Calorie target today", unit: "kcal", value: (await tool(c, "get_profile_and_targets", {})).dietPlan?.todaysTarget?.calories ?? null }),
    protein_target: async (c) => ({ label: "Protein target today", unit: "g", value: (await tool(c, "get_profile_and_targets", {})).dietPlan?.todaysTarget?.proteinG ?? null }),
    today_calories: async (c) => ({ label: "Calories today", unit: "kcal", value: (await tool(c, "get_nutrition", { days: 1 })).days.at(-1)?.totals?.calories ?? null }),
    today_protein: async (c) => ({ label: "Protein today", unit: "g", value: (await tool(c, "get_nutrition", { days: 1 })).days.at(-1)?.totals?.proteinG ?? null }),
    steps_average: async (c) => {
        const steps = await tool(c, "get_steps", {});
        return { label: `Steps, ${steps.rangeDays}-day average`, unit: "steps", value: steps.averagePerRecordedDay ?? null };
    },
};

/// The name of one of the user's exercises, from their sessions in the last two years, or null.
async function exerciseName(coach, exerciseId) {
    const progress = await tool(coach, "get_exercise_progress", { exercise: exerciseId, weeks: 104 });
    return (progress.sessions ?? []).find((s) => s.exerciseId === exerciseId)?.exercise ?? null;
}

async function exerciseStat(coach, exerciseId) {
    const progress = await tool(coach, "get_exercise_progress", { exercise: exerciseId });
    const name = (progress.sessions ?? []).find((s) => s.exerciseId === exerciseId)?.exercise ?? null;
    if (!name) return null;
    const value = (progress.appLatestEstimated1RM ?? []).find((a) => a.exercise === name)?.value ?? null;
    return { label: `${name} estimated 1RM`, unit: coach.env.weightUnit, value, exerciseName: name };
}

const ACTION_LABELS = {
    log_weight: () => "Log weight", log_meal: () => "Log a meal", start_workout: () => "Start a workout",
    open_exercise: (a) => `Open ${a.exerciseName}`, open_metric: (a) => `Open ${a.metric}`,
    open_check_in: () => "Open the weekly check-in", open_diet_plan: () => "Open the diet plan",
};

const BUILDERS = {
    async trend_chart(args, coach) {
        const { points, value, fallback } = await TREND_SOURCES[args.metric](coach, args);
        if (points.length === 0 || !fallback) return { error: `there is no ${args.metric} data in the last ${args.rangeDays} days` };
        return {
            component: {
                component: "TrendChart", metric: args.metric, points: bind("points"),
                ...(value.trend ? { trend: bind("trend") } : {}), unit: bind("unit"),
                ...(args.metric === "exercise_e1rm" ? { exerciseName: bind("exerciseName") } : {}),
            },
            value,
            fallback,
        };
    },

    async target_bars({ day }, coach) {
        const nutrition = await tool(coach, "get_nutrition", { days: daysBetween(day, coach.env.today) + 1 });
        const entry = nutrition.days.find((d) => d.day === day);
        const rows = NUTRIENTS.map(([nutrient, key, unit]) => ({ nutrient, value: entry?.totals?.[key] ?? null, target: entry?.target?.[key] ?? null, unit }));
        if (rows.every((r) => r.value == null && r.target == null)) return { error: `nothing is logged and there are no targets for ${day}` };
        const part = (r) => (r.nutrient === "calories" ? "" : ` ${r.nutrient}`);
        const fallback = entry?.logged
            ? `Food on ${day}${entry.partiallyLogged ? " (partly logged)" : ""}: ${rows.map((r) => `${r.target == null ? quantity(r.value, r.unit) : `${number(r.value)} of ${quantity(r.target, r.unit)}`}${part(r)}`).join(", ")}.`
            : `Food on ${day}: nothing logged; targets ${rows.map((r) => `${quantity(r.target, r.unit)}${part(r)}`).join(", ")}.`;
        return { component: { component: "TargetBars", rows: bind("rows"), day: bind("day") }, value: { rows, day }, fallback };
    },

    async stat_row({ stats }, coach) {
        const read = await Promise.all(stats.map((key) => (key.startsWith("exercise_e1rm:") ? exerciseStat(coach, key.slice(14)) : STATS[key](coach))));
        const missing = stats.filter((_, i) => read[i] == null);
        if (missing.length) return { error: `no logged sessions for ${missing.join(", ")}` };
        const value = read.map((s, i) => ({ key: stats[i], value: s.value, unit: s.unit, ...(s.exerciseName ? { exerciseName: s.exerciseName } : {}) }));
        return {
            component: { component: "StatRow", stats: bind("stats") },
            value: { stats: value },
            fallback: `${read.map((s) => `${s.label}: ${quantity(s.value, s.unit)}`).join("; ")}.`,
        };
    },

    async actions({ actions }, coach) {
        const named = [];
        for (const action of actions) {
            if (action.kind !== "open_exercise") { named.push(action); continue; }
            const name = await exerciseName(coach, action.exerciseId);
            if (!name) return { error: `no logged sessions for exercise ${action.exerciseId}` };
            named.push({ ...action, exerciseName: name });
        }
        return {
            component: { component: "Actions", actions: bind("actions") },
            value: { actions: named },
            fallback: `You can: ${named.map((a) => ACTION_LABELS[a.kind](a)).join("; ")}.`,
        };
    },

    async follow_ups({ questions }) {
        return {
            component: { component: "FollowUps", questions: bind("questions") },
            value: { questions },
            fallback: `Suggested questions: ${questions.join(" / ")}`,
        };
    },
};

/// One block as streamed: the surface, its root component and its data, in A2UI v0.9 order.
export function a2uiBlock({ surfaceId, kind, asOf, fallback, component, value }) {
    return {
        surfaceId, kind, asOf, fallback,
        messages: [
            { version: A2UI_VERSION, createSurface: { surfaceId, catalogId: COACH_CATALOG_ID } },
            { version: A2UI_VERSION, updateComponents: { surfaceId, components: [{ id: "root", ...component }] } },
            { version: A2UI_VERSION, updateDataModel: { surfaceId, path: "/", value } },
        ],
    };
}

// MARK: - One reply's blocks

const notShown = (reason) => ({ shown: false, reason: `Not shown: ${reason}.` });

/// The blocks of one reply, in the order they were shown; `onBlock` gets each as it is built.
/// Calls run one at a time, so the cap and the surface ids hold when the model asks for several
/// blocks at once. `add` never throws: a block it cannot show or build (a tool failed) is dropped
/// and the model told why.
export function coachBlocks({ messageId, onBlock = null }) {
    const list = [];
    let queue = Promise.resolve();
    // One log line per decision, with no user data: which kind, and why one wasn't shown.
    const refuse = (kind, reason) => {
        console.log(JSON.stringify({ event: "coach_block", kind, shown: false, reason }));
        return notShown(reason);
    };
    async function add(input, coach) {
        const kind = typeof input?.kind === "string" ? input.kind.slice(0, 40) : null;
        if (list.length >= COACH_MAX_BLOCKS) return refuse(kind, `at most ${COACH_MAX_BLOCKS} blocks per reply`);
        const args = parseBlockArgs(input, coach.env);
        if (args.error) return refuse(kind, args.error);
        const built = await BUILDERS[args.kind](args, coach);
        if (built.error) return refuse(kind, built.error);
        const block = a2uiBlock({ surfaceId: `${messageId}-${list.length}`, kind: args.kind, asOf: coach.env.today, ...built });
        list.push(block);
        console.log(JSON.stringify({ event: "coach_block", kind: args.kind, shown: true }));
        onBlock?.(block);
        return { shown: true, shows: block.fallback };
    }
    return {
        list,
        add(input, coach) {
            queue = queue.then(() => add(input, coach)).catch((error) => {
                console.error(`coach block failed: ${error.message}`);
                return notShown("it could not be built");
            });
            return queue;
        },
    };
}

// MARK: - The model's tool

const SHOW_BLOCK_INPUT = z.object({
    kind: z.string().describe("trend_chart | target_bars | stat_row | actions | follow_ups"),
    metric: z.string().optional().describe("trend_chart only: weight | exercise_e1rm | expenditure | steps"),
    exerciseId: z.string().optional().describe("trend_chart with exercise_e1rm only: the exerciseId exactly as a tool returned it"),
    rangeDays: z.number().optional().describe("trend_chart only: days back from today, 7 to 365"),
    day: z.string().optional().describe("target_bars only: \"today\" or YYYY-MM-DD within the last 90 days"),
    stats: z.array(z.string()).optional().describe(`stat_row only: 1 to 3 of ${STAT_KEYS.join(", ")}, or exercise_e1rm:<exerciseId>`),
    actions: z.array(z.object({
        kind: z.string().describe(ACTION_KINDS.join(" | ")),
        exerciseId: z.string().optional().describe("open_exercise only"),
        metric: z.string().optional().describe("open_metric only: weight | expenditure | steps"),
    }).passthrough()).optional().describe("actions only: 1 to 3 buttons that open a screen in the app"),
    questions: z.array(z.string()).optional().describe("follow_ups only: 1 to 3 questions the user might ask next, at most 80 characters, stating no figures"),
}).passthrough();

/// `show_block`, offered only when the app renders blocks. Its schema is loose on purpose (Genkit
/// would end the whole reply on a schema error); `parseBlockArgs` is the strict check.
export function defineShowBlockTool(ai) {
    return ai.defineTool(
        {
            name: "show_block",
            description: "Show the user one card under your answer. The app fills every figure in it from your tools; you choose only the kind and its settings. Answers whether it was shown and what it shows.",
            inputSchema: SHOW_BLOCK_INPUT,
            outputSchema: z.any(),
        },
        async (input, { context }) => context.coach.blocks?.add(input, context.coach) ?? notShown("blocks are off"),
    );
}

// MARK: - Stream and storage

/// A block's stream chunk. It keeps a `text` key, empty, because clients from before blocks read
/// every chunk's text and throw without one.
export const blockChunk = (block) => ({ text: "", block });

/// A block as the assistant message stores it: snake_case `as_of`, like the chat's other fields.
export const storedBlock = ({ surfaceId, kind, asOf, fallback, messages }) => ({ surfaceId, kind, as_of: asOf, fallback, messages });

/// The chat's messages, with the oldest blocks' A2UI messages emptied until the whole fits well
/// inside Firestore's 1 MiB document: such a block renders its fallback text instead.
export function fitStoredBlocks(messages, budget = 700_000) {
    let excess = JSON.stringify(messages).length - budget;
    if (excess <= 0) return messages;
    return messages.map((message) => {
        if (excess <= 0 || !message.blocks) return message;
        return {
            ...message,
            blocks: message.blocks.map((block) => {
                if (excess <= 0 || block.messages.length === 0) return block;
                excess -= JSON.stringify(block.messages).length - 2;
                return { ...block, messages: [] };
            }),
        };
    });
}
