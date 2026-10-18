import 'package:compound/social/invite/invite_cubit.dart';
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockSocial extends Mock implements SocialRepository;

void main() {
  late FakeConnectivityRepository connectivity;
  late List<void> blocked;
  final now = DateTime(2026, 10, 15, 12);
  late SocialRepository social;
  late UserModel viewer;
  late AnalyticsRecorder analytics;

  setUp(() async {
    connectivity = FakeConnectivityRepository();
    blocked = [];
    connectivity.blocked.listen(blocked.add);
    viewer = sampleUser(now: now);
    social = await inMemorySocialRepository(
      firestore: FakeFirebaseFirestore(),
      users: InMemoryUserRepository(users: {sampleUserId: viewer}),
      now: now,
    );
    analytics = AnalyticsRecorder();
  });

  group(InviteCubit, () {
    // InviteTests.testAcceptingOpensTheInviterWithAFollowingToast
    test('accepting answers with the inviter and what happened', () async {
      final cubit = InviteCubit(
        connectivity: connectivity,
        social: social,
        analytics: analytics,
      );
      await cubit.accept('push 2345', viewer: viewer);
      final result = cubit.state.result! as InviteAccepted;
      expect(result.inviter.userId, 'user1');
      expect(result.acceptance.youFollow, InviteOutcome.following);
      expect(result.acceptance.theyFollow, InviteOutcome.following);
      expect(cubit.state.resultId, 1);
      expect(cubit.state.isBusy, isFalse);
      expect(analytics.names, ['Invite_Accept_Start', 'Invite_Accept_Success']);
    });

    // InviteTests.testAPrivateProfileSaysARequestIsWaiting
    test('a private profile answers that a request is waiting', () async {
      final mock = _MockSocial();
      when(() => mock.acceptInvite('PUSH2345')).thenAnswer(
        (_) async => const InviteAcceptance(
          inviterId: 'user1',
          youFollow: InviteOutcome.requested,
          theyFollow: InviteOutcome.following,
        ),
      );
      when(() => mock.users(['user1'], viewer: viewer))
          .thenAnswer((_) async => const [UserModel(userId: 'user1')]);
      final cubit = InviteCubit(
        connectivity: connectivity,
        social: mock,
        analytics: analytics,
      );
      await cubit.accept('PUSH2345', viewer: viewer);
      expect(
        (cubit.state.result! as InviteAccepted).acceptance.youFollow,
        InviteOutcome.requested,
      );
    });

    // InviteTests.testARefusedInviteExplainsWhyAndOpensNothing
    test('a refused invite says why', () async {
      final cubit = InviteCubit(
        connectivity: connectivity,
        social: social,
        analytics: analytics,
      );
      await cubit.accept('NOPE', viewer: viewer);
      expect(
        cubit.state.result,
        const InviteAcceptFailed(InviteFailure.invalidCode),
      );
      await cubit.accept('ABCDEFGH', viewer: viewer);
      expect(
        cubit.state.result,
        const InviteAcceptFailed(InviteFailure.notFound),
      );
      expect(cubit.state.resultId, 2);
      expect(analytics.names.last, 'Invite_Accept_Fail');
    });

    test('an inviter who cannot be read is not found; other errors have no '
        'reason', () async {
      final mock = _MockSocial();
      when(() => mock.acceptInvite(any())).thenAnswer(
        (_) async => const InviteAcceptance(
          inviterId: 'gone',
          youFollow: InviteOutcome.following,
          theyFollow: InviteOutcome.following,
        ),
      );
      when(() => mock.users(['gone'], viewer: viewer))
          .thenAnswer((_) async => const []);
      final cubit = InviteCubit(
        connectivity: connectivity,
        social: mock,
        analytics: analytics,
      );
      await cubit.accept('PUSH2345', viewer: viewer);
      expect(
        cubit.state.result,
        const InviteAcceptFailed(InviteFailure.notFound),
      );

      when(() => mock.acceptInvite(any())).thenThrow(StateError('offline'));
      await cubit.accept('PUSH2345', viewer: viewer);
      expect(cubit.state.result, const InviteAcceptFailed(null));
    });

    test("shares the viewer's link, creating the invite once", () async {
      final cubit = InviteCubit(
        connectivity: connectivity,
        social: social,
        analytics: analytics,
      );
      await cubit.shareRequested(
        sampleUserId,
        pressedEvent: 'SocialView_InviteFriend_Press',
      );
      final first = cubit.state.result! as InviteShareReady;
      expect(first.link, startsWith('compound://join/'));
      expect(first.link, hasLength('compound://join/'.length + 8));
      await cubit.shareRequested(sampleUserId);
      expect(cubit.state.result, first);
      expect(cubit.state.resultId, 2);
      expect(analytics.names, ['SocialView_InviteFriend_Press']);
    });

    // InviteTests.testOfflineAcceptSaysYoureOfflineAndCallsNothing, and
    // SettingsPresenterTests.testOfflineInviteSaysYoureOfflineInsteadOfSharing
    test("offline neither accepting nor sharing starts; each says you're "
        'offline', () async {
      connectivity.offline = true;
      final mock = _MockSocial();
      final cubit = InviteCubit(
        connectivity: connectivity,
        social: mock,
        analytics: analytics,
      );

      await cubit.accept('PUSH2345', viewer: viewer);
      await cubit.shareRequested(
        sampleUserId,
        pressedEvent: 'ProfileView_InviteFriend_Press',
      );
      await pumpEventQueue();

      verifyNever(() => mock.acceptInvite(any()));
      verifyNever(() => mock.myInvite(any()));
      expect(cubit.state, const InviteState());
      expect(analytics.names, isEmpty);
      expect(blocked, hasLength(2));
    });

    test('a failed invite says so', () async {
      final mock = _MockSocial();
      when(() => mock.myInvite(any())).thenThrow(StateError('x'));
      final cubit = InviteCubit(
        connectivity: connectivity,
        social: mock,
        analytics: analytics,
      );
      await cubit.shareRequested(sampleUserId);
      expect(cubit.state.result, const InviteShareFailed());
    });

    test('a second request while busy is ignored', () async {
      final cubit = InviteCubit(
        connectivity: connectivity,
        social: social,
        analytics: analytics,
      );
      final first = cubit.shareRequested(sampleUserId);
      await cubit.shareRequested(sampleUserId);
      await cubit.accept('PUSH2345', viewer: viewer);
      await first;
      expect(cubit.state.resultId, 1);
    });
  });
}
