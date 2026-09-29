// Trigger tests against the Firestore emulator: seed documents, run the wrapped function, read back.
// Needs FIRESTORE_EMULATOR_HOST, so `npm test` (pure tests) skips this file and `npm run test:triggers`
// starts the emulator for it. FCM and Storage are stubbed with recorders; nothing leaves the machine.
import { describe, test, before, after, beforeEach, mock } from "node:test";
import assert from "node:assert/strict";

const HOST = process.env.FIRESTORE_EMULATOR_HOST;
const PROJECT = "demo-dialedin";

describe("Cloud Functions on the Firestore emulator", { skip: !HOST && "needs FIRESTORE_EMULATOR_HOST (npm run test:triggers)" }, () => {
    let fft, fns, db;
    const sent = [];
    const storage = { prefixes: [], files: [] };

    before(async () => {
        process.env.GCLOUD_PROJECT = PROJECT;
        fft = (await import("firebase-functions-test")).default({ projectId: PROJECT });
        fns = await import("./index.js");
        const firestore = await import("firebase-admin/firestore");
        db = firestore.getFirestore();

        const { Messaging } = await import("firebase-admin/messaging");
        Messaging.prototype.send = async (message) => { sent.push(message); return "stub-id"; };
        const { Storage } = await import("firebase-admin/storage");
        Storage.prototype.bucket = () => ({
            deleteFiles: async ({ prefix }) => { storage.prefixes.push(prefix); },
            file: (name) => ({ delete: async () => { storage.files.push(name); } }),
        });
    });

    after(() => fft?.cleanup());

    beforeEach(async () => {
        sent.length = 0;
        storage.prefixes.length = 0;
        storage.files.length = 0;
        const res = await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: "DELETE" });
        assert.ok(res.ok, "emulator reset");
    });

    // Helpers: real snapshots read back from the emulator, so ref and exists behave as deployed.
    const doc = (path) => db.doc(path);
    const read = async (path) => (await doc(path).get()).data();
    const exists = async (path) => (await doc(path).get()).exists;
    const seed = (docs) => Promise.all(Object.entries(docs).map(([path, data]) => doc(path).set(data)));
    const run = (fn, event) => fft.wrap(fn)(event);

    // A write to `path`, run through `fn` as the Change (updated/written/deleted) it produces.
    async function change(fn, path, write, params) {
        const beforeSnap = await doc(path).get();
        await write(doc(path));
        const afterSnap = await doc(path).get();
        return run(fn, { data: fft.makeChange(beforeSnap, afterSnap), params });
    }
    // A document created at `path`, run through `fn` as the snapshot onDocumentCreated gets.
    async function created(fn, path, data, params) {
        await doc(path).set(data);
        return run(fn, { data: await doc(path).get(), params });
    }

    const HOUR = 60 * 60 * 1000;

    describe("onActivityNotificationCreated", () => {
        test("pushes a like to the token in private settings", async () => {
            await seed({ "users/r": { first_name: "Rae" }, "users/r/private/settings": { fcm_token: "tok-r" } });
            await created(fns.onActivityNotificationCreated, "users/r/notifications/n1",
                { type: "like", actor_id: "a", actor_name: "Ann", session_id: "s1", date_created: new Date() },
                { userId: "r", notificationId: "n1" });
            assert.equal(sent.length, 1);
            assert.equal(sent[0].token, "tok-r");
            assert.equal(sent[0].notification.body, "Ann liked your workout");
            assert.equal(sent[0].data.session_id, "s1");
        });

        test("sends nothing when the type is opted out, falling back to the user doc", async () => {
            await seed({ "users/r": { fcm_token: "tok-r", social_push_likes: false } });
            await created(fns.onActivityNotificationCreated, "users/r/notifications/n1",
                { type: "like", actor_id: "a", actor_name: "Ann", date_created: new Date() },
                { userId: "r", notificationId: "n1" });
            assert.equal(sent.length, 0);
        });

        test("drops a nudge within 24 hours of the same actor's last one, and deletes it", async () => {
            await seed({
                "users/r/private/settings": { fcm_token: "tok-r" },
                "users/r/notifications/old": { type: "nudge", actor_id: "a", date_created: new Date(Date.now() - 2 * HOUR) },
            });
            await created(fns.onActivityNotificationCreated, "users/r/notifications/new",
                { type: "nudge", actor_id: "a", actor_name: "Ann", date_created: new Date() },
                { userId: "r", notificationId: "new" });
            assert.equal(sent.length, 0);
            assert.equal(await exists("users/r/notifications/new"), false);
            assert.equal(await exists("users/r/notifications/old"), true);
        });

        test("pushes a nudge once the cooldown has passed", async () => {
            await seed({
                "users/r/private/settings": { fcm_token: "tok-r" },
                "users/r/notifications/old": { type: "nudge", actor_id: "a", date_created: new Date(Date.now() - 25 * HOUR) },
            });
            await created(fns.onActivityNotificationCreated, "users/r/notifications/new",
                { type: "nudge", actor_id: "a", actor_name: "Ann", date_created: new Date() },
                { userId: "r", notificationId: "new" });
            assert.equal(sent.length, 1);
            assert.equal(await exists("users/r/notifications/new"), true);
        });
    });

    test("onUserBlockListChanged ends the blocked person's follow and drops their request", async () => {
        await seed({
            "users/a": { blocked_user_ids: [] },
            "users/b": { following_ids: ["a", "c"] },
            "users/a/follow_requests/b": { requester_id: "b", status: "pending" },
            "users/a/follow_requests/c": { requester_id: "c", status: "pending" },
        });
        await change(fns.onUserBlockListChanged, "users/a", (ref) => ref.update({ blocked_user_ids: ["b"] }), { uid: "a" });
        assert.deepEqual((await read("users/b")).following_ids, ["c"]);
        assert.equal(await exists("users/a/follow_requests/b"), false);
        assert.equal(await exists("users/a/follow_requests/c"), true);
    });

    test("onUserBlockListChanged blocking a deleted account does not recreate it", async () => {
        await seed({ "users/a": {} });
        await change(fns.onUserBlockListChanged, "users/a", (ref) => ref.update({ blocked_user_ids: ["gone"] }), { uid: "a" });
        assert.equal(await exists("users/gone"), false);
    });

    describe("onFollowRequestUpdated", () => {
        test("an acceptance writes the follow and the notification, and deletes the request", async () => {
            await seed({
                "users/t": { first_name: "Tia", photo_url: "https://img/t" },
                "users/r": { following_ids: [] },
                "users/t/follow_requests/r": { requester_id: "r", status: "pending" },
            });
            await change(fns.onFollowRequestUpdated, "users/t/follow_requests/r",
                (ref) => ref.update({ status: "accepted" }), { targetId: "t", requesterId: "r" });
            assert.deepEqual((await read("users/r")).following_ids, ["t"]);
            const note = await read("users/r/notifications/follow_accepted_t");
            assert.equal(note.type, "followAccepted");
            assert.equal(note.actor_id, "t");
            assert.equal(note.actor_name, "Tia");
            assert.equal(note.actor_image_url, "https://img/t");
            assert.equal(await exists("users/t/follow_requests/r"), false);
        });

        test("a decline changes nothing else", async () => {
            await seed({
                "users/r": { following_ids: [] },
                "users/t/follow_requests/r": { requester_id: "r", status: "pending" },
            });
            await change(fns.onFollowRequestUpdated, "users/t/follow_requests/r",
                (ref) => ref.update({ status: "declined" }), { targetId: "t", requesterId: "r" });
            assert.deepEqual((await read("users/r")).following_ids, []);
            assert.equal((await read("users/t/follow_requests/r")).status, "declined");
            assert.equal(await exists("users/r/notifications/follow_accepted_t"), false);
        });
    });

    describe("onFollowRequestCreated", () => {
        test("pushes the request to the target", async () => {
            await seed({ "users/t": {}, "users/t/private/settings": { fcm_token: "tok-t" } });
            await created(fns.onFollowRequestCreated, "users/t/follow_requests/r",
                { requester_id: "r", requester_name: "Rae", status: "pending" }, { targetId: "t", requesterId: "r" });
            assert.equal(sent.length, 1);
            assert.equal(sent[0].token, "tok-t");
            assert.equal(sent[0].data.type, "follow_request");
            assert.equal(sent[0].notification.body, "Rae wants to follow you");
        });

        test("stays quiet for a requester the target blocked", async () => {
            await seed({ "users/t": { blocked_user_ids: ["r"] }, "users/t/private/settings": { fcm_token: "tok-t" } });
            await created(fns.onFollowRequestCreated, "users/t/follow_requests/r",
                { requester_id: "r", requester_name: "Rae", status: "pending" }, { targetId: "t", requesterId: "r" });
            assert.equal(sent.length, 0);
        });
    });

    describe("removeFollower", () => {
        test("takes the caller out of the follower's following_ids and drops the follow notification", async () => {
            await seed({ "users/f": { following_ids: ["u", "x"] }, "users/u/notifications/follow_f": { type: "follow" } });
            const result = await run(fns.removeFollower, { data: { followerId: "f" }, auth: { uid: "u" } });
            assert.deepEqual(result, { removed: "f" });
            assert.deepEqual((await read("users/f")).following_ids, ["x"]);
            assert.equal(await exists("users/u/notifications/follow_f"), false);
        });

        test("tolerates a follower whose account is gone, without recreating it", async () => {
            const result = await run(fns.removeFollower, { data: { followerId: "gone" }, auth: { uid: "u" } });
            assert.deepEqual(result, { removed: "gone" });
            assert.equal(await exists("users/gone"), false);
        });
    });

    test("onUserFollowingChanged deletes pending requests between the pair both ways", async () => {
        await seed({
            "users/u": { following_ids: ["x", "y"] },
            "users/x/follow_requests/u": { requester_id: "u", status: "pending" },
            "users/u/follow_requests/x": { requester_id: "x", status: "pending" },
            "users/u/follow_requests/y": { requester_id: "y", status: "pending" },
        });
        await change(fns.onUserFollowingChanged, "users/u", (ref) => ref.update({ following_ids: ["y"] }), { uid: "u" });
        assert.equal(await exists("users/x/follow_requests/u"), false);
        assert.equal(await exists("users/u/follow_requests/x"), false);
        assert.equal(await exists("users/u/follow_requests/y"), true);
    });

    describe("onUserPrivacyChanged", () => {
        test("going public accepts every pending request whose id matches its requester", async () => {
            await seed({
                "users/u": { is_private: true },
                "users/u/follow_requests/a": { requester_id: "a", status: "pending" },
                "users/u/follow_requests/b": { requester_id: "b", status: "declined" },
                "users/u/follow_requests/c": { requester_id: "someone-else", status: "pending" },
            });
            await change(fns.onUserPrivacyChanged, "users/u", (ref) => ref.update({ is_private: false }), { uid: "u" });
            assert.equal((await read("users/u/follow_requests/a")).status, "accepted");
            assert.equal((await read("users/u/follow_requests/b")).status, "declined");
            assert.equal((await read("users/u/follow_requests/c")).status, "pending");
        });

        test("going private accepts nothing", async () => {
            await seed({
                "users/u": { is_private: false },
                "users/u/follow_requests/a": { requester_id: "a", status: "pending" },
            });
            await change(fns.onUserPrivacyChanged, "users/u", (ref) => ref.update({ is_private: true }), { uid: "u" });
            assert.equal((await read("users/u/follow_requests/a")).status, "pending");
        });
    });

    describe("onUsernameChanged", () => {
        test("a changed username releases the old reservation", async () => {
            await seed({ "users/u": { username: "old" }, "usernames/old": { user_id: "u" }, "usernames/new": { user_id: "u" } });
            await change(fns.onUsernameChanged, "users/u", (ref) => ref.update({ username: "new" }), { uid: "u" });
            assert.equal(await exists("usernames/old"), false);
            assert.equal(await exists("usernames/new"), true);
        });

        test("a handle someone else has since reserved is left alone", async () => {
            await seed({ "users/u": { username: "old" }, "usernames/old": { user_id: "other" } });
            await change(fns.onUsernameChanged, "users/u", (ref) => ref.update({ username: "new" }), { uid: "u" });
            assert.equal((await read("usernames/old")).user_id, "other");
        });

        test("deleting the account releases the handle", async () => {
            await seed({ "users/u": { username: "old" }, "usernames/old": { user_id: "u" } });
            await change(fns.onUsernameChanged, "users/u", (ref) => ref.delete(), { uid: "u" });
            assert.equal(await exists("usernames/old"), false);
        });
    });

    test("onUserDeleted removes the user from everyone else's data and their uploads", async () => {
        await seed({
            "users/u": { username: "uu", following_ids: ["t"] },
            "users/u/workout_sessions/own": { ended_at: new Date() },
            "users/u/recipe_templates/rec1": { name: "Oats" },
            "users/u/foods/food1": { name: "Egg" },
            "users/f": { following_ids: ["u", "t"] },
            "users/b": { blocked_user_ids: ["u"] },
            "users/t": { following_ids: [] },
            "users/t/follow_requests/u": { requester_id: "u", status: "pending" },
            "users/t/follow_requests/f": { requester_id: "f", status: "pending" },
            "users/t/workout_sessions/s1": { liked_by_user_ids: ["u", "f"] },
            "users/t/notifications/n1": { actor_id: "u", type: "like" },
            "users/t/notifications/n2": { actor_id: "f", type: "like" },
            "workout_session_comments/c1": { author_id: "u", session_author_id: "t" },
            "workout_session_comments/c2": { author_id: "f", session_author_id: "u" },
            "workout_session_comments/c3": { author_id: "f", session_author_id: "t" },
            "usernames/uu": { user_id: "u" },
            "exercise_templates/e1": { author_id: "u" },
            "exercise_templates/e2": { author_id: "f" },
            "diet_plans/u": { calories: 2000 },
        });
        // onDocumentDeleted wants the pre-delete snapshot as its data; the handler does the delete.
        await run(fns.onUserDeleted, { data: await doc("users/u").get(), params: { uid: "u" } });

        assert.equal(await exists("users/u"), false);
        assert.equal(await exists("users/u/workout_sessions/own"), false);
        assert.equal(await exists("users/u/recipe_templates/rec1"), false);
        assert.deepEqual((await read("users/f")).following_ids, ["t"]);
        assert.deepEqual((await read("users/b")).blocked_user_ids, []);
        assert.equal(await exists("users/t/follow_requests/u"), false);
        assert.equal(await exists("users/t/follow_requests/f"), true);
        assert.deepEqual((await read("users/t/workout_sessions/s1")).liked_by_user_ids, ["f"]);
        assert.equal(await exists("users/t/notifications/n1"), false);
        assert.equal(await exists("users/t/notifications/n2"), true);
        assert.equal(await exists("workout_session_comments/c1"), false);
        assert.equal(await exists("workout_session_comments/c2"), false);
        assert.equal(await exists("workout_session_comments/c3"), true);
        assert.equal(await exists("usernames/uu"), false);
        assert.equal(await exists("exercise_templates/e1"), false);
        assert.equal(await exists("exercise_templates/e2"), true);
        assert.equal(await exists("diet_plans/u"), false);
        assert.deepEqual(storage.prefixes, ["users/u/"]);
        assert.deepEqual(storage.files.sort(), ["exercises/e1", "ingredient_templates/food1", "recipe_templates/rec1"]);
    });

    describe("onReportCreated", () => {
        const report = (id, reporter) => [`reports/${id}`, {
            id, reporter_id: reporter, target_id: "s1", target_type: "session", target_author_id: "t", reason: "spam", status: "open",
        }];

        test("the third distinct reporter hides the session and queues it", async () => {
            await seed({ "users/t/workout_sessions/s1": { name: "Legs" }, ...Object.fromEntries([report("r1", "a"), report("r2", "b")]) });
            const [path, data] = report("r3", "c");
            await created(fns.onReportCreated, path, data, { reportId: "r3" });
            assert.equal((await read("users/t/workout_sessions/s1")).hidden, true);
            const queue = await read("moderation_queue/s1");
            assert.deepEqual(queue.reporter_ids, ["a", "b", "c"]);
            assert.deepEqual(queue.report_ids, ["r1", "r2", "r3"]);
            assert.equal(queue.hidden, true);
        });

        test("one person reporting three times hides nothing", async () => {
            await seed({ "users/t/workout_sessions/s1": { name: "Legs" }, ...Object.fromEntries([report("r1", "a"), report("r2", "a")]) });
            const [path, data] = report("r3", "a");
            await created(fns.onReportCreated, path, data, { reportId: "r3" });
            assert.equal((await read("users/t/workout_sessions/s1")).hidden, undefined);
            assert.equal(await exists("moderation_queue/s1"), false);
        });
    });

    describe("onWorkoutSessionEndedForChallenges", () => {
        const challenge = {
            title: "Five in a week", member_ids: ["u", "v"], target_sessions: 1,
            starts_at: new Date(Date.now() - 24 * HOUR), ends_at: new Date(Date.now() + 24 * HOUR),
        };
        const finish = () => change(fns.onWorkoutSessionEndedForChallenges, "users/u/workout_sessions/s1",
            (ref) => ref.update({ ended_at: new Date() }), { uid: "u", sessionId: "s1" });

        test("finishing a session counts it and completes the challenge", async () => {
            await seed({ "challenges/c1": challenge, "users/u": { first_name: "Uma" }, "users/u/workout_sessions/s1": { name: "Push" } });
            await finish();
            const progress = await read("challenges/c1/progress/u");
            assert.equal(progress.sessions, 1);
            assert.deepEqual(progress.session_ids, ["s1"]);
            const note = await read("users/u/notifications/challenge_complete_c1");
            assert.equal(note.type, "challenge_complete");
            assert.equal(note.comment_text, "Five in a week");
            assert.equal(note.actor_name, "Uma");
        });

        test("a retried trigger does not count the session twice", async () => {
            await seed({
                "challenges/c1": { ...challenge, target_sessions: 3 },
                "challenges/c1/progress/u": { sessions: 1, session_ids: ["s1"] },
                "users/u/workout_sessions/s1": { name: "Push" },
            });
            await finish();
            assert.equal((await read("challenges/c1/progress/u")).sessions, 1);
        });

        test("a challenge that has ended is not counted", async () => {
            await seed({
                "challenges/c1": { ...challenge, ends_at: new Date(Date.now() - HOUR) },
                "users/u/workout_sessions/s1": { name: "Push" },
            });
            await finish();
            assert.equal(await exists("challenges/c1/progress/u"), false);
        });
    });

    describe("acceptInvite", () => {
        const invite = { code: "ABCDEFGH", inviter_id: "i", uses: 0, max_uses: 50 };
        const accept = (uid, code = "abcd-efgh") => run(fns.acceptInvite, { data: { code }, auth: uid ? { uid } : undefined });

        test("public profiles follow each other and the use is counted", async () => {
            await seed({ "invites/ABCDEFGH": invite, "users/i": { first_name: "Ivy" }, "users/u": { first_name: "Uma" } });
            const result = await accept("u");
            assert.deepEqual(result, { inviter_id: "i", you_follow: "following", they_follow: "following" });
            assert.deepEqual((await read("users/u")).following_ids, ["i"]);
            assert.deepEqual((await read("users/i")).following_ids, ["u"]);
            assert.equal((await read("users/i/notifications/follow_u")).actor_name, "Uma");
            assert.equal((await read("users/u/notifications/follow_i")).actor_name, "Ivy");
            assert.equal((await read("invites/ABCDEFGH")).uses, 1);
        });

        test("a private inviter gets a follow request instead", async () => {
            await seed({ "invites/ABCDEFGH": invite, "users/i": { first_name: "Ivy", is_private: true }, "users/u": { first_name: "Uma" } });
            const result = await accept("u");
            assert.equal(result.you_follow, "requested");
            const request = await read("users/i/follow_requests/u");
            assert.equal(request.status, "pending");
            assert.equal(request.requester_name, "Uma");
            assert.equal((await read("users/u")).following_ids, undefined);
        });

        test("accepting again when nothing changes does not use it up", async () => {
            await seed({
                "invites/ABCDEFGH": { ...invite, uses: 7 },
                "users/i": { following_ids: ["u"] }, "users/u": { following_ids: ["i"] },
            });
            await accept("u");
            assert.equal((await read("invites/ABCDEFGH")).uses, 7);
        });

        test("refuses unknown codes, own invites, exhausted invites and signed-out callers", async () => {
            await seed({ "invites/ABCDEFGH": { ...invite, uses: 50 }, "users/i": {}, "users/u": {} });
            await assert.rejects(accept("u", "ZZZZZZZZ"), { code: "not-found" });
            await assert.rejects(accept("i"), { code: "failed-precondition" });
            await assert.rejects(accept("u"), { code: "resource-exhausted" });
            await assert.rejects(accept(null), { code: "unauthenticated" });
            await assert.rejects(accept("u", "nope"), { code: "invalid-argument" });
            assert.equal((await read("users/u")).following_ids, undefined);
        });
    });

    // Both scheduled functions read `new Date()` themselves, so the clock is pinned to a Sunday 18:00
    // UTC in the future (in the past, the Firestore client's absolute deadlines would expire at once).
    describe("scheduled pushes", () => {
        const sunday = new Date(Date.UTC(2031, 0, 5, 18, 0, 0)); // Sunday 5 January 2031, 18:00 UTC
        beforeEach(() => mock.timers.enable({ apis: ["Date"], now: sunday }));
        after(() => mock.timers.reset());

        test("streakReminder warns a user whose streak ends tonight, and no one else", async () => {
            const settings = { fcm_token: "tok", timezone: "Etc/UTC", reminder_hour: 18 };
            await seed({
                "users/a/private/settings": { ...settings, fcm_token: "tok-a" },
                "user_streaks/a/workout/current_streak": { current_streak: 4, date_last_event: new Date(sunday.getTime() - 20 * HOUR) },
                "users/b/private/settings": { ...settings, fcm_token: "tok-b" },
                "user_streaks/b/workout/current_streak": { current_streak: 4, date_last_event: new Date(sunday.getTime() - HOUR) },
                "users/c/private/settings": { ...settings, fcm_token: "tok-c", reminder_hour: 9 },
                "user_streaks/c/workout/current_streak": { current_streak: 4, date_last_event: new Date(sunday.getTime() - 20 * HOUR) },
            });
            await run(fns.streakReminder, {});
            mock.timers.reset();
            assert.deepEqual(sent.map((m) => m.token), ["tok-a"]);
            assert.equal(sent[0].notification.body, "Your 4-day streak ends at midnight");
        });

        test("weeklyDigest counts the user's and their circle's sessions over seven days", async () => {
            const day = 24 * HOUR;
            await seed({
                "users/u": { following_ids: ["f", "g"] },
                "users/u/private/settings": { fcm_token: "tok-u", timezone: "Etc/UTC" },
                "users/u/workout_sessions/s1": { date_created: new Date(sunday.getTime() - day) },
                "users/u/workout_sessions/old": { date_created: new Date(sunday.getTime() - 8 * day) },
                "users/f/workout_sessions/s1": { date_created: new Date(sunday.getTime() - 2 * day) },
                "users/f/workout_sessions/rest": { date_created: new Date(sunday.getTime() - 2 * day), is_rest_day: true },
                "users/g/workout_sessions/s1": { date_created: new Date(sunday.getTime() - 3 * day) },
                "users/lonely": {},
                "users/lonely/private/settings": { fcm_token: "tok-l", timezone: "Etc/UTC" },
            });
            await run(fns.weeklyDigest, {});
            mock.timers.reset();
            assert.deepEqual(sent.map((m) => m.token), ["tok-u"]);
            assert.equal(sent[0].notification.body, "This week: you trained 1 time, your circle 2");
        });
    });

    describe("sessionPage", () => {
        // An onRequest function is a plain (req, res) handler; this res records what it was sent.
        async function get(path) {
            const out = { status: 200, headers: {}, body: null };
            const res = {
                status(code) { out.status = code; return this; },
                set(key, value) { out.headers[key] = value; return this; },
                send(body) { out.body = body; return this; },
            };
            await fns.sessionPage({ method: "GET", path, headers: {} }, res);
            return out;
        }
        const start = new Date("2026-09-24T09:00:00Z");
        const session = (extra = {}) => ({
            author_id: "a", name: "Push Day", date_created: start, ended_at: new Date(start.getTime() + HOUR),
            exercises: [{ template_id: "bench", name: "Bench Press", tracking_mode: "weightReps",
                sets: [{ weight_kg: 100, reps: 5, isWarmup: false, completed_at: start }] }],
            ...extra,
        });

        test("renders a public session with its record against an earlier one", async () => {
            await seed({
                "users/a": { first_name: "Ann", is_private: false },
                "users/a/workout_sessions/s2": session(),
                "users/a/workout_sessions/s1": session({ date_created: new Date(start.getTime() - 24 * HOUR), ended_at: new Date(start.getTime() - 23 * HOUR),
                    exercises: [{ template_id: "bench", name: "Bench Press", tracking_mode: "weightReps", sets: [{ weight_kg: 90, reps: 5, isWarmup: false, completed_at: start }] }] }),
            });
            const out = await get("/s/a/s2");
            assert.equal(out.status, 200);
            assert.match(out.body, /Ann&#39;s Push Day on DialedIn/);
            assert.match(out.body, /<li>Bench Press 100 kg × 5<\/li>/);
            assert.match(out.headers["Cache-Control"], /max-age/);
        });

        test("answers the same 404 for a private author, a hidden session and a missing one", async () => {
            await seed({
                "users/p": { first_name: "Pat", is_private: true },
                "users/p/workout_sessions/s1": session({ author_id: "p" }),
                "users/a": { first_name: "Ann" },
                "users/a/workout_sessions/h": session({ hidden: true }),
            });
            const bodies = [];
            for (const path of ["/s/p/s1", "/s/a/h", "/s/a/missing", "/s/a"]) {
                const out = await get(path);
                assert.equal(out.status, 404, path);
                bodies.push(out.body);
            }
            assert.equal(new Set(bodies).size, 1);
            assert.doesNotMatch(bodies[0], /Pat|Push Day/);
        });
    });
});
