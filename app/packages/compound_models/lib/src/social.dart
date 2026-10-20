/// The documents people write to each other: follow requests,
/// notifications, comments, reports and username reservations.
///
/// Notifications, comments, reports and reservations are dictionaries in
/// the Swift app, built and parsed by hand rather than by `Codable`, so
/// these read the way those parsers do.
library;

import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';

/// Where a follow request stands (Swift `FollowRequestModel.Status`).
enum FollowRequestStatus implements FirestoreEnum {
  /// `pending`: waiting on the target.
  pending('pending'),

  /// `accepted`: the `onFollowRequestUpdated` function writes the follow.
  accepted('accepted'),

  /// `declined`: left for the requester to see.
  declined('declined');

  new(this.value);

  @override
  final String value;
}

/// What a notification is about (Swift
/// `ActivityNotificationModel.ActivityType`).
enum ActivityType implements FirestoreEnum {
  /// `like`.
  like('like'),

  /// `comment`; a reply when `is_reply` is set.
  comment('comment'),

  /// `follow`: no session behind it.
  follow('follow'),

  /// `nudge`: someone asked the user to train today.
  nudge('nudge'),

  /// `mention`.
  mention('mention'),

  /// `followAccepted`, written by the `onFollowRequestUpdated` function.
  followAccepted('followAccepted'),

  /// `share`: `share_id` names the share.
  share('share'),

  /// `challenge_complete`, written by the
  /// `onWorkoutSessionEndedForChallenges` function.
  challengeComplete('challenge_complete');

  new(this.value);

  @override
  final String value;
}

/// What a report is about (Swift `ReportContentType`).
enum ReportContentType implements FirestoreEnum {
  /// `comment`.
  comment('comment'),

  /// `session`.
  session('session'),

  /// `user`.
  user('user');

  new(this.value);

  @override
  final String value;
}

/// Why something was reported (Swift `ReportReason`).
enum ReportReason implements FirestoreEnum {
  /// `spam`.
  spam('spam'),

  /// `harassment`.
  harassment('harassment'),

  /// `inappropriate`.
  inappropriate('inappropriate'),

  /// `other`.
  other('other');

  new(this.value);

  @override
  final String value;
}

/// Field names of a [FollowRequestModel], exactly as the Swift `CodingKeys`
/// spell them.
abstract final class FollowRequestModelKeys {
  /// `requester_id`.
  static const requesterId = 'requester_id';

  /// `requester_name`.
  static const requesterName = 'requester_name';

  /// `requester_image_url`.
  static const requesterImageUrl = 'requester_image_url';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `status`.
  static const status = 'status';

  /// Every field, in declaration order.
  static const List<String> all = [
    requesterId,
    requesterName,
    requesterImageUrl,
    dateCreated,
    status,
  ];
}

/// A request to follow a private profile, at
/// `users/{target}/follow_requests/{requester_id}` (Swift
/// `FollowRequestModel`). The target answers by writing `status` alone.
class const FollowRequestModel({
  /// Who asked; also the document id.
  required final String requesterId,

  /// Their name when they asked.
  required final String requesterName,

  /// When they asked.
  required final DateTime dateCreated,

  /// Where it stands.
  final FollowRequestStatus status = FollowRequestStatus.pending,

  /// Their picture when they asked.
  final String? requesterImageUrl,
}) {
  /// Creates a [FollowRequestModel].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does; a null image
  /// (which `acceptInvite` writes) reads as absent.
  factory fromFirestore(Map<String, Object?> data) => FollowRequestModel(
    requesterId: data[FollowRequestModelKeys.requesterId]! as String,
    requesterName: data[FollowRequestModelKeys.requesterName]! as String,
    requesterImageUrl:
        data[FollowRequestModelKeys.requesterImageUrl] as String?,
    dateCreated: data[FollowRequestModelKeys.dateCreated]! as DateTime,
    status: enumFromValue(
      FollowRequestStatus.values,
      data[FollowRequestModelKeys.status]! as String,
    ),
  );

  /// The Firestore-shaped map Swift writes, a null image left out.
  Map<String, Object?> toFirestore() => {
    FollowRequestModelKeys.requesterId: requesterId,
    FollowRequestModelKeys.requesterName: requesterName,
    FollowRequestModelKeys.requesterImageUrl: ?requesterImageUrl,
    FollowRequestModelKeys.dateCreated: dateCreated,
    FollowRequestModelKeys.status: status.value,
  };
}

/// Field names of an [ActivityNotificationModel], exactly as
/// `FirebaseActivityNotificationService` spells them. The document id is
/// not a field.
abstract final class ActivityNotificationModelKeys {
  /// `type`.
  static const type = 'type';

  /// `actor_id`.
  static const actorId = 'actor_id';

  /// `actor_name`.
  static const actorName = 'actor_name';

  /// `actor_image_url`.
  static const actorImageUrl = 'actor_image_url';

  /// `session_id`.
  static const sessionId = 'session_id';

  /// `session_author_id`.
  static const sessionAuthorId = 'session_author_id';

  /// `comment_text`.
  static const commentText = 'comment_text';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `is_read`.
  static const isRead = 'is_read';

  /// `share_id`.
  static const shareId = 'share_id';

  /// `is_reply`.
  static const isReply = 'is_reply';

  /// `challenge_id`.
  static const challengeId = 'challenge_id';

  /// Every field, in declaration order.
  static const List<String> all = [
    type,
    actorId,
    actorName,
    actorImageUrl,
    sessionId,
    sessionAuthorId,
    commentText,
    dateCreated,
    isRead,
    shareId,
    isReply,
    challengeId,
  ];
}

/// An entry in a user's activity, at `users/{uid}/notifications/{id}`
/// (Swift `ActivityNotificationModel`). The actor writes it to the
/// recipient; `onActivityNotificationCreated` turns it into a push.
class const ActivityNotificationModel({
  /// The document id, which is not stored in the document.
  required final String id,

  /// What happened.
  required final ActivityType type,

  /// Who did it.
  required final String actorId,

  /// Their name.
  required final String actorName,

  /// The session it is about; empty when there is none.
  required final String sessionId,

  /// That session's author, or the user followed or nudged.
  required final String sessionAuthorId,

  /// When it happened.
  required final DateTime dateCreated,

  /// Whether the recipient has seen it.
  final bool isRead = false,

  /// Whether a comment answers the recipient's own comment.
  final bool isReply = false,

  /// The actor's picture.
  final String? actorImageUrl,

  /// The comment, or the shared item's or challenge's name.
  final String? commentText,

  /// The `shares/{id}` behind a share.
  final String? shareId,

  /// The `challenges/{id}` behind a completed challenge.
  final String? challengeId,
}) {
  /// Creates an [ActivityNotificationModel].
  this;

  /// Decodes as `FirebaseActivityNotificationService.parse` does: the type
  /// must be known and the strings and timestamp present; the rest read
  /// with `as?`, `is_read` and `is_reply` defaulting to false.
  factory fromFirestore(
    String id,
    Map<String, Object?> data,
  ) => ActivityNotificationModel(
    id: id,
    type: enumFromValue(
      ActivityType.values,
      data[ActivityNotificationModelKeys.type]! as String,
    ),
    actorId: data[ActivityNotificationModelKeys.actorId]! as String,
    actorName: data[ActivityNotificationModelKeys.actorName]! as String,
    actorImageUrl: lenientString(
      data[ActivityNotificationModelKeys.actorImageUrl],
    ),
    sessionId: data[ActivityNotificationModelKeys.sessionId]! as String,
    sessionAuthorId:
        data[ActivityNotificationModelKeys.sessionAuthorId]! as String,
    commentText: lenientString(data[ActivityNotificationModelKeys.commentText]),
    dateCreated: data[ActivityNotificationModelKeys.dateCreated]! as DateTime,
    isRead: lenientBool(data[ActivityNotificationModelKeys.isRead]) ?? false,
    shareId: lenientString(data[ActivityNotificationModelKeys.shareId]),
    isReply: lenientBool(data[ActivityNotificationModelKeys.isReply]) ?? false,
    challengeId: lenientString(data[ActivityNotificationModelKeys.challengeId]),
  );

  /// The map `addNotification` writes: absent optionals and a false
  /// `is_reply` are left out.
  Map<String, Object?> toFirestore() => {
    ActivityNotificationModelKeys.type: type.value,
    ActivityNotificationModelKeys.actorId: actorId,
    ActivityNotificationModelKeys.actorName: actorName,
    ActivityNotificationModelKeys.actorImageUrl: ?actorImageUrl,
    ActivityNotificationModelKeys.sessionId: sessionId,
    ActivityNotificationModelKeys.sessionAuthorId: sessionAuthorId,
    ActivityNotificationModelKeys.commentText: ?commentText,
    ActivityNotificationModelKeys.dateCreated: dateCreated,
    ActivityNotificationModelKeys.isRead: isRead,
    ActivityNotificationModelKeys.shareId: ?shareId,
    if (isReply) ActivityNotificationModelKeys.isReply: true,
    ActivityNotificationModelKeys.challengeId: ?challengeId,
  };
}

/// Field names of a [WorkoutSessionComment], exactly as
/// `FirebaseCommentsService` spells them.
abstract final class WorkoutSessionCommentKeys {
  /// `id`.
  static const id = 'id';

  /// `session_id`.
  static const sessionId = 'session_id';

  /// `session_author_id`.
  static const sessionAuthorId = 'session_author_id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `author_name`.
  static const authorName = 'author_name';

  /// `author_image_url`.
  static const authorImageUrl = 'author_image_url';

  /// `text`.
  static const text = 'text';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `deleted_at`.
  static const deletedAt = 'deleted_at';

  /// `parent_id`.
  static const parentId = 'parent_id';

  /// `mentioned_user_ids`.
  static const mentionedUserIds = 'mentioned_user_ids';

  /// `liked_by_user_ids`.
  static const likedByUserIds = 'liked_by_user_ids';

  /// `hidden`.
  static const hidden = 'hidden';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    sessionId,
    sessionAuthorId,
    authorId,
    authorName,
    authorImageUrl,
    text,
    dateCreated,
    deletedAt,
    parentId,
    mentionedUserIds,
    likedByUserIds,
    hidden,
  ];
}

/// A comment on a workout session, at `workout_session_comments/{id}`
/// (Swift `WorkoutSessionComment`).
///
/// Swift leaves out of a thread any document whose `deleted_at` is not nil,
/// a null included, so [deletedAt] is never written as null; it is set
/// alone, by the author, to delete. Likes change one id at a time
/// (`arrayUnion`/`arrayRemove` on `liked_by_user_ids`), and `hidden` is
/// written only by the `onReportCreated` function.
class const WorkoutSessionComment({
  /// The comment's id; also the document id.
  required final String id,

  /// The session it is on.
  required final String sessionId,

  /// That session's author; the rules check their block list.
  required final String sessionAuthorId,

  /// Who wrote it.
  required final String authorId,

  /// What it says.
  required final String text,

  /// When it was written.
  required final DateTime dateCreated,

  /// Everyone tagged in [text].
  final List<String> mentionedUserIds = const [],

  /// Everyone who has liked it.
  final List<String> likedByUserIds = const [],

  /// The writer's name.
  final String? authorName,

  /// The writer's picture.
  final String? authorImageUrl,

  /// When the author deleted it.
  final DateTime? deletedAt,

  /// The comment this one replies to; one level only.
  final String? parentId,

  /// Set once three people have reported it.
  final bool? hidden,
}) {
  /// Creates a [WorkoutSessionComment].
  this;

  /// Decodes as `FirebaseCommentsService.fetchComments` does, reading the
  /// optionals with `as?`, but keeps a deleted comment, which the thread
  /// drops. The id is [documentId] where given (Swift reads the document
  /// id), else the stored `id`.
  factory fromFirestore(
    Map<String, Object?> data, {
    String? documentId,
  }) => WorkoutSessionComment(
    id: documentId ?? data[WorkoutSessionCommentKeys.id]! as String,
    sessionId: data[WorkoutSessionCommentKeys.sessionId]! as String,
    sessionAuthorId: data[WorkoutSessionCommentKeys.sessionAuthorId]! as String,
    authorId: data[WorkoutSessionCommentKeys.authorId]! as String,
    authorName: lenientString(data[WorkoutSessionCommentKeys.authorName]),
    authorImageUrl: lenientString(
      data[WorkoutSessionCommentKeys.authorImageUrl],
    ),
    text: data[WorkoutSessionCommentKeys.text]! as String,
    dateCreated: data[WorkoutSessionCommentKeys.dateCreated]! as DateTime,
    deletedAt: lenientDate(data[WorkoutSessionCommentKeys.deletedAt]),
    parentId: lenientString(data[WorkoutSessionCommentKeys.parentId]),
    mentionedUserIds:
        lenientStringList(data[WorkoutSessionCommentKeys.mentionedUserIds]) ??
        const [],
    likedByUserIds:
        lenientStringList(data[WorkoutSessionCommentKeys.likedByUserIds]) ??
        const [],
    hidden: lenientBool(data[WorkoutSessionCommentKeys.hidden]),
  );

  /// The document as Swift leaves it: `addComment`'s map, with a missing
  /// name, picture or parent written as null and the mentions always
  /// present, then [deletedAt], a non-empty like list and [hidden] where
  /// they are set.
  Map<String, Object?> toFirestore() => {
    WorkoutSessionCommentKeys.id: id,
    WorkoutSessionCommentKeys.sessionId: sessionId,
    WorkoutSessionCommentKeys.sessionAuthorId: sessionAuthorId,
    WorkoutSessionCommentKeys.authorId: authorId,
    WorkoutSessionCommentKeys.authorName: authorName,
    WorkoutSessionCommentKeys.authorImageUrl: authorImageUrl,
    WorkoutSessionCommentKeys.text: text,
    WorkoutSessionCommentKeys.dateCreated: dateCreated,
    WorkoutSessionCommentKeys.parentId: parentId,
    WorkoutSessionCommentKeys.mentionedUserIds: mentionedUserIds,
    WorkoutSessionCommentKeys.deletedAt: ?deletedAt,
    if (likedByUserIds.isNotEmpty)
      WorkoutSessionCommentKeys.likedByUserIds: likedByUserIds,
    WorkoutSessionCommentKeys.hidden: ?hidden,
  };
}

/// Field names of a [ReportModel], exactly as `FirebaseReportService` and
/// the `reports` rule's allowed-keys list spell them.
abstract final class ReportModelKeys {
  /// `id`.
  static const id = 'id';

  /// `reporter_id`.
  static const reporterId = 'reporter_id';

  /// `target_type`.
  static const targetType = 'target_type';

  /// `target_id`.
  static const targetId = 'target_id';

  /// `target_author_id`.
  static const targetAuthorId = 'target_author_id';

  /// `reason`.
  static const reason = 'reason';

  /// `note`.
  static const note = 'note';

  /// `status`.
  static const status = 'status';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// Every field, in declaration order. The rules refuse any other key.
  static const List<String> all = [
    id,
    reporterId,
    targetType,
    targetId,
    targetAuthorId,
    reason,
    note,
    status,
    dateCreated,
  ];
}

/// A report, at `reports/{id}` (Swift `ReportSubmission`). Write-once by the
/// reporter and always `open`; only the `onReportCreated` function reads
/// it.
class const ReportModel({
  /// The report's id; also the document id.
  required final String id,

  /// Who reported.
  required final String reporterId,

  /// What kind of thing.
  required final ReportContentType targetType,

  /// Its id.
  required final String targetId,

  /// Why.
  required final ReportReason reason,

  /// When.
  required final DateTime dateCreated,

  /// Who wrote it; null for a profile the app reports without one.
  final String? targetAuthorId,

  /// The reporter's note, at most 500 characters.
  final String? note,
}) {
  /// Creates a [ReportModel].
  this;

  /// Decodes what `FirebaseReportService` writes; a null author or note
  /// reads as absent.
  factory fromFirestore(Map<String, Object?> data) => ReportModel(
    id: data[ReportModelKeys.id]! as String,
    reporterId: data[ReportModelKeys.reporterId]! as String,
    targetType: enumFromValue(
      ReportContentType.values,
      data[ReportModelKeys.targetType]! as String,
    ),
    targetId: data[ReportModelKeys.targetId]! as String,
    targetAuthorId: data[ReportModelKeys.targetAuthorId] as String?,
    reason: enumFromValue(
      ReportReason.values,
      data[ReportModelKeys.reason]! as String,
    ),
    note: data[ReportModelKeys.note] as String?,
    dateCreated: data[ReportModelKeys.dateCreated]! as DateTime,
  );

  /// The only status a client writes.
  static const openStatus = 'open';

  /// The map `FirebaseReportService` writes: every key present, a missing
  /// author or note as null.
  Map<String, Object?> toFirestore() => {
    ReportModelKeys.id: id,
    ReportModelKeys.reporterId: reporterId,
    ReportModelKeys.targetType: targetType.value,
    ReportModelKeys.targetId: targetId,
    ReportModelKeys.targetAuthorId: targetAuthorId,
    ReportModelKeys.reason: reason.value,
    ReportModelKeys.note: note,
    ReportModelKeys.status: openStatus,
    ReportModelKeys.dateCreated: dateCreated,
  };
}

/// Field names of a [UsernameReservation], exactly as
/// `FirebaseUserQueryService` spells them.
abstract final class UsernameReservationKeys {
  /// `user_id`.
  static const userId = 'user_id';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// Every field, in declaration order.
  static const List<String> all = [userId, dateCreated];
}

/// A claimed handle, at `usernames/{handle}`. Created once, never updated;
/// the owner may delete it.
class const UsernameReservation({
  /// Who holds the handle.
  required final String userId,

  /// When it was claimed. Swift writes `FieldValue.serverTimestamp()`, so
  /// a repository does the same rather than writing this; it reads as null
  /// until the server has filled it in.
  final DateTime? dateCreated,
}) {
  /// Creates a [UsernameReservation].
  this;

  /// Decodes as `usernameOwner` reads it: `user_id`, and the timestamp if
  /// there is one.
  factory fromFirestore(Map<String, Object?> data) => UsernameReservation(
    userId: data[UsernameReservationKeys.userId]! as String,
    dateCreated: lenientDate(data[UsernameReservationKeys.dateCreated]),
  );

  /// The Firestore-shaped map, a null timestamp left out.
  Map<String, Object?> toFirestore() => {
    UsernameReservationKeys.userId: userId,
    UsernameReservationKeys.dateCreated: ?dateCreated,
  };
}
