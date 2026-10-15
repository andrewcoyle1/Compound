import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/contract.dart';

class _MockFunctions extends Mock implements FirebaseFunctions;

class _MockCallable extends Mock implements HttpsCallable;

class _MockResult extends Mock implements HttpsCallableResult<Object?>;

// The two parties of the social fixtures: Ada writes, Grace is on the other
// end (contracts/firestore/*/full.json).
const ada = 'user_contract_full';
const grace = 'user_contract_friend';

final adaUser = UserModel(
  userId: ada,
  submittedFirstName: 'Ada',
  submittedLastName: 'Lovelace',
  submittedProfileImage: 'https://example.com/ada.jpg',
  creationDate: DateTime.utc(2025),
  didCompleteOnboarding: true,
  followingIds: const [grace],
);

UserModel person(
  String id, {
  String? first,
  String? username,
  List<String>? following,
  List<String>? blocked,
  bool? isPrivate,
  int createdDay = 1,
}) => UserModel(
  userId: id,
  submittedFirstName: first,
  username: username,
  followingIds: following,
  blockedUserIds: blocked,
  isPrivate: isPrivate,
  creationDate: DateTime.utc(2026, 1, createdDay),
  didCompleteOnboarding: true,
);

/// The keys every notification the repository writes may and must have:
/// those of the full and minimal fixtures, and it decodes.
void expectNotificationShape(String id, Map<String, Object?> written) {
  final full = taggedFixture('activity_notification', 'full').keys.toSet();
  final minimal = taggedFixture('activity_notification', 'minimal').keys;
  expect(full.containsAll(written.keys), isTrue, reason: '$written');
  expect(written.keys.toSet().containsAll(minimal), isTrue, reason: '$written');
  ActivityNotificationModel.fromFirestore(id, taggedJsonToFirestore(written));
}

void main() {
  late FakeFirebaseFirestore firestore;
  late InMemoryUserRepository users;
  late List<(String, Map<String, Object?>)> calls;
  late Object? Function(String name) answer;
  late List<String> decodeErrors;
  late List<String> newIds;
  late List<String> newCodes;
  var now = DateTime.utc(2026, 10, 14, 9, 10, 11, 125);
  late SocialRepository subject;

  Future<void> put(String path, Map<String, Object?> data) =>
      firestore.doc(path).set(asStored(data));

  Future<Map<String, Object?>?> stored(String path) async {
    final data = (await firestore.doc(path).get()).data();
    return data == null ? null : storedAsTagged(data);
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    users = InMemoryUserRepository(users: {ada: adaUser});
    calls = [];
    answer = (_) => null;
    decodeErrors = [];
    newIds = [];
    newCodes = [];
    now = DateTime.utc(2026, 10, 14, 9, 10, 11, 125);
    subject = SocialRepository(
      firestore: firestore,
      callFunction: (name, data) async {
        calls.add((name, data));
        return answer(name);
      },
      users: users,
      onDecodeError: (path, _, _) => decodeErrors.add(path),
      now: () => now,
      newId: () => newIds.removeAt(0),
      newInviteCode: () => newCodes.removeAt(0),
    );
  });

  Future<UserModel> profile() async => (await users.watchUser(ada).first)!;

  group('people', () {
    setUp(() async {
      for (final user in [
        person('fan', first: 'Fan', following: [ada], createdDay: 2),
        person('foe', first: 'Foe', following: [ada]),
        person('adam', first: 'Adam', username: 'adam'),
        person('adah', first: 'Bob', username: 'ada.h', createdDay: 5),
        person('hidden', first: 'Hidden', isPrivate: true, createdDay: 9),
      ]) {
        await put('users/${user.userId}', user.toFirestore());
      }
      await put('users/broken', {
        'user_id': 'broken',
        'creation_date': DateTime.utc(2020),
      });
    });

    final viewer = person(ada, following: ['adam'], blocked: ['foe']);

    test('followersOf: who follows, less the blocked', () async {
      final found = await subject.followersOf(ada, viewer: viewer);
      expect(found.map((user) => user.userId), ['fan']);
    });

    test('searchUsers: handle matches first, each once, less the blocked; '
        'the name capitalised', () async {
      final found = await subject.searchUsers('ada', viewer: viewer);
      expect(
        found.map((user) => user.userId),
        unorderedEquals(['adah', 'adam']),
      );
      expect(
        (await subject.searchUsers('@fo', viewer: viewer)).map((u) => u.userId),
        isEmpty,
      );
      expect(await subject.searchUsers('Fan Club', viewer: viewer), isEmpty);
      expect(
        (await subject.searchUsers('fa', viewer: viewer)).map((u) => u.userId),
        ['fan'],
      );
    });

    test('suggestedUsers: newest first, less the viewer, followed, blocked '
        'and private', () async {
      await put('users/$ada', viewer.toFirestore());
      final found = await subject.suggestedUsers(viewer: viewer, limit: 2);
      expect(found.map((user) => user.userId), ['adah', 'fan']);
    });

    test('users: by id, 30 to a query, less the blocked and the missing; '
        'reports the unreadable', () async {
      final ids = [
        for (var i = 0; i < 30; i++) 'none-$i',
        'fan',
        'foe',
        'broken',
      ];
      final found = await subject.users(ids, viewer: viewer);
      expect(found.map((user) => user.userId), ['fan']);
      expect(decodeErrors, ['users/broken']);
      expect(await subject.users(const [], viewer: viewer), isEmpty);
    });

    test(
      'watchFollowingUsers: the first 30 followed, less the blocked',
      () async {
        final watching = person(
          ada,
          following: ['fan', 'foe', for (var i = 0; i < 40; i++) 'none-$i'],
          blocked: ['foe'],
        );
        final found = await subject.watchFollowingUsers(watching).first;
        expect(found.map((user) => user.userId), ['fan']);
        expect(await subject.watchFollowingUsers(person(ada)).first, isEmpty);
      },
    );
  });

  group('sessions', () {
    Future<void> session(String author, String id, int day) =>
        put('users/$author/workout_sessions/$id', {
          ...modelFixture('workout_session', 'full'),
          'id': id,
          'author_id': author,
          'date_created': DateTime.utc(2026, 10, day),
        });

    setUp(() async {
      await session('fan', 'a', 1);
      await session('fan', 'b', 3);
      await session('other', 'c', 2);
      await session('late', 'd', 4);
      // Older than the rest: the fake, unlike Firestore, orders a document
      // without the field first.
      await put('users/fan/workout_sessions/bad', {
        'author_id': 'fan',
        'date_created': DateTime.utc(2026, 9),
      });
    });

    test('watchFollowingSessions: the first 30 authors, newest first, nested '
        'fields read back exactly', () async {
      final feed = await subject.watchFollowingSessions([
        'fan',
        'other',
        for (var i = 0; i < 28; i++) 'none-$i',
        'late',
      ]).first;
      expect(feed.map((session) => session.id), ['b', 'c', 'a']);
      expect(firestoreToTaggedJson(feed.last.toFirestore()), {
        ...taggedFixture('workout_session', 'full'),
        'id': 'a',
        'author_id': 'fan',
        'date_created': {r'$timestamp': '2026-10-01T00:00:00.000Z'},
      });
      expect(await subject.watchFollowingSessions(const []).first, isEmpty);
    });

    test('sessionsByAuthor and sessionById', () async {
      expect(
        (await subject.sessionsByAuthor('fan', limit: 1)).map((s) => s.id),
        ['b'],
      );
      expect((await subject.sessionsByAuthor('fan')).map((s) => s.id), [
        'b',
        'a',
      ]);
      expect((await subject.sessionById('c', authorId: 'other'))!.id, 'c');
      expect(await subject.sessionById('c', authorId: 'fan'), isNull);
    });
  });

  group('follows', () {
    test('follow adds the id once and tells the followed user', () async {
      await subject.follow('fan', viewer: adaUser);
      await subject.follow(grace, viewer: await profile());

      expect((await profile()).followingIds, [grace, 'fan']);
      final notification = await stored('users/fan/notifications/follow_$ada');
      expectNotificationShape('follow_$ada', notification!);
      expect(notification, {
        'type': 'follow',
        'actor_id': ada,
        'actor_name': 'Ada Lovelace',
        'actor_image_url': 'https://example.com/ada.jpg',
        'session_id': '',
        'session_author_id': 'fan',
        'date_created': {r'$timestamp': '2026-10-14T09:10:11.125Z'},
        'is_read': false,
      });
    });

    test('unfollow removes the id and the follow notification', () async {
      await subject.follow('fan', viewer: adaUser);
      await subject.unfollow('fan', viewer: await profile());

      expect((await profile()).followingIds, [grace]);
      expect(await stored('users/fan/notifications/follow_$ada'), isNull);
    });

    test('block drops the follow in the same write and its notification; '
        'unblock lifts it', () async {
      await subject.follow('fan', viewer: adaUser);
      await subject.block('fan', viewer: await profile());
      await subject.block('fan', viewer: await profile());
      await subject.block('stranger', viewer: await profile());

      expect((await profile()).followingIds, [grace]);
      expect((await profile()).blockedUserIds, ['fan', 'stranger']);
      expect(await stored('users/fan/notifications/follow_$ada'), isNull);

      await subject.unblock('fan', viewer: await profile());
      expect((await profile()).blockedUserIds, ['stranger']);
    });

    test('nudge writes one notification a local day', () async {
      now = DateTime(2026, 10, 14, 23, 30).toUtc();
      await subject.nudge(grace, viewer: adaUser);
      final notification = await stored(
        'users/$grace/notifications/nudge_${ada}_2026-10-14',
      );
      expectNotificationShape('n', notification!);
      expect(notification['type'], 'nudge');
    });

    test('removeFollower calls the function', () async {
      await subject.removeFollower('fan');
      expect(calls.single.$1, 'removeFollower');
      expect(calls.single.$2, {'followerId': 'fan'});
    });
  });

  group('follow requests', () {
    const path = 'users/$grace/follow_requests/$ada';

    test('sendFollowRequest writes the full and minimal fixtures', () async {
      await subject.sendFollowRequest(grace, viewer: adaUser);
      expect(
        await stored(path),
        strictlyEquals(taggedFixture('follow_request', 'full')),
      );

      await subject.sendFollowRequest(
        grace,
        viewer: const UserModel(
          userId: ada,
          firstName: 'Ada',
          lastName: 'Lovelace',
        ),
      );
      expect(
        await stored(path),
        strictlyEquals(taggedFixture('follow_request', 'minimal')),
      );

      await subject.sendFollowRequest(
        grace,
        viewer: const UserModel(userId: ada),
      );
      expect((await stored(path))!['requester_name'], 'Someone');
    });

    test('answerFollowRequest writes status alone', () async {
      await put(path, modelFixture('follow_request', 'full'));
      await subject.answerFollowRequest(ada, targetId: grace, accept: true);
      expect(
        await stored(path),
        strictlyEquals({
          ...taggedFixture('follow_request', 'full'),
          'status': 'accepted',
        }),
      );
      await subject.answerFollowRequest(ada, targetId: grace, accept: false);
      expect((await stored(path))!['status'], 'declined');
    });

    test('cancelFollowRequest deletes it', () async {
      await put(path, modelFixture('follow_request', 'full'));
      await subject.cancelFollowRequest(grace, requesterId: ada);
      expect(await stored(path), isNull);
    });

    test('watchIncomingFollowRequests: pending, newest first, less the '
        'blocked', () async {
      FollowRequestModel request(String id, int day, [String? status]) =>
          FollowRequestModel(
            requesterId: id,
            requesterName: id,
            dateCreated: DateTime.utc(2026, 10, day),
            status: status == null
                ? FollowRequestStatus.pending
                : FollowRequestStatus.declined,
          );
      for (final item in [
        request('old', 1),
        request('new', 3),
        request('blocked', 4),
        request('declined', 5, 'declined'),
      ]) {
        await put(
          'users/$ada/follow_requests/${item.requesterId}',
          item.toFirestore(),
        );
      }
      await put('users/$ada/follow_requests/bad', {'status': 'pending'});

      final requests = await subject
          .watchIncomingFollowRequests(person(ada, blocked: ['blocked']))
          .first;
      expect(requests.map((r) => r.requesterId), ['new', 'old']);
      expect(decodeErrors, ['users/$ada/follow_requests/bad']);
    });

    test(
      'sentFollowRequestTargetIds: the targets of pending requests',
      () async {
        await put(path, modelFixture('follow_request', 'full'));
        await put('users/other/follow_requests/$ada', {
          ...modelFixture('follow_request', 'full'),
          'status': 'declined',
        });
        expect(await subject.sentFollowRequestTargetIds(ada), [grace]);
      },
    );
  });

  group('likes', () {
    const sessionPath = 'users/$grace/workout_sessions/s1';

    setUp(
      () => put(sessionPath, {
        ...modelFixture('workout_session', 'full'),
        'id': 's1',
        'author_id': grace,
        'liked_by_user_ids': ['someone'],
      }),
    );

    test('likeSession adds only the viewer and tells the author; '
        'unlikeSession takes both back', () async {
      await subject.likeSession('s1', authorId: grace, viewer: adaUser);
      expect((await stored(sessionPath))!['liked_by_user_ids'], [
        'someone',
        ada,
      ]);
      final notification = await stored(
        'users/$grace/notifications/like_s1_$ada',
      );
      expectNotificationShape('like', notification!);
      expect(notification['session_id'], 's1');
      expect(notification['type'], 'like');

      await subject.unlikeSession('s1', authorId: grace, viewer: adaUser);
      expect((await stored(sessionPath))!['liked_by_user_ids'], ['someone']);
      expect(await stored('users/$grace/notifications/like_s1_$ada'), isNull);
    });

    test('liking your own session tells nobody', () async {
      final grace0 = person(grace);
      await subject.likeSession('s1', authorId: grace, viewer: grace0);
      expect(await stored('users/$grace/notifications/like_s1_$grace'), isNull);
      await subject.unlikeSession('s1', authorId: grace, viewer: grace0);
      expect((await stored(sessionPath))!['liked_by_user_ids'], ['someone']);
    });
  });

  group('comments', () {
    WorkoutSessionComment fixture(String name) =>
        WorkoutSessionComment.fromFirestore(
          modelFixture('session_comment', name),
        );

    test("comments: the session's, less deleted ones, null deleted_at "
        'included; reports the unreadable', () async {
      await put('workout_session_comments/a', {
        ...modelFixture('session_comment', 'minimal'),
        'id': 'stored-id',
      });
      await put('workout_session_comments/gone', {
        ...modelFixture('session_comment', 'minimal'),
        'deleted_at': null,
      });
      await put(
        'workout_session_comments/full',
        modelFixture('session_comment', 'full'),
      );
      await put('workout_session_comments/bad', {
        'session_id': 'session_contract_full',
      });

      final found = await subject.comments('session_contract_full');
      expect(found.map((comment) => comment.id), ['a']);
      expect(decodeErrors, ['workout_session_comments/bad']);
    });

    test('addComment writes the minimal fixture exactly, and the full one '
        'less what only others set', () async {
      await subject.addComment(fixture('minimal'));
      expect(
        await stored('workout_session_comments/comment_contract_minimal'),
        strictlyEquals(taggedFixture('session_comment', 'minimal')),
      );
      final notification = await stored(
        'users/$grace/notifications/comment_comment_contract_minimal',
      );
      expectNotificationShape('c', notification!);
      expect(notification['is_read'], false);

      await subject.addComment(fixture('full'));
      expect(
        await stored('workout_session_comments/comment_contract_full'),
        strictlyEquals(
          taggedFixture('session_comment', 'full')
            ..remove('deleted_at')
            ..remove('liked_by_user_ids')
            ..remove('hidden'),
        ),
      );
    });

    test("a reply tells the parent's author, unless the parent is deleted "
        'or elsewhere', () async {
      final reply = WorkoutSessionComment(
        id: 'r1',
        sessionId: 's1',
        sessionAuthorId: grace,
        authorId: ada,
        text: 'Thanks',
        dateCreated: now,
        parentId: 'p1',
      );
      Future<void> parent(Map<String, Object?> overrides) =>
          put('workout_session_comments/p1', {
            ...modelFixture('session_comment', 'minimal'),
            'id': 'p1',
            'session_id': 's1',
            'author_id': 'parent',
            ...overrides,
          });
      Future<Map<String, Object?>?> parentHeard() =>
          stored('users/parent/notifications/comment_r1');

      await subject.addComment(reply);
      expect(await parentHeard(), isNull);

      await parent({'session_id': 'other'});
      await subject.addComment(reply);
      expect(await parentHeard(), isNull);

      await parent({'deleted_at': now});
      await subject.addComment(reply);
      expect(await parentHeard(), isNull);

      await parent({});
      await subject.addComment(reply);
      expect((await parentHeard())!['is_reply'], true);
    });

    test('deleteComment sets deleted_at alone', () async {
      await put(
        'workout_session_comments/comment_contract_minimal',
        modelFixture('session_comment', 'minimal'),
      );
      now = DateTime.utc(2026, 10, 14, 11, 30, 0, 500);
      await subject.deleteComment('comment_contract_minimal');
      expect(
        await stored('workout_session_comments/comment_contract_minimal'),
        strictlyEquals({
          ...taggedFixture('session_comment', 'minimal'),
          'deleted_at': {r'$timestamp': '2026-10-14T11:30:00.500Z'},
        }),
      );
    });

    test('setCommentLike sets the state for one user', () async {
      const path = 'workout_session_comments/comment_contract_minimal';
      await put(path, modelFixture('session_comment', 'minimal'));
      await subject.setCommentLike(
        'comment_contract_minimal',
        userId: grace,
        liked: true,
      );
      await subject.setCommentLike(
        'comment_contract_minimal',
        userId: grace,
        liked: true,
      );
      expect((await stored(path))!['liked_by_user_ids'], [grace]);
      await subject.setCommentLike(
        'comment_contract_minimal',
        userId: grace,
        liked: false,
      );
      expect((await stored(path))!['liked_by_user_ids'], isEmpty);
    });
  });

  group('notifications', () {
    Future<void> notification(String id, int minute, {bool read = false}) =>
        put('users/$ada/notifications/$id', {
          ...modelFixture('activity_notification', 'minimal'),
          'date_created': DateTime.utc(2026, 10, 14, 9, minute),
          'is_read': read,
        });

    test('pages newest first, 50 at a time, after a date', () async {
      for (var i = 0; i < 52; i++) {
        await notification('n$i', i, read: i.isEven);
      }
      await put('users/$ada/notifications/bad', {
        'type': 'unknown',
        'date_created': DateTime.utc(2026),
      });

      final first = await subject.notifications(ada);
      expect(first, hasLength(SocialRepository.notificationPageSize));
      expect(first.first.id, 'n51');
      expect(first.last.id, 'n2');
      expect(decodeErrors, isEmpty);
      // fake_cloud_firestore's cursors assume an ascending order, so after a
      // descending page it finds nothing; Firestore answers n1, n0 and the
      // unreadable one. Only that the query runs is checked here.
      await subject.notifications(ada, before: first.last.dateCreated);
    });

    test('watchNewNotifications: only those added after it starts', () async {
      await notification('old', 0);
      final arrivals = <String>[];
      final subscription = subject
          .watchNewNotifications(ada)
          .listen((n) => arrivals.add(n.id));
      await pumpEventQueue();
      await notification('new', 20);
      await firestore.doc('users/$ada/notifications/new').update({
        'is_read': true,
      });
      await pumpEventQueue();
      await subscription.cancel();
      expect(arrivals, ['new']);
    });

    test('markNotificationsRead and markAllNotificationsRead set is_read '
        'alone, 500 to a batch', () async {
      for (var i = 0; i < 502; i++) {
        await notification('n$i', 0);
      }
      await subject.markNotificationsRead(ada, ['n0', 'n1']);
      await subject.markNotificationsRead(ada, const []);
      expect(
        await stored('users/$ada/notifications/n0'),
        strictlyEquals({
          ...taggedFixture('activity_notification', 'minimal'),
          'date_created': {r'$timestamp': '2026-10-14T09:00:00.000Z'},
          'is_read': true,
        }),
      );
      expect((await stored('users/$ada/notifications/n2'))!['is_read'], false);

      await subject.markAllNotificationsRead(ada);
      final unread = await firestore
          .collection('users/$ada/notifications')
          .where('is_read', isEqualTo: false)
          .get();
      expect(unread.docs, isEmpty);
    });

    test('deleteNotification', () async {
      await notification('n0', 0);
      await subject.deleteNotification(ada, 'n0');
      expect(await stored('users/$ada/notifications/n0'), isNull);
    });
  });

  group('challenges', () {
    test("createChallenge writes the fixtures; challenges lists a member's, "
        'soonest ending first', () async {
      for (final name in ['full', 'minimal']) {
        final challenge = ChallengeModel.fromFirestore(
          modelFixture('challenge', name),
        );
        await subject.createChallenge(challenge);
        expect(
          await stored('challenges/${challenge.id}'),
          strictlyEquals(taggedFixture('challenge', name)),
        );
      }
      await put('challenges/bad', {
        'member_ids': [ada],
      });

      expect((await subject.challenges(ada)).map((c) => c.id), [
        'challenge_contract_minimal',
        'challenge_contract_full',
      ]);
      expect((await subject.challenges(grace)).map((c) => c.id), [
        'challenge_contract_full',
      ]);
      expect(decodeErrors, ['challenges/bad']);
    });

    test('challenge reads one, or null', () async {
      await put('challenges/c', modelFixture('challenge', 'full'));
      await put('challenges/bad', {'title': 'x'});
      expect((await subject.challenge('c'))!.title, 'October Grind');
      expect(await subject.challenge('none'), isNull);
      expect(await subject.challenge('bad'), isNull);
    });

    test('challengeProgress: sessions per member', () async {
      await put(
        'challenges/c/progress/$ada',
        modelFixture('challenge_progress', 'full'),
      );
      await put('challenges/c/progress/bad', {'sessions': 'x'});
      expect(await subject.challengeProgress('c'), {
        ada: ChallengeProgressModel.fromFirestore(
          modelFixture('challenge_progress', 'full'),
        ).sessions,
      });
    });

    test('leaveChallenge takes only the member out', () async {
      await put('challenges/c', modelFixture('challenge', 'full'));
      await subject.leaveChallenge('c', userId: grace);
      expect(
        await stored('challenges/c'),
        strictlyEquals({
          ...taggedFixture('challenge', 'full'),
          'member_ids': [ada],
        }),
      );
    });
  });

  group('invites', () {
    test('myInvite creates the full fixture with a free code', () async {
      await put('invites/TAKEN234', {
        ...modelFixture('invite', 'minimal'),
        'code': 'TAKEN234',
        'inviter_id': 'other',
      });
      newCodes = ['TAKEN234', 'ABCD2345'];
      now = DateTime.utc(2026, 10, 2, 12);

      final created = await subject.myInvite(ada);
      expect(created.code, 'ABCD2345');
      expect(
        await stored('invites/ABCD2345'),
        strictlyEquals(taggedFixture('invite', 'full')),
      );
      expect((await subject.myInvite(ada)).code, 'ABCD2345');
    });

    test('myInvite gives up after five taken codes', () async {
      for (final code in ['AAAA2345', 'BBBB2345']) {
        await put('invites/$code', {
          ...modelFixture('invite', 'minimal'),
          'code': code,
          'inviter_id': 'other',
        });
      }
      newCodes = ['AAAA2345', 'BBBB2345', 'AAAA2345', 'BBBB2345', 'AAAA2345'];
      await expectLater(
        subject.myInvite(ada),
        throwsA(
          isA<InviteException>().having(
            (e) => e.failure,
            'failure',
            InviteFailure.noFreeCode,
          ),
        ),
      );
    });

    test('acceptInvite normalises the code and reads the outcome', () async {
      answer = (_) => <Object?, Object?>{
        'inviter_id': grace,
        'you_follow': 'following',
        'they_follow': 'requested',
      };
      final acceptance = await subject.acceptInvite('abcd-2345');
      expect(calls.single.$1, 'acceptInvite');
      expect(calls.single.$2, {'code': 'ABCD2345'});
      expect(acceptance.inviterId, grace);
      expect(acceptance.youFollow, InviteOutcome.following);
      expect(acceptance.theyFollow, InviteOutcome.requested);
    });

    Matcher failure(InviteFailure failure) => throwsA(
      isA<InviteException>()
          .having((e) => e.failure, 'failure', failure)
          .having((e) => e.toString(), 'toString', contains('$failure')),
    );

    test('acceptInvite refuses a bad code without calling', () async {
      await expectLater(
        subject.acceptInvite('nope'),
        failure(InviteFailure.invalidCode),
      );
      expect(calls, isEmpty);
    });

    test("acceptInvite maps the function's refusals", () async {
      for (final (code, expected) in [
        ('invalid-argument', InviteFailure.invalidCode),
        ('not-found', InviteFailure.notFound),
        ('failed-precondition', InviteFailure.ownInvite),
        ('resource-exhausted', InviteFailure.exhausted),
        ('permission-denied', InviteFailure.unavailable),
      ]) {
        answer = (_) =>
            throw FirebaseFunctionsException(message: code, code: code);
        await expectLater(subject.acceptInvite('ABCD2345'), failure(expected));
      }
      answer = (_) =>
          throw FirebaseFunctionsException(message: 'x', code: 'internal');
      await expectLater(
        subject.acceptInvite('ABCD2345'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('acceptInvite refuses an unreadable answer', () async {
      for (final data in [
        null,
        {'inviter_id': grace, 'you_follow': 'x', 'they_follow': 'following'},
        {'inviter_id': grace, 'you_follow': 'following', 'they_follow': 'x'},
      ]) {
        answer = (_) => data;
        await expectLater(
          subject.acceptInvite('ABCD2345'),
          failure(InviteFailure.unexpectedResponse),
        );
      }
    });
  });

  group('shares', () {
    test('sendShare writes the fixtures and tells each recipient', () async {
      for (final name in ['full', 'minimal']) {
        final fixture = ShareModel.fromFirestore(modelFixture('share', name));
        newIds = [fixture.id];
        now = fixture.dateCreated;
        await subject.sendShare(
          fixture.payload,
          recipientIds: [grace],
          viewer: adaUser,
        );
        expect(
          await stored('shares/${fixture.id}'),
          strictlyEquals(taggedFixture('share', name)),
        );
        final notification = await stored(
          'users/$grace/notifications/share_${fixture.id}',
        );
        expectNotificationShape('s', notification!);
        expect(notification['share_id'], fixture.id);
        expect(notification['comment_text'], switch (fixture.payload) {
          TemplateSharePayload(:final template) => template.name,
          MesocycleSharePayload(:final mesocycle) => mesocycle.name,
        });
      }

      newIds = ['one', 'two'];
      await subject.sendShare(
        ShareModel.fromFirestore(modelFixture('share', 'minimal')).payload,
        recipientIds: ['a', 'b'],
        viewer: const UserModel(userId: ada),
      );
      expect((await stored('shares/two'))!['to_user_id'], 'b');
      expect(
        (await stored('users/a/notifications/share_one'))!['actor_name'],
        'Someone',
      );
    });

    test('share reads one, or null; answerShare writes status alone', () async {
      await put('shares/s', modelFixture('share', 'full'));
      await put('shares/bad', {'kind': 'template'});
      expect((await subject.share('s'))!.toUserId, grace);
      expect(await subject.share('none'), isNull);
      expect(await subject.share('bad'), isNull);

      await subject.answerShare('s', ShareStatus.dismissed);
      expect(
        await stored('shares/s'),
        strictlyEquals({
          ...taggedFixture('share', 'full'),
          'status': 'dismissed',
        }),
      );
    });
  });

  test('report writes the full and minimal fixtures', () async {
    for (final name in ['full', 'minimal']) {
      final fixture = ReportModel.fromFirestore(modelFixture('report', name));
      newIds = [fixture.id];
      now = fixture.dateCreated;
      await subject.report(
        reporterId: fixture.reporterId,
        targetType: fixture.targetType,
        targetId: fixture.targetId,
        targetAuthorId: fixture.targetAuthorId,
        reason: fixture.reason,
        note: fixture.note,
      );
      expect(
        await stored('reports/${fixture.id}'),
        strictlyEquals(taggedFixture('report', name)),
      );
    }
  });

  group('usernames', () {
    setUp(() => put('usernames/taken', {'user_id': grace}));

    test("isUsernameAvailable: free or the viewer's, never invalid", () async {
      await put('usernames/mine', {'user_id': ada});
      expect(
        await subject.isUsernameAvailable('@Free', viewer: adaUser),
        isTrue,
      );
      expect(
        await subject.isUsernameAvailable('mine', viewer: adaUser),
        isTrue,
      );
      expect(
        await subject.isUsernameAvailable('taken', viewer: adaUser),
        isFalse,
      );
      expect(await subject.isUsernameAvailable('x', viewer: adaUser), isFalse);
    });

    test(
      'claimUsername reserves the handle, then sets it on the profile',
      () async {
        await subject.claimUsername(' @Ada_L ', viewer: adaUser);
        final reservation = (await firestore.doc('usernames/ada_l').get())
            .data()!;
        expect(reservation.keys.toSet(), {'user_id', 'date_created'});
        expect(reservation['user_id'], ada);
        expect(reservation['date_created'], isA<Timestamp>());
        expect((await profile()).username, 'ada_l');
      },
    );

    test('claimUsername finishes a claim the viewer already reserved, and '
        'skips their current handle', () async {
      await put('usernames/mine', {'user_id': ada});
      await subject.claimUsername('mine', viewer: adaUser);
      expect((await profile()).username, 'mine');
      await subject.claimUsername('mine', viewer: await profile());
    });

    test('claimUsername refuses an invalid or taken handle', () async {
      Matcher failure(UsernameFailure failure) => throwsA(
        isA<UsernameException>()
            .having((e) => e.failure, 'failure', failure)
            .having((e) => '$e', 'toString', contains('$failure')),
      );
      await expectLater(
        subject.claimUsername('a', viewer: adaUser),
        failure(UsernameFailure.invalid),
      );
      await expectLater(
        subject.claimUsername('taken', viewer: adaUser),
        failure(UsernameFailure.taken),
      );
      expect((await profile()).username, isNull);
    });
  });

  test(
    'defaults: ids, codes and now are generated; decode errors logged',
    () async {
      final plain = SocialRepository(
        firestore: firestore,
        callFunction: (_, _) async => null,
        users: users,
      );
      await plain.report(
        reporterId: ada,
        targetType: ReportContentType.user,
        targetId: grace,
        reason: ReportReason.spam,
      );
      final report = (await firestore.collection('reports').get()).docs.single;
      expect(report.id, matches(RegExp(r'^[0-9A-F-]{36}$')));
      final invite = await plain.myInvite(ada);
      expect(InviteCode.normalised(invite.code), invite.code);
      await put('challenges/bad', {'title': 'x'});
      expect(await plain.challenge('bad'), isNull);
    },
  );

  test('callFirebaseFunction calls the named callable', () async {
    final functions = _MockFunctions();
    final callable = _MockCallable();
    final result = _MockResult();
    when(() => functions.httpsCallable('removeFollower')).thenReturn(callable);
    when(() => callable.call<Object?>(any<Object?>()))
        .thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'removed': 'fan'});

    final data = await callFirebaseFunction(functions)('removeFollower', {
      'followerId': 'fan',
    });

    expect(data, {'removed': 'fan'});
    verify(() => callable.call<Object?>({'followerId': 'fan'})).called(1);
  });
}
