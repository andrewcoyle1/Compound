import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
    buildActivityPush, buildFollowAcceptedNotification, cleanJson, newlyBlockedIds, normaliseName,
    planFollowAccepted, pushRecipientSettings, requireAuth, userDisplayName,
    buildFollowRequestPush, removedFollowingIds, planAutoAccept, removeFollowerTarget,
    buildStreakReminderPush, buildWeeklyDigestPush, countTrainingSessions, digestWindowStart, isNudgeOnCooldown,
    isStreakReminderDue, isWeeklyDigestDue, localTime, INTERRUPTION_LEVELS, formatLocKey,
    SOCIAL_PUSH_PREFERENCE_KEYS as SOCIAL_PUSH_PREFERENCE_KEYS_FOR_LEVELS, sessionPageContent, offProductToFood,
    offCountryTag, offSearchLangs, mergeSearchHits,
    stravaTokenForm, stravaTokenErrorCode,
} from "./lib.js";

test("cleanJson strips the code fences Gemini adds and leaves bare JSON alone", () => {
    assert.equal(cleanJson('```json\n{"a":1}\n```'), '{"a":1}');
    assert.equal(cleanJson('```\n{"a":1}```'), '{"a":1}');
    assert.equal(cleanJson('  {"a":1}  '), '{"a":1}');
});

test("normaliseName folds case and whitespace so the same ingredient is found again", () => {
    assert.equal(normaliseName("  Greek Yoghurt "), "greek yoghurt");
});

test("requireAuth returns the uid or throws unauthenticated", () => {
    assert.equal(requireAuth({ auth: { uid: "u1" } }), "u1");
    assert.throws(() => requireAuth({ auth: null }), { code: "unauthenticated" });
    assert.throws(() => requireAuth({}), { code: "unauthenticated" });
});

// The only thing stopping a rebuilt client from calling the backend is App Check plus auth on
// every callable, and enforceAppCheck lives in options the deployed object does not expose, so
// this reads the source: each onCall must take CALLABLE_OPTIONS and open with requireAuth.
test("every callable enforces App Check and requires auth", () => {
    const src = readFileSync(new URL("./index.js", import.meta.url), "utf8");
    assert.match(src, /const CALLABLE_OPTIONS = \{[^}]*enforceAppCheck: true/);
    const callables = [...src.matchAll(/export const (\w+) = onCall\(([^,]+),\s*async \(request\) => \{\s*([^\n]*)/g)];
    assert.match(src, /const STRAVA_CALLABLE_OPTIONS = \{ \.\.\.CALLABLE_OPTIONS,/);
    assert.equal(callables.length, 9, "expected nine callables");
    for (const [, name, options, firstLine] of callables) {
        assert.match(options.trim(), /^(STRAVA_)?CALLABLE_OPTIONS$/, `${name} must use CALLABLE_OPTIONS`);
        assert.match(firstLine, /requireAuth\(request\)/, `${name} must call requireAuth first`);
    }
});

test("each deployed callable rejects an unauthenticated request before doing any work", async () => {
    const fns = await import("./index.js");
    for (const name of ["foodAnalyze", "mealDescribe", "nutritionLabelAnalyze", "chatGenerate", "imageGenerate", "foodSearch", "removeFollower", "stravaToken"]) {
        await assert.rejects(fns[name].run({ data: {}, auth: null }), { code: "unauthenticated" }, name);
    }
});

// Changed: pushes used to carry generic English titles ("New like"). They now have no title (the
// system shows the app's name) and a body the device localizes from the app's string catalog.
test("buildActivityPush sends each social type as a catalog key and routes the tap to the Dashboard tab", () => {
    const recipient = { fcm_token: "tok" };
    const like = buildActivityPush({ type: "like", actor_name: "Jane", session_id: "s1", session_author_id: "u1", actor_id: "a1" }, recipient);
    assert.equal(like.token, "tok");
    assert.deepEqual(like.notification, { body: "Jane liked your workout" });
    assert.deepEqual(like.apns.payload.aps.alert, { body: "Jane liked your workout", locKey: "%@ liked your workout", locArgs: ["Jane"] });
    assert.deepEqual(like.data, { tab: "dashboard", type: "like", session_id: "s1", session_author_id: "u1", actor_id: "a1" });

    const comment = buildActivityPush({ type: "comment", actor_name: "Jane", comment_text: "Nice!" }, recipient);
    assert.deepEqual(comment.notification, { body: 'Jane commented: "Nice!"' });
    assert.equal(comment.apns.payload.aps.alert.locKey, '%@ commented: "%@"');
    assert.deepEqual(comment.apns.payload.aps.alert.locArgs, ["Jane", "Nice!"]);
    assert.equal(buildActivityPush({ type: "comment", actor_name: "Jane" }, recipient).notification.body, "Jane commented");
    const reply = buildActivityPush({ type: "comment", actor_name: "Jane", comment_text: "Yes", is_reply: true }, recipient);
    assert.equal(reply.notification.body, 'Jane replied to your comment: "Yes"');

    const follow = buildActivityPush({ type: "follow", actor_name: "Jane" }, recipient);
    assert.deepEqual(follow.notification, { body: "Jane started following you" });
    assert.equal(follow.data.session_id, "");
    assert.equal(follow.data.session_author_id, "");

    assert.equal(buildActivityPush({ type: "like" }, recipient).notification.body, "Someone liked your workout");
});

test("buildActivityPush tells a mentioned user who tagged them, with the comment's preview", () => {
    const mention = buildActivityPush(
        { type: "mention", actor_name: "Jane", comment_text: " Nice one @Sam ", session_id: "s1", session_author_id: "u1" },
        { fcm_token: "tok" }
    );
    assert.deepEqual(mention.notification, { body: 'Jane mentioned you: "Nice one @Sam"' });
    assert.equal(mention.data.type, "mention");
    assert.equal(mention.data.session_id, "s1");
    assert.equal(mention.data.session_author_id, "u1");
    const long = buildActivityPush({ type: "mention", actor_name: "Jane", comment_text: "z".repeat(100) }, { fcm_token: "tok" });
    assert.equal(long.notification.body, `Jane mentioned you: "${"z".repeat(59)}…"`);
});

test("buildActivityPush truncates a long comment to a 60-character preview", () => {
    const long = "x".repeat(100);
    const { body } = buildActivityPush({ type: "comment", actor_name: "Jane", comment_text: long }, { fcm_token: "tok" }).notification;
    assert.equal(body, `Jane commented: "${"x".repeat(59)}…"`);
    const exact = buildActivityPush({ type: "comment", actor_name: "Jane", comment_text: "y".repeat(60) }, { fcm_token: "tok" });
    assert.equal(exact.notification.body, `Jane commented: "${"y".repeat(60)}"`);
});

test("buildActivityPush sends nothing without a token, for an unknown type, or when opted out", () => {
    assert.equal(buildActivityPush({ type: "like" }, {}), null);
    assert.equal(buildActivityPush({ type: "like" }, undefined), null);
    assert.equal(buildActivityPush({ type: "poke" }, { fcm_token: "tok" }), null);
    assert.equal(buildActivityPush({ type: "mention" }, { fcm_token: "tok", social_push_mentions: false }), null);
    assert.equal(buildActivityPush({ type: "like" }, { fcm_token: "tok", social_push_likes: false }), null);
    assert.equal(buildActivityPush({ type: "comment" }, { fcm_token: "tok", social_push_comments: false }), null);
    assert.equal(buildActivityPush({ type: "follow" }, { fcm_token: "tok", social_push_follows: false }), null);
    assert.equal(buildActivityPush({ type: "nudge" }, { fcm_token: "tok", social_push_nudges: false }), null);
    // Opting out of one type leaves the others on.
    assert.notEqual(buildActivityPush({ type: "follow" }, { fcm_token: "tok", social_push_likes: false }), null);
});

test("newlyBlockedIds returns only the ids the update added to blocked_user_ids", () => {
    assert.deepEqual(newlyBlockedIds({ blocked_user_ids: ["a"] }, { blocked_user_ids: ["a", "b"] }), ["b"]);
    // Profiles written before blocking existed have no field on either side.
    assert.deepEqual(newlyBlockedIds({}, { blocked_user_ids: ["a"] }), ["a"]);
    assert.deepEqual(newlyBlockedIds(undefined, undefined), []);
    assert.deepEqual(newlyBlockedIds({ blocked_user_ids: ["a"] }, {}), []);
    // An unblock, or an update that leaves the list alone, has nothing to clean up.
    assert.deepEqual(newlyBlockedIds({ blocked_user_ids: ["a", "b"] }, { blocked_user_ids: ["a"] }), []);
    assert.deepEqual(newlyBlockedIds({ blocked_user_ids: ["a"] }, { blocked_user_ids: ["a"], is_private: true }), []);
    assert.deepEqual(newlyBlockedIds({}, { blocked_user_ids: ["a", "a"] }), ["a"]);
});

test("pushRecipientSettings reads the private doc first and falls back to the user doc", () => {
    const legacy = { fcm_token: "old", social_push_likes: false, social_push_comments: false, display_name: "x" };

    // Not migrated yet: everything comes from the user doc, and nothing else is copied over.
    assert.deepEqual(pushRecipientSettings(undefined, legacy), {
        fcm_token: "old", social_push_likes: false, social_push_comments: false, social_push_follows: undefined,
        social_push_nudges: undefined, social_push_mentions: undefined, social_push_shares: undefined, social_push_challenges: undefined,
    });

    // Migrated: the private doc wins field by field, including a false over a legacy true.
    const merged = pushRecipientSettings({ fcm_token: "new", social_push_comments: true, social_push_follows: false }, legacy);
    assert.equal(merged.fcm_token, "new");
    assert.equal(merged.social_push_likes, false);
    assert.equal(merged.social_push_comments, true);
    assert.equal(merged.social_push_follows, false);
    assert.equal(pushRecipientSettings({ social_push_likes: false }, { social_push_likes: true }).social_push_likes, false);

    // Neither doc: no token, so buildActivityPush sends nothing.
    assert.equal(buildActivityPush({ type: "like" }, pushRecipientSettings(undefined, undefined)), null);
    assert.equal(buildActivityPush({ type: "like" }, pushRecipientSettings({ fcm_token: "new" }, undefined)).token, "new");
});

test("buildActivityPush turns a nudge into a push with no session behind it", () => {
    const nudge = buildActivityPush({ type: "nudge", actor_name: "Jane", actor_id: "a1" }, { fcm_token: "tok" });
    assert.deepEqual(nudge.notification, { body: "Jane nudged you to train" });
    assert.deepEqual(nudge.data, { tab: "dashboard", type: "nudge", session_id: "", session_author_id: "", actor_id: "a1" });
});

test("planFollowAccepted acts only when a request has just become accepted", () => {
    const params = { targetId: "t1", requesterId: "r1" };
    const pending = { requester_id: "r1", status: "pending" };
    const accepted = { requester_id: "r1", status: "accepted" };

    assert.deepEqual(planFollowAccepted(pending, accepted, params), {
        requesterId: "r1", targetId: "t1", notificationId: "follow_accepted_t1",
    });
    assert.equal(planFollowAccepted(pending, { ...pending, status: "declined" }, params), null);
    assert.equal(planFollowAccepted(pending, pending, params), null);
    // Already accepted before this write: the follow was handled then.
    assert.equal(planFollowAccepted(accepted, accepted, params), null);
    // Deleted, or a request whose body names someone other than its document id.
    assert.equal(planFollowAccepted(pending, undefined, params), null);
    assert.equal(planFollowAccepted(pending, { requester_id: "intruder", status: "accepted" }, params), null);
    assert.equal(planFollowAccepted(pending, accepted, { targetId: "r1", requesterId: "r1" }), null);
    assert.equal(planFollowAccepted(pending, accepted, {}), null);
});

test("buildFollowAcceptedNotification names the accepting user in the shape the app parses", () => {
    const now = new Date(0);
    const plan = { targetId: "t1", requesterId: "r1" };
    const doc = buildFollowAcceptedNotification(
        { submitted_first_name: "Jane", last_name: "Smith", photo_url: "https://img" }, plan, now
    );
    assert.deepEqual(doc, {
        type: "followAccepted",
        actor_id: "t1",
        actor_name: "Jane Smith",
        actor_image_url: "https://img",
        session_id: "",
        session_author_id: "r1",
        date_created: now,
        is_read: false,
    });
    assert.equal(buildFollowAcceptedNotification(undefined, plan, now).actor_name, "Someone");
    assert.equal("actor_image_url" in buildFollowAcceptedNotification({}, plan, now), false);
});

test("userDisplayName prefers the submitted name and falls back to Someone", () => {
    assert.equal(userDisplayName({ submitted_first_name: "Sam", first_name: "Samuel" }), "Sam");
    assert.equal(userDisplayName({ first_name: "Al", last_name: "Bo" }), "Al Bo");
    assert.equal(userDisplayName({}), "Someone");
});

test("buildActivityPush sends a followAccepted push under the follows preference", () => {
    const push = buildActivityPush({ type: "followAccepted", actor_name: "Jane", actor_id: "t1" }, { fcm_token: "tok" });
    assert.deepEqual(push.notification, { body: "Jane accepted your follow request" });
    assert.equal(buildActivityPush({ type: "followAccepted" }, { fcm_token: "tok", social_push_follows: false }), null);
});

test("buildFollowRequestPush asks the target, routes to notifications and respects the follows opt-out", () => {
    const request = { requester_id: "r1", requester_name: "Jane", status: "pending" };
    const push = buildFollowRequestPush(request, { fcm_token: "tok" }, {});
    assert.equal(push.token, "tok");
    assert.deepEqual(push.notification, { body: "Jane wants to follow you" });
    assert.equal(push.apns.payload.aps.badge, 1);
    assert.equal(buildFollowRequestPush(request, { fcm_token: "tok" }, {}, 4).apns.payload.aps.badge, 4);
    assert.deepEqual(push.data, { tab: "dashboard", type: "follow_request", session_id: "", session_author_id: "", actor_id: "r1" });
    assert.equal(buildFollowRequestPush({ ...request, requester_name: undefined }, { fcm_token: "tok" }).notification.body, "Someone wants to follow you");

    assert.equal(buildFollowRequestPush(request, { fcm_token: "tok", social_push_follows: false }, {}), null);
    assert.equal(buildFollowRequestPush(request, {}, {}), null);
    assert.equal(buildFollowRequestPush({ ...request, status: "accepted" }, { fcm_token: "tok" }, {}), null);
    assert.equal(buildFollowRequestPush(request, { fcm_token: "tok" }, { blocked_user_ids: ["r1"] }), null);
    assert.equal(buildFollowRequestPush(undefined, { fcm_token: "tok" }, {}), null);
});

test("removedFollowingIds returns only the ids an update dropped from following_ids", () => {
    assert.deepEqual(removedFollowingIds({ following_ids: ["a", "b"] }, { following_ids: ["a"] }), ["b"]);
    assert.deepEqual(removedFollowingIds({ following_ids: ["a"] }, {}), ["a"]);
    assert.deepEqual(removedFollowingIds({}, { following_ids: ["a"] }), []);
    assert.deepEqual(removedFollowingIds(undefined, undefined), []);
    assert.deepEqual(removedFollowingIds({ following_ids: ["a"] }, { following_ids: ["a"], is_private: true }), []);
});

test("planAutoAccept accepts every valid pending request only when a profile goes public", () => {
    const requests = [
        { id: "r1", data: { requester_id: "r1", status: "pending" } },
        { id: "r2", data: { requester_id: "r2", status: "declined" } },
        { id: "r3", data: { requester_id: "intruder", status: "pending" } },
        { id: "r4", data: { requester_id: "r4", status: "pending" } },
    ];
    assert.deepEqual(planAutoAccept({ is_private: true }, { is_private: false }, requests), ["r1", "r4"]);
    assert.deepEqual(planAutoAccept({ is_private: true }, { is_private: false }, []), []);
    assert.equal(planAutoAccept({ is_private: false }, { is_private: true }, requests), null);
    assert.equal(planAutoAccept({ is_private: true }, { is_private: true }, requests), null);
    assert.equal(planAutoAccept({}, { is_private: false }, requests), null);
    assert.equal(planAutoAccept(undefined, undefined, requests), null);
});

test("removeFollowerTarget takes a follower id that is not the caller", () => {
    assert.equal(removeFollowerTarget({ followerId: "f1" }, "me"), "f1");
    assert.equal(removeFollowerTarget({ followerId: "me" }, "me"), null);
    assert.equal(removeFollowerTarget({ followerId: " " }, "me"), null);
    assert.equal(removeFollowerTarget({ followerId: 3 }, "me"), null);
    assert.equal(removeFollowerTarget({}, "me"), null);
    assert.equal(removeFollowerTarget(undefined, "me"), null);
});

// ---------------------------------------------------------------------------
// Usernames
// ---------------------------------------------------------------------------

import { planUsernameRelease, shouldReleaseReservation } from "./lib.js";

test("planUsernameRelease releases the old handle only when it changed or the user was deleted", () => {
    assert.equal(planUsernameRelease({ username: "bob" }, { username: "bobby" }), "bob");
    assert.equal(planUsernameRelease({ username: "bob" }, {}), "bob");
    assert.equal(planUsernameRelease({ username: "bob" }, undefined), "bob");
    assert.equal(planUsernameRelease({ username: "bob" }, { username: "bob" }), null);
    assert.equal(planUsernameRelease({}, { username: "bob" }), null);
    assert.equal(planUsernameRelease(undefined, { username: "bob" }), null);
    assert.equal(planUsernameRelease({ username: "" }, {}), null);
});

test("shouldReleaseReservation leaves a handle someone else now holds", () => {
    assert.equal(shouldReleaseReservation({ user_id: "u1" }, "u1"), true);
    assert.equal(shouldReleaseReservation({ user_id: "u2" }, "u1"), false);
    assert.equal(shouldReleaseReservation(undefined, "u1"), false);
    assert.equal(shouldReleaseReservation({ user_id: undefined }, undefined), false);
});

test("buildActivityPush sends a share push under the shares preference", () => {
    const push = buildActivityPush({ type: "share", actor_name: "Jane" }, { fcm_token: "tok" });
    assert.deepEqual(push.notification, { body: "Jane shared a workout" });
    assert.equal(buildActivityPush({ type: "share" }, { fcm_token: "tok", social_push_shares: false }), null);
});

// ---------------------------------------------------------------------------
// Scheduled pushes
// ---------------------------------------------------------------------------

test("localTime reads the user's wall clock across time zones and DST, and rejects bad zones", () => {
    const instant = new Date("2026-03-08T12:30:00Z");
    assert.deepEqual(localTime(instant, "Europe/London"), { date: "2026-03-08", hour: 12, weekday: 0 });
    // US clocks sprang forward at 02:00 that morning: 12:30Z is 08:30 EDT, not 07:30 EST.
    assert.deepEqual(localTime(instant, "America/New_York"), { date: "2026-03-08", hour: 8, weekday: 0 });
    assert.deepEqual(localTime(instant, "Pacific/Auckland"), { date: "2026-03-09", hour: 1, weekday: 1 });
    assert.equal(localTime(new Date("2026-06-01T12:00:00Z"), "Asia/Kolkata").hour, 17);
    assert.equal(localTime(instant, undefined), null);
    assert.equal(localTime(instant, "Not/AZone"), null);
});

test("the streak reminder is due only in the user's reminder hour, defaulting to 19", () => {
    const settings = { fcm_token: "tok", timezone: "America/New_York", reminder_hour: 20, social_push_streak_reminder: true };
    // 20:00 EST in winter is 01:00Z; after the change 20:00 EDT is 00:00Z.
    assert.equal(isStreakReminderDue(settings, new Date("2026-01-15T01:00:00Z")), true);
    assert.equal(isStreakReminderDue(settings, new Date("2026-01-15T00:00:00Z")), false);
    assert.equal(isStreakReminderDue(settings, new Date("2026-07-15T00:00:00Z")), true);
    // Changed: absent used to mean on. The reminder is now off until the person says yes.
    assert.equal(isStreakReminderDue({ fcm_token: "tok", timezone: "Europe/London" }, new Date("2026-01-15T19:00:00Z")), false);
    assert.equal(isStreakReminderDue({ fcm_token: "tok", timezone: "Europe/London", social_push_streak_reminder: true }, new Date("2026-01-15T19:00:00Z")), true);
    assert.equal(isStreakReminderDue({ ...settings, social_push_streak_reminder: false }, new Date("2026-01-15T01:00:00Z")), false);
    assert.equal(isStreakReminderDue({ timezone: "Europe/London", reminder_hour: 19 }, new Date("2026-01-15T19:00:00Z")), false);
    assert.equal(isStreakReminderDue(null, new Date()), false);
});

test("buildStreakReminderPush fires when the last workout was yesterday on the user's clock", () => {
    const settings = { fcm_token: "tok", timezone: "Australia/Sydney", reminder_hour: 19, social_push_streak_reminder: true };
    const now = new Date("2026-01-15T08:00:00Z"); // 19:00 AEDT on the 15th
    const push = buildStreakReminderPush(settings, { current_streak: 5, date_last_event: new Date("2026-01-14T09:00:00Z") }, now);
    assert.deepEqual(push.notification, { title: "Streak at Risk", body: "Your 5-day streak ends at midnight." });
    assert.equal(push.apns.payload.aps.alert.titleLocKey, "Streak at Risk");
    assert.equal(push.apns.payload.aps.alert.locKey, "Your %@-day streak ends at midnight.");
    assert.deepEqual(push.data, { tab: "training", type: "streakReminder" });
    assert.equal(push.token, "tok");
    // A Firestore Timestamp is read through toDate().
    assert.ok(buildStreakReminderPush(settings, { current_streak: 5, date_last_event: { toDate: () => new Date("2026-01-14T09:00:00Z") } }, now));

    // Trained today (the 15th local, although still the 14th in UTC): no push.
    assert.equal(buildStreakReminderPush(settings, { current_streak: 5, date_last_event: new Date("2026-01-14T22:00:00Z") }, now), null);
    // Last workout two days ago: the streak has already gone.
    assert.equal(buildStreakReminderPush(settings, { current_streak: 5, date_last_event: new Date("2026-01-13T09:00:00Z") }, now), null);
    assert.equal(buildStreakReminderPush(settings, { current_streak: 0, date_last_event: new Date("2026-01-14T09:00:00Z") }, now), null);
    assert.equal(buildStreakReminderPush(settings, undefined, now), null);
    assert.equal(buildStreakReminderPush(settings, { current_streak: 5, date_last_event: new Date("2026-01-14T09:00:00Z") }, new Date("2026-01-15T09:00:00Z")), null);
});

test("the weekly digest is due at 18:00 on Sunday local time only", () => {
    const settings = { fcm_token: "tok", timezone: "America/Los_Angeles" };
    assert.equal(isWeeklyDigestDue(settings, new Date("2026-01-19T02:00:00Z")), true); // Sun 18:00 PST
    assert.equal(isWeeklyDigestDue(settings, new Date("2026-07-20T01:00:00Z")), true); // Sun 18:00 PDT
    assert.equal(isWeeklyDigestDue(settings, new Date("2026-01-18T18:00:00Z")), false); // Sun 10:00 PST
    assert.equal(isWeeklyDigestDue({ fcm_token: "tok", timezone: "Europe/London" }, new Date("2026-01-17T18:00:00Z")), false); // Saturday
    assert.equal(isWeeklyDigestDue({ ...settings, social_push_weekly_digest: false }, new Date("2026-01-19T02:00:00Z")), false);
});

test("the digest counts real sessions and needs someone followed", () => {
    assert.equal(countTrainingSessions([{}, { deleted_at: new Date() }, { is_rest_day: true }, { is_rest_day: false }]), 2);
    assert.equal(countTrainingSessions(undefined), 0);
    assert.equal(digestWindowStart(new Date("2026-01-18T18:00:00Z")).toISOString(), "2026-01-11T18:00:00.000Z");

    const push = buildWeeklyDigestPush({ fcm_token: "tok" }, { mine: 3, circle: 11, followingCount: 2 });
    assert.equal(push.notification.body, "Workouts this week: you 3, your circle 11.");
    assert.equal(push.notification.title, "Your Week");
    assert.deepEqual(push.data, { tab: "social", type: "weeklyDigest" });
    assert.equal(buildWeeklyDigestPush({ fcm_token: "tok" }, { mine: 1, circle: 0, followingCount: 1 }).notification.body,
        "Workouts this week: you 1, your circle 0.");
    assert.equal(buildWeeklyDigestPush({ fcm_token: "tok" }, { mine: 3, circle: 0, followingCount: 0 }), null);
    assert.equal(buildWeeklyDigestPush({}, { mine: 3, circle: 1, followingCount: 1 }), null);
});

test("isNudgeOnCooldown holds for just under 24 hours after the last nudge", () => {
    const now = new Date("2026-01-15T00:01:00Z");
    const hoursAgo = (h) => new Date(now.getTime() - h * 3600 * 1000);
    assert.equal(isNudgeOnCooldown(hoursAgo(0.05), now), true);
    assert.equal(isNudgeOnCooldown({ toDate: () => hoursAgo(23.99) }, now), true);
    assert.equal(isNudgeOnCooldown(hoursAgo(24), now), false);
    assert.equal(isNudgeOnCooldown(hoursAgo(30), now), false);
    assert.equal(isNudgeOnCooldown(undefined, now), false);
});

// Account deletion cleanup
// ---------------------------------------------------------------------------

import { planUserDeletion, USER_DELETION_BATCH_SIZE } from "./lib.js";

test("planUserDeletion removes the user from others' data and skips what the recursive delete took", () => {
    const plan = planUserDeletion("me", {
        followers: ["users/a", "users/a", "users/me"],
        blockers: ["users/b"],
        likedSessions: ["users/a/workout_sessions/s1", "users/me/workout_sessions/s2"],
        followRequests: ["users/a/follow_requests/me"],
        comments: ["workout_session_comments/c1", "workout_session_comments/c1", "workout_session_comments/c2"],
        notifications: ["users/a/notifications/n1", "users/me/notifications/n2"],
        usernames: ["usernames/jane"],
        exercises: ["e1"],
        recipeTemplates: ["r1"],
        foods: ["f1"],
    });
    assert.deepEqual(plan.batches, [[
        { type: "arrayRemove", path: "users/a", field: "following_ids", value: "me" },
        { type: "arrayRemove", path: "users/b", field: "blocked_user_ids", value: "me" },
        { type: "arrayRemove", path: "users/a/workout_sessions/s1", field: "liked_by_user_ids", value: "me" },
        { type: "delete", path: "users/a/follow_requests/me" },
        { type: "delete", path: "workout_session_comments/c1" },
        { type: "delete", path: "workout_session_comments/c2" },
        { type: "delete", path: "users/a/notifications/n1" },
        { type: "delete", path: "usernames/jane" },
        { type: "delete", path: "exercise_templates/e1" },
        { type: "delete", path: "diet_plans/me" },
    ]]);
    assert.deepEqual(plan.storagePrefixes, ["users/me/"]);
    assert.deepEqual(plan.storageFiles, ["exercises/e1", "recipe_templates/r1", "ingredient_templates/f1"]);
});

test("planUserDeletion chunks its writes into batches of 400", () => {
    assert.equal(USER_DELETION_BATCH_SIZE, 400);
    const followers = Array.from({ length: 850 }, (_, i) => `users/u${i}`);
    const plan = planUserDeletion("me", { followers });
    assert.deepEqual(plan.batches.map((batch) => batch.length), [400, 400, 51]);
    assert.deepEqual(plan.batches.flat().at(-1), { type: "delete", path: "diet_plans/me" });
    assert.equal(plan.batches[1][0].path, "users/u400");

    // Nothing to clean elsewhere: only the diet plan and the user's own Storage folder.
    const empty = planUserDeletion("me");
    assert.deepEqual(empty.batches, [[{ type: "delete", path: "diet_plans/me" }]]);
    assert.deepEqual(empty.storageFiles, []);
});

// MARK: - CommentLikes
test("buildActivityPush words a reply to the recipient's comment as a reply", () => {
    const recipient = { fcm_token: "tok" };
    const reply = buildActivityPush({ type: "comment", is_reply: true, actor_name: "Jane", comment_text: "Agreed" }, recipient);
    assert.deepEqual(reply.notification, { body: 'Jane replied to your comment: "Agreed"' });
    assert.equal(reply.data.type, "comment");
    const plain = buildActivityPush({ type: "comment", is_reply: false, actor_name: "Jane", comment_text: "Agreed" }, recipient);
    assert.equal(plain.notification.body, 'Jane commented: "Agreed"');
    assert.equal(buildActivityPush({ type: "comment", is_reply: true }, { fcm_token: "tok", social_push_comments: false }), null);
});

import { REPORT_HIDE_THRESHOLD, planReportModeration } from "./lib.js";

const report = (id, reporter, extra = {}) => ({
    id, reporter_id: reporter, target_type: "session", target_id: "s1", target_author_id: "author",
    reason: "spam", status: "open", ...extra,
});

test("planReportModeration waits for three distinct reporters", () => {
    assert.equal(REPORT_HIDE_THRESHOLD, 3);
    const newest = report("r3", "c");
    assert.equal(planReportModeration(newest, [report("r1", "a"), report("r2", "b")]), null);
    // One person reporting three times is still one reporter.
    assert.equal(planReportModeration(newest, [report("r1", "c"), report("r2", "c"), newest]), null);
    // Reports already actioned or dismissed, or naming a different author, do not count.
    assert.equal(planReportModeration(newest, [
        report("r1", "a", { status: "dismissed" }), report("r2", "b", { target_author_id: "other" }), newest,
    ]), null);
});

test("planReportModeration hides a session under its author and queues it", () => {
    const newest = report("r3", "c", { reason: "harassment" });
    const plan = planReportModeration(newest, [report("r1", "a"), report("r2", "b"), newest]);
    assert.equal(plan.hidePath, "users/author/workout_sessions/s1");
    assert.equal(plan.queueId, "s1");
    assert.deepEqual(plan.queue, {
        target_id: "s1", target_type: "session", target_author_id: "author",
        reporter_ids: ["a", "b", "c"], report_ids: ["r1", "r2", "r3"], reasons: ["harassment", "spam"], hidden: true,
    });
});

test("planReportModeration hides a comment at the top level and never hides a profile", () => {
    const comment = (id, who) => report(id, who, { target_type: "comment", target_id: "c1" });
    const commentPlan = planReportModeration(comment("r3", "c"), [comment("r1", "a"), comment("r2", "b"), comment("r3", "c")]);
    assert.equal(commentPlan.hidePath, "workout_session_comments/c1");

    const profile = (id, who) => report(id, who, { target_type: "user", target_id: "u1", target_author_id: "u1" });
    const profilePlan = planReportModeration(profile("r3", "c"), [profile("r1", "a"), profile("r2", "b"), profile("r3", "c")]);
    assert.equal(profilePlan.hidePath, null);
    assert.equal(profilePlan.queue.hidden, false);
    assert.equal(profilePlan.queueId, "u1");

    // A session report with no author cannot be located, so it is queued but not hidden.
    const orphan = (id, who) => report(id, who, { target_author_id: null });
    assert.equal(planReportModeration(orphan("r3", "c"), [orphan("r1", "a"), orphan("r2", "b"), orphan("r3", "c")]).hidePath, null);
});

// ---------------------------------------------------------------------------
// Challenges
// ---------------------------------------------------------------------------

import {
    activeChallengesFor, planChallengeProgress, sessionJustEnded,
    SOCIAL_PUSH_PREFERENCE_KEYS as CHALLENGE_PUSH_KEYS, buildActivityPush as buildChallengePush,
} from "./lib.js";

test("sessionJustEnded fires only when ended_at is first set on a training session", () => {
    const ended = { ended_at: new Date() };
    assert.equal(sessionJustEnded({}, ended), true);
    assert.equal(sessionJustEnded(undefined, ended), true, "created already finished");
    assert.equal(sessionJustEnded({ ended_at: null }, ended), true);
    assert.equal(sessionJustEnded(ended, { ...ended, name: "edited" }), false, "already ended");
    assert.equal(sessionJustEnded({}, {}), false, "still running");
    assert.equal(sessionJustEnded({}, undefined), false, "deleted");
    assert.equal(sessionJustEnded({}, { ...ended, is_rest_day: true }), false, "rest day");
    assert.equal(sessionJustEnded({}, { ...ended, deleted_at: new Date() }), false, "soft-deleted");
});

test("activeChallengesFor keeps running challenges the author is in", () => {
    const at = new Date("2026-10-10T12:00:00Z");
    const challenge = (id, start, end, members = ["me"]) => ({
        id, member_ids: members, starts_at: new Date(start), ends_at: new Date(end),
    });
    const all = [
        challenge("running", "2026-10-01", "2026-10-15"),
        challenge("future", "2026-10-11", "2026-10-20"),
        challenge("over", "2026-09-01", "2026-10-10T12:00:00Z"),
        challenge("not-mine", "2026-10-01", "2026-10-15", ["other"]),
        challenge("starts-now", "2026-10-10T12:00:00Z", "2026-10-20"),
    ];
    assert.deepEqual(activeChallengesFor(all, "me", at).map((c) => c.id), ["running", "starts-now"]);
    // Firestore Timestamps work as well as Dates.
    const ts = (d) => ({ toDate: () => new Date(d) });
    assert.equal(activeChallengesFor([{ id: "t", member_ids: ["me"], starts_at: ts("2026-10-01"), ends_at: ts("2026-10-15") }], "me", ts(at)).length, 1);
    assert.deepEqual(activeChallengesFor(all, "me", null), []);
});

test("planChallengeProgress counts a session once and notifies on reaching the target", () => {
    const now = new Date("2026-10-10T12:00:00Z");
    const challenge = { id: "c1", title: "October Grind", target_sessions: 3 };
    const user = { submitted_first_name: "Jane", submitted_last_name: "Doe" };

    const first = planChallengeProgress(challenge, "me", "s1", undefined, user, now);
    assert.deepEqual(first.progress, { sessions: 1, updated_at: now, session_ids: ["s1"] });
    assert.equal(first.notification, null);

    assert.equal(planChallengeProgress(challenge, "me", "s1", first.progress, user, now), null, "retry is a no-op");

    const third = planChallengeProgress(challenge, "me", "s3", { sessions: 2, session_ids: ["s1", "s2"] }, user, now);
    assert.equal(third.progress.sessions, 3);
    assert.equal(third.notificationId, "challenge_complete_c1");
    assert.deepEqual(third.notification, {
        type: "challenge_complete", actor_id: "me", actor_name: "Jane Doe", session_id: "", session_author_id: "me",
        comment_text: "October Grind", challenge_id: "c1", date_created: now, is_read: false,
    });

    const beyond = planChallengeProgress(challenge, "me", "s4", third.progress, user, now);
    assert.equal(beyond.progress.sessions, 4, "keeps counting past the target");
    assert.equal(beyond.notification, null, "notifies only once");
});

test("a challenge_complete notification pushes 'You finished <title>' unless opted out", () => {
    assert.equal(CHALLENGE_PUSH_KEYS.challenge_complete, "social_push_challenges");
    const notification = { type: "challenge_complete", comment_text: "October Grind", actor_id: "me" };
    const push = buildChallengePush(notification, { fcm_token: "t" });
    assert.equal(push.notification.body, "You finished October Grind");
    assert.equal(push.data.type, "challenge_complete");
    assert.equal(buildChallengePush(notification, { fcm_token: "t", social_push_challenges: false }), null);
});

// ---------------------------------------------------------------------------
// Invites
// ---------------------------------------------------------------------------

import {
    normaliseInviteCode, planInviteAcceptance, inviteOutcome, buildFollowNotification, buildInviteFollowRequest,
    INVITE_CODE_ALPHABET,
} from "./lib.js";

test("normaliseInviteCode uppercases, drops spaces and dashes, and refuses anything else", () => {
    assert.equal(normaliseInviteCode("push 2345"), "PUSH2345");
    assert.equal(normaliseInviteCode("PUSH-2345"), "PUSH2345");
    assert.equal(normaliseInviteCode("PUSH234"), null, "too short");
    assert.equal(normaliseInviteCode("PUSH23450"), null, "too long");
    assert.equal(normaliseInviteCode("PUSH2340"), null, "0 is not in the alphabet");
    assert.equal(normaliseInviteCode("LIFT2345"), null, "L and I are not in the alphabet");
    assert.equal(normaliseInviteCode(12345678), null);
    assert.equal(normaliseInviteCode(undefined), null);
    for (const c of "01ILO") assert.ok(!INVITE_CODE_ALPHABET.includes(c));
});

test("planInviteAcceptance refuses a missing, own, blocked or used-up invite", () => {
    const invite = { code: "PUSH2345", inviter_id: "a", uses: 0, max_uses: 50 };
    const inviter = { following_ids: [] };
    const invitee = { following_ids: [] };
    const code = (args) => planInviteAcceptance(args).error?.[0];
    assert.equal(code({ callerId: "b", invite: undefined, inviter, invitee }), "not-found");
    assert.equal(code({ callerId: "b", invite, inviter: undefined, invitee }), "not-found");
    assert.equal(code({ callerId: "a", invite, inviter, invitee }), "failed-precondition");
    assert.equal(code({ callerId: "b", invite, inviter: { blocked_user_ids: ["b"] }, invitee }), "permission-denied");
    assert.equal(code({ callerId: "b", invite, inviter, invitee: { blocked_user_ids: ["a"] } }), "permission-denied");
    assert.equal(code({ callerId: "b", invite: { ...invite, uses: 50 }, inviter, invitee }), "resource-exhausted");
    assert.equal(code({ callerId: "b", invite: { inviter_id: "a", uses: 50 }, inviter, invitee }), "resource-exhausted", "max_uses defaults to 50");
});

test("planInviteAcceptance follows both ways, requests a private profile, and counts only a change", () => {
    const invite = { inviter_id: "a", uses: 3, max_uses: 50 };
    assert.deepEqual(
        planInviteAcceptance({ callerId: "b", invite, inviter: {}, invitee: {} }),
        { inviterId: "a", inviteeFollows: "follow", inviterFollows: "follow", countsUse: true }
    );
    const privateBoth = planInviteAcceptance({ callerId: "b", invite, inviter: { is_private: true }, invitee: { is_private: true } });
    assert.equal(privateBoth.inviteeFollows, "request");
    assert.equal(privateBoth.inviterFollows, "request");

    // Already following both ways: nothing to write, no use taken, even on a used-up invite.
    const already = planInviteAcceptance({
        callerId: "b",
        invite: { ...invite, uses: 50 },
        inviter: { following_ids: ["b"], is_private: true },
        invitee: { following_ids: ["a"] },
    });
    assert.deepEqual(already, { inviterId: "a", inviteeFollows: "already", inviterFollows: "already", countsUse: false });

    assert.equal(inviteOutcome("request"), "requested");
    assert.equal(inviteOutcome("follow"), "following");
    assert.equal(inviteOutcome("already"), "following");
});

test("the follow and request docs acceptInvite writes match the shapes the app writes", () => {
    const now = new Date("2026-09-24T10:00:00Z");
    const follower = { submitted_first_name: "Alex", submitted_last_name: "Kim", photo_url: "p.jpg" };
    assert.deepEqual(buildFollowNotification(follower, { followerId: "b", followedId: "a" }, now), {
        type: "follow", actor_id: "b", actor_name: "Alex Kim", session_id: "", session_author_id: "a",
        date_created: now, is_read: false, actor_image_url: "p.jpg",
    });
    assert.deepEqual(buildInviteFollowRequest({}, "b", now), {
        requester_id: "b", requester_name: "Someone", requester_image_url: null, date_created: now, status: "pending",
    });
});

// MARK: - Web share page

test("sessionPage: parseSessionPath accepts /s/{author}/{id} and nothing else", async () => {
    const { parseSessionPath } = await import("./lib.js");
    assert.deepEqual(parseSessionPath("/s/uid_1/ABC-123"), { authorId: "uid_1", sessionId: "ABC-123" });
    for (const bad of ["/s/a", "/s/a/b/c", "/x/a/b", "/s/a/b%2Fc", "/s/../b", "", null]) {
        assert.equal(parseSessionPath(bad), null, String(bad));
    }
});

const sharePageFixture = () => {
    const start = new Date("2026-09-24T09:00:00Z");
    const set = (weight_kg, reps, at = start) => ({ weight_kg, reps, completed_at: at, isWarmup: false });
    const bench = (sets) => ({ template_id: "bench", name: "Bench Press", tracking_mode: "weightReps", sets });
    return {
        author: { first_name: "Ann", last_name: "Secret", photo_url: "https://img.example/a.png", is_private: false },
        session: {
            id: "s2", author_id: "a", name: "Push Day", date_created: start, ended_at: new Date("2026-09-24T10:05:00Z"), streak_count: 12,
            exercises: [bench([{ weight_kg: 40, reps: 10, isWarmup: true, completed_at: start }, set(100, 5), set(90, 8)])],
        },
        prior: [{ id: "s1", author_id: "a", date_created: new Date("2026-09-20T09:00:00Z"), ended_at: new Date("2026-09-20T10:00:00Z"), exercises: [bench([set(95, 5)])] }],
    };
};

test("sessionPage: the page shows first name, stats, PRs and streak, with Open Graph tags", async () => {
    const { buildSessionPageHtml } = await import("./lib.js");
    const { author, session, prior } = sharePageFixture();
    const html = buildSessionPageHtml({ session, author, priorSessions: prior, url: "https://p.web.app/s/a/s2" });
    assert.match(html, /<title>Ann&#39;s Push Day on DialedIn<\/title>/);
    assert.match(html, /<strong>Ann<\/strong>/);
    assert.match(html, /Thursday, September 24/);
    assert.match(html, /1h 5m/);
    assert.match(html, /1,220 kg/); // 100×5 + 90×8, warm-up excluded
    assert.match(html, /<li>Bench Press 100 kg × 5<\/li>/);
    assert.match(html, /12-day streak/);
    assert.match(html, /<meta property="og:url" content="https:\/\/p.web.app\/s\/a\/s2">/);
    assert.match(html, /<meta property="og:image" content="https:\/\/img.example\/a.png">/);
    assert.match(html, /App Store/);
    assert.doesNotMatch(html, /Secret/, "no last name");
});

test("sessionPage: a first-ever lift is not a record, and a lighter set beats nothing", async () => {
    const { personalRecordLines } = await import("./lib.js");
    const { session, prior } = sharePageFixture();
    assert.deepEqual(personalRecordLines(session, []), []);
    prior[0].exercises[0].sets[0].weight_kg = 120;
    assert.deepEqual(personalRecordLines(session, prior), []);
});

test("sessionPage: private author, hidden, deleted or unfinished session → null", async () => {
    const { buildSessionPageHtml } = await import("./lib.js");
    const cases = [
        (f) => { f.author.is_private = true; },
        (f) => { f.session.hidden = true; },
        (f) => { f.session.deleted_at = new Date(); },
        (f) => { delete f.session.ended_at; },
        (f) => { f.session = null; },
        (f) => { f.author = undefined; },
    ];
    for (const mutate of cases) {
        const f = sharePageFixture();
        mutate(f);
        assert.equal(buildSessionPageHtml({ session: f.session, author: f.author }), null, mutate.toString());
    }
});

test("sessionPage: user text is escaped and non-https avatars are dropped", async () => {
    const { buildSessionPageHtml, escapeHtml, notFoundPageHtml } = await import("./lib.js");
    assert.equal(escapeHtml(`<a href="x">'&'</a>`), "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;");
    const { author, session } = sharePageFixture();
    author.first_name = "<script>alert(1)</script>";
    author.photo_url = "javascript:alert(1)";
    session.name = `"><img src=x onerror=alert(1)>`;
    const html = buildSessionPageHtml({ session, author });
    assert.doesNotMatch(html, /<script>|<img src=x|javascript:/);
    assert.match(html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
    assert.match(notFoundPageHtml(), /Workout not found/);
});

// ---------------------------------------------------------------------------
// Interruption levels, badge and localization (HIG decision 12e)
// ---------------------------------------------------------------------------

test("likes and the weekly digest are passive; comments, mentions, follows, nudges and shares are active", () => {
    const level = (type) => buildActivityPush({ type, actor_name: "Jane" }, { fcm_token: "tok" }).apns.payload.aps["interruption-level"];
    assert.equal(level("like"), "passive");
    for (const type of ["comment", "mention", "follow", "followAccepted", "follow_request", "nudge", "share"]) {
        assert.equal(level(type), "active", type);
    }
    // Every type that can push states a level.
    for (const type of Object.keys(SOCIAL_PUSH_PREFERENCE_KEYS_FOR_LEVELS)) assert.ok(INTERRUPTION_LEVELS[type], type);
    const digest = buildWeeklyDigestPush({ fcm_token: "tok" }, { mine: 1, circle: 1, followingCount: 1 });
    assert.equal(digest.apns.payload.aps["interruption-level"], "passive");
    const streak = buildStreakReminderPush(
        { fcm_token: "tok", timezone: "Etc/UTC", reminder_hour: 19, social_push_streak_reminder: true },
        { current_streak: 3, date_last_event: new Date("2026-01-14T09:00:00Z") },
        new Date("2026-01-15T19:00:00Z")
    );
    assert.equal(streak.apns.payload.aps["interruption-level"], "active");
});

test("the badge is the recipient's unread count, never below 1", () => {
    const badge = (count) => buildActivityPush({ type: "like" }, { fcm_token: "tok" }, count).apns.payload.aps.badge;
    assert.equal(badge(5), 5);
    assert.equal(badge(0), 1);
    assert.equal(buildActivityPush({ type: "like" }, { fcm_token: "tok" }).apns.payload.aps.badge, 1);
});

test("formatLocKey fills %@ in order, as the device does with loc-args", () => {
    assert.equal(formatLocKey('%@ commented: "%@"', ["Jane", "Hi"]), 'Jane commented: "Hi"');
    assert.equal(formatLocKey("You finished a challenge", []), "You finished a challenge");
});

test("the unread badge counts unread notifications and pending follow requests", () => {
    const source = readFileSync(new URL("./index.js", import.meta.url), "utf8");
    assert.match(source, /collection\("notifications"\)\.where\("is_read", "==", false\)\.count\(\)/);
    assert.match(source, /collection\("follow_requests"\)\.where\("status", "==", "pending"\)\.count\(\)/);
    assert.match(source, /buildActivityPush\(notification, recipient, await unreadBadgeCount\(userRef\)\)/);
});

test("sessionPageContent leaves paused time out of the duration", () => {
    const session = { date_created: new Date("2026-09-29T10:00:00Z"), ended_at: new Date("2026-09-29T11:00:00Z") };
    assert.equal(sessionPageContent(session, {}).durationText, "1h 0m");
    assert.equal(sessionPageContent({ ...session, paused_seconds: 600.7 }, {}).durationText, "50m");
    assert.equal(sessionPageContent({ ...session, paused_seconds: 99999 }, {}).durationText, "0m");
});

test("offProductToFood converts OFF's grams into the app's mg and mcg and joins brand arrays", () => {
    const food = offProductToFood({
        product_name: " Weetabix Original ",
        brands: ["Weetabix", "Weetabix Ltd"],
        serving_quantity: 37.5,
        nutriments: {
            "energy-kcal_100g": 362, proteins_100g: 12, sodium_100g: 0.112,
            iron_100g: 0.012, "vitamin-b1_100g": 0.0012, "vitamin-pp_100g": 0.014, "vitamin-d_100g": 0.0000025,
        },
    });
    assert.equal(food.name, "Weetabix Original");
    assert.equal(food.brandName, "Weetabix, Weetabix Ltd");
    assert.equal(food.calories, 362);
    assert.equal(food.protein, 12);
    assert.ok(Math.abs(food.sodiumMg - 112) < 1e-9);
    assert.ok(Math.abs(food.ironMg - 12) < 1e-9);
    assert.ok(Math.abs(food.thiaminMg - 1.2) < 1e-9);
    assert.ok(Math.abs(food.niacinMg - 14) < 1e-9);
    assert.ok(Math.abs(food.vitaminDMcg - 2.5) < 1e-9);
    assert.equal(food.calciumMg, null);
});

test("offProductToFood falls back to kilojoules and drops nameless hits", () => {
    assert.ok(Math.abs(offProductToFood({ product_name: "Oats", brands: "Tesco", nutriments: { "energy-kj_100g": 1569 } }).calories - 375) < 0.1);
    assert.equal(offProductToFood({ product_name: "Oats", brands: "Tesco" }).brandName, "Tesco");
    assert.equal(offProductToFood({ product_name: "  " }), null);
});

test("stravaTokenForm adds the secret and picks the grant from what the app sent", () => {
    assert.deepEqual(stravaTokenForm({ clientId: "42", code: "c" }, "s"),
        { client_id: "42", client_secret: "s", code: "c", grant_type: "authorization_code" });
    assert.deepEqual(stravaTokenForm({ clientId: "42", refreshToken: "r" }, "s"),
        { client_id: "42", client_secret: "s", refresh_token: "r", grant_type: "refresh_token" });
    assert.equal(stravaTokenForm({ clientId: "42" }, "s"), null);
    assert.equal(stravaTokenForm({ code: "c" }, "s"), null);
    assert.equal(stravaTokenForm(null, "s"), null);
});

test("stravaTokenErrorCode tells a revoked grant apart from an outage", () => {
    assert.equal(stravaTokenErrorCode(400), "permission-denied");
    assert.equal(stravaTokenErrorCode(401), "permission-denied");
    assert.equal(stravaTokenErrorCode(429), "unavailable");
    assert.equal(stravaTokenErrorCode(503), "unavailable");
});

test("offCountryTag lets through only an OFF country tag, since it goes into the search query", () => {
    assert.equal(offCountryTag("en:ireland"), "en:ireland");
    assert.equal(offCountryTag("en:united-kingdom"), "en:united-kingdom");
    assert.equal(offCountryTag('en:ireland" OR *:*'), null);
    assert.equal(offCountryTag("IE"), null);
    assert.equal(offCountryTag(undefined), null);
});

test("offSearchLangs searches the app's language and English, and falls back to English", () => {
    assert.equal(offSearchLangs("es"), "es,en");
    assert.equal(offSearchLangs("en"), "en");
    assert.equal(offSearchLangs("spanish"), "en");
    assert.equal(offSearchLangs(undefined), "en");
});

test("mergeSearchHits puts the country first, drops repeats and products with no calories", () => {
    const local = [{ code: "1", name: "Tesco Gala Apples", calories: 53 }, { code: "2", name: "Gala apples", calories: null }];
    const global = [{ code: "1", name: "Tesco Gala Apples", calories: 53 }, { code: "3", name: "Chausson aux pommes", calories: 251 }];
    assert.deepEqual(mergeSearchHits(local, global).map((f) => f.code), ["1", "3"]);
    assert.equal(mergeSearchHits(local, global, 1).length, 1);
});
