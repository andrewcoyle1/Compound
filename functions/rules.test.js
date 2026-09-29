// Firestore security rules, one allow and one deny per `match` block in ../firestore.rules.
// Needs the Firestore emulator: run `npm run test:rules`, which starts it under the demo project.
// Plain `npm test` also picks this file up; without FIRESTORE_EMULATOR_HOST it skips itself.
import { test, before, beforeEach, after } from "node:test";
import { readFileSync } from "node:fs";
import {
    initializeTestEnvironment, assertSucceeds, assertFails,
} from "@firebase/rules-unit-testing";
import {
    doc, getDoc, setDoc, updateDoc, deleteDoc, arrayUnion, arrayRemove,
    collectionGroup, query, where, getDocs, Timestamp,
} from "firebase/firestore";

const skip = !process.env.FIRESTORE_EMULATOR_HOST && "FIRESTORE_EMULATOR_HOST not set; run npm run test:rules";

let env;
const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const seed = (path, data) => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));
const now = () => Timestamp.now();
const later = (days) => Timestamp.fromMillis(Date.now() + days * 86_400_000);

// alice has blocked mallory. bob is a stranger in good standing.
const ALICE = "alice", BOB = "bob", MALLORY = "mallory";

before(async () => {
    if (skip) return;
    env = await initializeTestEnvironment({
        projectId: "demo-dialedin",
        firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") },
    });
});
beforeEach(async () => {
    if (skip) return;
    await env.clearFirestore();
    await seed(`users/${ALICE}`, { id: ALICE, blocked_user_ids: [MALLORY] });
});
after(async () => { if (env) await env.cleanup(); });

const t = (name, fn) => test(name, { skip }, fn);

// ---------------- USERS ----------------

t("users: any signed-in user reads a profile; signed-out does not", async () => {
    await assertSucceeds(getDoc(doc(db(BOB), `users/${ALICE}`)));
    await assertFails(getDoc(doc(db(), `users/${ALICE}`)));
});

t("users: owner writes their own profile, nobody else's", async () => {
    await assertSucceeds(setDoc(doc(db(BOB), `users/${BOB}`), { id: BOB }));
    await assertFails(setDoc(doc(db(BOB), `users/${ALICE}`), { id: ALICE }));
});

t("users: a username must be a reservation the writer holds", async () => {
    await seed(`usernames/bob`, { user_id: BOB });
    await seed(`usernames/alice`, { user_id: ALICE });
    await assertSucceeds(setDoc(doc(db(BOB), `users/${BOB}`), { username: "bob" }));
    await assertFails(setDoc(doc(db(BOB), `users/${BOB}`), { username: "alice" }));
    await assertFails(setDoc(doc(db(BOB), `users/${BOB}`), { username: "unclaimed" }));
    await assertSucceeds(setDoc(doc(db(BOB), `users/${BOB}`), { username: null }));
});

t("users/private: owner only", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), `users/${ALICE}/private/settings`), { fcm_token: "x" }));
    await assertFails(getDoc(doc(db(BOB), `users/${ALICE}/private/settings`)));
});

// Owner-only subcollections whose documents carry the owner as author_id / user_id.
for (const [sub, key] of [
    ["body_measurements", "author_id"], ["steps", "author_id"], ["goals", "user_id"],
    ["gym_profiles", "author_id"], ["training_programs", "author_id"], ["workout_templates", "author_id"],
    ["nutrition_day_annotations", "author_id"], ["logging_break", "author_id"],
    ["check_in_record", "author_id"], ["recipe_templates", "author_id"], ["foods", "author_id"],
]) {
    t(`users/${sub}: owner creates their own; another user and a forged owner field do not`, async () => {
        await assertSucceeds(setDoc(doc(db(ALICE), `users/${ALICE}/${sub}/d1`), { [key]: ALICE }));
        await assertFails(setDoc(doc(db(BOB), `users/${ALICE}/${sub}/d2`), { [key]: ALICE }));
        await assertFails(setDoc(doc(db(ALICE), `users/${ALICE}/${sub}/d3`), { [key]: BOB }));
        await assertFails(getDoc(doc(db(BOB), `users/${ALICE}/${sub}/d1`)));
    });
}

// Owner-only subcollections with no field checks.
for (const path of [
    "workout_settings/s", "exercise_settings/s", "food_log_settings/s", "analytics_settings/s",
    "shortcut_settings/s", "nutrition_strategy_settings/s", "meal_logs/2026-09-25/meals/m1",
]) {
    t(`users/${path.split("/")[0]}: owner only`, async () => {
        await assertSucceeds(setDoc(doc(db(ALICE), `users/${ALICE}/${path}`), { a: 1 }));
        await assertFails(getDoc(doc(db(BOB), `users/${ALICE}/${path}`)));
    });
}

t("users/goals: the fixed fields of a goal cannot change", async () => {
    await seed(`users/${ALICE}/goals/g`, { user_id: ALICE, target_weight_kg: 70, note: "a" });
    await assertSucceeds(updateDoc(doc(db(ALICE), `users/${ALICE}/goals/g`), { note: "b" }));
    await assertFails(updateDoc(doc(db(ALICE), `users/${ALICE}/goals/g`), { target_weight_kg: 60 }));
});

// ---------------- WORKOUT SESSIONS ----------------

const SESSION = `users/${ALICE}/workout_sessions/s1`;
const seedSession = (extra = {}) => seed(SESSION, { author_id: ALICE, liked_by_user_ids: [], ...extra });

t("users/workout_sessions: owner creates; another user cannot create in their path", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), SESSION), { author_id: ALICE }));
    await assertFails(setDoc(doc(db(BOB), `users/${ALICE}/workout_sessions/s2`), { author_id: BOB }));
});

t("users/workout_sessions: anyone unblocked toggles their own like; nothing else", async () => {
    await seedSession({ liked_by_user_ids: [ALICE] });
    await assertSucceeds(updateDoc(doc(db(BOB), SESSION), { liked_by_user_ids: arrayUnion(BOB) }));
    await assertSucceeds(updateDoc(doc(db(BOB), SESSION), { liked_by_user_ids: arrayRemove(BOB) }));
    await assertFails(updateDoc(doc(db(BOB), SESSION), { title: "mine now" }));
    // Someone else's like is theirs to take back, not bob's.
    await assertFails(updateDoc(doc(db(BOB), SESSION), { liked_by_user_ids: [] }));
});

t("users/workout_sessions: a blocked user cannot like", async () => {
    await seedSession();
    await assertFails(updateDoc(doc(db(MALLORY), SESSION), { liked_by_user_ids: arrayUnion(MALLORY) }));
});

t("users/workout_sessions: the owner cannot change hidden", async () => {
    await seedSession({ hidden: true, title: "a" });
    await assertSucceeds(updateDoc(doc(db(ALICE), SESSION), { title: "b" }));
    await assertFails(updateDoc(doc(db(ALICE), SESSION), { hidden: false }));
});

t("workout_sessions collection group: any signed-in user queries the feed; signed-out does not", async () => {
    await seedSession();
    const feed = (d) => getDocs(query(collectionGroup(d, "workout_sessions"), where("author_id", "==", ALICE)));
    await assertSucceeds(feed(db(BOB)));
    await assertFails(feed(db()));
});

// ---------------- FOLLOW REQUESTS ----------------

const REQ = (from) => `users/${ALICE}/follow_requests/${from}`;

t("users/follow_requests: requester creates their own pending request, not an accepted one", async () => {
    await assertSucceeds(setDoc(doc(db(BOB), REQ(BOB)), { requester_id: BOB, status: "pending" }));
    await assertFails(setDoc(doc(db(BOB), REQ("carol")), { requester_id: "carol", status: "pending" }));
    await assertFails(setDoc(doc(db(BOB), REQ(BOB)), { requester_id: BOB, status: "accepted" }));
});

t("users/follow_requests: a blocked user cannot request to follow", async () => {
    await assertFails(setDoc(doc(db(MALLORY), REQ(MALLORY)), { requester_id: MALLORY, status: "pending" }));
});

t("users/follow_requests: target accepts by changing status only; requester cannot accept", async () => {
    await seed(REQ(BOB), { requester_id: BOB, status: "pending" });
    await assertFails(updateDoc(doc(db(BOB), REQ(BOB)), { status: "accepted" }));
    await assertFails(updateDoc(doc(db(ALICE), REQ(BOB)), { status: "accepted", requester_id: "x" }));
    await assertSucceeds(updateDoc(doc(db(ALICE), REQ(BOB)), { status: "accepted" }));
});

t("users/follow_requests: requester cancels; a third party neither reads nor deletes", async () => {
    await seed(REQ(BOB), { requester_id: BOB, status: "pending" });
    await assertFails(getDoc(doc(db("carol"), REQ(BOB))));
    await assertFails(deleteDoc(doc(db("carol"), REQ(BOB))));
    await assertSucceeds(deleteDoc(doc(db(BOB), REQ(BOB))));
});

t("follow_requests collection group: a requester lists only their own outgoing requests", async () => {
    await seed(REQ(BOB), { requester_id: BOB, status: "pending" });
    const mine = (d, uid) => getDocs(query(collectionGroup(d, "follow_requests"), where("requester_id", "==", uid)));
    await assertSucceeds(mine(db(BOB), BOB));
    await assertFails(mine(db("carol"), BOB));
});

// ---------------- NOTIFICATIONS ----------------

const NOTE = `users/${ALICE}/notifications/n1`;

t("users/notifications: an actor writes as themselves; not as someone else, and cannot read", async () => {
    await assertSucceeds(setDoc(doc(db(BOB), NOTE), { actor_id: BOB, type: "like" }));
    await assertFails(setDoc(doc(db(BOB), `users/${ALICE}/notifications/n2`), { actor_id: "carol" }));
    await assertFails(getDoc(doc(db(BOB), NOTE)));
    await assertSucceeds(getDoc(doc(db(ALICE), NOTE)));
});

t("users/notifications: a blocked actor can neither create nor overwrite, but may delete their old one", async () => {
    await assertFails(setDoc(doc(db(MALLORY), NOTE), { actor_id: MALLORY }));
    await seed(NOTE, { actor_id: MALLORY });
    await assertFails(setDoc(doc(db(MALLORY), NOTE), { actor_id: MALLORY, type: "follow" }));
    await assertSucceeds(deleteDoc(doc(db(MALLORY), NOTE)));
});

// ---------------- STREAKS ----------------

for (const [name, path] of [
    ["user_streaks", ""], ["user_streaks/workout", "/workout/w"], ["user_streaks/workout/data", "/workout/w/data/d"],
]) {
    t(`${name}: owner writes; others do not`, async () => {
        await assertSucceeds(setDoc(doc(db(ALICE), `user_streaks/${ALICE}${path}`), { n: 1 }));
        await assertFails(setDoc(doc(db(BOB), `user_streaks/${ALICE}${path}`), { n: 2 }));
    });
}

// ---------------- ADMIN-ONLY ----------------
// No client allow exists for these; the deny is the whole contract.

for (const path of ["food_search_cache/q", "moderation_queue/t"]) {
    t(`${path.split("/")[0]}: closed to every client`, async () => {
        await assertFails(getDoc(doc(db(ALICE), path)));
        await assertFails(setDoc(doc(db(ALICE), path), { a: 1 }));
    });
}

// ---------------- TOP-LEVEL AUTHORED LIBRARIES ----------------

for (const [col, key] of [
    ["ingredient_templates", "author_id"], ["recipe_templates", "author_id"], ["gym_profiles", "author_id"],
    ["exercise_templates", "author_id"], ["workout_exercises", "author_id"], ["workout_sets", "author_id"],
    ["program_templates", "author_id"], ["training_plans", "user_id"], ["training_programs", "author_id"],
    ["workout_templates", "author_id"],
]) {
    t(`${col}: author creates and edits; others read but cannot edit`, async () => {
        await assertSucceeds(setDoc(doc(db(ALICE), `${col}/d`), { [key]: ALICE, name: "a" }));
        await assertFails(setDoc(doc(db(BOB), `${col}/e`), { [key]: ALICE }));
        await assertSucceeds(getDoc(doc(db(BOB), `${col}/d`)));
        await assertFails(updateDoc(doc(db(BOB), `${col}/d`), { name: "b" }));
    });
}

t("workout_templates: anyone bumps click_count by exactly one", async () => {
    await seed("workout_templates/w", { author_id: ALICE, click_count: 3 });
    await assertSucceeds(updateDoc(doc(db(BOB), "workout_templates/w"), { click_count: 4 }));
    await assertFails(updateDoc(doc(db(BOB), "workout_templates/w"), { click_count: 10 }));
});

t("exercise_history: author only, reads included", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), "exercise_history/h"), { author_id: ALICE }));
    await assertFails(getDoc(doc(db(BOB), "exercise_history/h")));
});

t("diet_plans: owner only, and a userId field must match", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), `diet_plans/${ALICE}`), { userId: ALICE }));
    await assertFails(setDoc(doc(db(ALICE), `diet_plans/${ALICE}`), { userId: BOB }));
    await assertFails(getDoc(doc(db(BOB), `diet_plans/${ALICE}`)));
});

// ---------------- REPORTS ----------------

const report = (over = {}) => ({
    id: "r1", reporter_id: BOB, target_type: "session", target_id: "s1", target_author_id: ALICE,
    reason: "spam", note: null, status: "open", date_created: now(), ...over,
});

t("reports: reporter files an open report as themselves; nobody reads it", async () => {
    await assertSucceeds(setDoc(doc(db(BOB), "reports/r1"), report()));
    await assertFails(getDoc(doc(db(BOB), "reports/r1")));
    await assertFails(setDoc(doc(db(BOB), "reports/r2"), report({ id: "r2", reporter_id: ALICE })));
    await assertFails(setDoc(doc(db(BOB), "reports/r3"), report({ id: "r3", status: "resolved" })));
});

// ---------------- COMMENTS ----------------

const COMMENT = "workout_session_comments/c1";
const comment = (author, over = {}) => ({ author_id: author, session_author_id: ALICE, text: "nice", ...over });

t("workout_session_comments: author comments; a blocked user and a missing session_author_id do not", async () => {
    await assertSucceeds(setDoc(doc(db(BOB), COMMENT), comment(BOB)));
    await assertFails(setDoc(doc(db(MALLORY), "workout_session_comments/c2"), comment(MALLORY)));
    const { session_author_id: _, ...bare } = comment(BOB);
    await assertFails(setDoc(doc(db(BOB), "workout_session_comments/c3"), bare));
});

t("workout_session_comments: author soft-deletes only; no edits, no hard delete", async () => {
    await seed(COMMENT, comment(BOB));
    await assertSucceeds(updateDoc(doc(db(BOB), COMMENT), { deleted_at: now() }));
    await assertFails(updateDoc(doc(db(BOB), COMMENT), { text: "edited" }));
    await assertFails(deleteDoc(doc(db(BOB), COMMENT)));
});

t("workout_session_comments likes: own id only, and not by someone the comment author blocked", async () => {
    await seed(COMMENT, comment(ALICE, { liked_by_user_ids: [BOB] }));
    await assertSucceeds(updateDoc(doc(db("carol"), COMMENT), { liked_by_user_ids: arrayUnion("carol") }));
    await assertFails(updateDoc(doc(db("carol"), COMMENT), { liked_by_user_ids: arrayRemove(BOB) }));
    await assertFails(updateDoc(doc(db(MALLORY), COMMENT), { liked_by_user_ids: arrayUnion(MALLORY) }));
});

// ---------------- USERNAMES ----------------

t("usernames: claim a valid free handle for yourself; not an invalid one, not for someone else", async () => {
    await assertSucceeds(setDoc(doc(db(BOB), "usernames/bob_1"), { user_id: BOB }));
    await assertFails(setDoc(doc(db(BOB), "usernames/.bob"), { user_id: BOB }));
    await assertFails(setDoc(doc(db(BOB), "usernames/Bob"), { user_id: BOB }));
    await assertFails(setDoc(doc(db(BOB), "usernames/carol"), { user_id: "carol" }));
});

t("usernames: a taken handle cannot be overwritten; only its owner releases it", async () => {
    await seed("usernames/alice", { user_id: ALICE });
    await assertFails(setDoc(doc(db(BOB), "usernames/alice"), { user_id: BOB }));
    await assertFails(deleteDoc(doc(db(BOB), "usernames/alice")));
    await assertSucceeds(deleteDoc(doc(db(ALICE), "usernames/alice")));
});

// ---------------- SHARES ----------------

const share = (from, to, over = {}) => ({ id: "sh1", from_user_id: from, to_user_id: to, kind: "template", status: "pending", ...over });

t("shares: sender creates a pending share for someone else who has not blocked them", async () => {
    await assertSucceeds(setDoc(doc(db(BOB), "shares/sh1"), share(BOB, ALICE)));
    await assertFails(setDoc(doc(db(BOB), "shares/sh2"), share(BOB, BOB, { id: "sh2" })));
    await assertFails(setDoc(doc(db(MALLORY), "shares/sh3"), share(MALLORY, ALICE, { id: "sh3" })));
});

t("shares: only the recipient answers; a third party cannot read", async () => {
    await seed("shares/sh1", share(BOB, ALICE));
    await assertFails(getDoc(doc(db("carol"), "shares/sh1")));
    await assertFails(updateDoc(doc(db(BOB), "shares/sh1"), { status: "accepted" }));
    await assertSucceeds(updateDoc(doc(db(ALICE), "shares/sh1"), { status: "accepted" }));
    await assertSucceeds(deleteDoc(doc(db(BOB), "shares/sh1")));
});

// ---------------- CHALLENGES ----------------

const CH = "challenges/ch1";
const challenge = (over = {}) => ({
    id: "ch1", owner_id: ALICE, title: "Ten in Oct", member_ids: [ALICE, BOB], target_sessions: 10,
    starts_at: now(), ends_at: later(30), date_created: now(), ...over,
});

t("challenges: owner creates as a member; not when they left themselves out", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), CH), challenge()));
    await assertFails(setDoc(doc(db(ALICE), "challenges/ch2"), challenge({ id: "ch2", member_ids: [BOB] })));
    await assertFails(setDoc(doc(db(ALICE), "challenges/ch3"), challenge({ id: "ch3", ends_at: now(), starts_at: later(1) })));
});

t("challenges: members read; others do not", async () => {
    await seed(CH, challenge());
    await assertSucceeds(getDoc(doc(db(BOB), CH)));
    await assertFails(getDoc(doc(db("carol"), CH)));
});

t("challenges: a member leaves; they cannot remove someone else; owner renames", async () => {
    await seed(CH, challenge({ member_ids: [ALICE, BOB, "carol"] }));
    await assertFails(updateDoc(doc(db(BOB), CH), { member_ids: [ALICE, BOB] }));
    await assertSucceeds(updateDoc(doc(db(BOB), CH), { member_ids: arrayRemove(BOB) }));
    await assertSucceeds(updateDoc(doc(db(ALICE), CH), { title: "Renamed" }));
    await assertFails(updateDoc(doc(db(BOB), CH), { title: "Hijacked" }));
});

t("challenges/progress: members read; no client writes", async () => {
    await seed(CH, challenge());
    await seed(`${CH}/progress/${BOB}`, { sessions: 2 });
    await assertSucceeds(getDoc(doc(db(BOB), `${CH}/progress/${BOB}`)));
    await assertFails(getDoc(doc(db("carol"), `${CH}/progress/${BOB}`)));
    await assertFails(setDoc(doc(db(BOB), `${CH}/progress/${BOB}`), { sessions: 99 }));
});

// ---------------- INVITES ----------------

const invite = (code, over = {}) => ({ code, inviter_id: BOB, date_created: now(), uses: 0, max_uses: 50, ...over });

t("invites: inviter creates an unused code of the right shape; nobody edits it", async () => {
    await assertSucceeds(setDoc(doc(db(BOB), "invites/ABCD2345"), invite("ABCD2345")));
    await assertFails(setDoc(doc(db(BOB), "invites/ABCD0O1I"), invite("ABCD0O1I")));
    await assertFails(setDoc(doc(db(BOB), "invites/WXYZ2345"), invite("WXYZ2345", { uses: 5 })));
    await assertSucceeds(getDoc(doc(db(ALICE), "invites/ABCD2345")));
    await assertFails(updateDoc(doc(db(BOB), "invites/ABCD2345"), { uses: 1 }));
});

// ---------------- PROGRESS PHOTOS ----------------

const photo = (id, owner = ALICE, over = {}) => ({
    id, author_id: owner, date: now(), pose: "front",
    storage_path: `users/${owner}/progress_photos/${id}.jpg`, image_url: "https://example.com/p.jpg", ...over,
});
const PHOTO = `users/${ALICE}/progress_photos/p1`;

t("users/progress_photos: owner creates, reads, updates and deletes their own", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), PHOTO), photo("p1", ALICE, { weight_kg: 80.5, note: "week 1" })));
    await assertSucceeds(getDoc(doc(db(ALICE), PHOTO)));
    await assertSucceeds(updateDoc(doc(db(ALICE), PHOTO), { pose: "side" }));
    await assertSucceeds(deleteDoc(doc(db(ALICE), PHOTO)));
});

t("users/progress_photos: nobody else reads, writes or deletes them", async () => {
    await seed(PHOTO, photo("p1"));
    await assertFails(getDoc(doc(db(BOB), PHOTO)));
    await assertFails(getDoc(doc(db(), PHOTO)));
    await assertFails(setDoc(doc(db(BOB), `users/${ALICE}/progress_photos/p2`), photo("p2")));
    await assertFails(updateDoc(doc(db(BOB), PHOTO), { note: "hi" }));
    await assertFails(deleteDoc(doc(db(BOB), PHOTO)));
});

t("users/progress_photos: a forged owner, storage path, pose, id or extra field is rejected", async () => {
    const path = `users/${ALICE}/progress_photos/p3`;
    await assertFails(setDoc(doc(db(ALICE), path), photo("p3", ALICE, { author_id: BOB })));
    await assertFails(setDoc(doc(db(ALICE), path), photo("p3", ALICE, { storage_path: `users/${BOB}/progress_photos/p3.jpg` })));
    await assertFails(setDoc(doc(db(ALICE), path), photo("p3", ALICE, { pose: "flexing" })));
    await assertFails(setDoc(doc(db(ALICE), path), photo("p4")));
    await assertFails(setDoc(doc(db(ALICE), path), photo("p3", ALICE, { is_public: true })));
    await assertFails(setDoc(doc(db(ALICE), path), photo("p3", ALICE, { date: "yesterday" })));
});
