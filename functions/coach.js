// The AI coach: a read-only chat about the caller's own training, nutrition and body data.
//
// Design: docs/specs/ai-coach.md. The model never sees a uid or a path. Each tool reads one allowed
// area through a data source bound to the caller (Firestore in production, fixtures in tests and
// the evaluation), and shapes it into the user's units with the same figures the app's screens
// show (coach-maths.js). There is deliberately no tool for Strava activities, progress photos or
// anything belonging to other people, and no generic read: the exclusions hold by construction.

import { readFileSync } from "node:fs";
import { HttpsError } from "firebase-functions/v2/https";
import { z } from "genkit";
import { localTime } from "./lib.js";
import {
    addDays, daysBetween, setEstimated1RM, exerciseOneRM, weeklyMuscleSets, weightTrend,
    estimateTDEE, resolvedBMREquation, expenditureSamples, expenditureHistory, completedWorkingSets,
    energyDensityKcalPerKg,
} from "./coach-maths.js";

// MARK: - Limits

export const COACH_DAILY_LIMIT = 50;
export const COACH_BURST_LIMIT = 5;
export const COACH_BURST_WINDOW_MS = 60_000;
export const COACH_MAX_MESSAGE_CHARS = 2000;
export const COACH_MAX_STORED_MESSAGES = 100;
// The recent turns sent to the model, newest kept first: about 3k tokens of conversation.
export const COACH_HISTORY_CHAR_BUDGET = 12_000;

export const COACH_CONTEXT_KINDS = [
    "today", "weight_trend", "exercise", "session", "check_in", "nutrition_day", "weekly_review", "mesocycle", "expenditure", "muscle_group",
];

// MARK: - Request

/// The request, checked at the trust boundary: { chatId?, message, context?: { kind, id?, date? } }.
export function validateCoachRequest(data) {
    const message = typeof data?.message === "string" ? data.message.trim() : "";
    if (message.length < 1 || message.length > COACH_MAX_MESSAGE_CHARS) {
        throw new HttpsError("invalid-argument", `message must be 1-${COACH_MAX_MESSAGE_CHARS} characters`);
    }
    const chatId = data?.chatId ?? null;
    if (chatId !== null && !(typeof chatId === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(chatId))) {
        throw new HttpsError("invalid-argument", "chatId is malformed");
    }
    let context = null;
    if (data?.context != null) {
        const { kind, id, date } = data.context;
        if (!COACH_CONTEXT_KINDS.includes(kind)) throw new HttpsError("invalid-argument", "context.kind is unknown");
        if (id != null && !(typeof id === "string" && id.length <= 128)) throw new HttpsError("invalid-argument", "context.id is malformed");
        if (date != null && !(typeof date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(date))) {
            throw new HttpsError("invalid-argument", "context.date must be YYYY-MM-DD");
        }
        context = { kind, id: id ?? null, date: date ?? null };
    }
    return { chatId, message, context };
}

/// Consent is the boolean the app writes; withdrawing sets it false, and the timestamp stays.
export function hasCoachConsent(privateSettings) {
    return privateSettings?.coach_consent === true;
}

// MARK: - Quota

/// The day's count and the last minute's messages, after one more message, or why it is refused.
/// `usage` is coach_usage/{uid}: { day, count, recent: [epoch ms] }.
export function planCoachQuota(usage, { day, nowMs }) {
    const count = usage?.day === day ? (usage.count ?? 0) : 0;
    const recent = (usage?.recent ?? []).filter((ms) => nowMs - ms < COACH_BURST_WINDOW_MS);
    if (count >= COACH_DAILY_LIMIT) return { allowed: false, reason: "quota", remaining: 0 };
    if (recent.length >= COACH_BURST_LIMIT) return { allowed: false, reason: "burst", remaining: COACH_DAILY_LIMIT - count };
    return {
        allowed: true,
        remaining: COACH_DAILY_LIMIT - count - 1,
        next: { day, count: count + 1, recent: [...recent, nowMs] },
    };
}

/// Counts the message against coach_usage/{uid} in a transaction, before anything is generated.
export async function consumeCoachQuota(db, uid, { day, nowMs }) {
    const ref = db.collection("coach_usage").doc(uid);
    return db.runTransaction(async (tx) => {
        const plan = planCoachQuota((await tx.get(ref)).data(), { day, nowMs });
        if (!plan.allowed) {
            throw plan.reason === "quota"
                ? new HttpsError("resource-exhausted", "Daily coach limit reached", { reason: "quota", limit: COACH_DAILY_LIMIT })
                : new HttpsError("resource-exhausted", "Too many messages at once", { reason: "burst", limit: COACH_BURST_LIMIT });
        }
        tx.set(ref, plan.next);
        return plan.remaining;
    });
}

// MARK: - Premium

const PREMIUM_CACHE_MS = 5 * 60_000;
const premiumCache = new Map();

/// Whether RevenueCat has an active entitlement for the uid (the app user id is the Firebase uid).
/// A yes is cached for five minutes; a no is not, so a fresh purchase works at once. RevenueCat
/// answers 404 for a customer it has never seen, which is a no. Anything else it cannot answer is
/// `unavailable`: the check fails closed.
export async function isCoachPremium(uid, { projectId, apiKey, fetchImpl = fetch, nowMs = Date.now(), cache = premiumCache }) {
    if ((cache.get(uid) ?? 0) > nowMs) return true;
    if (!projectId || !apiKey) throw new HttpsError("unavailable", "Premium check is not configured");
    let response;
    try {
        response = await fetchImpl(
            `https://api.revenuecat.com/v2/projects/${encodeURIComponent(projectId)}/customers/${encodeURIComponent(uid)}/active_entitlements`,
            { headers: { Authorization: `Bearer ${apiKey}` } },
        );
    } catch (error) {
        throw new HttpsError("unavailable", `RevenueCat unreachable: ${error.message}`);
    }
    if (response.status === 404) return false;
    if (!response.ok) throw new HttpsError("unavailable", `RevenueCat returned ${response.status}`);
    const body = await response.json();
    const premium = Array.isArray(body?.items) && body.items.length > 0;
    if (premium) cache.set(uid, nowMs + PREMIUM_CACHE_MS);
    return premium;
}

// MARK: - Chats

export function chatTitle(message) {
    const line = message.replace(/\s+/g, " ").trim();
    return line.length <= 60 ? line : `${line.slice(0, 59).trimEnd()}…`;
}

/// The stored messages with the new ones appended, the oldest dropped past the cap.
export function appendChatMessages(messages, added, cap = COACH_MAX_STORED_MESSAGES) {
    return [...(messages ?? []), ...added].slice(-cap);
}

/// The most recent turns that fit the budget, oldest first, as Genkit messages.
export function historyForModel(messages, budget = COACH_HISTORY_CHAR_BUDGET) {
    const kept = [];
    let used = 0;
    for (const message of [...(messages ?? [])].reverse()) {
        used += message.text?.length ?? 0;
        if (used > budget) break;
        kept.unshift({ role: message.role === "assistant" ? "model" : "user", content: [{ text: message.text }] });
    }
    // A history must open with the user.
    while (kept.length > 0 && kept[0].role !== "user") kept.shift();
    return kept;
}

// MARK: - Data sources

const asDate = (value) => {
    if (value == null) return null;
    if (value instanceof Date) return value;
    if (typeof value.toDate === "function") return value.toDate();
    if (typeof value === "string" || typeof value === "number") {
        const date = new Date(value);
        return Number.isNaN(date.getTime()) ? null : date;
    }
    if (typeof value._seconds === "number") return new Date(value._seconds * 1000);
    return null;
};

/// The caller's data in Firestore. Every read is under users/{uid}, the user's own diet plan, or
/// their own exercises; nothing here can reach another account or an excluded collection.
export function firestoreSource(db, uid) {
    const user = db.collection("users").doc(uid);
    const all = async (query) => (await query.get()).docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    const one = async (ref) => { const snap = await ref.get(); return snap.exists ? { id: snap.id, ...snap.data() } : null; };
    const since = (collection, field, date) => (date ? user.collection(collection).where(field, ">=", date) : user.collection(collection));
    return memoize({
        user: () => one(user),
        privateSettings: () => one(user.collection("private").doc("settings")),
        analyticsSettings: async () => (await all(user.collection("analytics_settings")))[0] ?? null,
        goals: () => all(user.collection("goals")),
        dietPlan: () => one(db.collection("diet_plans").doc(uid)),
        strategySettings: async () => (await all(user.collection("nutrition_strategy_settings")))[0] ?? null,
        annotations: () => all(user.collection("nutrition_day_annotations")),
        loggingBreak: async () => (await all(user.collection("logging_break")))[0] ?? null,
        checkInRecord: async () => (await all(user.collection("check_in_record")))[0] ?? null,
        sessions: (from) => all(since("workout_sessions", "date_created", from)),
        meals: (from) => all(since("meal_logs", "date", from)),
        measurements: (from) => all(since("body_measurements", "date", from)),
        steps: (from) => all(since("steps", "date", from)),
        mesocycles: () => all(user.collection("mesocycles")),
        macrocycles: () => all(user.collection("macrocycles")),
        userExercises: () => all(db.collection("exercise_templates").where("author_id", "==", uid)),
    });
}

/// The same interface over a plain object of documents, for tests and the evaluation.
export function fixtureSource(account) {
    const after = (docs, field, from) => (docs ?? []).filter((doc) => !from || (asDate(doc[field]) ?? 0) >= from);
    return memoize({
        user: async () => account.user ?? null,
        privateSettings: async () => account.privateSettings ?? null,
        analyticsSettings: async () => account.analyticsSettings ?? null,
        goals: async () => account.goals ?? [],
        dietPlan: async () => account.dietPlan ?? null,
        strategySettings: async () => account.strategySettings ?? null,
        annotations: async () => account.annotations ?? [],
        loggingBreak: async () => account.loggingBreak ?? null,
        checkInRecord: async () => account.checkInRecord ?? null,
        sessions: async (from) => after(account.sessions, "date_created", from),
        meals: async (from) => after(account.meals, "date", from),
        measurements: async (from) => after(account.measurements, "date", from),
        steps: async (from) => after(account.steps, "date", from),
        mesocycles: async () => account.mesocycles ?? [],
        macrocycles: async () => account.macrocycles ?? [],
        userExercises: async () => account.userExercises ?? [],
    });
}

// One read per method and argument per request: several tools ask for the user or the sessions.
function memoize(source) {
    const cache = new Map();
    return Object.fromEntries(Object.entries(source).map(([name, fn]) => [name, (arg) => {
        const key = `${name}:${arg instanceof Date ? arg.getTime() : arg ?? ""}`;
        if (!cache.has(key)) cache.set(key, fn(arg));
        return cache.get(key);
    }]));
}

// MARK: - Units and days

const LB_PER_KG = 2.2046226218;
const KM_PER_MI = 1.609344;
const round = (value, places = 1) => (value == null || !Number.isFinite(value) ? null : Math.round(value * 10 ** places) / 10 ** places + 0);

/// The caller's units, zone and today, the frame every tool answers in.
export async function coachEnvironment(source, now = new Date()) {
    const [user, settings] = await Promise.all([source.user(), source.privateSettings()]);
    const timeZone = validTimeZone(settings?.timezone) ? settings.timezone : "UTC";
    return {
        now,
        timeZone,
        today: localTime(now, timeZone).date,
        weightUnit: user?.submitted_weight_unit_preference === "pounds" ? "lb" : "kg",
        distanceUnit: user?.submitted_distance_unit_preference === "miles" ? "mi" : "km",
        lengthUnit: user?.submitted_length_unit_preference === "inches" ? "in" : "cm",
        firstName: user?.submitted_first_name ?? user?.first_name ?? null,
    };
}

function validTimeZone(zone) {
    if (typeof zone !== "string" || !zone) return false;
    try { new Intl.DateTimeFormat("en-US", { timeZone: zone }); return true; } catch { return false; }
}

const dayOf = (value, env) => { const date = asDate(value); return date ? localTime(date, env.timeZone).date : null; };
const weight = (kg, env) => (kg == null ? null : round(env.weightUnit === "lb" ? kg * LB_PER_KG : kg, 1));
const distance = (meters, env) => (meters == null ? null : round(env.distanceUnit === "mi" ? meters / 1000 / KM_PER_MI : meters / 1000, 2));
const length = (cm, env) => (cm == null ? null : round(env.lengthUnit === "in" ? cm / 2.54 : cm, 1));
const clampDays = (value, fallback, max) => Math.min(Math.max(Math.round(Number(value) || fallback), 1), max);
// The start of a range `days` long ending today, a little early so the time zone cannot drop a day.
const rangeStart = (env, days) => new Date(env.now.getTime() - (days + 1) * 86_400_000);

// Wall-clock midnight test, for a logging break that began at the very start of a day.
function isLocalMidnight(date, timeZone) {
    const parts = new Intl.DateTimeFormat("en-US", { timeZone, hourCycle: "h23", hour: "2-digit", minute: "2-digit", second: "2-digit" }).formatToParts(date);
    return parts.filter((p) => ["hour", "minute", "second"].includes(p.type)).every((p) => Number(p.value) === 0);
}

// MARK: - Shaping sessions

/// A finished, undeleted session in the maths' shape, or null.
export function shapeSession(doc, env) {
    if (doc.deleted_at || !doc.ended_at) return null;
    const ended = asDate(doc.ended_at);
    const started = asDate(doc.date_created) ?? ended;
    return {
        id: doc.id,
        name: doc.name ?? "Workout",
        day: dayOf(ended, env),
        at: ended.getTime(),
        isRestDay: doc.is_rest_day === true,
        durationMin: Math.max(0, Math.round((ended - started) / 60_000 - (doc.paused_seconds ?? 0) / 60)),
        notes: doc.notes ?? null,
        mesocycleId: doc.mesocycle_id ?? null,
        templateId: doc.workout_template_id ?? null,
        exercises: (doc.exercises ?? []).map((exercise) => ({
            templateId: exercise.template_id,
            name: exercise.name,
            notes: exercise.notes ?? null,
            sets: (exercise.sets ?? []).map((set) => ({
                reps: set.reps ?? null,
                weightKg: set.weight_kg ?? null,
                durationSec: set.duration_sec ?? null,
                distanceMeters: set.distance_meters ?? null,
                rpe: set.rpe ?? null,
                side: set.side ?? null,
                id: set.id ?? null,
                kind: set.kind ?? null,
                parentSetId: set.parent_set_id ?? null,
                isWarmup: set.isWarmup === true,
                completed: set.completed_at != null,
            })),
        })),
    };
}

async function finishedSessions(source, env, days) {
    const docs = await source.sessions(days ? rangeStart(env, days) : null);
    return docs.map((doc) => shapeSession(doc, env)).filter(Boolean)
        .filter((s) => !days || daysBetween(s.day, env.today) < days);
}

const matchesExercise = (exercise, query) => {
    if (!query) return true;
    const q = String(query).toLowerCase();
    return exercise.templateId === query || (exercise.name ?? "").toLowerCase().includes(q);
};

function describeSet(set, env) {
    const parts = [];
    if (set.weightKg > 0) parts.push(`${weight(set.weightKg, env)} ${env.weightUnit}`);
    if (set.reps != null) parts.push(`${set.reps} reps`);
    if (set.durationSec != null) parts.push(`${set.durationSec} s`);
    if (set.distanceMeters != null) parts.push(`${distance(set.distanceMeters, env)} ${env.distanceUnit}`);
    if (set.rpe != null) parts.push(`RPE ${set.rpe}`);
    if (set.side) parts.push(set.side);
    if (set.isWarmup) parts.push("warm-up");
    if (!set.completed) parts.push("not completed");
    return parts.join(", ");
}

// MARK: - Exercise library

let builtInMuscles = null;
/// Template id → muscle groups, built-in and the user's own; the user's win on a clash.
async function exerciseMuscles(source) {
    builtInMuscles ??= Object.fromEntries(
        JSON.parse(readFileSync(new URL("./data/PrebuiltExercises.json", import.meta.url), "utf8")).exercises
            .map((e) => [e.id, e.muscle_groups ?? {}]),
    );
    const own = Object.fromEntries((await source.userExercises()).map((e) => [e.id, e.muscle_groups ?? {}]));
    return { ...builtInMuscles, ...own };
}

export const MUSCLES = [
    "triceps", "upperTraps", "obliques", "neck", "lats", "forearms", "sideDelts", "rearDelts", "frontDelts", "chest", "biceps",
    "upperBack", "lowerBack", "abs", "serratus", "quads", "hamstrings", "glutes", "calves", "abductors", "adductors", "tibialis",
];
// MuscleVolume.productiveWeeklySets and .tier(sets:): one band for every muscle (Pelland 2026,
// Baz-Valle 2022), with Compound's own tiers around it.
const PRODUCTIVE_WEEKLY_SETS = [10, 20];
const MAINTENANCE_WEEKLY_SETS = 4;
const volumeTier = (sets) => (sets < MAINTENANCE_WEEKLY_SETS ? "belowMaintenance"
    : sets < PRODUCTIVE_WEEKLY_SETS[0] ? "maintaining"
        : sets > PRODUCTIVE_WEEKLY_SETS[1] ? "high" : "productive");

// CoreInteractor.expenditureKcalPerKg: the latest weight, and a body fat reading from the last 90
// days, through the energy density; 7,700 kcal/kg without one.
const TRUSTED_BODY_FAT_DAYS = 90;
function expenditureKcalPerKg(measurements, now, fallbackWeightKg = null) {
    const dated = measurements.map((m) => ({ ...m, at: asDate(m.date) })).filter((m) => m.at);
    const latest = (rows) => rows.sort((a, b) => b.at - a.at)[0];
    const cutoff = now.getTime() - TRUSTED_BODY_FAT_DAYS * 86_400_000;
    const bodyFat = latest(dated.filter((m) => m.at.getTime() >= cutoff && m.body_fat_percentage > 0))?.body_fat_percentage ?? null;
    const weightKg = latest(dated.filter((m) => m.weight_kg > 0))?.weight_kg ?? fallbackWeightKg;
    return energyDensityKcalPerKg(weightKg, bodyFat);
}

// MARK: - Profile helpers

function objectiveOf(goal) {
    const value = goal?.objective;
    if (typeof value === "string") return value;
    if (value && typeof value === "object") return Object.keys(value)[0] ?? null;
    return null;
}

function ageYears(user, now) {
    const dob = asDate(user?.submitted_date_of_birth);
    if (!dob) return null;
    let years = now.getUTCFullYear() - dob.getUTCFullYear();
    const birthdayPassed = now.getUTCMonth() > dob.getUTCMonth() || (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() >= dob.getUTCDate());
    if (!birthdayPassed) years -= 1;
    return years;
}

const activeGoal = (goals) => [...(goals ?? [])].filter((g) => g.status === "active")
    .sort((a, b) => (asDate(b.created_at) ?? 0) - (asDate(a.created_at) ?? 0))[0] ?? null;

const weekdayIndex = (dayKey) => (new Date(`${dayKey}T12:00:00Z`).getUTCDay() + 6) % 7; // Monday = 0, as the diet plan.
const targetFor = (plan, dayKey) => plan?.days?.[weekdayIndex(dayKey)] ?? null;
const macros = (t) => (t ? { calories: round(t.calories, 0), proteinG: round(t.proteinGrams, 0), carbsG: round(t.carbGrams, 0), fatG: round(t.fatGrams, 0) } : null);

function mealTotals(meal) {
    const sum = { calories: 0, protein: 0, carbs: 0, fat_total: 0 };
    for (const item of meal.items ?? []) for (const key of Object.keys(sum)) sum[key] += Number(item.nutrients?.[key] ?? 0) || 0;
    return sum;
}

// MARK: - Tools (pure: source and environment in, plain data out)

export const COACH_TOOLS = {
    async get_profile_and_targets(source, env) {
        const [user, goals, plan, strategy] = await Promise.all([source.user(), source.goals(), source.dietPlan(), source.strategySettings()]);
        const goal = activeGoal(goals);
        const objective = objectiveOf(goal);
        const weeklyChange = goal?.weekly_change_kg == null ? null
            : objective === "loseWeight" ? -Math.abs(goal.weekly_change_kg) : objective === "gainWeight" ? Math.abs(goal.weekly_change_kg) : 0;
        return {
            firstName: env.firstName,
            today: env.today,
            timeZone: env.timeZone,
            units: { weight: env.weightUnit, distance: env.distanceUnit, length: env.lengthUnit },
            sex: user?.submitted_gender ?? null,
            ageYears: ageYears(user, env.now),
            height: length(user?.submitted_height_centimeters, env),
            profileWeight: weight(user?.submitted_weight_kilograms, env),
            activityLevel: user?.submitted_daily_activity_level ?? null,
            exerciseFrequency: user?.submitted_exercise_frequency ?? null,
            weeklySessionGoal: user?.weekly_session_goal ?? 3,
            goal: goal ? {
                objective,
                startWeight: weight(goal.starting_weight_kg, env),
                targetWeight: weight(goal.target_weight_kg, env),
                plannedWeeklyChange: weight(weeklyChange, env),
                startedOn: dayOf(goal.created_at, env),
            } : null,
            dietPlan: plan ? {
                preferredDiet: plan.preferredDiet ?? null,
                calorieFloor: plan.calorieFloor ?? null,
                proteinIntake: plan.proteinIntake ?? null,
                calorieDistribution: plan.calorieDistribution ?? null,
                expenditureUsedKcal: round(plan.tdeeEstimate, 0),
                todaysTarget: macros(targetFor(plan, env.today)),
                weekTargetsMondayFirst: (plan.days ?? []).map(macros),
            } : null,
            nutritionStrategy: strategy ? {
                checkInWeekday: strategy.check_in_weekday ?? 2,
                expenditureMode: strategy.calculation_mode ?? "dynamic",
                stepInformedUpdates: strategy.step_informed_updates === true,
            } : null,
        };
    },

    async get_workout_history(source, env, { days = 28, exercise = null } = {}) {
        const range = clampDays(days, 28, 365);
        const sessions = (await finishedSessions(source, env, range)).filter((s) => !s.isRestDay)
            .sort((a, b) => b.at - a.at);
        const shaped = sessions.map((s) => ({
            day: s.day,
            name: s.name,
            durationMin: s.durationMin,
            notes: s.notes,
            exercises: s.exercises.filter((e) => matchesExercise(e, exercise)).map((e) => ({
                name: e.name,
                exerciseId: e.templateId,
                notes: e.notes,
                workingSetsCompleted: completedWorkingSets(e),
                sets: e.sets.map((set) => describeSet(set, env)),
            })),
        })).filter((s) => !exercise || s.exercises.length > 0);
        return { rangeDays: range, sessionCount: shaped.length, sessions: shaped.slice(0, 30), truncated: shaped.length > 30 };
    },

    async get_exercise_progress(source, env, { exercise, weeks = 12 } = {}) {
        if (!exercise) return { error: "Name the exercise." };
        const range = clampDays(weeks, 12, 104) * 7;
        const sessions = (await finishedSessions(source, env, range)).filter((s) => !s.isRestDay).sort((a, b) => a.at - b.at);
        const points = [];
        let best = 0;
        for (const session of sessions) {
            for (const e of session.exercises.filter((x) => matchesExercise(x, exercise))) {
                const working = e.sets.filter((set) => !set.isWarmup && set.completed);
                const scored = working.filter((set) => set.parentSetId == null)
                    .map((set) => ({ set, e1rm: setEstimated1RM(set) }))
                    .filter((entry) => entry.e1rm != null)
                    .sort((a, b) => b.e1rm - a.e1rm)[0];
                const isRecord = scored != null && scored.e1rm > best;
                if (scored) best = Math.max(best, scored.e1rm);
                points.push({
                    day: session.day,
                    exercise: e.name,
                    exerciseId: e.templateId,
                    workingSets: completedWorkingSets(e),
                    bestSet: scored ? describeSet(scored.set, env) : null,
                    estimated1RM: scored ? weight(scored.e1rm, env) : null,
                    volume: weight(working.reduce((sum, set) => sum + (set.weightKg ?? 0) * (set.reps ?? 0) * (set.side === "both" ? 2 : 1), 0), env),
                    newBestInRange: isRecord,
                });
            }
        }
        const appFigures = exerciseOneRM(sessions.map((s) => ({ ...s, exercises: s.exercises.filter((x) => matchesExercise(x, exercise)) })));
        return {
            rangeWeeks: range / 7,
            unit: env.weightUnit,
            estimated1RMFormula: "Epley on reps to failure, as the app shows it: n = reps + (10 − RPE) when RPE was logged, else reps; e1RM = weight when n = 1, weight × (1 + n / 30) for n up to 10; sets past 10 reps to failure give no estimate (Reynolds 2006)",
            sessions: points,
            bestEstimated1RMInRange: weight(best || null, env),
            appLatestEstimated1RM: Object.values(appFigures).map((a) => ({ exercise: a.name, value: weight(a.latest1RM, env) })),
        };
    },

    async get_training_volume(source, env, { weeks = 4 } = {}) {
        const count = clampDays(weeks, 4, 12);
        const [sessions, templates] = await Promise.all([finishedSessions(source, env, count * 7), exerciseMuscles(source)]);
        const weekly = weeklyMuscleSets(sessions.filter((s) => !s.isRestDay), templates, env.today, count, MUSCLES);
        return {
            note: "Weighted hard sets per muscle in rolling 7-day windows ending today, oldest first. A hard set is a finished, non-warm-up set not logged below RPE 6 (sets without RPE count); each drop or myo/rest-pause mini-set adds 0.5, up to 2 per set. A muscle trained directly counts a set as 1, one it assists as 0.5; a left/right pair counts once. Every muscle has the same tiers: below 4 below maintenance, 4 to under 10 maintaining, 10-20 productive, over 20 high (fine if still progressing and recovering). The 4 and 10 cut-points are the app's own; the 10-20 band is from meta-analyses.",
            weeks: count,
            muscles: Object.fromEntries(MUSCLES.map((muscle) => {
                const sets = weekly[muscle].map((v) => round(v, 1));
                const [low, high] = PRODUCTIVE_WEEKLY_SETS;
                const last = weekly[muscle][weekly[muscle].length - 1];
                return [muscle, { weeklySets: sets, productivePerWeek: `${low}-${high}`, lastWeekTier: volumeTier(last) }];
            })),
        };
    },

    async get_nutrition(source, env, { days = 7 } = {}) {
        const range = clampDays(days, 7, 90);
        const [meals, plan, annotations, loggingBreak] = await Promise.all([
            source.meals(rangeStart(env, range)), source.dietPlan(), source.annotations(), source.loggingBreak(),
        ]);
        const byDay = {};
        for (const meal of meals) {
            const day = meal.day_key ?? dayOf(meal.date, env);
            if (!day || daysBetween(day, env.today) >= range || daysBetween(day, env.today) < 0) continue;
            (byDay[day] ??= []).push(meal);
        }
        const notesByDay = Object.fromEntries((annotations ?? []).map((a) => [a.day_key, a]));
        const breakStart = loggingBreak ? dayOf(loggingBreak.start_date, env) : null;
        const breakEnd = loggingBreak?.end_date ? dayOf(loggingBreak.end_date, env) : null;
        const detailed = range <= 14;
        const out = [];
        for (let i = range - 1; i >= 0; i--) {
            const day = addDays(env.today, -i);
            const dayMeals = byDay[day] ?? [];
            const totals = dayMeals.map(mealTotals).reduce((a, t) => ({
                calories: a.calories + t.calories, protein: a.protein + t.protein, carbs: a.carbs + t.carbs, fat: a.fat + t.fat_total,
            }), { calories: 0, protein: 0, carbs: 0, fat: 0 });
            const entry = {
                day,
                logged: dayMeals.length > 0,
                totals: dayMeals.length > 0 ? { calories: round(totals.calories, 0), proteinG: round(totals.protein, 0), carbsG: round(totals.carbs, 0), fatG: round(totals.fat, 0) } : null,
                target: macros(targetFor(plan, day)),
                partiallyLogged: notesByDay[day]?.is_partially_logged === true,
                fastingDay: notesByDay[day]?.is_fasting_day === true,
                inLoggingBreak: breakStart != null && day >= breakStart && (breakEnd == null || day <= breakEnd),
            };
            if (detailed) {
                entry.meals = dayMeals.sort((a, b) => (asDate(a.date) ?? 0) - (asDate(b.date) ?? 0)).map((meal) => ({
                    time: localTime(asDate(meal.date), env.timeZone)?.hour ?? null,
                    calories: round(mealTotals(meal).calories, 0),
                    items: (meal.items ?? []).map((item) => item.displayName).filter(Boolean).slice(0, 12),
                    notes: meal.notes ?? null,
                }));
            }
            out.push(entry);
        }
        const logged = out.filter((d) => d.logged && !d.partiallyLogged);
        const avg = (key) => (logged.length ? round(logged.reduce((s, d) => s + d.totals[key], 0) / logged.length, 0) : null);
        return {
            rangeDays: range,
            note: "The current day is still in progress. Averages use fully logged days only.",
            averagesOverLoggedDays: { days: logged.length, calories: avg("calories"), proteinG: avg("proteinG"), carbsG: avg("carbsG"), fatG: avg("fatG") },
            days: out,
        };
    },

    async get_body_metrics(source, env, { days = 90 } = {}) {
        const range = clampDays(days, 90, 730);
        const all = (await source.measurements(null)).filter((m) => !m.deleted_at)
            .map((m) => ({ ...m, at: asDate(m.date) })).filter((m) => m.at).sort((a, b) => a.at - b.at);
        const weighIns = all.filter((m) => Number.isFinite(m.weight_kg) && m.weight_kg > 0);
        const trend = weightTrend(weighIns.map((m) => m.weight_kg), weighIns.map((m) => dayOf(m.at, env)));
        const inRange = (m) => daysBetween(dayOf(m.at, env), env.today) < range;
        const shown = weighIns.map((m, i) => ({ m, trend: trend[i] })).filter(({ m }) => inRange(m));
        const circumferenceFields = Object.keys(all.reduce((acc, m) => Object.assign(acc, m), {})).filter((k) => k.endsWith("_circumference"));
        const circumferences = Object.fromEntries(circumferenceFields.map((field) => {
            const values = all.filter((m) => inRange(m) && Number.isFinite(m[field]));
            if (values.length === 0) return [field, null];
            const first = values[0][field];
            const last = values[values.length - 1][field];
            return [field.replace("_circumference", ""), { latest: length(last, env), changeInRange: length(last - first, env), measuredOn: dayOf(values[values.length - 1].at, env) }];
        }).filter(([, v]) => v));
        const bodyFat = all.filter((m) => Number.isFinite(m.body_fat_percentage));
        return {
            rangeDays: range,
            units: { weight: env.weightUnit, length: env.lengthUnit },
            trendNote: "The trend is the line on the app's Weight Trend screen: a Kalman filter over the weigh-ins (level and slope, with the real gap in days between readings), smoothed with the readings after each point. One weigh-in is taken to carry about 0.5% of body weight of noise (at least 0.3 kg); only the first weigh-in of a day counts; an odd reading is down-weighted, and one more than max(3 kg, 4%) off the trend is ignored unless the next weigh-in agrees.",
            weighIns: shown.slice(-60).map(({ m, trend: t }) => ({ day: dayOf(m.at, env), weight: weight(m.weight_kg, env), trend: weight(t, env) })),
            trendChangeInRange: shown.length >= 2 ? weight(shown[shown.length - 1].trend - shown[0].trend, env) : null,
            latestBodyFatPercent: bodyFat.length ? round(bodyFat[bodyFat.length - 1].body_fat_percentage, 1) : null,
            circumferences,
        };
    },

    async get_expenditure(source, env, { days = 28 } = {}) {
        const range = clampDays(days, 28, 180);
        const [user, strategy, annotations, loggingBreak, meals, measurements, steps, plan] = await Promise.all([
            source.user(), source.strategySettings(), source.annotations(), source.loggingBreak(),
            source.meals(null), source.measurements(null), source.steps(null), source.dietPlan(),
        ]);

        const openBreak = loggingBreak && !loggingBreak.end_date && asDate(loggingBreak.start_date) <= env.now ? loggingBreak : null;
        const today = openBreak ? dayOf(openBreak.start_date, env) : env.today;
        const breakStart = loggingBreak ? asDate(loggingBreak.start_date) : null;
        const sampleBreak = breakStart ? {
            startDay: isLocalMidnight(breakStart, env.timeZone) ? dayOf(breakStart, env) : addDays(dayOf(breakStart, env), 1),
            endDay: loggingBreak.end_date ? dayOf(loggingBreak.end_date, env) : null,
        } : null;

        const live = (m) => !m.deleted_at;
        const samples = expenditureSamples({
            meals: meals.map((m) => ({ dayKey: m.day_key ?? dayOf(m.date, env), calories: mealTotals(m).calories })),
            measurements: measurements.map((m) => ({ day: dayOf(m.date, env), weightKg: m.weight_kg, deleted: !live(m), at: asDate(m.date)?.getTime() ?? 0 })),
            steps: steps.map((s) => ({ day: dayOf(s.date, env), number: s.number ?? 0, deleted: !live(s) })),
            annotations: (annotations ?? []).map((a) => ({ dayKey: a.day_key, isPartiallyLogged: a.is_partially_logged === true, isFastingDay: a.is_fasting_day === true })),
            loggingBreak: sampleBreak,
            today,
        });

        const latestBodyFat = measurements.filter((m) => live(m) && Number.isFinite(m.body_fat_percentage))
            .sort((a, b) => (asDate(b.date) ?? 0) - (asDate(a.date) ?? 0))[0]?.body_fat_percentage ?? null;
        const age = ageYears(user, env.now);
        const prior = estimateTDEE({
            gender: user?.submitted_gender,
            weightKg: user?.submitted_weight_kilograms,
            heightCm: user?.submitted_height_centimeters,
            ageYears: age == null ? 30 : Math.max(14, age),
            activity: user?.submitted_daily_activity_level ?? "moderate",
        }, { equation: resolvedBMREquation(strategy, latestBodyFat), bodyFatPercentage: latestBodyFat });

        const history = expenditureHistory({
            samples,
            priorKcal: prior,
            settings: {
                calculationMode: strategy?.calculation_mode ?? "dynamic",
                calculationStartDay: strategy?.calculation_start_date ? dayOf(strategy.calculation_start_date, env) : null,
                stepInformedUpdates: strategy?.step_informed_updates === true,
            },
            today,
            kcalPerKg: expenditureKcalPerKg(measurements.filter(live), env.now, user?.submitted_weight_kilograms ?? null),
        });
        const shape = (e) => ({
            day: e.day, kcal: e.kcal, source: e.source, provisional: e.isProvisional,
            trendWeight: weight(e.trendWeightKg, env), weeklyTrendChange: weight(e.weeklyTrendChangeKg, env),
            loggedDaysInWindow: e.loggedDays, weighInsInWindow: e.weighInCount, stepAdjustmentKcal: round(e.stepAdjustmentKcal, 0),
            sdKcal: round(e.sdKcal, 0), likely80PercentRangeKcal: e.source === "adaptive" && e.sdKcal != null ? [round(e.kcal - 1.28 * e.sdKcal, 0), round(e.kcal + 1.28 * e.sdKcal, 0)] : null,
            weeklyTrendChangeSD: weight(e.weeklyTrendChangeSDKg, env), recentLoggedIntakeKcal: round(e.recentIntakeKcal, 0),
        });
        return {
            note: "The app's adaptive expenditure: a daily Kalman filter over trend weight, habitual intake and expenditure, fed by weigh-ins and completely logged days (days in a logging break, flagged partial, or under half the estimate unless marked as a fast are skipped). It is on the scale the user logs, so it is 'based on what you logged'. 'prior' (and 'provisional') means it is still calibrating, which lasts until 21 days, 14 weigh-ins, an SD under 200 kcal and 80% of the last 28 days logged; the formula figure stands meanwhile. The shown figure stays within 60-160% of the formula. sdKcal is the filter's 1-SD uncertainty; the likely range is the 80% interval (±1.28 SD). Even with good data, individual estimates carry about ±200 kcal of error.",
            current: shape(history[history.length - 1]),
            formulaEstimateKcal: round(prior, 0),
            formulaNote: "The formula estimate is resting metabolic rate (Mifflin-St Jeor by default; Cunningham, 500 + 22 x fat-free mass, when body fat is logged and the user opted in) times a physical activity level for the user's activity answer: sedentary 1.4, light 1.55, moderate 1.7, active 1.85, very active 2.0, with workouts counted inside that answer. Typical error is a few hundred kcal a day.",
            frozenByOpenLoggingBreak: openBreak != null,
            dietPlanBuiltOnKcal: round(plan?.tdeeEstimate, 0),
            history: history.slice(-range).map(shape),
        };
    },

    async get_steps(source, env, { days = 14 } = {}) {
        const range = clampDays(days, 14, 180);
        const [steps, analytics] = await Promise.all([source.steps(rangeStart(env, range)), source.analyticsSettings()]);
        const byDay = {};
        for (const s of steps) {
            if (s.deleted_at) continue;
            const day = dayOf(s.date, env);
            if (day && daysBetween(day, env.today) < range) byDay[day] = Math.max(byDay[day] ?? 0, s.number ?? 0);
        }
        const recorded = Object.values(byDay);
        return {
            rangeDays: range,
            dailyGoal: analytics?.daily_step_goal ?? 8000,
            averagePerRecordedDay: recorded.length ? round(recorded.reduce((a, b) => a + b, 0) / recorded.length, 0) : null,
            days: Object.entries(byDay).sort(([a], [b]) => (a < b ? -1 : 1)).map(([day, count]) => ({ day, steps: count })),
        };
    },

    async get_plan(source, env) {
        const [user, mesocycles, macrocycles] = await Promise.all([source.user(), source.mesocycles(), source.macrocycles()]);
        const mesocycle = mesocycles.find((m) => m.id === user?.submitted_active_mesocycle_id);
        if (!mesocycle) return { activeMesocycle: null };
        const macrocycle = [...macrocycles].filter((m) => m.status === "active" || m.status === "completed")
            .sort((a, b) => (asDate(b.date_modified) ?? 0) - (asDate(a.date_modified) ?? 0))[0] ?? null;
        const followsIt = macrocycle && (macrocycle.mesocycle_ids ?? [])[macrocycle.mesocycle_index ?? 0] === mesocycle.id;
        // ponytail: an account from before macrocycles counts from the epoch rather than replaying
        // MesocycleSchedule.legacyRun's restart rule; fine for anyone on a current build.
        const startedAt = followsIt ? asDate(macrocycle.mesocycle_started_at) : new Date(0);
        const sessions = (await finishedSessions(source, env, null)).filter((s) => !s.isRestDay && s.at >= startedAt.getTime());
        const progress = mesocycleProgress(mesocycle, sessions, followsIt ? macrocycle : null);
        const dayPlan = (t) => ({ name: t.name, isRestDay: (t.exercises ?? []).length === 0, exercises: (t.exercises ?? []).map((e) => `${e.exercise?.name ?? "?"} × ${(e.set_targets ?? []).length || 1} sets`) });
        return {
            macrocycle: followsIt ? { name: macrocycle.name, mesocycle: (macrocycle.mesocycle_index ?? 0) + 1, of: (macrocycle.mesocycle_ids ?? []).length, status: macrocycle.status } : null,
            activeMesocycle: {
                name: mesocycle.name,
                microcycles: mesocycle.num_microcycles,
                deload: mesocycle.deload ?? "none",
                startedOn: dayOf(startedAt, env),
                currentMicrocycle: progress.currentCycle + 1,
                isDeloadWeek: (mesocycle.deload === "start" && progress.currentCycle === 0) || (mesocycle.deload === "end" && progress.currentCycle + 1 === mesocycle.num_microcycles),
                deloadWeekRule: "A deload week keeps about half of each exercise's working sets (rounded up, at least one) at 90% of the planned weight, reps as planned; frequency is unchanged.",
                complete: progress.next == null,
                nextWorkout: progress.next ? dayPlan(progress.next) : null,
                trainedToday: sessions.some((s) => s.day === env.today),
                dayPlans: (mesocycle.workout_templates ?? []).map(dayPlan),
            },
        };
    },

    async get_check_ins(source, env) {
        const [record, strategy] = await Promise.all([source.checkInRecord(), source.strategySettings()]);
        return {
            checkInWeekday: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][(strategy?.check_in_weekday ?? 2) - 1],
            lastCompletedWeekStarting: record?.last_completed_week_start ? dayOf(record.last_completed_week_start, env) : null,
            lastSkippedWeekStarting: record?.last_skipped_week_start ? dayOf(record.last_skipped_week_start, env) : null,
        };
    },
};

/// MesocycleSchedule.progress for workout slots: each finished session fills its own day's slot
/// in the lowest microcycle where it is still open; skipped slots stay closed. Rest days never
/// hold the queue up, so they are left out.
export function mesocycleProgress(mesocycle, sessions, macrocycle) {
    const plans = mesocycle.workout_templates ?? [];
    const cycles = Math.max(mesocycle.num_microcycles ?? 1, 1);
    const firstCycle = macrocycle?.start_microcycle_index ?? 0;
    const open = Array.from({ length: cycles }, (_, cycle) => plans.map((plan) => (plan.exercises ?? []).length > 0 && cycle >= firstCycle));
    for (const skip of (macrocycle?.skips ?? []).filter((s) => s.mesocycle_index === (macrocycle.mesocycle_index ?? 0))) {
        if (open[skip.cycle_index]?.[skip.position] !== undefined && plans[skip.position]?.workout_id === skip.template_id) open[skip.cycle_index][skip.position] = false;
    }
    const names = new Set(plans.map((p) => p.name));
    for (const session of [...sessions].sort((a, b) => a.at - b.at)) {
        if (!(session.mesocycleId === mesocycle.id || (session.mesocycleId == null && names.has(session.name)))) continue;
        outer: for (let cycle = 0; cycle < cycles; cycle++) {
            for (let position = 0; position < plans.length; position++) {
                const plan = plans[position];
                const same = session.templateId ? plan.workout_id === session.templateId : plan.name === session.name;
                if (open[cycle][position] && same) { open[cycle][position] = false; break outer; }
            }
        }
    }
    for (let cycle = 0; cycle < cycles; cycle++) {
        const position = open[cycle].indexOf(true);
        if (position >= 0) return { currentCycle: cycle, next: plans[position] };
    }
    return { currentCycle: cycles - 1, next: null };
}

// MARK: - Genkit wiring

const TOOL_SPECS = {
    get_profile_and_targets: { description: "The user's profile, units, weekly session goal, weight goal, diet plan with daily calorie and macro targets, and nutrition strategy. Call this first in most conversations.", input: z.object({}) },
    get_workout_history: { description: "Finished workouts in the last N days with every set (weight, reps, RPE, warm-ups) and notes. Optionally only one exercise (name or id).", input: z.object({ days: z.number().optional(), exercise: z.string().optional() }) },
    get_exercise_progress: { description: "One exercise over the last N weeks: best set and estimated 1RM per session, working sets, volume, and new bests.", input: z.object({ exercise: z.string(), weeks: z.number().optional() }) },
    get_training_volume: { description: "Weighted hard sets per muscle per week over the last N weeks (1-12), with the app's volume tier for the last week (10-20 productive for every muscle).", input: z.object({ weeks: z.number().optional() }) },
    get_nutrition: { description: "Daily calories and macros against that day's targets over the last N days, with meals and notes for ranges up to 14 days, partial or fasting days, and logging breaks.", input: z.object({ days: z.number().optional() }) },
    get_body_metrics: { description: "Weigh-ins with the smoothed trend, body fat and body circumferences over the last N days.", input: z.object({ days: z.number().optional() }) },
    get_expenditure: { description: "The app's adaptive daily energy expenditure (TDEE): today's estimate, how it was reached, and its recent history.", input: z.object({ days: z.number().optional() }) },
    get_steps: { description: "Daily step counts over the last N days and the user's step goal.", input: z.object({ days: z.number().optional() }) },
    get_plan: { description: "The training plan being followed: macrocycle, active mesocycle, current microcycle, deload, and the next workout.", input: z.object({}) },
    get_check_ins: { description: "The weekly nutrition check-in day and when the last check-ins were completed or skipped.", input: z.object({}) },
};

/// The tools on a Genkit instance. The caller's data reaches them through `context.coach`, which
/// the model can neither see nor set.
export function defineCoachTools(ai) {
    return Object.entries(TOOL_SPECS).map(([name, spec]) => ai.defineTool(
        { name, description: spec.description, inputSchema: spec.input, outputSchema: z.any() },
        async (input, { context }) => {
            const { source, env } = context.coach;
            try {
                return await COACH_TOOLS[name](source, env, input ?? {});
            } catch (error) {
                console.error(`coach tool ${name} failed: ${error.message}`);
                return { error: "This data could not be read just now." };
            }
        },
    ));
}

const CONTEXT_LINES = {
    today: () => "The user opened the coach from the Today screen.",
    weight_trend: () => "The user opened the coach from their weight trend.",
    exercise: (c) => `The user opened the coach from the history of one exercise (exercise id "${c.id}"); start with get_exercise_progress for it.`,
    session: (c) => `The user opened the coach from one workout (session id "${c.id}"${c.date ? `, on ${c.date}` : ""}); look it up with get_workout_history.`,
    check_in: () => "The user opened the coach from their weekly nutrition check-in.",
    nutrition_day: (c) => `The user opened the coach from their food log for ${c.date ?? "a day"}.`,
    weekly_review: () => "The user opened the coach from their weekly review of last week.",
    mesocycle: () => "The user opened the coach from their training plan.",
    expenditure: () => "The user opened the coach from their energy expenditure.",
    muscle_group: (c) => `The user opened the coach from the "${c.id}" muscle group; get_training_volume covers it.`,
};

export function coachSystemPrompt(env, context) {
    return [
        "You are Compound's coach: a knowledgeable, encouraging strength and nutrition coach for this one user, inside the Compound app.",
        `Today is ${env.today} (${env.timeZone}). Use ${env.weightUnit} for weight, ${env.distanceUnit} for distance and ${env.lengthUnit} for body measurements.${env.firstName ? ` The user's first name is ${env.firstName}.` : ""}`,
        "Rules:",
        "- Every number about the user must come from a tool result. Never estimate, invent or assume the user's figures. If the data is missing, say so plainly and suggest what to log.",
        "- Say what an answer is based on, briefly (for example: \"from your last 4 bench sessions\" or \"over the last 28 days of logging\").",
        "- Expenditure, the weight trend and estimated 1RMs come from the tools exactly as the app shows them; do not recompute them a different way.",
        "- Never advise eating below the user's calorie floor in their diet plan, or losing more than about 1% of body weight a week. Do not recommend crash diets, extreme fasting or dehydration.",
        "- For pain, injury, illness, medication, pregnancy or disordered eating, be supportive and recommend a qualified professional instead of giving treatment advice.",
        "- You can only read data. You cannot log, edit, delete or change anything in the app (workouts, meals, targets, plans or settings). If asked, say so and tell the user where in the app to do it.",
        "- You have no access to Strava, progress photos, or other people's data, including friends and followers.",
        "- Be concise and concrete: short paragraphs or a few bullets, plain language, no tables unless asked. Answer the question first.",
        context ? `Context: ${CONTEXT_LINES[context.kind](context)}` : "",
    ].filter(Boolean).join("\n");
}

/// The reply generator `coachChat` calls: `runCoach` on Vertex, replaced in tests.
export const coachRuntime = { reply: null };

/// One reply: the system prompt, the recent turns and the message, with the tools bound to the
/// caller's data. `onChunk` gets each piece of text as it arrives.
export async function runCoach({ ai, model, tools, config, source, env, history, message, context, onChunk }) {
    const { stream, response } = ai.generateStream({
        model,
        system: coachSystemPrompt(env, context),
        messages: history,
        prompt: message,
        tools,
        maxTurns: 8,
        config,
        context: { coach: { source, env } },
    });
    for await (const chunk of stream) {
        if (chunk.text) onChunk?.(chunk.text);
    }
    return (await response).text.trim();
}
