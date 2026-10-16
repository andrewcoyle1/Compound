// Firestore security rules, one allow and one deny per `match` block in ../firestore.rules.
// Needs the Firestore emulator: run `npm run test:rules`, which starts it under the demo project.
// Plain `npm test` also picks this file up; without FIRESTORE_EMULATOR_HOST it skips itself.
import { test, before, beforeEach, after } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
    initializeTestEnvironment, assertSucceeds, assertFails,
} from "@firebase/rules-unit-testing";
import {
    doc, getDoc, setDoc, updateDoc, deleteDoc, arrayUnion, arrayRemove,
    collectionGroup, query, where, getDocs, Timestamp, deleteField, writeBatch,
    collection, orderBy, limit, serverTimestamp,
} from "firebase/firestore";
import {
    SOCIAL_PUSH_PREFERENCE_KEYS, buildFollowAcceptedNotification, buildFollowNotification, buildInviteFollowRequest,
    planChallengeProgress, stravaActivityDoc,
} from "./lib.js";

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

t("users: only the owner deletes their profile, whatever its username (account deletion)", async () => {
    // The Flutter and Swift apps delete users/{uid} before the Auth user; onUserDeleted does the rest.
    await seed(`users/${BOB}`, { id: BOB, username: "unreserved" });
    await assertFails(deleteDoc(doc(db(ALICE), `users/${BOB}`)));
    await assertSucceeds(deleteDoc(doc(db(BOB), `users/${BOB}`)));
});

t("users/private: owner only", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), `users/${ALICE}/private/settings`), { fcm_token: "x" }));
    await assertFails(getDoc(doc(db(BOB), `users/${ALICE}/private/settings`)));
});

// ---------------- FIRESTORE CONTRACT ----------------
// Each model's `full` fixture in ../contracts/firestore (docs/specs/flutter/firestore-contract.md)
// is a document both apps may write, so its owner must be able to create it where it lives.
const contractFixture = (model, name = "full") => JSON.parse(
    readFileSync(new URL(`../contracts/firestore/${model}/${name}.json`, import.meta.url), "utf8"),
    (_, value) => (value && typeof value === "object" && !Array.isArray(value)
        && Object.keys(value).length === 1 && typeof value.$timestamp === "string")
        ? Timestamp.fromDate(new Date(value.$timestamp)) : value,
);

t("contract: the owner creates the full UserModel and PrivateUserSettings at their paths", async () => {
    const user = contractFixture("user_model");
    const uid = user.user_id;
    await seed(`usernames/${user.username}`, { user_id: uid });
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}`), user));
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/private/settings`), contractFixture("private_user_settings")));
});

t("contract: the author creates the full WorkoutSessionModel at its path", async () => {
    const session = contractFixture("workout_session");
    const uid = session.author_id;
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/workout_sessions/${session.id}`), session));
});

t("contract: the owner creates the full meal, diet plan and food log settings at their paths", async () => {
    const meal = contractFixture("meal_log");
    const uid = meal.author_id;
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/meal_logs/${meal.meal_id}`), meal));
    const plan = contractFixture("diet_plan");
    await assertSucceeds(setDoc(doc(db(plan.userId), `diet_plans/${plan.userId}`), plan));
    const settings = contractFixture("food_log_settings");
    await assertSucceeds(setDoc(
        doc(db(settings.author_id), `users/${settings.author_id}/food_log_settings/${settings.id}`), settings,
    ));
});

t("contract: the owner creates the full body measurement, steps, analytics settings and goal at their paths", async () => {
    const entry = contractFixture("body_measurement");
    const uid = entry.author_id;
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/body_measurements/${entry.id}`), entry));
    const steps = contractFixture("steps");
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/steps/${steps.id}`), steps));
    const settings = contractFixture("analytics_settings");
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/analytics_settings/${settings.id}`), settings));
    const goal = contractFixture("weight_goal");
    const goalRef = doc(db(uid), `users/${uid}/goals/${goal.goal_id}`);
    await assertSucceeds(setDoc(goalRef, goal));
    // GoalManager's status update is allowed; a write that moves where the goal started is not.
    await assertSucceeds(updateDoc(goalRef, { status: "abandoned" }));
    await assertFails(setDoc(goalRef, { ...goal, starting_weight_kg: goal.starting_weight_kg + 1 }, { merge: true }));
});

t("contract: the Flutter app's single-field analytics settings merges create and update it, owner only", async () => {
    // body_repository's saveStepGoal and saveHiddenSections: each merges one field with the fixed id and
    // author_id, the step goal with an empty arrayUnion that creates hidden_section_ids only when missing.
    const uid = "user_contract_minimal";
    const ref = (as) => doc(db(as), `users/${uid}/analytics_settings/analytics_settings`);
    const fixed = { id: "analytics_settings", author_id: uid };
    const stepGoal = (goal) => ({ ...fixed, daily_step_goal: goal, hidden_section_ids: arrayUnion() });
    const hidden = (ids) => ({ ...fixed, hidden_section_ids: ids });

    // Created from nothing by either write.
    await assertSucceeds(setDoc(ref(uid), stepGoal(9000), { merge: true }));
    const created = (await getDoc(ref(uid))).data();
    assert.deepEqual(created, { ...fixed, daily_step_goal: 9000, hidden_section_ids: [] });
    await env.clearFirestore();
    await assertSucceeds(setDoc(ref(uid), hidden(["habits"]), { merge: true }));

    // Updated, each leaving the other field alone.
    await assertSucceeds(setDoc(ref(uid), stepGoal(6000), { merge: true }));
    await assertSucceeds(setDoc(ref(uid), hidden(["habits", "nutrition"]), { merge: true }));
    assert.deepEqual((await getDoc(ref(uid))).data(), {
        ...fixed, daily_step_goal: 6000, hidden_section_ids: ["habits", "nutrition"],
    });

    await assertFails(setDoc(ref(BOB), stepGoal(1), { merge: true }));
    await assertFails(setDoc(ref(BOB), hidden([]), { merge: true }));
});

t("contract: the author creates the full exercise and workout template where the app keeps them", async () => {
    // The app keeps a user's exercises in the top-level exercise_templates, queried by author_id;
    // there is no users/{uid}/exercises.
    const exercise = contractFixture("exercise_model");
    const uid = exercise.author_id;
    await assertSucceeds(setDoc(doc(db(uid), `exercise_templates/${exercise.id}`), exercise));
    await assertFails(setDoc(doc(db(BOB), `exercise_templates/bob_copy`), exercise));
    await assertFails(setDoc(doc(db(uid), `users/${uid}/exercises/${exercise.id}`), exercise));
    const template = contractFixture("workout_template");
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/workout_templates/${template.workout_id}`), template));
    await assertSucceeds(setDoc(doc(db(uid), `workout_templates/${template.workout_id}`), template));
    await assertFails(setDoc(doc(db(BOB), `workout_templates/bob_copy`), template));
    await assertFails(setDoc(doc(db(BOB), `users/${BOB}/workout_templates/${template.workout_id}`), template));
});

t("contract: the owner creates the full gym profile and exercise and workout settings at their paths", async () => {
    const gym = contractFixture("gym_profile");
    const uid = gym.author_id;
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/gym_profiles/${gym.id}`), gym));
    await assertFails(setDoc(doc(db(BOB), `users/${BOB}/gym_profiles/${gym.id}`), gym));
    await assertFails(setDoc(doc(db(BOB), `users/${uid}/gym_profiles/bob_copy`), gym));
    const exerciseSettings = contractFixture("exercise_settings");
    await assertSucceeds(setDoc(
        doc(db(uid), `users/${uid}/exercise_settings/${exerciseSettings.id}`), exerciseSettings,
    ));
    const workoutSettings = contractFixture("workout_settings");
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/workout_settings/workout_settings`), workoutSettings));
    await assertFails(setDoc(doc(db(BOB), `users/${uid}/workout_settings/workout_settings`), workoutSettings));
});

t("contract: the owner creates the full mesocycle, macrocycle and food at their paths", async () => {
    const mesocycle = contractFixture("mesocycle");
    const uid = mesocycle.author_id;
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/mesocycles/${mesocycle.id}`), mesocycle));
    await assertFails(setDoc(doc(db(BOB), `users/${uid}/mesocycles/bob_copy`), mesocycle));
    await assertFails(setDoc(doc(db(BOB), `users/${BOB}/mesocycles/${mesocycle.id}`), mesocycle));
    const macrocycle = contractFixture("macrocycle");
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/macrocycles/${macrocycle.id}`), macrocycle));
    await assertFails(setDoc(doc(db(BOB), `users/${uid}/macrocycles/bob_copy`), macrocycle));
    await assertFails(setDoc(doc(db(BOB), `users/${BOB}/macrocycles/${macrocycle.id}`), macrocycle));
    const food = contractFixture("food_model");
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/foods/${food.ingredient_id}`), food));
    await assertFails(setDoc(doc(db(BOB), `users/${uid}/foods/bob_copy`), food));
    await assertFails(setDoc(doc(db(BOB), `users/${BOB}/foods/${food.ingredient_id}`), food));
});

t("contract: the owner creates the full recipe at its path", async () => {
    const recipe = contractFixture("recipe_template");
    const uid = recipe.author_id;
    await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/recipe_templates/${recipe.recipe_id}`), recipe));
    await assertFails(setDoc(doc(db(BOB), `users/${uid}/recipe_templates/bob_copy`), recipe));
    await assertFails(setDoc(doc(db(BOB), `users/${BOB}/recipe_templates/${recipe.recipe_id}`), recipe));
});

t("contract: the owner creates the full and minimal progress photo at their paths", async () => {
    for (const name of ["full", "minimal"]) {
        const photo = contractFixture("progress_photo", name);
        const uid = photo.author_id;
        await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/progress_photos/${photo.id}`), photo));
        await assertFails(setDoc(doc(db(BOB), `users/${uid}/progress_photos/bob_copy`), photo));
        await assertFails(setDoc(doc(db(BOB), `users/${BOB}/progress_photos/${photo.id}`), photo));
    }
});

t("contract: the owner creates the full check-in documents and shortcut settings at their paths", async () => {
    const paths = {
        nutrition_strategy_settings: "nutrition_strategy_settings/nutrition_strategy_settings",
        check_in_record: "check_in_record/check_in_record",
        logging_break: "logging_break/logging_break",
        nutrition_day_annotation: `nutrition_day_annotations/${contractFixture("nutrition_day_annotation").day_key}`,
        shortcut_settings: "shortcut_settings/shortcut_settings",
    };
    for (const [model, path] of Object.entries(paths)) {
        const fixture = contractFixture(model);
        const uid = fixture.author_id;
        await assertFails(setDoc(doc(db(BOB), `users/${uid}/${path}`), fixture));
        await assertSucceeds(setDoc(doc(db(uid), `users/${uid}/${path}`), fixture));
        await assertFails(getDoc(doc(db(BOB), `users/${uid}/${path}`)));
    }
    // The check-in documents must name their owner when created.
    const annotation = contractFixture("nutrition_day_annotation");
    for (const path of ["check_in_record/check_in_record", "logging_break/logging_break", "nutrition_day_annotations/2026-10-01"]) {
        await assertFails(setDoc(doc(db(BOB), `users/${BOB}/${path}`), { ...annotation, author_id: ALICE }));
    }
});

// ---------------- FIRESTORE CONTRACT: SOCIAL ----------------
// The social fixtures name two parties: ACTOR writes (requests, comments, sends, reports) and
// FRIEND is on the other end. Each document is created by its real writer, and the cross-user
// rules hold for the fixture itself.
const ACTOR = "user_contract_full", FRIEND = "user_contract_friend";
const friendBlocksActor = () => seed(`users/${FRIEND}`, { id: FRIEND, blocked_user_ids: [ACTOR] });

t("contract: a follow request is created by its requester and answered by its target with status alone", async () => {
    const request = contractFixture("follow_request");
    const path = `users/${FRIEND}/follow_requests/${request.requester_id}`;
    await assertFails(setDoc(doc(db(BOB), path), request));
    await assertSucceeds(setDoc(doc(db(ACTOR), path), request));
    await assertSucceeds(setDoc(doc(db(ACTOR), path), contractFixture("follow_request", "minimal")));
    await assertFails(updateDoc(doc(db(ACTOR), path), { status: "accepted" }));
    await assertFails(updateDoc(doc(db(FRIEND), path), { status: "accepted", requester_name: "Someone else" }));
    await assertSucceeds(updateDoc(doc(db(FRIEND), path), { status: "accepted" }));
    await friendBlocksActor();
    await assertFails(setDoc(doc(db(ACTOR), path), request));
});

t("contract: the actor writes a notification to its recipient, who alone reads it; not once blocked", async () => {
    const path = (id) => `users/${FRIEND}/notifications/${id}`;
    await assertSucceeds(setDoc(doc(db(ACTOR), path("full")), contractFixture("activity_notification")));
    await assertSucceeds(setDoc(doc(db(ACTOR), path("minimal")), contractFixture("activity_notification", "minimal")));
    await assertFails(setDoc(doc(db(BOB), path("forged")), contractFixture("activity_notification")));
    await assertFails(getDoc(doc(db(ACTOR), path("full"))));
    await assertSucceeds(getDoc(doc(db(FRIEND), path("full"))));
    await assertSucceeds(updateDoc(doc(db(FRIEND), path("full")), { is_read: true }));
    await friendBlocksActor();
    await assertFails(setDoc(doc(db(ACTOR), path("again")), contractFixture("activity_notification")));
});

t("contract: a comment is created by its author, soft-deleted by them and liked one id at a time", async () => {
    const created = contractFixture("session_comment", "minimal");
    const ref = (as) => doc(db(as), `workout_session_comments/${created.id}`);
    await assertFails(setDoc(ref(BOB), created));
    await assertSucceeds(setDoc(ref(ACTOR), created));
    const full = contractFixture("session_comment");
    await assertSucceeds(setDoc(doc(db(ACTOR), `workout_session_comments/${full.id}`), full));
    await assertSucceeds(updateDoc(ref(FRIEND), { liked_by_user_ids: arrayUnion(FRIEND) }));
    await assertFails(updateDoc(ref(FRIEND), { deleted_at: now() }));
    await assertSucceeds(updateDoc(ref(ACTOR), { deleted_at: now() }));
    await friendBlocksActor();
    await assertFails(setDoc(doc(db(ACTOR), "workout_session_comments/again"), { ...created, id: "again" }));
});

t("contract: a challenge is created by its owner and read by its members only", async () => {
    for (const name of ["full", "minimal"]) {
        const challenge = contractFixture("challenge", name);
        await assertFails(setDoc(doc(db(BOB), `challenges/${challenge.id}`), challenge));
        await assertSucceeds(setDoc(doc(db(challenge.owner_id), `challenges/${challenge.id}`), challenge));
    }
    const full = contractFixture("challenge");
    await assertSucceeds(getDoc(doc(db(FRIEND), `challenges/${full.id}`)));
    await assertFails(getDoc(doc(db(BOB), `challenges/${full.id}`)));
    await assertSucceeds(updateDoc(doc(db(FRIEND), `challenges/${full.id}`), { member_ids: arrayRemove(FRIEND) }));
});

t("contract: challenge progress is read by members and written by no client", async () => {
    const challenge = contractFixture("challenge");
    const path = `challenges/${challenge.id}/progress/${FRIEND}`;
    await seed(`challenges/${challenge.id}`, challenge);
    await seed(path, contractFixture("challenge_progress"));
    await assertSucceeds(getDoc(doc(db(FRIEND), path)));
    await assertFails(getDoc(doc(db(BOB), path)));
    await assertFails(setDoc(doc(db(FRIEND), path), contractFixture("challenge_progress")));
});

t("contract: an invite is created by its inviter under its code, read by anyone, edited by nobody", async () => {
    for (const name of ["full", "minimal"]) {
        const invite = contractFixture("invite", name);
        await assertFails(setDoc(doc(db(BOB), `invites/${invite.code}`), invite));
        await assertSucceeds(setDoc(doc(db(invite.inviter_id), `invites/${invite.code}`), invite));
    }
    const invite = contractFixture("invite");
    await assertSucceeds(getDoc(doc(db(FRIEND), `invites/${invite.code}`)));
    await assertFails(updateDoc(doc(db(ACTOR), `invites/${invite.code}`), { uses: 1 }));
});

t("contract: a share is sent pending and answered by its recipient with status alone", async () => {
    for (const name of ["full", "minimal"]) {
        const share = contractFixture("share", name);
        await assertSucceeds(setDoc(doc(db(ACTOR), `shares/${share.id}`), share));
    }
    const share = contractFixture("share");
    const ref = (as) => doc(db(as), `shares/${share.id}`);
    await assertFails(getDoc(ref(BOB)));
    await assertSucceeds(getDoc(ref(FRIEND)));
    await assertFails(updateDoc(ref(ACTOR), { status: "accepted" }));
    await assertFails(updateDoc(ref(FRIEND), { status: "accepted", payload: {} }));
    await assertSucceeds(updateDoc(ref(FRIEND), { status: "accepted" }));
    await friendBlocksActor();
    await assertFails(setDoc(doc(db(ACTOR), "shares/again"), { ...share, id: "again" }));
});

t("contract: a report is filed by its reporter with only the allowed keys, nulls included", async () => {
    for (const name of ["full", "minimal"]) {
        const report = contractFixture("report", name);
        await assertFails(setDoc(doc(db(BOB), `reports/${report.id}`), report));
        await assertSucceeds(setDoc(doc(db(report.reporter_id), `reports/${report.id}`), report));
    }
    const report = contractFixture("report");
    await assertFails(getDoc(doc(db(ACTOR), `reports/${report.id}`)));
    await assertFails(setDoc(doc(db(ACTOR), "reports/extra"), { ...report, id: "extra", extra: true }));
});

t("contract: a username is reserved by its holder and cannot be taken over", async () => {
    const reservation = contractFixture("username_reservation");
    await assertFails(setDoc(doc(db(BOB), "usernames/ada"), reservation));
    await assertSucceeds(setDoc(doc(db(ACTOR), "usernames/ada"), reservation));
    await assertFails(setDoc(doc(db(BOB), "usernames/ada"), { user_id: BOB }));
    await assertSucceeds(getDoc(doc(db(BOB), "usernames/ada")));
});

// ---------------- CONTRACT: WHAT THE FUNCTIONS READ AND WRITE ----------------
// No emulator needed. Every field functions/index.js and lib.js read from these documents is a key
// of the model's full fixture, and every document they write has the fixture's shape, so a Swift
// or Flutter change that renames a field fails here rather than silently breaking a trigger.
const keysOf = (model, name = "full") => Object.keys(contractFixture(model, name));
const assertKeysIn = (fields, model) => {
    const keys = new Set(keysOf(model));
    const missing = fields.filter((field) => !keys.has(field));
    assert.deepEqual(missing, [], `${model}/full.json lacks ${missing.join(", ")}`);
};
const assertNotificationShape = (written) => {
    assertKeysIn(Object.keys(written), "activity_notification");
    for (const key of keysOf("activity_notification", "minimal")) assert.ok(key in written, `notification lacks ${key}`);
    assert.ok(enumsFixture.ActivityType.includes(written.type), `unknown notification type ${written.type}`);
};
const enumsFixture = JSON.parse(readFileSync(new URL("../contracts/firestore/enums.json", import.meta.url), "utf8"));

test("coachChat writes and reads the coach_chat fixture's shape", () => {
    // The chat it sets in its transaction, and the turns appendChatMessages stores.
    assert.deepEqual(keysOf("coach_chat").sort(), ["context_kind", "created_at", "id", "messages", "title", "updated_at"]);
    assert.deepEqual(Object.keys(contractFixture("coach_chat").messages[0]).sort(), ["created_at", "id", "role", "text"]);
    assert.deepEqual(enumsFixture.CoachMessageRole, ["user", "assistant"]);
    // Read back when it appends a turn, and by historyForModel.
    assertKeysIn(["title", "created_at", "context_kind", "messages"], "coach_chat");
});

test("stravaActivityDoc writes the strava_imported_activity fixture's shape", () => {
    // Every field, from a full Strava activity; a missing heart rate is left out, as minimal has.
    const full = stravaActivityDoc({
        id: 12345678901, name: "Morning Run", sport_type: "Run", start_date: "2026-10-11T06:30:00Z",
        elapsed_time: 2100, moving_time: 1980, distance: 6200.5, total_elevation_gain: 45.5, average_heartrate: 151.25,
    });
    assert.deepEqual(Object.keys(full).sort(), keysOf("strava_imported_activity").sort());
    const bare = stravaActivityDoc({ id: 1, start_date: "2026-10-11T06:30:00Z" });
    for (const key of keysOf("strava_imported_activity", "minimal")) assert.ok(key in bare, `activity lacks ${key}`);
    assertKeysIn(Object.keys(bare), "strava_imported_activity");
    assert.equal(typeof full.id, "string");
});

test("functions read only fields the social fixtures have", () => {
    // onActivityNotificationCreated, buildActivityPush, activityAlert, nudgeOnCooldown, unreadBadgeCount.
    assertKeysIn(["type", "actor_id", "actor_name", "comment_text", "is_reply", "session_id", "session_author_id",
        "date_created", "is_read"], "activity_notification");
    // onFollowRequestCreated/Updated, planFollowAccepted, buildFollowRequestPush, planAutoAccept.
    assertKeysIn(["status", "requester_id", "requester_name"], "follow_request");
    // onReportCreated, planReportModeration; it then sets `hidden` on the comment or session.
    assertKeysIn(["id", "reporter_id", "target_type", "target_id", "target_author_id", "reason", "status"], "report");
    assertKeysIn(["hidden"], "session_comment");
    assertKeysIn(["hidden", "ended_at", "is_rest_day", "deleted_at"], "workout_session");
    // onWorkoutSessionEndedForChallenges, activeChallengesFor, planChallengeProgress.
    assertKeysIn(["id", "starts_at", "ends_at", "member_ids", "target_sessions", "title"], "challenge");
    assertKeysIn(["sessions"], "challenge_progress");
    // acceptInvite, planInviteAcceptance.
    assertKeysIn(["inviter_id", "uses", "max_uses"], "invite");
    // onUsernameChanged, shouldReleaseReservation.
    assertKeysIn(["user_id"], "username_reservation");
    // The user document other people's triggers read: userDisplayName, the actor's picture,
    // blocking, follows, privacy, usernames, and pushRecipientSettings' legacy fallback.
    assertKeysIn(["submitted_first_name", "first_name", "submitted_last_name", "last_name", "submitted_profile_image",
        "photo_url", "blocked_user_ids", "following_ids", "is_private", "username", "fcm_token", "social_push_likes",
        "social_push_comments", "social_push_follows", "social_push_nudges", "social_push_mentions"], "user_model");
    assertKeysIn(["fcm_token", ...Object.values(SOCIAL_PUSH_PREFERENCE_KEYS)], "private_user_settings");
});

test("functions write notifications, follow requests and progress in the fixtures' shapes", () => {
    const user = contractFixture("user_model");
    const plain = { first_name: "Grace" };
    for (const target of [user, plain]) {
        assertNotificationShape(buildFollowAcceptedNotification(target, { targetId: FRIEND, requesterId: ACTOR }));
        assertNotificationShape(buildFollowNotification(target, { followerId: ACTOR, followedId: FRIEND }));
        const request = buildInviteFollowRequest(target, ACTOR);
        assert.deepEqual(Object.keys(request).sort(), keysOf("follow_request").sort());
    }
    // Without a picture the request carries a null image, which legacy-null-image.json covers.
    assert.equal(buildInviteFollowRequest(plain, ACTOR).requester_image_url, null);
    assert.ok(keysOf("follow_request", "legacy-null-image").includes("requester_image_url"));

    const challenge = { ...contractFixture("challenge"), target_sessions: 1 };
    const plan = planChallengeProgress(challenge, FRIEND, "session_1", undefined, user);
    assertNotificationShape(plan.notification);
    assert.deepEqual(Object.keys(plan.progress).sort(), keysOf("challenge_progress", "legacy-server-session-ids").sort());
});

// ---------------- FLUTTER WRITES (M3) ----------------
// Each write the Flutter repositories make, in the shape they make it: whole documents merged
// (`set` with `merge: true`) and partial updates with `update`. The owner may make each one;
// another signed-in user may not.
const merge = (ref, data) => setDoc(ref, data, { merge: true });

t("flutter: createUser and updateUserFields on users/{uid}", async () => {
    const user = contractFixture("user_model");
    const uid = user.user_id;
    await seed(`usernames/${user.username}`, { user_id: uid });
    await seed(`usernames/grace`, { user_id: uid });
    await assertFails(merge(doc(db(BOB), `users/${uid}`), user));
    await assertSucceeds(merge(doc(db(uid), `users/${uid}`), user));
    // Every field `UserField` allows, as `everyFieldUpdate` in user_repository's tests sets them.
    const update = {
        submitted_first_name: "Grace", submitted_last_name: "Hopper", submitted_email: "grace@example.com",
        submitted_profile_image: "https://example.com/grace.jpg", submitted_gender: "female",
        submitted_date_of_birth: Timestamp.fromDate(new Date("1985-06-07T00:00:00Z")),
        submitted_height_centimeters: 180.5, submitted_weight_kilograms: 70.75,
        submitted_length_unit_preference: "centimeters", submitted_weight_unit_preference: "kilograms",
        submitted_distance_unit_preference: "kilometers", submitted_exercise_frequency: "5-6",
        submitted_daily_activity_level: "moderate", submitted_cardio_fitness_level: "advanced",
        submitted_active_mesocycle_id: "mesocycle_2", submitted_favourite_gym_profile_id: "gym_2",
        submitted_current_goal_id: "goal_2", did_complete_onboarding: false,
        accepted_health_disclaimer_version: "2026.10.01", accepted_health_disclaimer_date: now(),
        accepted_health_privacy_policy_version: "2026.10.02", accepted_health_privacy_policy_date: now(),
        is_private: false, blocked_user_ids: ["user_x"], following_ids: [], username: "grace",
        weekly_session_goal: 5,
    };
    await assertFails(updateDoc(doc(db(BOB), `users/${uid}`), update));
    await assertSucceeds(updateDoc(doc(db(uid), `users/${uid}`), update));
});

t("flutter: mergePrivateSettings, coach consent withdrawn by writing false", async () => {
    const uid = contractFixture("user_model").user_id;
    const ref = (as) => doc(db(as), `users/${uid}/private/settings`);
    await assertSucceeds(merge(ref(uid), contractFixture("private_user_settings")));
    await assertSucceeds(merge(ref(uid), { coach_consent: false }));
    await assertFails(merge(ref(BOB), { coach_consent: false }));
});

t("flutter: saveMeasurement merges a body measurement", async () => {
    const entry = contractFixture("body_measurement");
    const uid = entry.author_id;
    const ref = (as) => doc(db(as), `users/${uid}/body_measurements/${entry.id}`);
    await assertFails(merge(ref(BOB), entry));
    await assertSucceeds(merge(ref(uid), entry));
    await assertSucceeds(merge(ref(uid), { ...entry, weight_kg: 70.5 }));
    await assertFails(merge(ref(BOB), { ...entry, weight_kg: 70.5 }));
});

t("flutter: saveGoal, abandonGoal, and the frozen start", async () => {
    const goal = contractFixture("weight_goal");
    const uid = goal.user_id;
    const ref = (as) => doc(db(as), `users/${uid}/goals/${goal.goal_id}`);
    await assertFails(merge(ref(BOB), goal));
    await assertSucceeds(merge(ref(uid), goal));
    // Saving the same goal again changes nothing frozen, so the rules allow it.
    await assertSucceeds(merge(ref(uid), goal));
    await assertFails(updateDoc(ref(BOB), { status: "abandoned" }));
    await assertSucceeds(updateDoc(ref(uid), { status: "abandoned" }));
    for (const frozen of [
        { starting_weight_kg: goal.starting_weight_kg + 1 }, { created_at: now() },
        { goal_id: "other" }, { user_id: BOB },
    ]) {
        await assertFails(merge(ref(uid), { ...goal, ...frozen }));
    }
});

// body_repository's editGoal: one update of the objective (its chosen case set and the others
// deleted, key by key), the target and the rate. A merge of the whole goal would keep the old
// case beside the new one, which neither app can decode.
t("flutter: editGoal changes the objective, target and rate, and nothing frozen", async () => {
    const goal = contractFixture("weight_goal");
    const uid = goal.user_id;
    const ref = (as) => doc(db(as), `users/${uid}/goals/${goal.goal_id}`);
    await seed(`users/${uid}/goals/${goal.goal_id}`, goal);
    const edit = {
        "objective.loseWeight": {}, "objective.maintain": deleteField(), "objective.gainWeight": deleteField(),
        target_weight_kg: 60.5, weekly_change_kg: 0.35,
    };
    await assertFails(updateDoc(ref(BOB), edit));
    await assertSucceeds(updateDoc(ref(uid), edit));
    let stored;
    await env.withSecurityRulesDisabled(async (ctx) => {
        stored = (await getDoc(doc(ctx.firestore(), `users/${uid}/goals/${goal.goal_id}`))).data();
    });
    assert.deepEqual(stored.objective, { loseWeight: {} });
    assert.equal(stored.target_weight_kg, 60.5);
    assert.equal(stored.weekly_change_kg, 0.35);
    assert.equal(stored.starting_weight_kg, goal.starting_weight_kg);
    for (const frozen of [
        { starting_weight_kg: goal.starting_weight_kg + 1 }, { created_at: now() },
        { goal_id: "other" }, { user_id: BOB },
    ]) {
        await assertFails(updateDoc(ref(uid), { ...edit, ...frozen }));
    }
});

t("flutter: saveMeal and saveDietPlan merge", async () => {
    const meal = contractFixture("meal_log");
    const uid = meal.author_id;
    const mealRef = (as) => doc(db(as), `users/${uid}/meal_logs/${meal.meal_id}`);
    await assertFails(merge(mealRef(BOB), meal));
    await assertSucceeds(merge(mealRef(uid), meal));
    await assertSucceeds(merge(mealRef(uid), { ...meal, items: [] }));
    const plan = contractFixture("diet_plan");
    const planRef = (as) => doc(db(as), `diet_plans/${plan.planId}`);
    await assertFails(merge(planRef(BOB), plan));
    await assertSucceeds(merge(planRef(plan.userId), plan));
    await assertSucceeds(merge(planRef(plan.userId), { ...plan, tdeeEstimate: 2400.5 }));
});

t("flutter: saveMesocycle and saveMacrocycle merge; starting a program ends the running macrocycle", async () => {
    const mesocycle = contractFixture("mesocycle");
    const uid = mesocycle.author_id;
    await seed(`users/${uid}`, { user_id: uid });
    const mesocycleRef = (as, id = mesocycle.id) => doc(db(as), `users/${uid}/mesocycles/${id}`);
    await assertFails(merge(mesocycleRef(BOB), mesocycle));
    await assertSucceeds(merge(mesocycleRef(uid), mesocycle));
    await assertSucceeds(merge(mesocycleRef(uid), { ...mesocycle, name: "Renamed" }));
    await assertFails(merge(mesocycleRef(BOB), { ...mesocycle, name: "Renamed" }));
    // The copy of a prebuilt program: a new id, the user as author.
    await assertSucceeds(merge(mesocycleRef(uid, "COPY-ID"), { ...mesocycle, id: "COPY-ID" }));
    await assertFails(merge(mesocycleRef(uid, "FORGED"), { ...mesocycle, id: "FORGED", author_id: BOB }));

    const running = { ...contractFixture("macrocycle"), status: "active" };
    const macrocycleRef = (as, id) => doc(db(as), `users/${uid}/macrocycles/${id}`);
    await assertSucceeds(merge(macrocycleRef(uid, running.id), running));
    // Ending it: the whole document merged back with status and date_modified changed.
    const ended = { ...running, status: "ended", date_modified: now() };
    await assertFails(merge(macrocycleRef(BOB, running.id), ended));
    await assertSucceeds(merge(macrocycleRef(uid, running.id), ended));
    // The new macrocycle of the copy alone, active from its first microcycle.
    const started = {
        id: "NEW-MACRO", author_id: uid, name: mesocycle.name, mesocycle_ids: ["COPY-ID"], status: "active",
        mesocycle_index: 0, mesocycle_started_at: now(), skips: [], iteration: 1,
        date_created: now(), date_modified: now(),
    };
    await assertFails(merge(macrocycleRef(BOB, started.id), started));
    await assertSucceeds(merge(macrocycleRef(uid, started.id), started));
    // Then the profile points at the copy.
    await assertFails(updateDoc(doc(db(BOB), `users/${uid}`), { submitted_active_mesocycle_id: "COPY-ID" }));
    await assertSucceeds(updateDoc(doc(db(uid), `users/${uid}`), { submitted_active_mesocycle_id: "COPY-ID" }));
});

t("flutter: saveGymProfile merges a gym, then setFavouriteGymProfile names it", async () => {
    const gym = contractFixture("gym_profile");
    const uid = gym.author_id;
    await seed(`users/${uid}`, { user_id: uid });
    const ref = (as) => doc(db(as), `users/${uid}/gym_profiles/${gym.id}`);
    await assertFails(merge(ref(BOB), gym));
    await assertSucceeds(merge(ref(uid), gym));
    await assertSucceeds(merge(ref(uid), { ...gym, name: "Untitled Gym Profile", date_modified: now() }));
    await assertFails(merge(ref(BOB), { ...gym, name: "Taken" }));
    await assertFails(updateDoc(doc(db(BOB), `users/${uid}`), { submitted_favourite_gym_profile_id: gym.id }));
    await assertSucceeds(updateDoc(doc(db(uid), `users/${uid}`), { submitted_favourite_gym_profile_id: gym.id }));
});

t("flutter: saveFood merges a food, and never one without author_id", async () => {
    const food = contractFixture("food_model");
    const uid = food.author_id;
    const ref = (as) => doc(db(as), `users/${uid}/foods/${food.ingredient_id}`);
    const { author_id: _, ...unowned } = food;
    await assertFails(merge(ref(uid), unowned));
    await assertFails(merge(ref(BOB), food));
    await assertSucceeds(merge(ref(uid), food));
    await assertSucceeds(merge(ref(uid), { ...food, name: "Oat Milk Light" }));
    await assertFails(merge(ref(BOB), { ...food, name: "Oat Milk Light" }));
    // An Open Food Facts result cached in the library, as the barcode lookup saves it.
    const offRef = doc(db(uid), `users/${uid}/foods/off-5010029000061`);
    await assertFails(merge(offRef, { ...unowned, ingredient_id: "off-5010029000061" }));
    await assertSucceeds(merge(offRef, { ...food, ingredient_id: "off-5010029000061" }));
});

t("flutter: saveRecipe merges a recipe, and never one without author_id; deleteRecipe is the owner's", async () => {
    const recipe = contractFixture("recipe_template");
    const uid = recipe.author_id;
    const ref = (as) => doc(db(as), `users/${uid}/recipe_templates/${recipe.recipe_id}`);
    const { author_id: _, ...unowned } = recipe;
    await assertFails(merge(ref(uid), unowned));
    await assertFails(merge(ref(BOB), recipe));
    await assertSucceeds(merge(ref(uid), recipe));
    await assertSucceeds(merge(ref(uid), { ...recipe, name: "Overnight Oats Light" }));
    await assertFails(merge(ref(BOB), { ...recipe, name: "Taken" }));
    await assertFails(deleteDoc(ref(BOB)));
    await assertSucceeds(deleteDoc(ref(uid)));
});

t("flutter: saveProgressPhoto merges a photo only at its own storage path; deleteProgressPhoto is the owner's", async () => {
    const photo = contractFixture("progress_photo");
    const uid = photo.author_id;
    const ref = (as) => doc(db(as), `users/${uid}/progress_photos/${photo.id}`);
    const { author_id: _, ...unowned } = photo;
    await assertFails(merge(ref(uid), unowned));
    await assertFails(merge(ref(uid), { ...photo, storage_path: `users/${uid}/profile` }));
    await assertFails(merge(ref(uid), { ...photo, pose: "top" }));
    await assertFails(merge(ref(BOB), photo));
    await assertSucceeds(merge(ref(uid), photo));
    await assertSucceeds(merge(ref(uid), { ...photo, note: "Evening" }));
    await assertFails(getDoc(ref(BOB)));
    await assertFails(deleteDoc(ref(BOB)));
    await assertSucceeds(deleteDoc(ref(uid)));
});

t("flutter: saveSession merges a workout session, updateWeekStreakCount sets the streak", async () => {
    const session = contractFixture("workout_session");
    const uid = session.author_id;
    const ref = (as) => doc(db(as), `users/${uid}/workout_sessions/${session.id}`);
    // A finished session is new: the first save creates it, as the app encodes it.
    await assertFails(merge(ref(BOB), session));
    await assertSucceeds(merge(ref(uid), session));
    // Saved again as the app holds it, exercises replaced whole.
    await assertSucceeds(merge(ref(uid), { ...session, exercises: [] }));
    await assertFails(merge(ref(BOB), { ...session, exercises: [] }));
    await assertSucceeds(updateDoc(ref(uid), { week_streak_count: 9 }));
    await assertFails(updateDoc(ref(BOB), { week_streak_count: 9 }));
    // Moderation's flag is not the author's to set.
    await assertFails(merge(ref(uid), { ...session, hidden: true }));
});

t("flutter: updateEditedSession writes only the edited fields; the owner deletes", async () => {
    const session = contractFixture("workout_session");
    const uid = session.author_id;
    const ref = (as) => doc(db(as), `users/${uid}/workout_sessions/${session.id}`);
    await assertSucceeds(merge(ref(uid), session));
    // A like made while the author edits.
    await assertSucceeds(updateDoc(ref(BOB), { liked_by_user_ids: arrayUnion(BOB) }));
    const start = Timestamp.fromDate(new Date("2026-10-02T07:00:00Z"));
    const edit = {
        exercises: [],
        notes: deleteField(),
        date_created: start,
        ended_at: Timestamp.fromDate(new Date("2026-10-02T08:00:00Z")),
        date_modified: now(),
    };
    await assertFails(updateDoc(ref(BOB), edit));
    await assertSucceeds(updateDoc(ref(uid), edit));
    const stored = (await getDoc(ref(uid))).data();
    assert.equal(stored.notes, undefined);
    assert.ok(stored.liked_by_user_ids.includes(BOB));
    assert.equal(stored.week_streak_count, session.week_streak_count);
    // Swift's edit: the whole session merged, notes included.
    await assertSucceeds(merge(ref(uid), { ...session, notes: "Edited", exercises: [] }));
    await assertFails(deleteDoc(ref(BOB)));
    await assertSucceeds(deleteDoc(ref(uid)));
});

t("flutter: finishing copies the streak to the private settings", async () => {
    const uid = contractFixture("workout_session").author_id;
    const ref = (as) => doc(db(as), `users/${uid}/private/settings`);
    const streak = {
        week_streak: 3, week_sessions: 2, week_goal: 3,
        week_ends_at: Timestamp.fromDate(new Date("2026-10-19T00:00:00Z")), last_trained_at: now(),
    };
    await assertSucceeds(merge(ref(uid), streak));
    await assertFails(merge(ref(BOB), streak));
    // Deleting the last workout: last_trained_at is deleted in the same merge.
    const cleared = { ...streak, week_sessions: 0, last_trained_at: deleteField() };
    await assertSucceeds(merge(ref(uid), cleared));
    await assertFails(merge(ref(BOB), cleared));
});

t("flutter: saveExerciseSettings merges a note and a rest override", async () => {
    const settings = contractFixture("exercise_settings");
    const uid = settings.author_id;
    const ref = (as) => doc(db(as), `users/${uid}/exercise_settings/${settings.id}`);
    await assertFails(merge(ref(BOB), settings));
    await assertSucceeds(merge(ref(uid), settings));
    await assertSucceeds(merge(ref(uid), { id: settings.id, author_id: uid, rest_duration_override: 90 }));
    await assertFails(merge(ref(BOB), { id: settings.id, author_id: uid, note: "x" }));
});

t("flutter: the check-in writes, in the shapes checkin_repository makes them", async () => {
    const settings = contractFixture("nutrition_strategy_settings");
    const uid = settings.author_id;
    const settingsRef = (as) => doc(db(as), `users/${uid}/nutrition_strategy_settings/nutrition_strategy_settings`);
    await assertFails(merge(settingsRef(BOB), settings));
    await assertSucceeds(merge(settingsRef(uid), settings));
    // A cleared start date is deleted rather than left behind by the merge.
    await assertSucceeds(merge(settingsRef(uid), { ...settings, calculation_start_date: deleteField() }));

    // Day annotations: set and delete in one batch.
    const annotation = contractFixture("nutrition_day_annotation");
    const annotationRef = (as, day) => doc(db(as), `users/${uid}/nutrition_day_annotations/${day}`);
    const batch = (as) => {
        const firestore = db(as);
        const path = (day) => `users/${uid}/nutrition_day_annotations/${day}`;
        return writeBatch(firestore)
            .set(doc(firestore, path(annotation.day_key)), annotation, { merge: true })
            .delete(doc(firestore, path("2026-10-11")));
    };
    await assertFails(batch(BOB).commit());
    await assertSucceeds(batch(uid).commit());
    await assertSucceeds(merge(annotationRef(uid, annotation.day_key), { ...annotation, is_fasting_day: false }));
    await assertFails(deleteDoc(annotationRef(BOB, annotation.day_key)));
    await assertSucceeds(deleteDoc(annotationRef(uid, annotation.day_key)));

    // The logging break: started with any old end deleted, then ended.
    const loggingBreak = contractFixture("logging_break");
    const breakRef = (as) => doc(db(as), `users/${uid}/logging_break/logging_break`);
    const open = { ...loggingBreak };
    delete open.end_date;
    await assertFails(merge(breakRef(BOB), { ...open, end_date: deleteField() }));
    await assertSucceeds(merge(breakRef(uid), { ...open, end_date: deleteField() }));
    await assertFails(merge(breakRef(BOB), loggingBreak));
    await assertSucceeds(merge(breakRef(uid), loggingBreak));
    await assertSucceeds(merge(breakRef(uid), { ...open, start_date: now(), end_date: deleteField() }));

    // The record: one week start merged at a time.
    const recordRef = (as) => doc(db(as), `users/${uid}/check_in_record/check_in_record`);
    const mark = (field) => ({ id: "check_in_record", author_id: uid, [field]: now() });
    await assertFails(merge(recordRef(BOB), mark("last_completed_week_start")));
    await assertSucceeds(merge(recordRef(uid), mark("last_completed_week_start")));
    await assertSucceeds(merge(recordRef(uid), mark("last_skipped_week_start")));
    await assertFails(merge(recordRef(BOB), mark("last_skipped_week_start")));
});

// ---------------- FLUTTER WRITES (M5): SOCIAL ----------------
// Each write social_repository makes, in its shape: whole documents with a plain `set` (as the
// Swift services write them), single fields with `update`, deletes, and batches of `is_read`.
// ACTOR writes, FRIEND is on the other end, BOB is a stranger; friendBlocksActor() blocks ACTOR.
const flutterNotification = (type, extra = {}) => ({
    type, actor_id: ACTOR, actor_name: "Ada Lovelace", actor_image_url: "https://example.com/ada.jpg",
    session_id: "", session_author_id: FRIEND, date_created: now(), is_read: false, ...extra,
});

t("flutter social: follow, unfollow and block edit the viewer's own lists; the follow notification is the actor's", async () => {
    await seed(`users/${ACTOR}`, { user_id: ACTOR, following_ids: [] });
    await assertSucceeds(updateDoc(doc(db(ACTOR), `users/${ACTOR}`), { following_ids: [FRIEND] }));
    await assertFails(updateDoc(doc(db(BOB), `users/${ACTOR}`), { following_ids: [BOB] }));
    await assertSucceeds(updateDoc(doc(db(ACTOR), `users/${ACTOR}`), { blocked_user_ids: [BOB], following_ids: [] }));
    const ref = (as) => doc(db(as), `users/${FRIEND}/notifications/follow_${ACTOR}`);
    await assertFails(setDoc(ref(BOB), flutterNotification("follow")));
    await assertSucceeds(setDoc(ref(ACTOR), flutterNotification("follow")));
    // Following again overwrites it, as `set` does.
    await assertSucceeds(setDoc(ref(ACTOR), flutterNotification("follow")));
    await assertFails(deleteDoc(ref(BOB)));
    await assertSucceeds(deleteDoc(ref(ACTOR)));
    await friendBlocksActor();
    await assertFails(setDoc(ref(ACTOR), flutterNotification("follow")));
});

t("flutter social: a nudge, once a day per id, and never to someone who blocked the actor", async () => {
    const ref = doc(db(ACTOR), `users/${FRIEND}/notifications/nudge_${ACTOR}_2026-10-14`);
    await assertSucceeds(setDoc(ref, flutterNotification("nudge")));
    await assertSucceeds(setDoc(ref, flutterNotification("nudge")));
    await friendBlocksActor();
    await assertFails(setDoc(ref, flutterNotification("nudge")));
});

t("flutter social: a follow request is sent and cancelled by its requester, answered by its target", async () => {
    const request = contractFixture("follow_request");
    const ref = (as) => doc(db(as), `users/${FRIEND}/follow_requests/${ACTOR}`);
    await assertFails(setDoc(ref(BOB), request));
    await assertSucceeds(setDoc(ref(ACTOR), request));
    await assertFails(updateDoc(ref(ACTOR), { status: "accepted" }));
    await assertFails(updateDoc(ref(BOB), { status: "declined" }));
    await assertSucceeds(updateDoc(ref(FRIEND), { status: "declined" }));
    // Asking again after a decline overwrites it pending.
    await assertSucceeds(setDoc(ref(ACTOR), request));
    await assertFails(deleteDoc(ref(FRIEND)));
    await assertFails(deleteDoc(ref(BOB)));
    await assertSucceeds(deleteDoc(ref(ACTOR)));
});

t("flutter social: incoming requests are the target's to list; sent ones the requester's, through the group", async () => {
    await seed(`users/${FRIEND}/follow_requests/${ACTOR}`, contractFixture("follow_request"));
    const incoming = (as) => getDocs(query(collectionGroup(db(as), "follow_requests"),
        where("requester_id", "==", ACTOR), where("status", "==", "pending")));
    await assertSucceeds(incoming(ACTOR));
    await assertFails(incoming(BOB));
    const pending = (as) => getDocs(query(
        collection(db(as), `users/${FRIEND}/follow_requests`), where("status", "==", "pending"), limit(100)));
    await assertSucceeds(pending(FRIEND));
    await assertFails(pending(ACTOR));
});

t("flutter social: a like adds or removes only the liker's id; its notification is theirs", async () => {
    const session = contractFixture("workout_session");
    const path = `users/${FRIEND}/workout_sessions/${session.id}`;
    await seed(path, { ...session, author_id: FRIEND, liked_by_user_ids: [] });
    const ref = (as) => doc(db(as), path);
    await assertSucceeds(updateDoc(ref(ACTOR), { liked_by_user_ids: arrayUnion(ACTOR) }));
    await assertFails(updateDoc(ref(BOB), { liked_by_user_ids: arrayUnion(ACTOR) }));
    await assertFails(updateDoc(ref(BOB), { liked_by_user_ids: arrayRemove(ACTOR) }));
    await assertSucceeds(updateDoc(ref(ACTOR), { liked_by_user_ids: arrayRemove(ACTOR) }));
    const like = (as) => doc(db(as), `users/${FRIEND}/notifications/like_${session.id}_${ACTOR}`);
    await assertSucceeds(setDoc(like(ACTOR), flutterNotification("like", { session_id: session.id })));
    await assertSucceeds(deleteDoc(like(ACTOR)));
    await friendBlocksActor();
    await assertFails(updateDoc(ref(ACTOR), { liked_by_user_ids: arrayUnion(ACTOR) }));
});

t("flutter social: a comment is set whole by its author, soft-deleted by them, liked one id at a time", async () => {
    const comment = contractFixture("session_comment", "minimal");
    const ref = (as) => doc(db(as), `workout_session_comments/${comment.id}`);
    await assertFails(setDoc(ref(BOB), comment));
    await assertSucceeds(setDoc(ref(ACTOR), comment));
    await assertSucceeds(getDocs(query(collection(db(BOB), "workout_session_comments"),
        where("session_id", "==", comment.session_id))));
    await assertSucceeds(updateDoc(ref(FRIEND), { liked_by_user_ids: arrayUnion(FRIEND) }));
    await assertFails(updateDoc(ref(FRIEND), { liked_by_user_ids: arrayUnion(BOB) }));
    await assertSucceeds(updateDoc(ref(FRIEND), { liked_by_user_ids: arrayRemove(FRIEND) }));
    await assertFails(updateDoc(ref(FRIEND), { deleted_at: now() }));
    await assertSucceeds(updateDoc(ref(ACTOR), { deleted_at: now() }));
    await assertFails(deleteDoc(ref(ACTOR)));
    // Its notification to the session's author.
    const notification = doc(db(ACTOR), `users/${FRIEND}/notifications/comment_${comment.id}`);
    await assertSucceeds(setDoc(notification, flutterNotification("comment", {
        session_id: comment.session_id, comment_text: comment.text,
    })));
});

t("flutter social: only the recipient pages, marks read in a batch and deletes notifications", async () => {
    for (const id of ["n1", "n2"]) {
        await seed(`users/${FRIEND}/notifications/${id}`, flutterNotification("follow"));
    }
    const page = (as) => getDocs(query(collection(db(as), `users/${FRIEND}/notifications`),
        orderBy("date_created", "desc"), limit(50)));
    await assertSucceeds(page(FRIEND));
    await assertFails(page(ACTOR));
    const markRead = (as) => {
        const firestore = db(as);
        const batch = writeBatch(firestore);
        for (const id of ["n1", "n2"]) batch.update(doc(firestore, `users/${FRIEND}/notifications/${id}`), { is_read: true });
        return batch.commit();
    };
    await assertFails(markRead(BOB));
    await assertSucceeds(markRead(FRIEND));
    await assertFails(deleteDoc(doc(db(BOB), `users/${FRIEND}/notifications/n1`)));
    await assertSucceeds(deleteDoc(doc(db(FRIEND), `users/${FRIEND}/notifications/n1`)));
});

t("flutter social: a challenge is created by its owner; a member leaves alone; members list theirs", async () => {
    const challenge = contractFixture("challenge");
    const ref = (as) => doc(db(as), `challenges/${challenge.id}`);
    await assertFails(setDoc(ref(BOB), challenge));
    await assertSucceeds(setDoc(ref(ACTOR), challenge));
    const mine = (as, uid = as) => getDocs(query(collection(db(as), "challenges"),
        where("member_ids", "array-contains", uid)));
    await assertSucceeds(mine(FRIEND));
    await assertFails(mine(BOB, FRIEND));
    await assertFails(updateDoc(ref(FRIEND), { member_ids: arrayRemove(ACTOR) }));
    await assertFails(updateDoc(ref(BOB), { member_ids: arrayRemove(BOB) }));
    await assertSucceeds(updateDoc(ref(FRIEND), { member_ids: arrayRemove(FRIEND) }));
});

t("flutter social: an invite is created once under a valid code, and found by its inviter", async () => {
    const invite = contractFixture("invite");
    const ref = (as, code = invite.code) => doc(db(as), `invites/${code}`);
    await assertFails(setDoc(ref(BOB), invite));
    await assertFails(setDoc(ref(ACTOR, "abcd2345"), { ...invite, code: "abcd2345" }));
    await assertSucceeds(setDoc(ref(ACTOR), invite));
    // A code taken in between: the second create is an update, which no client may make.
    await assertFails(setDoc(ref(ACTOR), invite));
    await assertSucceeds(getDocs(query(collection(db(ACTOR), "invites"),
        where("inviter_id", "==", ACTOR), limit(1))));
});

t("flutter social: a share is sent pending with its notification; the recipient answers with status alone", async () => {
    const share = contractFixture("share", "minimal");
    const ref = (as) => doc(db(as), `shares/${share.id}`);
    await assertFails(setDoc(ref(BOB), share));
    await assertSucceeds(setDoc(ref(ACTOR), share));
    await assertSucceeds(setDoc(doc(db(ACTOR), `users/${FRIEND}/notifications/share_${share.id}`),
        flutterNotification("share", { share_id: share.id, comment_text: "Push A" })));
    await assertFails(updateDoc(ref(ACTOR), { status: "dismissed" }));
    await assertFails(updateDoc(ref(FRIEND), { status: "pending" }));
    await assertSucceeds(updateDoc(ref(FRIEND), { status: "dismissed" }));
});

t("flutter social: a report is set once by its reporter with the allowed keys", async () => {
    const report = contractFixture("report", "minimal");
    await assertFails(setDoc(doc(db(BOB), `reports/${report.id}`), report));
    await assertSucceeds(setDoc(doc(db(ACTOR), `reports/${report.id}`), report));
    await assertFails(setDoc(doc(db(ACTOR), `reports/${report.id}`), report));
});

// The rules' `size()` counts UTF-16 code units, as Dart's `String.length` does, so the Flutter
// report sheet limits the note by that. Swift counts characters (grapheme clusters): its 500
// emoji pass the sheet and are refused here.
t("flutter social: a report note is limited to 500 UTF-16 code units", async () => {
    const file = (id, note) => setDoc(doc(db(ACTOR), `reports/${id}`),
        { ...contractFixture("report", "minimal"), id, note });
    await assertSucceeds(file("ascii-500", "a".repeat(500)));
    await assertFails(file("ascii-501", "a".repeat(501)));
    await assertSucceeds(file("accent-500", "é".repeat(500)));
    await assertSucceeds(file("emoji-250", "💪".repeat(250)));
    await assertFails(file("emoji-251", "💪".repeat(251)));
    await assertFails(file("emoji-500", "💪".repeat(500)));
});

t("flutter social: claiming a handle reserves it with a server timestamp, then names it on the profile", async () => {
    await seed(`users/${ACTOR}`, { user_id: ACTOR });
    const reserve = (as, handle) => setDoc(doc(db(as), `usernames/${handle}`),
        { user_id: as, date_created: serverTimestamp() });
    await assertFails(setDoc(doc(db(BOB), "usernames/ada_l"), { user_id: ACTOR, date_created: serverTimestamp() }));
    await assertSucceeds(reserve(ACTOR, "ada_l"));
    await assertFails(reserve(BOB, "ada_l"));
    await assertFails(reserve(ACTOR, "Ada"));
    await assertFails(updateDoc(doc(db(ACTOR), `users/${ACTOR}`), { username: "someone_else" }));
    await assertSucceeds(updateDoc(doc(db(ACTOR), `users/${ACTOR}`), { username: "ada_l" }));
});

// Owner-only subcollections whose documents carry the owner as author_id / user_id.
for (const [sub, key] of [
    ["body_measurements", "author_id"], ["steps", "author_id"], ["goals", "user_id"],
    ["gym_profiles", "author_id"], ["training_programs", "author_id"], ["workout_templates", "author_id"],
    ["mesocycles", "author_id"], ["macrocycles", "author_id"], ["training_plans", "author_id"],
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

// A goal's aim can be edited; where it started cannot, and a fresh start is a new document.
t("users/goals: target, rate and objective can be edited; the start cannot", async () => {
    await seed(`users/${ALICE}/goals/g`, {
        user_id: ALICE, goal_id: "g", target_weight_kg: 70, weekly_change_kg: 0.5,
        objective: { loseWeight: {} }, starting_weight_kg: 80.6, created_at: new Date(0),
    });
    const goal = doc(db(ALICE), `users/${ALICE}/goals/g`);
    await assertSucceeds(updateDoc(goal, { target_weight_kg: 75, weekly_change_kg: 0.25, objective: { maintain: {} } }));
    await assertFails(updateDoc(goal, { starting_weight_kg: 83 }));
    await assertFails(updateDoc(goal, { created_at: new Date() }));
    await assertFails(updateDoc(goal, { goal_id: "other" }));
});

t("users/goals: starting a new goal creates its own document", async () => {
    await seed(`users/${ALICE}/goals/${ALICE}`, { user_id: ALICE, starting_weight_kg: 80.6, status: "active" });
    await assertSucceeds(setDoc(doc(db(ALICE), `users/${ALICE}/goals/new-goal`), {
        user_id: ALICE, goal_id: "new-goal", starting_weight_kg: 83, target_weight_kg: 78, status: "active",
    }));
    await assertSucceeds(updateDoc(doc(db(ALICE), `users/${ALICE}/goals/${ALICE}`), { status: "abandoned" }));
    await assertFails(setDoc(doc(db(BOB), `users/${ALICE}/goals/bobs`), { user_id: ALICE }));
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

for (const path of ["food_search_cache/q", "moderation_queue/t", `strava_connections/${ALICE}`, "strava_events/e", `coach_usage/${ALICE}`]) {
    t(`${path.split("/")[0]}: closed to every client`, async () => {
        await assertFails(getDoc(doc(db(ALICE), path)));
        await assertFails(setDoc(doc(db(ALICE), path), { a: 1 }));
    });
}

t("users/strava_activities: the owner reads them; nobody writes them", async () => {
    const path = `users/${ALICE}/strava_activities/1`;
    // The contract's full activity: the shape the server writes and both apps read.
    await seed(path, contractFixture("strava_imported_activity"));
    await assertSucceeds(getDoc(doc(db(ALICE), path)));
    await assertFails(getDoc(doc(db(BOB), path)));
    await assertFails(setDoc(doc(db(ALICE), path), { id: "1", name: "Faster Run" }));
    await assertFails(deleteDoc(doc(db(ALICE), path)));
});

t("users/coach_chats: the owner reads and deletes them; nobody writes them", async () => {
    const path = `users/${ALICE}/coach_chats/c1`;
    // The contract's full chat: the shape coachChat writes and both apps read.
    await seed(path, contractFixture("coach_chat"));
    await assertSucceeds(getDoc(doc(db(ALICE), path)));
    await assertFails(getDoc(doc(db(BOB), path)));
    await assertFails(setDoc(doc(db(ALICE), path), { id: "c1", title: "Edited", messages: [] }));
    await assertFails(setDoc(doc(db(ALICE), `users/${ALICE}/coach_chats/c2`), { id: "c2", messages: [] }));
    await assertFails(deleteDoc(doc(db(BOB), path)));
    await assertSucceeds(deleteDoc(doc(db(ALICE), path)));
});

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
    await assertSucceeds(setDoc(doc(db(BOB), "shares/sh4"), share(BOB, ALICE, { id: "sh4", kind: "mesocycle" })));
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
