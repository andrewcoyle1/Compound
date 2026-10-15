import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/logic/circle_week.dart';
import 'package:compound/social/logic/people.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

class _MockAnalytics extends Mock implements AnalyticsRepository;

class _MockSocial extends Mock implements SocialRepository;

class _FakeEvent extends Fake implements LoggableEvent;

void main() {
  final now = DateTime(2026, 10, 15, 12);
  late UserModel viewer;
  late InMemoryUserRepository users;
  late SocialRepository social;
  late AnalyticsRepository analytics;
  late List<String> events;

  setUpAll(() => registerFallbackValue(_FakeEvent()));

  setUp(() async {
    viewer = sampleUser(now: now);
    users = InMemoryUserRepository(users: {sampleUserId: viewer});
    social = await inMemorySocialRepository(users: users, now: now);
    events = [];
    analytics = _MockAnalytics();
    when(() => analytics.trackEvent(any())).thenAnswer(
      (call) => events.add(
        (call.positionalArguments.first as LoggableEvent).eventName,
      ),
    );
  });

  CircleBloc build({SocialRepository? with_}) => CircleBloc(
    social: with_ ?? social,
    sessions: InMemoryWorkoutSessionRepository(
      sessions: sampleWorkoutSessions(uid: sampleUserId, now: now),
    ),
    analytics: analytics,
    now: () => now,
  );

  test('starts empty', () {
    expect(build().state, const CircleState());
  });

  test('follows the viewer’s circle and feed', () async {
    final bloc = build()..add(CircleViewerChanged(viewer));
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<CircleState>()
            .having((s) => s.followingUsers, 'following', hasLength(4))
            .having((s) => s.hasLoadedFollowingSessions, 'loaded', isTrue)
            .having((s) => s.ownSessions, 'own', isNotEmpty),
      ),
    );
    final state = bloc.state;
    expect(state.isFeedLoading, isFalse);
    expect(state.feed, isNotEmpty);
    expect(
      state.feed.every((session) => state.authorOf(session) != null),
      isTrue,
    );
    expect(state.authorOf(state.ownSessions.first)?.userId, sampleUserId);
    expect(
      state.members(now: now, firstDayOfWeek: 1).map((m) => m.user.userId),
      contains(sampleUserId),
    );
    await bloc.close();
  });

  test('a signed-out viewer empties the circle', () async {
    final bloc = build()..add(CircleViewerChanged(viewer));
    await bloc.stream.firstWhere((s) => s.followingUsers.isNotEmpty);
    bloc.add(const CircleViewerChanged(null));
    await expectLater(bloc.stream, emitsThrough(const CircleState()));
    await bloc.close();
  });

  test('follows and unfollows through the repository', () async {
    final bloc = build()..add(CircleViewerChanged(viewer));
    await bloc.stream.firstWhere((s) => s.hasLoadedFollowingSessions);
    final david = (await social.users(['user6'], viewer: viewer)).single;
    bloc.add(CircleFollowPressed(david));
    await pumpEventQueue();
    final followed = (await users.watchUser(sampleUserId).first)!;
    expect(followed.followingIds, contains('user6'));
    expect(events, ['FollowFlow_Follow_Start', 'FollowFlow_Follow_Success']);

    bloc.add(CircleViewerChanged(followed));
    await pumpEventQueue();
    expect(bloc.state.followState('user6'), FollowState.following);
    bloc.add(CircleFollowPressed(david));
    await pumpEventQueue();
    expect(
      (await users.watchUser(sampleUserId).first)!.followingIds,
      isNot(contains('user6')),
    );
    await bloc.close();
  });

  test('requests a private profile, and cancels the request', () async {
    final bloc = build()..add(CircleViewerChanged(viewer));
    await bloc.stream.firstWhere((s) => s.hasLoadedFollowingSessions);
    final bob = (await social.users(['user2'], viewer: viewer)).single;
    bloc.add(CircleFollowPressed(bob));
    await pumpEventQueue();
    expect(bloc.state.followState('user2'), FollowState.requested);
    bloc.add(CircleFollowPressed(bob));
    await pumpEventQueue();
    expect(bloc.state.followState('user2'), FollowState.follow);
    expect(events, [
      'FollowFlow_RequestFollow_Start',
      'FollowFlow_RequestFollow_Success',
      'FollowFlow_CancelRequest_Start',
      'FollowFlow_CancelRequest_Success',
    ]);
    await bloc.close();
  });

  group('failures', () {
    late _MockSocial failing;

    setUp(() {
      failing = _MockSocial();
      when(() => failing.sentFollowRequestTargetIds(any()))
          .thenThrow(Exception('offline'));
      when(() => failing.watchFollowingUsers(any()))
          .thenAnswer((_) => Stream.error(Exception('offline')));
      when(() => failing.watchFollowingSessions(any()))
          .thenAnswer((_) => Stream.error(Exception('offline')));
      when(() => failing.follow(any(), viewer: any(named: 'viewer')))
          .thenThrow(Exception('denied'));
      when(() => failing.unfollow(any(), viewer: any(named: 'viewer')))
          .thenThrow(Exception('denied'));
      when(
        () => failing.cancelFollowRequest(
          any(),
          requesterId: any(named: 'requesterId'),
        ),
      ).thenThrow(Exception('denied'));
      when(() => failing.nudge(any(), viewer: any(named: 'viewer')))
          .thenThrow(Exception('denied'));
    });

    setUpAll(() => registerFallbackValue(const UserModel(userId: 'x')));

    blocTest<CircleBloc, CircleState>(
      'say when following, unfollowing or cancelling failed',
      build: () => build(with_: failing),
      seed: () => CircleState(viewer: viewer, sentRequestIds: const {'user2'}),
      act: (bloc) => bloc
        ..add(const CircleFollowPressed(UserModel(userId: 'user6')))
        ..add(const CircleFollowPressed(UserModel(userId: 'user1')))
        ..add(const CircleFollowPressed(UserModel(userId: 'user2'))),
      verify: (bloc) {
        expect(bloc.state.noticeId, 3);
        expect(events.where((e) => e.endsWith('_Fail')), [
          'FollowFlow_Follow_Fail',
          'FollowFlow_Unfollow_Fail',
          'FollowFlow_CancelRequest_Fail',
        ]);
      },
    );

    blocTest<CircleBloc, CircleState>(
      'mark the feed loaded when it cannot be read',
      build: () => build(with_: failing),
      act: (bloc) => bloc.add(CircleViewerChanged(viewer)),
      wait: Duration.zero,
      verify: (bloc) {
        expect(bloc.state.hasLoadedFollowingSessions, isTrue);
        expect(bloc.state.followingUsers, isEmpty);
      },
    );

    blocTest<CircleBloc, CircleState>(
      'give a failed nudge back',
      build: () => build(with_: failing),
      seed: () => CircleState(viewer: viewer),
      act: (bloc) => bloc.add(
        const CircleNudgePressed(
          CircleMember(
            user: UserModel(userId: 'user5', displayName: 'Dev'),
            trainedToday: false,
            canNudge: true,
            sessionsThisWeek: 0,
            weeklyGoal: 3,
            isCurrentUser: false,
          ),
        ),
      ),
      expect: () => [
        isA<CircleState>().having((s) => s.nudgedOn(now), 'nudged', {'user5'}),
        isA<CircleState>()
            .having((s) => s.nudgedOn(now), 'nudged', isEmpty)
            .having((s) => s.notice, 'notice', CircleNotice.nudgeFailed)
            .having((s) => s.noticeName, 'name', 'Dev'),
      ],
    );
  });

  blocTest<CircleBloc, CircleState>(
    'nudges once a day',
    build: build,
    seed: () => CircleState(viewer: viewer),
    act: (bloc) {
      const member = CircleMember(
        user: UserModel(userId: 'user5'),
        trainedToday: false,
        canNudge: true,
        sessionsThisWeek: 0,
        weeklyGoal: 3,
        isCurrentUser: false,
      );
      bloc
        ..add(const CircleNudgePressed(member))
        ..add(const CircleNudgePressed(member));
    },
    verify: (bloc) {
      expect(bloc.state.nudgedOn(now), {'user5'});
      expect(bloc.state.nudgedOn(now.add(const Duration(days: 1))), isEmpty);
      expect(events, [
        'SocialView_Nudge_Press',
        'SocialView_Nudge_Start',
        'SocialView_Nudge_Success',
      ]);
    },
  );

  blocTest<CircleBloc, CircleState>(
    'remembers the dismissed banners',
    build: build,
    act: (bloc) => bloc
      ..add(const CircleUsernameBannerDismissed())
      ..add(CircleWeeklySummaryDismissed(DateTime(2026, 10, 12))),
    verify: (bloc) {
      expect(bloc.state.usernameBannerDismissed, isTrue);
      expect(bloc.state.dismissedSummaryWeek, DateTime(2026, 10, 12));
      expect(events, ['SocialView_WeeklySummary_Dismiss']);
    },
  );
}
