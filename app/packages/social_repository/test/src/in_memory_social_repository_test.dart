import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/contract.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);
  final viewer = sampleUser(now: now);

  test('every sample document reads back through its model', () async {
    final firestore = FakeFirebaseFirestore();
    for (final MapEntry(key: path, value: data) in sampleSocial(
      uid: sampleUserId,
      now: now,
    ).entries) {
      await firestore.doc(path).set(asStored(data));
    }
    final errors = <String>[];
    final subject = SocialRepository(
      firestore: firestore,
      callFunction: (_, _) async => null,
      users: InMemoryUserRepository(),
      onDecodeError: (path, _, _) => errors.add(path),
    );

    final everyone = await subject.users([
      for (var i = 1; i <= 6; i++) 'user$i',
    ], viewer: viewer);
    expect(everyone, hasLength(6));
    expect(
      await subject.watchFollowingSessions(viewer.followingIds!).first,
      hasLength(8),
    );
    final comments = [
      for (final session in await subject.sessionsByAuthor('user1'))
        ...await subject.comments(session.id),
      ...await subject.comments(
        sampleWorkoutSessions(uid: sampleUserId, now: now).last.id,
      ),
    ];
    expect(comments, hasLength(3));
    expect(await subject.challenges(sampleUserId), hasLength(2));
    expect(await subject.challengeProgress('mock_challenge_1'), hasLength(4));
    expect(await subject.notifications(sampleUserId), hasLength(5));
    expect(await subject.share('sample-share-template'), isNotNull);
    expect(
      await subject.watchIncomingFollowRequests(viewer).first,
      hasLength(1),
    );
    expect(errors, isEmpty);
  });

  group('inMemorySocialRepository', () {
    late SocialRepository subject;

    setUp(() async {
      subject = await inMemorySocialRepository(
        users: InMemoryUserRepository(users: {sampleUserId: viewer}),
        now: now,
      );
    });

    test('is the sample world around the signed-in user', () async {
      final following = await subject.watchFollowingUsers(viewer).first;
      expect(following.map((user) => user.userId), [
        'user1',
        'user3',
        'user4',
        'user5',
      ]);
      expect(
        (await subject.suggestedUsers(viewer: viewer)).map((u) => u.userId),
        ['user6'],
      );
      expect(
        await subject.isUsernameAvailable('alice.cooper', viewer: viewer),
        isTrue,
      );
      expect(
        await subject.isUsernameAvailable('charlie.c', viewer: viewer),
        isFalse,
      );
    });

    test('accepts invites as the function would refuse them', () async {
      final acceptance = await subject.acceptInvite('push 2345');
      expect(acceptance.inviterId, 'user1');
      expect(acceptance.youFollow, InviteOutcome.following);

      Matcher failure(InviteFailure failure) => throwsA(
        isA<InviteException>().having((e) => e.failure, 'failure', failure),
      );
      await expectLater(
        subject.acceptInvite('ZZZZ2345'),
        failure(InviteFailure.notFound),
      );
      final own = await subject.myInvite(sampleUserId);
      await expectLater(
        subject.acceptInvite(own.code),
        failure(InviteFailure.ownInvite),
      );
      for (var i = 1; i < InviteModel.defaultMaxUses; i++) {
        await subject.acceptInvite('PUSH2345');
      }
      await expectLater(
        subject.acceptInvite('PUSH2345'),
        failure(InviteFailure.exhausted),
      );
    });

    test('removes a follower as the function would', () async {
      expect(
        (await subject.followersOf(
          sampleUserId,
          viewer: viewer,
        )).map((u) => u.userId),
        contains('user4'),
      );
      await subject.removeFollower('user4');
      expect(
        (await subject.followersOf(
          sampleUserId,
          viewer: viewer,
        )).map((u) => u.userId),
        isNot(contains('user4')),
      );
      final notifications = await subject.notifications(sampleUserId);
      expect(notifications.map((n) => n.id), isNot(contains('follow_user4')));
    });
  });

  test('stagingCallFunction refuses a function it does not play', () async {
    await expectLater(
      stagingCallFunction(FakeFirebaseFirestore(), sampleUserId)('other', {}),
      throwsA(
        isA<FirebaseFunctionsException>().having(
          (e) => e.code,
          'code',
          'not-found',
        ),
      ),
    );
  });
}
