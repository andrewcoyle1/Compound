import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:compound_models/compound_models.dart';
import 'package:social_repository/src/social_rules.dart';
import 'package:user_repository/user_repository.dart';

/// Calls the Cloud Function [name] with [data] and returns what it answers,
/// throwing a [FirebaseFunctionsException] when it refuses.
typedef CallFunction = Future<Object?> Function(
  String name,
  Map<String, Object?> data,
);

/// [CallFunction] on Cloud Functions. The social callables enforce App
/// Check and sign-in, and live in `us-central1`, so [functions] must be
/// `FirebaseFunctions.instanceFor(region: 'us-central1')` on an app with App
/// Check activated (`FirebaseUserQueryService.swift:87`).
CallFunction callFirebaseFunction(FirebaseFunctions functions) =>
    (name, data) async =>
        (await functions.httpsCallable(name).call<Object?>(data)).data;

/// Called with a document's path when it cannot be decoded and is skipped.
typedef SocialDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// Why accepting or creating an invite failed (Swift `InviteError`).
enum InviteFailure {
  /// Not an invite code.
  invalidCode,

  /// No such invite.
  notFound,

  /// The caller's own invite.
  ownInvite,

  /// Used too many times.
  exhausted,

  /// Refused for another reason, such as a block.
  unavailable,

  /// `acceptInvite` answered something unreadable.
  unexpectedResponse,

  /// Five fresh codes in a row were taken.
  noFreeCode,
}

/// An invite could not be accepted or created.
class const InviteException(
  /// Why.
  final InviteFailure failure, [

  /// The error behind it, if any.
  final Object? cause,
]) implements Exception {
  /// Creates an [InviteException].
  this;

  @override
  String toString() => 'InviteException($failure)';
}

/// What accepting an invite did, in each direction: a private profile gets
/// a request instead of a follow (Swift `InviteAcceptance.Outcome`).
enum InviteOutcome {
  /// Following now.
  following,

  /// A follow request is waiting.
  requested,
}

/// What `acceptInvite` did, from the accepting user's side (Swift
/// `InviteAcceptance`).
class const InviteAcceptance({
  /// Whose invite it was.
  required final String inviterId,

  /// The accepting user following the inviter.
  required final InviteOutcome youFollow,

  /// The inviter following the accepting user.
  required final InviteOutcome theyFollow,
}) {
  /// Creates an [InviteAcceptance].
  this;
}

/// Why a handle could not be claimed (Swift `UsernameError`).
enum UsernameFailure {
  /// Not a valid handle.
  invalid,

  /// Someone else holds it, or got there first.
  taken,
}

/// A handle could not be claimed.
class const UsernameException(
  /// Why.
  final UsernameFailure failure,
) implements Exception {
  /// Creates a [UsernameException].
  this;

  @override
  String toString() => 'UsernameException($failure)';
}

/// What users share with each other, on Cloud Firestore: the Swift app's
/// `FirebaseUserQueryService`, `FirebaseWorkoutSessionLikeService`,
/// `FirebaseCommentsService`, `FirebaseActivityNotificationService`,
/// `FirebaseChallengeService`, `FirebaseInviteService`,
/// `FirebaseShareService` and `FirebaseReportService`, with the manager and
/// `CoreInteractor` logic around them (block filtering, the notifications
/// each action sends, claiming a handle, creating an invite).
///
/// The staging flavor runs this same class over an in-memory Firestore
/// (`inMemorySocialRepository`).
///
/// - Reads skip a document that does not decode and report it to
///   `onDecodeError`, as Swift's `compactMap` drops it.
/// - Writes complete once Firestore has them locally, online or not
///   ([writeLocally]); a refusal by the server goes to `onWriteError`. The
///   one exception is reserving a handle ([claimUsername]), whose outcome is
///   the server's answer.
/// - These documents are written whole with a plain `set`, as the Swift
///   services write them, not merged: each is created by one writer and
///   never extended by another build, and overwriting a notification must
///   drop the old one's optional fields.
/// - `following_ids`, `blocked_user_ids` and `username` on the user's own
///   profile go through [UserRepository], typed by its `UserField`.
class SocialRepository {
  /// Creates a [SocialRepository] on `firestore`, calling Cloud Functions
  /// through `callFunction` and writing the signed-in user's profile
  /// through `users`. `now` stamps what it creates, `newId` names it and
  /// `newInviteCode` draws invite codes.
  new({
    required this._firestore,
    required CallFunction callFunction,
    required this._users,
    SocialDecodeErrorHandler? onDecodeError,
    this._onWriteError = logWriteError,
    DateTime Function()? now,
    String Function()? newId,
    String Function()? newInviteCode,
  }) : _call = callFunction,
       _onDecodeError = onDecodeError ?? _log,
       _now = now ?? (() => DateTime.now().toUtc()),
       _newId = newId ?? newDocumentId,
       _newInviteCode = newInviteCode ?? InviteCode.random;

  final FirebaseFirestore _firestore;
  final CallFunction _call;
  final UserRepository _users;
  final SocialDecodeErrorHandler _onDecodeError;
  final WriteErrorReporter _onWriteError;
  final DateTime Function() _now;
  final String Function() _newId;
  final String Function() _newInviteCode;

  /// How many notifications a page holds
  /// (`ActivityNotificationManager.pageSize`).
  static const notificationPageSize = 50;

  CollectionReference<Map<String, dynamic>> get _userProfiles =>
      _firestore.collection('users');

  DocumentReference<Map<String, dynamic>> _followRequest(
    String targetId,
    String requesterId,
  ) => _userProfiles
      .doc(targetId)
      .collection('follow_requests')
      .doc(requesterId);

  CollectionReference<Map<String, dynamic>> _notifications(String uid) =>
      _userProfiles.doc(uid).collection('notifications');

  CollectionReference<Map<String, dynamic>> get _comments =>
      _firestore.collection('workout_session_comments');

  CollectionReference<Map<String, dynamic>> get _challenges =>
      _firestore.collection('challenges');

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('invites');

  CollectionReference<Map<String, dynamic>> get _shares =>
      _firestore.collection('shares');

  // ---------------------------------------------------------------- People

  /// Up to 200 users who follow [uid], less anyone [viewer] has blocked
  /// (`FirebaseUserQueryService.swift:7-13`, `UserManager.swift:283-285`).
  Future<List<UserModel>> followersOf(
    String uid, {
    required UserModel viewer,
  }) async => _visible(
    viewer,
    await _getUsers(
      _userProfiles
          .where(UserModelKeys.followingIds, arrayContains: uid)
          .limit(200),
    ),
  );

  /// People matching [query] by handle prefix, then by first name, each
  /// once, less anyone [viewer] has blocked
  /// (`UserManager+Username.swift:48-59`).
  ///
  /// The name search is Swift's: a range on `submitted_first_name` from the
  /// query with its first letter capitalised, up to 20
  /// (`FirebaseUserQueryService.swift:15-28`); the handle search a range on
  /// `username`, up to 20 (`:143-151`).
  Future<List<UserModel>> searchUsers(
    String query, {
    required UserModel viewer,
  }) async {
    final route = Username.searchRoute(query);
    final found = [
      if (route.handlePrefix case final prefix?)
        ...await _prefixSearch(UserModelKeys.username, prefix),
      if (route.name case final name?)
        ...await _prefixSearch(
          UserModelKeys.submittedFirstName,
          name[0].toUpperCase() + name.substring(1),
        ),
    ];
    final seen = <String>{};
    return _visible(viewer, [
      for (final user in found)
        if (seen.add(user.userId)) user,
    ]);
  }

  Future<List<UserModel>> _prefixSearch(String field, String prefix) =>
      _getUsers(
        _userProfiles
            .where(field, isGreaterThanOrEqualTo: prefix)
            .where(field, isLessThan: '$prefix\u{f8ff}')
            .limit(20),
      );

  /// Up to [limit] people for [viewer] to follow: the newest accounts, less
  /// [viewer], anyone they follow or have blocked, and private profiles
  /// (`UserManager.swift:295-306`, `FirebaseUserQueryService.swift:31-37`).
  /// Over-fetches by the number excluded so they do not leave it short.
  Future<List<UserModel>> suggestedUsers({
    required UserModel viewer,
    int limit = 10,
  }) async {
    final excluded = {
      viewer.userId,
      ...?viewer.followingIds,
      ...?viewer.blockedUserIds,
    };
    final newest = await _getUsers(
      _userProfiles
          .orderBy(UserModelKeys.creationDate, descending: true)
          .limit(limit + excluded.length),
    );
    return newest
        .where(
          (user) => !excluded.contains(user.userId) && user.isPrivate != true,
        )
        .take(limit)
        .toList();
  }

  /// The profiles of [ids], in no particular order, less anyone [viewer] has
  /// blocked; an id with no profile is skipped. Queried 30 at a time, the
  /// most an `in` filter takes (`FirebaseUserQueryService.swift:40-51`,
  /// `UserManager.swift:404-407`).
  Future<List<UserModel>> users(
    List<String> ids, {
    required UserModel viewer,
  }) async {
    final found = <UserModel>[];
    for (var start = 0; start < ids.length; start += 30) {
      found.addAll(
        await _getUsers(
          _userProfiles.where(
            UserModelKeys.userId,
            whereIn: ids.sublist(start, (start + 30).clamp(0, ids.length)),
          ),
        ),
      );
    }
    return _visible(viewer, found);
  }

  /// The profiles of the first 30 people [viewer] follows, less anyone they
  /// have blocked, re-emitted on every change; empty at once when they
  /// follow nobody (`UserManager.swift:31-34`, `:87-96`;
  /// `FollowingQueries.users`). Subscribe again when [viewer]'s following
  /// list changes, as Swift restarts its listener.
  Stream<List<UserModel>> watchFollowingUsers(UserModel viewer) {
    final ids = FollowingQueries.cappedIds(viewer.followingIds ?? const []);
    if (ids.isEmpty) return Stream.value(const []);
    return _userProfiles
        .where(UserModelKeys.userId, whereIn: ids)
        .snapshots()
        .map((snapshot) => _visible(viewer, _decodeAll(snapshot, _user)));
  }

  /// The following feed: the newest 200 sessions by the first 30 of
  /// [followingIds], read through the `workout_sessions` collection group
  /// and re-emitted on every change; empty at once when [followingIds] is
  /// (`WorkoutSessionManager.swift:71-81`, `FollowingQueries.sessions`).
  /// Needs the `author_id` + `date_created` collection-group index.
  Stream<List<WorkoutSessionModel>> watchFollowingSessions(
    List<String> followingIds,
  ) {
    final ids = FollowingQueries.cappedIds(followingIds);
    if (ids.isEmpty) return Stream.value(const []);
    return _firestore
        .collectionGroup('workout_sessions')
        .where(WorkoutSessionModelKeys.authorId, whereIn: ids)
        .orderBy(WorkoutSessionModelKeys.dateCreated, descending: true)
        .limit(FollowingQueries.sessionLimit)
        .snapshots()
        .map((snapshot) => _decodeAll(snapshot, _session));
  }

  /// Anyone's newest [limit] sessions, through the collection group, which
  /// the rules let any signed-in user read
  /// (`WorkoutSessionManager.swift:179-187`).
  Future<List<WorkoutSessionModel>> sessionsByAuthor(
    String authorId, {
    int limit = 20,
  }) async => _decodeAll(
    await _firestore
        .collectionGroup('workout_sessions')
        .where(WorkoutSessionModelKeys.authorId, isEqualTo: authorId)
        .orderBy(WorkoutSessionModelKeys.dateCreated, descending: true)
        .limit(limit)
        .get(),
    _session,
  );

  /// One session by anyone, for a notification's tap, or null when there is
  /// none (`WorkoutSessionManager.swift:194-207`; the caller looks in what it
  /// already holds first). Needs the `author_id` + `id` index.
  Future<WorkoutSessionModel?> sessionById(
    String id, {
    required String authorId,
  }) async => _decodeAll(
    await _firestore
        .collectionGroup('workout_sessions')
        .where(WorkoutSessionModelKeys.authorId, isEqualTo: authorId)
        .where(WorkoutSessionModelKeys.id, isEqualTo: id)
        .limit(1)
        .get(),
    _session,
  ).firstOrNull;

  // --------------------------------------------------------------- Follows

  /// [viewer] follows [targetId]: `following_ids` gains it if missing, and
  /// [targetId] gets a `follow_{viewer}` notification
  /// (`UserManager.swift:348-357`, `:566-590`).
  Future<void> follow(String targetId, {required UserModel viewer}) async {
    final following = viewer.followingIds ?? const [];
    await _users.updateUserFields(viewer.userId, [
      UserField.followingIds([
        ...following,
        if (!following.contains(targetId)) targetId,
      ]),
    ]);
    await _notify(
      targetId,
      _actorNotification(
        'follow_${viewer.userId}',
        ActivityType.follow,
        viewer,
        recipientId: targetId,
      ),
    );
  }

  /// [viewer] stops following [targetId], and takes back the follow
  /// notification (`UserManager.swift:359-368`, `:618-634`).
  Future<void> unfollow(String targetId, {required UserModel viewer}) async {
    await _users.updateUserFields(viewer.userId, [
      UserField.followingIds([
        for (final id in viewer.followingIds ?? const <String>[])
          if (id != targetId) id,
      ]),
    ]);
    await _delete(_notifications(targetId).doc('follow_${viewer.userId}'));
  }

  /// [viewer] blocks [targetId], dropping any follow in the same write, and
  /// takes back the follow notification if they were following
  /// (`UserManager.swift:322-333`, `:544-550`).
  Future<void> block(String targetId, {required UserModel viewer}) async {
    final blocked = viewer.blockedUserIds ?? const [];
    final following = viewer.followingIds ?? const [];
    await _users.updateUserFields(viewer.userId, [
      UserField.blockedUserIds([
        ...blocked,
        if (!blocked.contains(targetId)) targetId,
      ]),
      UserField.followingIds([
        for (final id in following)
          if (id != targetId) id,
      ]),
    ]);
    if (following.contains(targetId)) {
      await _delete(_notifications(targetId).doc('follow_${viewer.userId}'));
    }
  }

  /// [viewer] unblocks [targetId] (`UserManager.swift:335-345`).
  Future<void> unblock(String targetId, {required UserModel viewer}) =>
      _users.updateUserFields(viewer.userId, [
        UserField.blockedUserIds([
          for (final id in viewer.blockedUserIds ?? const <String>[])
            if (id != targetId) id,
        ]),
      ]);

  /// [viewer] asks [targetId] to train today. The notification's id carries
  /// the local day, so a second nudge that day overwrites the first
  /// (`UserManager.swift:599-616`). Keeping to one a day is the caller's.
  Future<void> nudge(String targetId, {required UserModel viewer}) {
    final now = _now();
    return _notify(
      targetId,
      _actorNotification(
        'nudge_${viewer.userId}_${_dayKey(now)}',
        ActivityType.nudge,
        viewer,
        recipientId: targetId,
        at: now,
      ),
    );
  }

  /// Takes the caller out of [followerId]'s following list through the
  /// `removeFollower` function, since that is someone else's document
  /// (`FirebaseUserQueryService.swift:86-90`). Waits for the function, so it
  /// fails offline.
  Future<void> removeFollower(String followerId) =>
      _call('removeFollower', {'followerId': followerId});

  // ------------------------------------------------------- Follow requests

  /// [viewer] asks to follow [targetId]'s private profile, at
  /// `users/{target}/follow_requests/{viewer}`
  /// (`UserManager.swift:373-384`, `FirebaseUserQueryService.swift:59-64`).
  Future<void> sendFollowRequest(
    String targetId, {
    required UserModel viewer,
  }) => _set(
    _followRequest(targetId, viewer.userId),
    FollowRequestModel(
      requesterId: viewer.userId,
      requesterName: fullNameOf(viewer) ?? 'Someone',
      requesterImageUrl: profileImageOf(viewer),
      dateCreated: _now(),
    ).toFirestore(),
  );

  /// [requesterId] takes back their request to [targetId]
  /// (`UserManager.swift:386-390`).
  Future<void> cancelFollowRequest(
    String targetId, {
    required String requesterId,
  }) => _delete(_followRequest(targetId, requesterId));

  /// [targetId] answers [requesterId]'s request by writing `status` alone;
  /// the `onFollowRequestUpdated` function does the rest
  /// (`UserManager.swift:398-402`, `FirebaseUserQueryService.swift:70-74`).
  Future<void> answerFollowRequest(
    String requesterId, {
    required String targetId,
    required bool accept,
  }) => _update(_followRequest(targetId, requesterId), {
    FollowRequestModelKeys.status:
        (accept ? FollowRequestStatus.accepted : FollowRequestStatus.declined)
            .value,
  });

  /// Up to 100 pending requests to follow [viewer], newest first, less
  /// anyone they have blocked, re-emitted on every change
  /// (`FirebaseUserQueryService.swift:76-104`, `UserManager.swift:448-452`).
  Stream<List<FollowRequestModel>> watchIncomingFollowRequests(
    UserModel viewer,
  ) => _userProfiles
      .doc(viewer.userId)
      .collection('follow_requests')
      .where(
        FollowRequestModelKeys.status,
        isEqualTo: FollowRequestStatus.pending.value,
      )
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => [
          for (final request in _decodeAll(
            snapshot,
            (_, data) => FollowRequestModel.fromFirestore(data),
          ))
            if (!_hasBlocked(viewer, request.requesterId)) request,
        ]..sort((a, b) => b.dateCreated.compareTo(a.dateCreated)),
      );

  /// The ids of the profiles [requesterId] has a pending request with, read
  /// through the `follow_requests` collection group
  /// (`FirebaseUserQueryService.swift:108-116`).
  Future<List<String>> sentFollowRequestTargetIds(String requesterId) async => [
    for (final document
        in (await _firestore
                .collectionGroup('follow_requests')
                .where(
                  FollowRequestModelKeys.requesterId,
                  isEqualTo: requesterId,
                )
                .where(
                  FollowRequestModelKeys.status,
                  isEqualTo: FollowRequestStatus.pending.value,
                )
                .get())
            .docs)
      ?document.reference.parent.parent?.id,
  ];

  // ----------------------------------------------------------------- Likes

  /// [viewer] likes [sessionId] by [authorId]: their own id alone joins
  /// `liked_by_user_ids`, and the author, unless it is [viewer], gets a
  /// `like_{session}_{viewer}` notification
  /// (`FirebaseWorkoutSessionLikeService.swift:6-11`; the notification is
  /// `CoreInteractor`'s).
  Future<void> likeSession(
    String sessionId, {
    required String authorId,
    required UserModel viewer,
  }) async {
    await _update(_sessionDocument(authorId, sessionId), {
      WorkoutSessionModelKeys.likedByUserIds: FieldValue.arrayUnion([
        viewer.userId,
      ]),
    });
    if (authorId == viewer.userId) return;
    await _notify(
      authorId,
      _actorNotification(
        'like_${sessionId}_${viewer.userId}',
        ActivityType.like,
        viewer,
        recipientId: authorId,
        sessionId: sessionId,
      ),
    );
  }

  /// [viewer] takes back their like, and its notification
  /// (`FirebaseWorkoutSessionLikeService.swift:13-18`).
  Future<void> unlikeSession(
    String sessionId, {
    required String authorId,
    required UserModel viewer,
  }) async {
    await _update(_sessionDocument(authorId, sessionId), {
      WorkoutSessionModelKeys.likedByUserIds: FieldValue.arrayRemove([
        viewer.userId,
      ]),
    });
    if (authorId == viewer.userId) return;
    await _delete(
      _notifications(authorId).doc('like_${sessionId}_${viewer.userId}'),
    );
  }

  DocumentReference<Map<String, dynamic>> _sessionDocument(
    String authorId,
    String sessionId,
  ) =>
      _userProfiles.doc(authorId).collection('workout_sessions').doc(sessionId);

  // -------------------------------------------------------------- Comments

  /// The comments on [sessionId], less deleted ones: any document with a
  /// `deleted_at` key, null included (`FirebaseCommentsService.swift:17-46`).
  Future<List<WorkoutSessionComment>> comments(String sessionId) async {
    final snapshot = await _comments
        .where(WorkoutSessionCommentKeys.sessionId, isEqualTo: sessionId)
        .get();
    return [
      for (final document in snapshot.docs)
        if (!document.data().containsKey(WorkoutSessionCommentKeys.deletedAt))
          ?_decode(
            document.reference.path,
            document.data(),
            (data) => WorkoutSessionComment.fromFirestore(
              data,
              documentId: document.id,
            ),
          ),
    ];
  }

  /// Writes [comment] as `addComment` does (its ten fields, absent ones as
  /// null) and then its notifications (`FirebaseCommentsService.swift:48-61`,
  /// `CoreInteractor`'s `addComment`).
  ///
  /// For a reply, the parent's author is read from the parent comment alone;
  /// Swift re-reads the whole thread for it. A parent that is deleted,
  /// unreadable or on another session counts as none, as there.
  Future<void> addComment(WorkoutSessionComment comment) async {
    await _set(
      _comments.doc(comment.id),
      comment.toFirestore()..removeWhere(
        (key, _) => const {
          WorkoutSessionCommentKeys.deletedAt,
          WorkoutSessionCommentKeys.likedByUserIds,
          WorkoutSessionCommentKeys.hidden,
        }.contains(key),
      ),
    );
    final parentId = comment.parentId;
    final parent = parentId == null
        ? null
        : await _comments.doc(parentId).get();
    final parentData = parent?.data();
    final parentAuthorId =
        parentData == null ||
            parentData.containsKey(WorkoutSessionCommentKeys.deletedAt) ||
            parentData[WorkoutSessionCommentKeys.sessionId] != comment.sessionId
        ? null
        : lenientString(parentData[WorkoutSessionCommentKeys.authorId]);
    for (final (recipient, notification) in commentNotifications(
      comment,
      parentAuthorId: parentAuthorId,
    )) {
      await _notify(recipient, notification);
    }
  }

  /// Soft-deletes comment [id]: `deleted_at` set to now, alone
  /// (`FirebaseCommentsService.swift:63-67`).
  Future<void> deleteComment(String id) => _update(_comments.doc(id), {
    WorkoutSessionCommentKeys.deletedAt: Timestamp.fromDate(_now()),
  });

  /// Adds ([liked]) or removes [userId]'s like on comment [id], setting the
  /// state rather than flipping it (`FirebaseCommentsService.swift:69-73`).
  Future<void> setCommentLike(
    String id, {
    required String userId,
    required bool liked,
  }) => _update(_comments.doc(id), {
    WorkoutSessionCommentKeys.likedByUserIds: liked
        ? FieldValue.arrayUnion([userId])
        : FieldValue.arrayRemove([userId]),
  });

  // --------------------------------------------------------- Notifications

  /// A page of [uid]'s notifications, newest first: the first, or those
  /// older than [before] (`FirebaseActivityNotificationService.swift:20-26`,
  /// `:92-99`). A notification sharing the exact time of the previous page's
  /// last is skipped, as in Swift.
  Future<List<ActivityNotificationModel>> notifications(
    String uid, {
    DateTime? before,
  }) async {
    var query = _notifications(uid)
        .orderBy(ActivityNotificationModelKeys.dateCreated, descending: true);
    if (before != null) query = query.startAfter([Timestamp.fromDate(before)]);
    return _decodeAll(
      await query.limit(notificationPageSize).get(),
      _notification,
    );
  }

  /// Each notification [uid] receives from now on, as it arrives
  /// (`FirebaseActivityNotificationService.swift:71-81`).
  Stream<ActivityNotificationModel> watchNewNotifications(String uid) =>
      _notifications(uid)
          .where(
            ActivityNotificationModelKeys.dateCreated,
            isGreaterThan: Timestamp.fromDate(_now()),
          )
          .snapshots()
          .expand(
            (snapshot) => [
              for (final change in snapshot.docChanges)
                if (change.type == DocumentChangeType.added)
                  ?_decode(
                    change.doc.reference.path,
                    change.doc.data()!,
                    (data) => _notification(change.doc.id, data),
                  ),
            ],
          );

  /// Marks [ids] read, in one batch (`:101-108`).
  Future<void> markNotificationsRead(String uid, List<String> ids) => _markRead(
    _notifications(uid),
    [for (final id in ids) _notifications(uid).doc(id)],
  );

  /// Marks every unread notification read (`:60-69`). Reads them first, so
  /// it waits for that read. Swift commits one batch, which fails past
  /// Firestore's 500 writes; this commits 500 at a time.
  Future<void> markAllNotificationsRead(String uid) async {
    final unread = await _notifications(uid)
        .where(ActivityNotificationModelKeys.isRead, isEqualTo: false)
        .get();
    await _markRead(_notifications(uid), [
      for (final document in unread.docs) document.reference,
    ]);
  }

  Future<void> _markRead(
    CollectionReference<Map<String, dynamic>> collection,
    List<DocumentReference<Map<String, dynamic>>> documents,
  ) async {
    for (var start = 0; start < documents.length; start += 500) {
      final batch = _firestore.batch();
      for (final document in documents.skip(start).take(500)) {
        batch.update(document, {ActivityNotificationModelKeys.isRead: true});
      }
      await writeLocally(collection.path, batch.commit, _onWriteError);
    }
  }

  /// Deletes [uid]'s notification [id] (`:56-58`).
  Future<void> deleteNotification(String uid, String id) =>
      _delete(_notifications(uid).doc(id));

  // ------------------------------------------------------------ Challenges

  /// Every challenge [uid] is in, soonest ending first
  /// (`FirebaseChallengeService.swift:16-21`, `ChallengeService.swift:39-48`).
  Future<List<ChallengeModel>> challenges(String uid) async => _decodeAll(
    await _challenges
        .where(ChallengeModelKeys.memberIds, arrayContains: uid)
        .get(),
    (_, data) => ChallengeModel.fromFirestore(data),
  )..sort((a, b) => a.endsAt.compareTo(b.endsAt));

  /// Challenge [id], or null when there is none or it cannot be read
  /// (`FirebaseChallengeService.swift:23-25`).
  Future<ChallengeModel?> challenge(String id) async {
    final document = await _challenges.doc(id).get();
    final data = document.data();
    return data == null
        ? null
        : _decode(document.reference.path, data, ChallengeModel.fromFirestore);
  }

  /// Sessions counted per member of challenge [id]; a member with no
  /// progress document has none (`FirebaseChallengeService.swift:27-36`).
  /// Only the `onWorkoutSessionEndedForChallenges` function writes it.
  Future<Map<String, int>> challengeProgress(String id) async {
    final snapshot = await _challenges.doc(id).collection('progress').get();
    return {
      for (final document in snapshot.docs)
        if (_decode(
              document.reference.path,
              document.data(),
              ChallengeProgressModel.fromFirestore,
            )
            case final progress?)
          document.id: progress.sessions,
    };
  }

  /// Creates [challenge] (`FirebaseChallengeService.swift:38-42`).
  Future<void> createChallenge(ChallengeModel challenge) =>
      _set(_challenges.doc(challenge.id), challenge.toFirestore());

  /// Takes [userId], alone, out of challenge [id]
  /// (`FirebaseChallengeService.swift:44-48`).
  Future<void> leaveChallenge(String id, {required String userId}) =>
      _update(_challenges.doc(id), {
        ChallengeModelKeys.memberIds: FieldValue.arrayRemove([userId]),
      });

  // --------------------------------------------------------------- Invites

  /// [uid]'s one invite, created the first time (`InviteService.swift:28-40`):
  /// up to five fresh codes are drawn, each checked free before it is
  /// written. A code taken in between makes the server refuse the create,
  /// which reaches `onWriteError`, never overwriting the other invite.
  Future<InviteModel> myInvite(String uid) async {
    final existing = _decodeAll(
      await _invites
          .where(InviteModelKeys.inviterId, isEqualTo: uid)
          .limit(1)
          .get(),
      (_, data) => InviteModel.fromFirestore(data),
    );
    if (existing.isNotEmpty) return existing.first;
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _newInviteCode();
      if ((await _invites.doc(code).get()).exists) continue;
      final invite = InviteModel(
        code: code,
        inviterId: uid,
        dateCreated: _now(),
      );
      await _set(_invites.doc(code), invite.toFirestore());
      return invite;
    }
    throw const InviteException(InviteFailure.noFreeCode);
  }

  /// Accepts invite [code] through the `acceptInvite` function, which makes
  /// every write (`FirebaseInviteService.swift:37-67`). The code is
  /// normalised first (`InviteService.swift:42-45`). Waits for the function,
  /// so it fails offline.
  Future<InviteAcceptance> acceptInvite(String code) async {
    final normalised = InviteCode.normalised(code);
    if (normalised == null) {
      throw const InviteException(InviteFailure.invalidCode);
    }
    final Object? data;
    try {
      data = await _call('acceptInvite', {'code': normalised});
    } on FirebaseFunctionsException catch (error) {
      final failure = switch (error.code) {
        'invalid-argument' => InviteFailure.invalidCode,
        'not-found' => InviteFailure.notFound,
        'failed-precondition' => InviteFailure.ownInvite,
        'resource-exhausted' => InviteFailure.exhausted,
        'permission-denied' => InviteFailure.unavailable,
        _ => null,
      };
      if (failure == null) rethrow;
      throw InviteException(failure, error);
    }
    InviteOutcome? outcome(Object? value) =>
        InviteOutcome.values.where((o) => o.name == value).firstOrNull;
    if (data
        case {
          'inviter_id': final String inviterId,
          'you_follow': final Object youFollow,
          'they_follow': final Object theyFollow,
        }
        when outcome(youFollow) != null && outcome(theyFollow) != null) {
      return InviteAcceptance(
        inviterId: inviterId,
        youFollow: outcome(youFollow)!,
        theyFollow: outcome(theyFollow)!,
      );
    }
    throw const InviteException(InviteFailure.unexpectedResponse);
  }

  // ---------------------------------------------------------------- Shares

  /// Sends [payload] from [viewer] to each of [recipientIds]: a pending
  /// `shares/{id}` and a `share_{id}` notification apiece
  /// (`CoreInteractor+Sharing.swift:12-32`).
  Future<void> sendShare(
    SharePayload payload, {
    required List<String> recipientIds,
    required UserModel viewer,
  }) async {
    for (final recipientId in recipientIds) {
      final share = ShareModel(
        id: _newId(),
        fromUserId: viewer.userId,
        toUserId: recipientId,
        payload: payload,
        dateCreated: _now(),
      );
      await _set(_shares.doc(share.id), share.toFirestore());
      await _notify(
        recipientId,
        ActivityNotificationModel(
          id: 'share_${share.id}',
          type: ActivityType.share,
          actorId: viewer.userId,
          actorName: fullNameOf(viewer) ?? 'Someone',
          actorImageUrl: viewer.submittedProfileImage,
          sessionId: '',
          sessionAuthorId: recipientId,
          commentText: switch (payload) {
            TemplateSharePayload(:final template) => template.name,
            MesocycleSharePayload(:final mesocycle) => mesocycle.name,
          },
          dateCreated: share.dateCreated,
          shareId: share.id,
        ),
      );
    }
  }

  /// Share [id], or null when there is none or it cannot be read
  /// (`FirebaseShareService.swift:22-24`).
  Future<ShareModel?> share(String id) async {
    final document = await _shares.doc(id).get();
    final data = document.data();
    return data == null
        ? null
        : _decode(document.reference.path, data, ShareModel.fromFirestore);
  }

  /// The recipient answers share [id] with [status] alone
  /// (`FirebaseShareService.swift:26-28`). Copying the payload into their
  /// library is the training repositories' job.
  Future<void> answerShare(String id, ShareStatus status) =>
      _update(_shares.doc(id), {ShareModelKeys.status: status.value});

  // --------------------------------------------------------------- Reports

  /// Files an open report, with only the keys the rules allow
  /// (`ReportManager.swift:64-83`, `FirebaseReportService.swift:16-28`).
  Future<void> report({
    required String reporterId,
    required ReportContentType targetType,
    required String targetId,
    required ReportReason reason,
    String? targetAuthorId,
    String? note,
  }) {
    final report = ReportModel(
      id: _newId(),
      reporterId: reporterId,
      targetType: targetType,
      targetId: targetId,
      targetAuthorId: targetAuthorId,
      reason: reason,
      note: note,
      dateCreated: _now(),
    );
    return _set(
      _firestore.collection('reports').doc(report.id),
      report.toFirestore(),
    );
  }

  // ------------------------------------------------------------- Usernames

  /// Whether [raw] is free, or already [viewer]'s; an invalid handle never is
  /// (`UserManager+Username.swift:15-20`).
  Future<bool> isUsernameAvailable(
    String raw, {
    required UserModel viewer,
  }) async {
    final handle = Username.normalised(raw);
    if (!Username.isValid(handle)) return false;
    final owner = await _usernameOwner(handle);
    return owner == null || owner == viewer.userId;
  }

  /// Reserves [raw] at `usernames/{handle}` and sets it on [viewer]'s
  /// profile (`UserManager+Username.swift:24-44`).
  ///
  /// Not a transaction, as in Swift: the reservation is a plain `set` the
  /// rules allow only as a create, so a handle someone reserved meanwhile
  /// fails rather than being overwritten. That outcome is the server's, so
  /// unlike every other write this one waits for it, and does not complete
  /// offline. A reservation [viewer] already holds, from an attempt whose
  /// profile write failed, is reused.
  Future<void> claimUsername(String raw, {required UserModel viewer}) async {
    final handle = Username.normalised(raw);
    if (!Username.isValid(handle)) {
      throw const UsernameException(UsernameFailure.invalid);
    }
    if (handle == viewer.username) return;
    final owner = await _usernameOwner(handle);
    if (owner == null) {
      try {
        await _firestore.collection('usernames').doc(handle).set({
          UsernameReservationKeys.userId: viewer.userId,
          UsernameReservationKeys.dateCreated: FieldValue.serverTimestamp(),
        });
      } on Object {
        throw const UsernameException(UsernameFailure.taken);
      }
    } else if (owner != viewer.userId) {
      throw const UsernameException(UsernameFailure.taken);
    }
    await _users.updateUserFields(viewer.userId, [UserField.username(handle)]);
  }

  /// `usernames/{handle}`'s `user_id`, or null when it is free
  /// (`FirebaseUserQueryService.swift:127-131`).
  Future<String?> _usernameOwner(String handle) async => lenientString(
    (await _firestore.collection('usernames').doc(handle).get())
        .data()?[UsernameReservationKeys.userId],
  );

  // --------------------------------------------------------------- Helpers

  /// A notification from [actor] as `CoreInteractor` builds its likes,
  /// follows and nudges: their full name, their uploaded picture and no
  /// session unless [sessionId] is given.
  ActivityNotificationModel _actorNotification(
    String id,
    ActivityType type,
    UserModel actor, {
    required String recipientId,
    String sessionId = '',
    DateTime? at,
  }) => ActivityNotificationModel(
    id: id,
    type: type,
    actorId: actor.userId,
    actorName: fullNameOf(actor) ?? 'Someone',
    actorImageUrl: actor.submittedProfileImage,
    sessionId: sessionId,
    sessionAuthorId: recipientId,
    dateCreated: at ?? _now(),
  );

  /// Writes [notification] to [recipientId], replacing any with its id
  /// (`FirebaseActivityNotificationService.swift:28-54`).
  Future<void> _notify(
    String recipientId,
    ActivityNotificationModel notification,
  ) => _set(
    _notifications(recipientId).doc(notification.id),
    notification.toFirestore(),
  );

  Future<void> _set(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, Object?> data,
  ) => writeLocally(
    document.path,
    () => document.set(_toFirestore(data)),
    _onWriteError,
  );

  Future<void> _update(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, Object?> data,
  ) => writeLocally(document.path, () => document.update(data), _onWriteError);

  Future<void> _delete(DocumentReference<Map<String, dynamic>> document) =>
      writeLocally(document.path, document.delete, _onWriteError);

  Future<List<UserModel>> _getUsers(Query<Map<String, dynamic>> query) async =>
      _decodeAll(await query.get(), _user);

  List<T> _decodeAll<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    T Function(String id, Map<String, Object?> data) decode,
  ) => [
    for (final document in snapshot.docs)
      ?_decode(
        document.reference.path,
        document.data(),
        (data) => decode(document.id, data),
      ),
  ];

  T? _decode<T>(
    String path,
    Map<String, Object?> data,
    T Function(Map<String, Object?>) decode,
  ) {
    try {
      return decode(_fromFirestore(data));
    } on Object catch (error, stackTrace) {
      _onDecodeError(path, error, stackTrace);
      return null;
    }
  }

  static UserModel _user(String _, Map<String, Object?> data) =>
      UserModel.fromFirestore(data);

  static WorkoutSessionModel _session(String _, Map<String, Object?> data) =>
      WorkoutSessionModel.fromFirestore(data);

  static ActivityNotificationModel _notification(
    String id,
    Map<String, Object?> data,
  ) => ActivityNotificationModel.fromFirestore(id, data);

  static List<UserModel> _visible(UserModel viewer, List<UserModel> users) => [
    for (final user in users)
      if (!_hasBlocked(viewer, user.userId)) user,
  ];

  static bool _hasBlocked(UserModel viewer, String userId) =>
      viewer.blockedUserIds?.contains(userId) ?? false;

  /// Swift's `Date.dayKey`: the local day, `yyyy-MM-dd`.
  static String _dayKey(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-'
        '${two(local.month)}-${two(local.day)}';
  }

  static void _log(String path, Object error, StackTrace stackTrace) =>
      developer.log(
        'Skipped $path: it does not decode',
        name: 'social_repository',
        error: error,
        stackTrace: stackTrace,
      );
}

// The same converter as the other repositories': Firestore's values to the
// models' at any depth, a [Timestamp] becoming a UTC [DateTime].
Map<String, Object?> _fromFirestore(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _value(value)));

Object? _value(Object? value) => switch (value) {
  final Timestamp timestamp => timestamp.toDate().toUtc(),
  final Map<String, Object?> map => _fromFirestore(map),
  final List<Object?> list => list.map(_value).toList(),
  _ => value,
};

/// The models' values to Firestore's at any depth: a [DateTime] becomes a
/// [Timestamp], as Swift stores a `Date`.
Map<String, Object?> _toFirestore(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _stored(value)));

Object? _stored(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => _toFirestore(map),
  final List<Object?> list => list.map(_stored).toList(),
  _ => value,
};
