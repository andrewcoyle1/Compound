import { HttpsError } from "firebase-functions/v2/https";

// Callers must be signed in, so AI spend and writes are attributable to a uid.
export function requireAuth(request) {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in required to call this function.");
    }
    return request.auth.uid;
}

// Strip markdown code fences Gemini sometimes wraps JSON in
export function cleanJson(text) {
    return text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}

export function normaliseName(name) {
    return name.trim().toLowerCase();
}

// The boolean in users/{uid}/private/settings that opts a recipient out of each social push.
// Absent means on, so profiles written before the setting existed keep getting pushes.
export const SOCIAL_PUSH_PREFERENCE_KEYS = {
    like: "social_push_likes",
    comment: "social_push_comments",
    follow: "social_push_follows",
    nudge: "social_push_nudges",
    mention: "social_push_mentions",
    followAccepted: "social_push_follows",
    follow_request: "social_push_follows",
    share: "social_push_shares",
    challenge_complete: "social_push_challenges",
};

// The token and preferences moved from the public user doc to users/{uid}/private/settings. Each
// field is read from the private doc, else the user doc, so a user whose app has not written the
// private doc yet still gets pushes and keeps their opt-outs.
// ponytail: the user-doc fallback can go once every active install writes the private doc.
export function pushRecipientSettings(privateSettings, userDoc) {
    const keys = ["fcm_token", ...Object.values(SOCIAL_PUSH_PREFERENCE_KEYS)];
    return Object.fromEntries(keys.map((key) => [key, privateSettings?.[key] ?? userDoc?.[key]]));
}

const COMMENT_PREVIEW_LENGTH = 60;

function commentPreview(notification) {
    const text = (notification.comment_text || "").trim();
    return text.length > COMMENT_PREVIEW_LENGTH
        ? `${text.slice(0, COMMENT_PREVIEW_LENGTH - 1)}…`
        : text;
}

// Builds the push for a users/{uid}/notifications doc, or null when it should not be sent:
// no token, an unknown type, or the recipient turned that type off. `data.tab` is what
// DeepLink(pushUserInfo:) reads, so a tap lands on the Dashboard where the bell lives; with
// `session_id` and `session_author_id` as well, the Dashboard then opens that session.
export function buildActivityPush(notification, recipient) {
    const token = recipient?.fcm_token;
    const preferenceKey = SOCIAL_PUSH_PREFERENCE_KEYS[notification?.type];
    if (!token || !preferenceKey || recipient[preferenceKey] === false) return null;

    const actor = notification.actor_name || "Someone";
    let title;
    let body;
    switch (notification.type) {
    case "like":
        title = "New like";
        body = `${actor} liked your workout`;
        break;
    case "comment":
        // is_reply: the comment answers the recipient's own comment, not their workout.
        title = notification.is_reply === true ? "New reply" : "New comment";
        body = notification.is_reply === true
            ? `${actor} replied to your comment: ${commentPreview(notification)}`
            : `${actor} commented: ${commentPreview(notification)}`;
        break;
    case "mention":
        title = "Mention";
        body = `${actor} mentioned you: ${commentPreview(notification)}`;
        break;
    case "follow":
        title = "New follower";
        body = `${actor} started following you`;
        break;
    case "nudge":
        title = "Nudge";
        body = `${actor} nudged you to train`;
        break;
    case "followAccepted":
        title = "Request accepted";
        body = followAcceptedMessage(actor);
        break;    case "follow_request":
        title = "Follow request";
        body = `${actor} wants to follow you`;
        break;
    case "share":
        title = "Shared with you";
        body = `${actor} shared a workout with you`;
        break;
    case "challenge_complete":
        title = "Challenge complete";
        body = challengeCompleteMessage(notification.comment_text);
        break;
    }

    return {
        token,
        notification: { title, body },
        apns: { payload: { aps: { badge: 1, sound: "default" } } },
        data: {
            tab: "dashboard",
            type: notification.type,
            session_id: notification.session_id || "",
            session_author_id: notification.session_author_id || "",
            actor_id: notification.actor_id || "",
        },
    };
}

// The ids in `after.blocked_user_ids` that were not in `before.blocked_user_ids`, for the trigger
// that makes a block also end the blocked person's follow. Either side may lack the field.
export function newlyBlockedIds(before, after) {
    const previous = new Set(before?.blocked_user_ids ?? []);
    return [...new Set(after?.blocked_user_ids ?? [])].filter((id) => !previous.has(id));
}

// ---------------------------------------------------------------------------
// Follow requests: users/{targetId}/follow_requests/{requesterId}
// ---------------------------------------------------------------------------

export function followAcceptedMessage(name) {
    return `${name || "Someone"} accepted your follow request`;
}

// The name the app shows for a user doc, mirroring UserModel.fullNameCalculated: the submitted
// name where there is one, else the one from auth.
export function userDisplayName(user) {
    const first = user?.submitted_first_name ?? user?.first_name;
    const last = user?.submitted_last_name ?? user?.last_name;
    return [first, last].filter(Boolean).join(" ") || "Someone";
}

// Decides whether an update to a follow request is an acceptance to act on. Returns null unless the
// status has just become "accepted" on a request whose requester_id matches its document id (the id
// the rules pin to the requester's uid); otherwise the ids the trigger needs.
export function planFollowAccepted(before, after, params) {
    if (!after || after.status !== "accepted" || before?.status === "accepted") return null;
    const { targetId, requesterId } = params ?? {};
    if (!targetId || !requesterId || after.requester_id !== requesterId || targetId === requesterId) return null;
    return { requesterId, targetId, notificationId: `follow_accepted_${targetId}` };
}

// The users/{requesterId}/notifications doc telling the requester they were accepted, in the shape
// the app's FirebaseActivityNotificationService parses. The accepting user is the actor.
export function buildFollowAcceptedNotification(target, { targetId, requesterId }, now = new Date()) {
    const notification = {
        type: "followAccepted",
        actor_id: targetId,
        actor_name: userDisplayName(target),
        session_id: "",
        session_author_id: requesterId,
        date_created: now,
        is_read: false,
    };
    const image = target?.submitted_profile_image ?? target?.photo_url;
    if (image) notification.actor_image_url = image;
    return notification;
}

// ---------------------------------------------------------------------------
// Follow requests, live: push, removal and auto-accept
// ---------------------------------------------------------------------------

// The push for a new users/{targetId}/follow_requests/{requesterId} doc, in buildActivityPush's
// shape with type "follow_request", which the app routes to its notifications screen. Null for a
// request that is not pending, one from someone the target blocked, or when buildActivityPush would
// send nothing (no token, follows opted out).
export function buildFollowRequestPush(request, recipient, target) {
    if (request?.status !== "pending" || !request.requester_id) return null;
    if ((target?.blocked_user_ids ?? []).includes(request.requester_id)) return null;
    return buildActivityPush(
        { type: "follow_request", actor_name: request.requester_name, actor_id: request.requester_id },
        recipient
    );
}

// The ids that `after.following_ids` dropped since `before`: an unfollow, a block, or a follower
// removed by the person they followed. Any pending request between the pair is then deleted.
export function removedFollowingIds(before, after) {
    const current = new Set(after?.following_ids ?? []);
    return [...new Set(before?.following_ids ?? [])].filter((id) => !current.has(id));
}

// The requester ids to accept when a profile goes from private to public, or null for any other
// update, so the trigger can return before reading any requests. `requests` are the pending docs as { id, data }; one whose requester_id disagrees with
// its document id is skipped, as planFollowAccepted would refuse it anyway.
export function planAutoAccept(before, after, requests) {
    if (before?.is_private !== true || after?.is_private !== false) return null;
    return (requests ?? [])
        .filter(({ id, data }) => data?.status === "pending" && data.requester_id === id)
        .map(({ id }) => id);
}

// Validates removeFollower's input against the caller: a non-empty id that is not the caller.
export function removeFollowerTarget(data, uid) {
    const followerId = data?.followerId;
    if (typeof followerId !== "string" || followerId.trim() === "" || followerId === uid) return null;
    return followerId;
}

// ---------------------------------------------------------------------------
// Usernames: usernames/{handle} reservations
// ---------------------------------------------------------------------------

// The handle to release after a write to users/{uid}: the old username when it changed or the
// document was deleted, else null. `after` is undefined for a delete.
export function planUsernameRelease(before, after) {
    const previous = before?.username;
    if (typeof previous !== "string" || previous === "") return null;
    return previous === after?.username ? null : previous;
}

// A reservation is released only while it still names the user who moved off it, so a handle that
// someone else has since reserved is never taken from them.
export function shouldReleaseReservation(reservation, uid) {
    return Boolean(uid) && reservation?.user_id === uid;
}

// Scheduled pushes: streak reminder, Sunday digest, and the nudge cooldown
// ---------------------------------------------------------------------------

// Opt-outs for the scheduled pushes, in users/{uid}/private/settings. Absent means on.
export const SCHEDULED_PUSH_PREFERENCE_KEYS = {
    streakReminder: "social_push_streak_reminder",
    weeklyDigest: "social_push_weekly_digest",
};

// The local hour the streak reminder goes out when the user has not picked one. Must match
// PrivateUserSettings.defaultReminderHour in the app.
export const DEFAULT_REMINDER_HOUR = 19;
export const DIGEST_WEEKDAY = 0; // Sunday
export const DIGEST_HOUR = 18;
const DAY_MS = 24 * 60 * 60 * 1000;
const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

// A Firestore Timestamp, a Date, or nothing, as a Date or null.
export function toDate(value) {
    if (value instanceof Date) return value;
    return typeof value?.toDate === "function" ? value.toDate() : null;
}

// The wall-clock date ("YYYY-MM-DD"), hour (0-23) and weekday (0 = Sunday) of `date` in an IANA
// time zone, or null when the zone is missing or unknown. Intl carries the DST rules, so the hour
// is the one on the user's clock whichever side of a change they are on.
export function localTime(date, timeZone) {
    if (!timeZone || !date) return null;
    let parts;
    try {
        parts = new Intl.DateTimeFormat("en-US", {
            timeZone, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", weekday: "short",
        }).formatToParts(date);
    } catch {
        return null;
    }
    const part = (type) => parts.find((p) => p.type === type).value;
    return {
        date: `${part("year")}-${part("month")}-${part("day")}`,
        hour: Number(part("hour")),
        weekday: WEEKDAYS.indexOf(part("weekday")),
    };
}

function previousDay(isoDate) {
    const [y, m, d] = isoDate.split("-").map(Number);
    return new Date(Date.UTC(y, m - 1, d - 1)).toISOString().slice(0, 10);
}

function scheduledPushBase(settings, preferenceKey, now) {
    if (!settings?.fcm_token || settings[preferenceKey] === false) return null;
    return localTime(now, settings.timezone);
}

// Whether it is this user's reminder hour on their clock and they want the reminder. The
// scheduled function checks this before reading the user's streak.
export function isStreakReminderDue(settings, now) {
    const local = scheduledPushBase(settings, SCHEDULED_PUSH_PREFERENCE_KEYS.streakReminder, now);
    return !!local && local.hour === (settings.reminder_hour ?? DEFAULT_REMINDER_HOUR);
}

// The "streak ends at midnight" push for one user, or null. `streak` is the StreakManager doc at
// user_streaks/{uid}/workout/current_streak. Sent in the user's reminder hour when the streak's
// last workout was yesterday on their clock: today means they have trained, earlier means the
// streak has already gone.
// ponytail: ignores the app's 2 leeway hours, so a workout just after midnight counts as today here.
export function buildStreakReminderPush(settings, streak, now) {
    if (!isStreakReminderDue(settings, now)) return null;
    const local = localTime(now, settings.timezone);
    const days = streak?.current_streak ?? 0;
    const lastEvent = localTime(toDate(streak?.date_last_event), settings.timezone);
    if (days <= 0 || !lastEvent || lastEvent.date !== previousDay(local.date)) return null;

    return {
        token: settings.fcm_token,
        notification: { title: "Streak at risk", body: `Your ${days}-day streak ends at midnight` },
        apns: { payload: { aps: { sound: "default" } } },
        data: { tab: "training", type: "streakReminder" },
    };
}

// Whether it is 18:00 on Sunday on this user's clock and they want the digest. The scheduled
// function checks this before reading anything else about the user.
export function isWeeklyDigestDue(settings, now) {
    const local = scheduledPushBase(settings, SCHEDULED_PUSH_PREFERENCE_KEYS.weeklyDigest, now);
    return !!local && local.weekday === DIGEST_WEEKDAY && local.hour === DIGEST_HOUR;
}

// The start of the digest's week: the seven days up to now.
export function digestWindowStart(now) {
    return new Date(now.getTime() - 7 * DAY_MS);
}

// Sessions that count as training: not deleted and not a logged rest day.
export function countTrainingSessions(sessions) {
    return (sessions ?? []).filter((s) => !s.deleted_at && !s.is_rest_day).length;
}

// The Sunday digest, or null when there is no token or the user follows nobody.
export function buildWeeklyDigestPush(settings, { mine, circle, followingCount }) {
    if (!settings?.fcm_token || !followingCount) return null;
    return {
        token: settings.fcm_token,
        notification: {
            title: "Your week",
            body: `This week: you trained ${mine} ${mine === 1 ? "time" : "times"}, your circle ${circle}`,
        },
        apns: { payload: { aps: { sound: "default" } } },
        data: { tab: "dashboard", type: "weeklyDigest" },
    };
}

// True when `previous` (the last nudge from the same actor to the same recipient) was under 24
// hours before `now`. The app writes one nudge doc per actor per day, so this is what stops a
// nudge at 23:59 and another at 00:01 both pushing.
export function isNudgeOnCooldown(previous, now) {
    const last = toDate(previous);
    if (!last) return false;
    const elapsed = toDate(now).getTime() - last.getTime();
    return elapsed < DAY_MS;
}

// Account deletion: everything a deleted users/{uid} leaves behind
// ---------------------------------------------------------------------------

export const USER_DELETION_BATCH_SIZE = 400;

// Turns what onUserDeleted read into the writes that remove the user from everyone else's data.
// Each list holds document paths (the ids for recipeTemplates, foods and exercises, which are also
// Storage names): followers and blockers have uid removed from following_ids / blocked_user_ids;
// sent follow requests, likes, comments, notifications, username reservations and exercises go.
// Paths under users/{uid} are dropped, as the recursive delete has already taken them, and an update
// to a missing document would fail its whole batch. Writes come back in batches of 400.
export function planUserDeletion(uid, lists = {}) {
    const own = `users/${uid}`;
    const isOwn = (path) => path === own || path.startsWith(`${own}/`);
    const writes = [];
    const deleted = new Set();
    const remove = (path) => {
        if (isOwn(path) || deleted.has(path)) return;
        deleted.add(path);
        writes.push({ type: "delete", path });
    };
    const pull = (paths, field) => {
        for (const path of new Set(paths ?? [])) {
            if (!isOwn(path)) writes.push({ type: "arrayRemove", path, field, value: uid });
        }
    };

    pull(lists.followers, "following_ids");
    pull(lists.blockers, "blocked_user_ids");
    pull(lists.likedSessions, "liked_by_user_ids");
    for (const path of lists.followRequests ?? []) remove(path);
    for (const path of lists.comments ?? []) remove(path);
    for (const path of lists.notifications ?? []) remove(path);
    for (const path of lists.usernames ?? []) remove(path);
    for (const id of lists.exercises ?? []) remove(`exercise_templates/${id}`);
    remove(`diet_plans/${uid}`);

    const batches = [];
    for (let start = 0; start < writes.length; start += USER_DELETION_BATCH_SIZE) {
        batches.push(writes.slice(start, start + USER_DELETION_BATCH_SIZE));
    }
    // The upload paths the app uses: everything under users/{uid}/ (profile, workout templates, gym
    // profiles), and one file per exercise, recipe template and food, named by its id.
    const storageFiles = [
        ...(lists.exercises ?? []).map((id) => `exercises/${id}`),
        ...(lists.recipeTemplates ?? []).map((id) => `recipe_templates/${id}`),
        ...(lists.foods ?? []).map((id) => `ingredient_templates/${id}`),
    ];
    return { batches, storagePrefixes: [`${own}/`], storageFiles };
}

// Report moderation: hide a session or comment once three people have reported it
// ---------------------------------------------------------------------------

export const REPORT_HIDE_THRESHOLD = 3;

// Decides what onReportCreated writes for a new report, given every report on the same target_id
// (the new one included). Only open reports that agree on target type and author count, and each
// reporter counts once, so one person reporting three times hides nothing. Below the threshold it
// returns null. At it: the document to set hidden on (a session lives under its author, a comment
// is top level, a profile is never hidden) and the moderation_queue/{targetId} document.
export function planReportModeration(report, reports, threshold = REPORT_HIDE_THRESHOLD) {
    if (!report?.target_id || !report.target_type) return null;
    const matching = (reports ?? []).filter((other) =>
        other.status === "open"
        && other.target_id === report.target_id
        && other.target_type === report.target_type
        && (other.target_author_id ?? null) === (report.target_author_id ?? null)
    );
    const reporterIds = [...new Set(matching.map((other) => other.reporter_id).filter(Boolean))].sort();
    if (reporterIds.length < threshold) return null;

    let hidePath = null;
    if (report.target_type === "comment") hidePath = `workout_session_comments/${report.target_id}`;
    if (report.target_type === "session" && report.target_author_id) {
        hidePath = `users/${report.target_author_id}/workout_sessions/${report.target_id}`;
    }
    return {
        hidePath,
        queueId: report.target_id,
        queue: {
            target_id: report.target_id,
            target_type: report.target_type,
            target_author_id: report.target_author_id ?? null,
            reporter_ids: reporterIds,
            report_ids: matching.map((other) => other.id).filter(Boolean).sort(),
            reasons: [...new Set(matching.map((other) => other.reason).filter(Boolean))].sort(),
            hidden: hidePath !== null,
        },
    };
}

// ---------------------------------------------------------------------------
// Challenges: challenges/{id} and challenges/{id}/progress/{uid}
// ---------------------------------------------------------------------------

export function challengeCompleteMessage(title) {
    return `You finished ${title || "a challenge"}`;
}

// Whether a write to users/{uid}/workout_sessions/{id} is the session being finished: ended_at goes
// from unset to set, on a session that is neither a rest day nor deleted. `before` is undefined for
// a session created already finished, which counts too.
export function sessionJustEnded(before, after) {
    if (!after || !after.ended_at || before?.ended_at) return false;
    return !after.is_rest_day && !after.deleted_at;
}

// The challenges a finished session counts towards: those `uid` is a member of that are running at
// `endedAt` (starts_at <= endedAt < ends_at). `challenges` are docs as { id, ...data }.
export function activeChallengesFor(challenges, uid, endedAt) {
    const at = toDate(endedAt);
    if (!uid || !at) return [];
    return (challenges ?? []).filter((challenge) => {
        const start = toDate(challenge.starts_at);
        const end = toDate(challenge.ends_at);
        return (challenge.member_ids ?? []).includes(uid) && start && end && start <= at && at < end;
    });
}

// One member's progress write for one finished session, or null when that session was already
// counted (a trigger retry). `progress` is the current progress doc or undefined. When this session
// takes the member to the target, `notification` is the challenge_complete doc for
// users/{uid}/notifications/{notificationId}, in the shape FirebaseActivityNotificationService parses.
export function planChallengeProgress(challenge, uid, sessionId, progress, user, now = new Date()) {
    const counted = progress?.session_ids ?? [];
    if (counted.includes(sessionId)) return null;
    const previous = progress?.sessions ?? 0;
    const sessions = previous + 1;
    const target = challenge.target_sessions ?? 0;
    const plan = {
        progress: { sessions, updated_at: now, session_ids: [...counted, sessionId] },
        notificationId: null,
        notification: null,
    };
    if (target > 0 && previous < target && sessions >= target) {
        plan.notificationId = `challenge_complete_${challenge.id}`;
        plan.notification = {
            type: "challenge_complete",
            actor_id: uid,
            actor_name: userDisplayName(user),
            session_id: "",
            session_author_id: uid,
            comment_text: challenge.title ?? "",
            challenge_id: challenge.id,
            date_created: now,
            is_read: false,
        };
    }
    return plan;
}

// ---------------------------------------------------------------------------
// Invites: invites/{code} { code, inviter_id, date_created, uses, max_uses }
// ---------------------------------------------------------------------------

// Mirrors InviteCode in the app and the invites rule: 8 characters, no 0/O or 1/I/L.
export const INVITE_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const INVITE_CODE_LENGTH = 8;
export const INVITE_MAX_USES = 50;

// The code acceptInvite was sent, uppercased with spaces and dashes dropped, or null if it is not
// a code at all.
export function normaliseInviteCode(raw) {
    if (typeof raw !== "string") return null;
    const code = raw.toUpperCase().replace(/[\s-]/g, "");
    if (code.length !== INVITE_CODE_LENGTH) return null;
    return [...code].every((c) => INVITE_CODE_ALPHABET.includes(c)) ? code : null;
}

// Decides what accepting an invite does, from the docs acceptInvite read in its transaction.
// Returns { error: [httpsErrorCode, message] } to refuse, else each direction of the follow as
// "already" (nothing to write), "follow" (arrayUnion into following_ids) or "request" (a pending
// follow request, because the person to be followed is private), plus whether this counts as a use
// of the invite. A repeat acceptance that changes nothing does not use one up.
export function planInviteAcceptance({ callerId, invite, inviter, invitee }) {
    if (!invite) return { error: ["not-found", "That invite code doesn't exist."] };
    const inviterId = invite.inviter_id;
    if (!inviter) return { error: ["not-found", "That invite code doesn't exist."] };
    if (inviterId === callerId) return { error: ["failed-precondition", "That's your own invite."] };
    if ((inviter.blocked_user_ids ?? []).includes(callerId) || (invitee?.blocked_user_ids ?? []).includes(inviterId)) {
        return { error: ["permission-denied", "That invite isn't available."] };
    }

    const direction = (follower, followedId, followed) => {
        if ((follower?.following_ids ?? []).includes(followedId)) return "already";
        return followed?.is_private === true ? "request" : "follow";
    };
    const inviteeFollows = direction(invitee, inviterId, inviter);
    const inviterFollows = direction(inviter, callerId, invitee);
    const countsUse = inviteeFollows !== "already" || inviterFollows !== "already";
    if (countsUse && (invite.uses ?? 0) >= (invite.max_uses ?? INVITE_MAX_USES)) {
        return { error: ["resource-exhausted", "That invite has been used too many times."] };
    }
    return { inviterId, inviteeFollows, inviterFollows, countsUse };
}

// A direction of the plan as the app reads it: a request is "requested", anything else "following".
export function inviteOutcome(direction) {
    return direction === "request" ? "requested" : "following";
}

// users/{followedId}/notifications/follow_{followerId}, the doc the app writes itself on a follow,
// so acceptInvite's follows reach the bell and push the same way.
export function buildFollowNotification(follower, { followerId, followedId }, now = new Date()) {
    const notification = {
        type: "follow",
        actor_id: followerId,
        actor_name: userDisplayName(follower),
        session_id: "",
        session_author_id: followedId,
        date_created: now,
        is_read: false,
    };
    const image = follower?.submitted_profile_image ?? follower?.photo_url;
    if (image) notification.actor_image_url = image;
    return notification;
}

// users/{targetId}/follow_requests/{requesterId}, in FollowRequestModel's shape.
export function buildInviteFollowRequest(requester, requesterId, now = new Date()) {
    return {
        requester_id: requesterId,
        requester_name: userDisplayName(requester),
        requester_image_url: requester?.submitted_profile_image ?? requester?.photo_url ?? null,
        date_created: now,
        status: "pending",
    };
}

// MARK: - Web share page
// /s/{authorId}/{sessionId} on Hosting renders one finished session as a static page. Everything
// the page prints goes through escapeHtml; the only person on it is the author, by first name and
// avatar, as on the in-app share card.

export const APP_STORE_URL = "https://apps.apple.com/app/dialedin"; // placeholder until the listing is live

const ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export function escapeHtml(value) {
    return String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

// "/s/{authorId}/{sessionId}" as ids, or null for any other path.
export function parseSessionPath(path) {
    const parts = String(path ?? "").split("/").filter(Boolean);
    if (parts.length !== 3 || parts[0] !== "s" || !ID_PATTERN.test(parts[1]) || !ID_PATTERN.test(parts[2])) return null;
    return { authorId: parts[1], sessionId: parts[2] };
}

// Whether the page may show `session` at all: a public author, and a finished session that is
// neither deleted nor hidden by moderation.
export function isSessionShareable(session, author) {
    return Boolean(session && author && author.is_private !== true && session.hidden !== true
        && !session.deleted_at && session.ended_at);
}

const workingSets = (exercise) => (exercise?.sets ?? []).filter((set) => !set.isWarmup);
const counts = (session) => session.ended_at && !session.is_rest_day && !session.deleted_at;

// The best completed working set of one exercise across `sessions` as [value, reps], or null.
// Mirrors WorkoutSessionHighlights.best: weight then reps for weighted lifts, the largest reps,
// time or distance otherwise.
function bestMark(templateId, mode, sessions) {
    const sets = sessions.filter((s) => s.ended_at).flatMap((s) => s.exercises ?? [])
        .filter((e) => e.template_id === templateId).flatMap(workingSets).filter((set) => set.completed_at);
    if (mode === "weightReps") {
        let best = null;
        for (const set of sets) {
            const mark = [set.weight_kg ?? 0, set.reps ?? 0];
            if (!best || mark[0] > best[0] || (mark[0] === best[0] && mark[1] > best[1])) best = mark;
        }
        return best && best[0] > 0 ? best : null;
    }
    const field = { repsOnly: "reps", timeOnly: "duration_sec", distanceTime: "distance_meters" }[mode];
    const values = sets.map((set) => set[field]).filter((v) => typeof v === "number");
    const top = values.length ? Math.max(...values) : 0;
    return top > 0 ? [top, 0] : null;
}

function describeMark([value, reps], mode) {
    const oneDp = (n) => String(Math.round(n * 10) / 10);
    switch (mode) {
        case "weightReps": return `${oneDp(value)} kg × ${reps}`;
        case "repsOnly": return `${Math.trunc(value)} reps`;
        case "timeOnly": return `${Math.floor(value / 60)}:${String(Math.trunc(value % 60)).padStart(2, "0")}`;
        default: return value >= 1000 ? `${oneDp(value / 1000)} km` : `${Math.trunc(value)} m`;
    }
}

// "Bench Press 100 kg × 5" for each exercise that beat every earlier finished session, at most
// `limit`. A first-ever lift is not a record. The JS twin of WorkoutSessionHighlights.personalRecords.
export function personalRecordLines(session, priorSessions, limit = 3) {
    const start = toDate(session.date_created);
    const earlier = priorSessions.filter((s) => counts(s) && s.id !== session.id && toDate(s.date_created) < start);
    const seen = new Set();
    const lines = [];
    for (const exercise of session.exercises ?? []) {
        if (seen.has(exercise.template_id) || lines.length >= limit) continue;
        seen.add(exercise.template_id);
        const now = bestMark(exercise.template_id, exercise.tracking_mode, [session]);
        const before = bestMark(exercise.template_id, exercise.tracking_mode, earlier);
        if (now && before && (now[0] > before[0] || (now[0] === before[0] && now[1] > before[1]))) {
            lines.push(`${exercise.name} ${describeMark(now, exercise.tracking_mode)}`);
        }
    }
    return lines;
}

// Everything the page prints, as plain strings, before escaping.
export function sessionPageContent(session, author, priorSessions = []) {
    const start = toDate(session.date_created);
    const end = toDate(session.ended_at);
    const seconds = start && end ? Math.max(0, Math.floor((end - start) / 1000)) : null;
    const hours = Math.floor((seconds ?? 0) / 3600);
    const minutes = Math.floor(((seconds ?? 0) % 3600) / 60);
    const volume = (session.exercises ?? []).flatMap(workingSets).reduce((sum, set) => sum + (set.weight_kg ?? 0) * (set.reps ?? 0), 0);
    const avatar = author.submitted_profile_image ?? author.photo_url;
    return {
        firstName: author.submitted_first_name || author.first_name || null,
        // Only https images: the URL lands in src and og:image.
        avatarURL: typeof avatar === "string" && avatar.startsWith("https://") ? avatar : null,
        sessionName: session.name || "Workout",
        // ponytail: UTC date; the author's zone is in private settings, read it if midnight sessions land on the wrong day.
        dateText: start ? start.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", timeZone: "UTC" }) : null,
        durationText: seconds === null ? null : hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`,
        volumeText: volume > 0 ? `${Math.round(volume).toLocaleString("en-US")} kg` : null,
        personalRecordLines: personalRecordLines(session, priorSessions),
        streakText: session.streak_count > 1 ? `${session.streak_count}-day streak` : null,
    };
}

const PAGE_STYLE = `body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#f2f2f7;color:#1c1c1e}
main{max-width:480px;margin:0 auto;padding:32px 16px}.card{background:#fff;border-radius:20px;padding:24px}
.author{display:flex;align-items:center;gap:12px}.author img{width:48px;height:48px;border-radius:50%;object-fit:cover}
h1{font-size:28px;margin:16px 0 4px}.date{color:#6e6e73;margin:0}.stats{display:flex;gap:24px;margin:20px 0}
.stats b{display:block;font-size:22px}.prs{padding-left:20px}.badge{display:inline-block;margin-top:24px;padding:12px 20px;border-radius:10px;background:#000;color:#fff;text-decoration:none}
@media (prefers-color-scheme:dark){body{background:#000;color:#f2f2f7}.card{background:#1c1c1e}.date{color:#98989d}.badge{background:#fff;color:#000}}`;

function page({ title, description, url, image, body }) {
    const meta = [
        ["og:title", title], ["og:description", description], ["og:type", "website"], ["og:site_name", "DialedIn"],
        ...(url ? [["og:url", url]] : []), ...(image ? [["og:image", image]] : []),
    ].map(([p, c]) => `<meta property="${p}" content="${escapeHtml(c)}">`).join("\n");
    return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(title)}</title><meta name="description" content="${escapeHtml(description)}">
${meta}
<meta name="twitter:card" content="summary">
<style>${PAGE_STYLE}</style></head>
<body><main>${body}
<a class="badge" href="${escapeHtml(APP_STORE_URL)}">Download on the App Store</a></main></body></html>`;
}

// The page for a shareable session, or null when the author is private or the session hidden,
// deleted or unfinished — the caller answers 404 with notFoundPageHtml().
export function buildSessionPageHtml({ session, author, priorSessions = [], url = null }) {
    if (!isSessionShareable(session, author)) return null;
    const c = sessionPageContent(session, author, priorSessions);
    const who = c.firstName ?? "Someone";
    const stats = [["Duration", c.durationText], ["Volume", c.volumeText]].filter(([, v]) => v);
    const description = [c.dateText, c.durationText, c.volumeText, c.personalRecordLines.length ? `${c.personalRecordLines.length} PR${c.personalRecordLines.length > 1 ? "s" : ""}` : null, c.streakText]
        .filter(Boolean).join(" · ");
    const body = `<article class="card">
<div class="author">${c.avatarURL ? `<img src="${escapeHtml(c.avatarURL)}" alt="">` : ""}<strong>${escapeHtml(who)}</strong></div>
<h1>${escapeHtml(c.sessionName)}</h1>
${c.dateText ? `<p class="date">${escapeHtml(c.dateText)}</p>` : ""}
${stats.length ? `<div class="stats">${stats.map(([k, v]) => `<div><b>${escapeHtml(v)}</b>${k}</div>`).join("")}</div>` : ""}
${c.personalRecordLines.length ? `<h2>Personal records</h2><ul class="prs">${c.personalRecordLines.map((l) => `<li>${escapeHtml(l)}</li>`).join("")}</ul>` : ""}
${c.streakText ? `<p>🔥 ${escapeHtml(c.streakText)}</p>` : ""}
</article>`;
    return page({ title: `${who}'s ${c.sessionName} on DialedIn`, description, url, image: c.avatarURL, body });
}

// Every refusal looks the same, so the page does not reveal whether a session exists.
export function notFoundPageHtml() {
    return page({ title: "Workout not found · DialedIn", description: "This workout isn't available.", body: `<article class="card"><h1>Workout not found</h1><p>This workout is private or no longer available.</p></article>` });
}
