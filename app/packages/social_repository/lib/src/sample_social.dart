import 'package:compound_models/compound_models.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The staging flavor's social world around [uid], as Firestore documents
/// keyed by path, with dates still [DateTime]s. It follows the Swift app's
/// mocks (`UserModel.mocks`, `ChallengeModel.mocks`, `ShareModel.mocks`,
/// `MockUserQueryService`, `MockInviteService`):
///
/// - six other users: the four [uid] follows (Maya, Charlie, Priya and Dev,
///   each with two recent sessions in the feed), Bob, private, with a
///   pending request to follow [uid], and David, who has blocked [uid];
/// - every handle reserved, [uid]'s `alice.cooper` included;
/// - [uid]'s own sessions, `workout_session_repository`'s
///   `sampleWorkoutSessions`, so likes on them land as they do in Firestore;
/// - comments on Maya's newest session and on [uid]'s own newest one;
/// - two challenges with standings, Maya's invite `PUSH2345`, and a
///   pending template share from Maya;
/// - notifications for [uid]: a like, a comment, a share and a nudge
///   unread, and a follow read.
Map<String, Map<String, Object?>> sampleSocial({
  required String uid,
  required DateTime now,
}) {
  DateTime ago(Duration duration) => now.subtract(duration);
  const day = Duration(days: 1);
  const hour = Duration(hours: 1);
  final own = sampleWorkoutSessions(uid: uid, now: now);
  final ownNewest = own.last;

  final friends = [
    _friend('user1', 'Maya', 'Chen', 'maya.chen', ago(day * 365), [
      uid,
      'user3',
    ]),
    _friend('user2', 'Bob', 'Martinez', 'bob_lifts', ago(day * 96), [
      uid,
    ], isPrivate: true),
    _friend('user3', 'Charlie', 'Nguyen', 'charlie.c', ago(day * 210), [
      uid,
      'user1',
    ]),
    _friend('user4', 'Priya', 'Shah', 'priya_runs', ago(day * 9), [uid]),
    _friend('user5', 'Dev', 'Patel', 'dev.patel', ago(day * 150), [
      uid,
      'user1',
      'user3',
    ]),
    _friend(
      'user6',
      'David',
      'Kerr',
      null,
      ago(day * 45),
      const [],
      blocked: [uid],
    ),
  ];
  final followed = ['user1', 'user3', 'user4', 'user5'];
  final feed = {
    for (final (index, friend) in followed.indexed)
      friend: [
        for (final session in sampleWorkoutSessions(
          uid: friend,
          now: ago(hour * (index * 5 + 1)),
        ).where((session) => !session.isRestDay).toList().reversed.take(2))
          {
            ...session.toFirestore(),
            WorkoutSessionModelKeys.id: '$friend-${session.id}',
            WorkoutSessionModelKeys.likedByUserIds: [
              if (friend == 'user1') uid,
            ],
          },
      ],
  };
  final mayaNewest = feed['user1']!.first;
  final mayaSessionId = mayaNewest[WorkoutSessionModelKeys.id]! as String;

  final comments = [
    WorkoutSessionComment(
      id: 'sample-comment-1',
      sessionId: mayaSessionId,
      sessionAuthorId: 'user1',
      authorId: 'user3',
      authorName: 'Charlie Nguyen',
      authorImageUrl: _avatar('charlie'),
      text: 'Great session! 💪',
      dateCreated: ago(hour * 3),
      likedByUserIds: const ['user1'],
    ),
    WorkoutSessionComment(
      id: 'sample-comment-2',
      sessionId: mayaSessionId,
      sessionAuthorId: 'user1',
      authorId: uid,
      authorName: 'Alice Cooper',
      text: 'Same time next week?',
      dateCreated: ago(hour * 2),
      parentId: 'sample-comment-1',
    ),
    WorkoutSessionComment(
      id: 'sample-comment-3',
      sessionId: ownNewest.id,
      sessionAuthorId: uid,
      authorId: 'user1',
      authorName: 'Maya Chen',
      authorImageUrl: _avatar('maya'),
      text: 'Those pushdowns 🔥',
      dateCreated: ago(hour),
    ),
  ];

  final challenges = [
    ChallengeModel(
      id: 'mock_challenge_1',
      ownerId: uid,
      title: 'October Grind',
      targetSessions: 12,
      startsAt: ago(day * 10),
      endsAt: now.add(day * 20),
      memberIds: [uid, 'user1', 'user3', 'user4', 'user5'],
      dateCreated: ago(day * 10),
    ),
    ChallengeModel(
      id: 'mock_challenge_2',
      ownerId: 'user1',
      title: 'Two-Week Kickstart',
      targetSessions: 6,
      startsAt: ago(day * 4),
      endsAt: now.add(day * 10),
      memberIds: ['user1', uid, 'user3'],
      dateCreated: ago(day * 4),
    ),
  ];
  final progress = {
    'mock_challenge_1': {uid: 5, 'user1': 7, 'user3': 4, 'user4': 2},
    'mock_challenge_2': {'user1': 3, uid: 6, 'user3': 1},
  };

  final share = ShareModel(
    id: 'sample-share-template',
    fromUserId: 'user1',
    toUserId: uid,
    payload: TemplateSharePayload(
      PrebuiltCatalogue.instance.workoutTemplates.first,
    ),
    dateCreated: ago(hour),
  );

  ActivityNotificationModel from(
    String id,
    ActivityType type,
    String actorId,
    String name,
    Duration before, {
    String sessionId = '',
    String? text,
    String? shareId,
    bool read = false,
  }) => ActivityNotificationModel(
    id: id,
    type: type,
    actorId: actorId,
    actorName: name,
    actorImageUrl: _avatar(name.split(' ').first.toLowerCase()),
    sessionId: sessionId,
    sessionAuthorId: uid,
    commentText: text,
    dateCreated: ago(before),
    isRead: read,
    shareId: shareId,
  );
  final nudgeDay = ago(hour * 3).toLocal();
  final notifications = [
    from(
      'like_${ownNewest.id}_user3',
      ActivityType.like,
      'user3',
      'Charlie Nguyen',
      hour * 2,
      sessionId: ownNewest.id,
    ),
    from(
      'comment_sample-comment-3',
      ActivityType.comment,
      'user1',
      'Maya Chen',
      hour,
      sessionId: ownNewest.id,
      text: 'Those pushdowns 🔥',
    ),
    from(
      'share_${share.id}',
      ActivityType.share,
      'user1',
      'Maya Chen',
      hour,
      text: PrebuiltCatalogue.instance.workoutTemplates.first.name,
      shareId: share.id,
    ),
    from(
      'nudge_user5_${nudgeDay.year}-'
          '${nudgeDay.month.toString().padLeft(2, '0')}-'
          '${nudgeDay.day.toString().padLeft(2, '0')}',
      ActivityType.nudge,
      'user5',
      'Dev Patel',
      hour * 3,
    ),
    from(
      'follow_user4',
      ActivityType.follow,
      'user4',
      'Priya Shah',
      day,
      read: true,
    ),
  ];

  return {
    for (final friend in friends)
      'users/${friend.userId}': friend.toFirestore(),
    for (final session in own)
      'users/$uid/workout_sessions/${session.id}': session.toFirestore(),
    for (final MapEntry(key: friend, value: sessions) in feed.entries)
      for (final session in sessions)
        'users/$friend/workout_sessions/${session[WorkoutSessionModelKeys.id]}':
            session,
    'usernames/alice.cooper': {UsernameReservationKeys.userId: uid},
    for (final friend in friends)
      if (friend.username case final handle?)
        'usernames/$handle': {
          UsernameReservationKeys.userId: friend.userId,
          UsernameReservationKeys.dateCreated: friend.creationDate,
        },
    'users/$uid/follow_requests/user2': FollowRequestModel(
      requesterId: 'user2',
      requesterName: 'Bob Martinez',
      requesterImageUrl: _avatar('bob'),
      dateCreated: ago(const Duration(minutes: 30)),
    ).toFirestore(),
    for (final comment in comments)
      'workout_session_comments/${comment.id}': comment.toFirestore(),
    for (final challenge in challenges)
      'challenges/${challenge.id}': challenge.toFirestore(),
    for (final MapEntry(key: challengeId, value: counts) in progress.entries)
      for (final MapEntry(key: member, value: sessions) in counts.entries)
        'challenges/$challengeId/progress/$member': ChallengeProgressModel(
          sessions: sessions,
          updatedAt: ago(hour * 6),
        ).toFirestore(),
    'invites/PUSH2345': InviteModel(
      code: 'PUSH2345',
      inviterId: 'user1',
      dateCreated: ago(day * 30),
    ).toFirestore(),
    'shares/${share.id}': share.toFirestore(),
    for (final notification in notifications)
      'users/$uid/notifications/${notification.id}': notification.toFirestore(),
  };
}

String _avatar(String seed) => 'https://picsum.photos/seed/$seed/200';

UserModel _friend(
  String id,
  String first,
  String last,
  String? username,
  DateTime created,
  List<String> following, {
  bool? isPrivate,
  List<String>? blocked,
}) => UserModel(
  userId: id,
  email: '${first.toLowerCase()}@example.com',
  isAnonymous: false,
  displayName: '$first $last',
  firstName: first,
  lastName: last,
  submittedFirstName: first,
  submittedLastName: last,
  photoUrl: _avatar(first.toLowerCase()),
  submittedProfileImage: _avatar(first.toLowerCase()),
  creationDate: created,
  didCompleteOnboarding: true,
  followingIds: following,
  username: username,
  isPrivate: isPrivate,
  blockedUserIds: blocked,
);
