import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The repository's writes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy). Reserving a handle is
// the one write that waits for the server.
void main() {
  group('SocialRepository offline', () {
    const ada = 'user_contract_full';
    const grace = 'user_contract_friend';
    const viewer = UserModel(
      userId: ada,
      firstName: 'Ada',
      followingIds: [grace],
      didCompleteOnboarding: true,
    );
    late OfflineFirestore firestore;
    late List<(String, String)> refused;
    late SocialRepository subject;

    // FieldValue binds to whichever factory is installed when first called;
    // fake_cloud_firestore installs its own only when a fake is built.
    setUpAll(FakeFirebaseFirestore.new);

    setUp(() {
      firestore = OfflineFirestore();
      refused = [];
      subject = SocialRepository(
        firestore: firestore,
        callFunction: (_, _) async => null,
        users: InMemoryUserRepository(users: {ada: viewer}),
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
        now: () => DateTime.utc(2026, 10, 14),
        newId: () => 'id',
        newInviteCode: () => 'ABCD2345',
      );
    });

    test('every write completes offline; a refusal is reported', () async {
      firestore.cached['workout_session_comments/parent'] = storedFixture(
        'session_comment',
        'minimal',
      );
      firestore.cached['users/$ada/notifications/n1'] = {'is_read': false};
      final share = ShareModel.fromFirestore(modelFixture('share', 'minimal'));
      final comment = WorkoutSessionComment(
        id: 'c1',
        sessionId: 'session_contract_full',
        sessionAuthorId: grace,
        authorId: ada,
        text: 'Hi',
        dateCreated: DateTime.utc(2026, 10, 14),
        parentId: 'parent',
      );

      await subject.follow('fan', viewer: viewer);
      await subject.unfollow(grace, viewer: viewer);
      await subject.block(grace, viewer: viewer);
      await subject.nudge(grace, viewer: viewer);
      await subject.sendFollowRequest(grace, viewer: viewer);
      await subject.cancelFollowRequest(grace, requesterId: ada);
      await subject.answerFollowRequest(grace, targetId: ada, accept: true);
      await subject.likeSession('s1', authorId: grace, viewer: viewer);
      await subject.unlikeSession('s1', authorId: grace, viewer: viewer);
      await subject.addComment(comment);
      await subject.deleteComment('c1');
      await subject.setCommentLike('c1', userId: ada, liked: true);
      await subject.markNotificationsRead(ada, ['n1']);
      await subject.markAllNotificationsRead(ada);
      await subject.deleteNotification(ada, 'n1');
      await subject.createChallenge(
        ChallengeModel.fromFirestore(modelFixture('challenge', 'minimal')),
      );
      await subject.leaveChallenge('c', userId: ada);
      await subject.myInvite(ada);
      await subject.sendShare(
        share.payload,
        recipientIds: [grace],
        viewer: viewer,
      );
      await subject.answerShare('id', ShareStatus.accepted);
      await subject.report(
        reporterId: ada,
        targetType: ReportContentType.user,
        targetId: grace,
        reason: ReportReason.spam,
      );

      final paths = [
        'users/fan/notifications/follow_$ada',
        'users/$grace/notifications/follow_$ada',
        'users/$grace/notifications/follow_$ada',
        'users/$grace/notifications/nudge_${ada}_2026-10-14',
        'users/$grace/follow_requests/$ada',
        'users/$grace/follow_requests/$ada',
        'users/$ada/follow_requests/$grace',
        'users/$grace/workout_sessions/s1',
        'users/$grace/notifications/like_s1_$ada',
        'users/$grace/workout_sessions/s1',
        'users/$grace/notifications/like_s1_$ada',
        'workout_session_comments/c1',
        'users/$grace/notifications/comment_c1',
        'workout_session_comments/c1',
        'workout_session_comments/c1',
        'users/$ada/notifications',
        'users/$ada/notifications',
        'users/$ada/notifications/n1',
        'challenges/challenge_contract_minimal',
        'challenges/c',
        'invites/ABCD2345',
        'shares/id',
        'users/$grace/notifications/share_id',
        'shares/id',
        'reports/id',
      ];
      expect(firestore.writes, [
        for (final path in paths)
          if (path == 'users/$ada/notifications') 'batch' else path,
      ]);
      expect(refused, isEmpty);

      firestore.refuse('permission-denied');
      await pumpEventQueue();

      expect(refused, [for (final path in paths) (path, 'permission-denied')]);
    });

    test(
      'claimUsername waits for the server, and a refusal means taken',
      () async {
        var done = false;
        final claim = subject
            .claimUsername('ada', viewer: viewer)
            .whenComplete(() => done = true);
        await pumpEventQueue();
        expect(done, isFalse);
        expect(firestore.writes, ['usernames/ada']);

        firestore.refuse('permission-denied');
        await expectLater(
          claim,
          throwsA(
            isA<UsernameException>().having(
              (e) => e.failure,
              'failure',
              UsernameFailure.taken,
            ),
          ),
        );
        expect(refused, isEmpty);
      },
    );
  });
}
