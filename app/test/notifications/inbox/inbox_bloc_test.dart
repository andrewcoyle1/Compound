import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/notifications/inbox/inbox_bloc.dart';
import 'package:compound/notifications/inbox/notification_grouping.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../settings/general/recorded_analytics.dart';

class _MockSocial extends Mock implements SocialRepository;

/// Ported from `NotificationTapThroughTests`, `NotificationsFollowRequestTests`
/// and `ActivityNotificationPagingTests`, plus the app-wide badge.
void main() {
  final now = DateTime(2026, 10, 15, 12);
  final viewer = sampleUser(now: now);
  const uid = sampleUserId;
  late SocialRepository social;
  late RecordedAnalytics analytics;
  late StreamController<List<FollowRequestModel>> requests;
  late StreamController<ActivityNotificationModel> arrivals;

  ActivityNotificationModel item(
    String id, {
    ActivityType type = ActivityType.like,
    String actor = 'user1',
    String session = 's1',
    int minutesAgo = 0,
    bool isRead = false,
  }) => ActivityNotificationModel(
    id: id,
    type: type,
    actorId: actor,
    actorName: 'Maya Chen',
    sessionId: session,
    sessionAuthorId: uid,
    dateCreated: now.subtract(Duration(minutes: minutesAgo)),
    isRead: isRead,
  );

  final request = FollowRequestModel(
    requesterId: 'user2',
    requesterName: 'Bob Martinez',
    dateCreated: now,
  );
  final session = sampleWorkoutSessions(uid: uid, now: now).last;
  final maya = sampleUser(now: now).copyWithId('user1');

  setUpAll(() => registerFallbackValue(viewer));

  setUp(() {
    social = _MockSocial();
    analytics = RecordedAnalytics();
    requests = StreamController.broadcast();
    arrivals = StreamController.broadcast();
    when(() => social.watchIncomingFollowRequests(any()))
        .thenAnswer((_) => requests.stream);
    when(() => social.watchNewNotifications(uid))
        .thenAnswer((_) => arrivals.stream);
    when(() => social.notifications(uid)).thenAnswer((_) async => []);
    when(() => social.markAllNotificationsRead(uid)).thenAnswer((_) async {});
    when(() => social.markNotificationsRead(uid, any()))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await requests.close();
    await arrivals.close();
  });

  InboxBloc build() => InboxBloc(social: social, analytics: analytics);

  InboxState seeded(List<ActivityNotificationModel> notifications) =>
      InboxState(viewer: viewer, notifications: notifications);

  test('starts empty', () => expect(build().state, const InboxState()));

  group('following the viewer', () {
    blocTest<InboxBloc, InboxState>(
      'reads the first page, and holds requests and arrivals as they come',
      setUp: () =>
          when(() => social.notifications(uid))
              .thenAnswer((_) async => [item('old', minutesAgo: 60)]),
      build: build,
      act: (bloc) async {
        bloc.add(InboxViewerChanged(viewer));
        await pumpEventQueue();
        requests.add([request]);
        arrivals
          ..add(item('new'))
          // An arrival already held is not added twice.
          ..add(item('new'));
        await pumpEventQueue();
      },
      verify: (bloc) {
        expect(bloc.state.notifications.map((n) => n.id), ['new', 'old']);
        expect(bloc.state.requests, [request]);
        expect(bloc.state.hasMore, isFalse);
      },
    );

    blocTest<InboxBloc, InboxState>(
      'a failed first read is logged, and the badge stays as it was',
      setUp: () =>
          when(() => social.notifications(uid)).thenThrow(Exception('offline')),
      build: build,
      act: (bloc) async {
        bloc.add(InboxViewerChanged(viewer));
        await pumpEventQueue();
      },
      verify: (bloc) {
        expect(bloc.state.notifications, isEmpty);
        expect(analytics.names, ['SocialView_LoadNotifications_Fail']);
      },
    );

    blocTest<InboxBloc, InboxState>(
      'Social’s refresh reads the first page again',
      build: build,
      seed: () => InboxState(viewer: viewer),
      act: (bloc) => bloc.add(const InboxBadgeRefreshRequested()),
      verify: (_) => verify(() => social.notifications(uid)).called(1),
    );

    blocTest<InboxBloc, InboxState>(
      'a profile update keeps what is held; a sign-out empties it',
      build: build,
      act: (bloc) async {
        bloc.add(InboxViewerChanged(viewer));
        await pumpEventQueue();
        arrivals.add(item('a'));
        await pumpEventQueue();
        bloc.add(InboxViewerChanged(viewer.copyWithName('Alicia')));
        await pumpEventQueue();
        expect(bloc.state.notifications, hasLength(1));
        bloc.add(const InboxViewerChanged(null));
        await pumpEventQueue();
      },
      verify: (bloc) {
        expect(bloc.state, const InboxState());
        // The same account kept its listeners.
        verify(() => social.watchNewNotifications(uid)).called(1);
      },
    );

    blocTest<InboxBloc, InboxState>(
      'with no viewer, nothing is read',
      build: build,
      act: (bloc) => bloc
        ..add(const InboxBadgeRefreshRequested())
        ..add(const InboxLoadRequested())
        ..add(const InboxLoadMorePressed())
        ..add(InboxGroupPressed(groupNotifications([item('a')]).single))
        ..add(InboxGroupDeleted(groupNotifications([item('a')]).single))
        ..add(InboxFollowBackPressed(item('a')))
        ..add(InboxRequestAnswered(request, accept: true)),
      expect: () => <InboxState>[],
      verify: (_) => verifyZeroInteractions(social),
    );
  });

  group('badges', () {
    test('the bell counts unread rows and requests', () {
      final state = InboxState(
        viewer: viewer,
        notifications: [
          item('a'),
          item('b', minutesAgo: 1),
          item('c', type: ActivityType.follow, actor: 'user4', session: ''),
          item('d', session: 's2', isRead: true),
        ],
        requests: [request],
      );
      expect(state.bellBadgeCount, 3);
    });

    test('the tab counts only comments and mentions, and requests', () {
      final state = InboxState(
        viewer: viewer,
        notifications: [
          item('like'),
          item('c1', type: ActivityType.comment),
          item('c2', type: ActivityType.comment, minutesAgo: 5),
          item('m', type: ActivityType.mention),
        ],
        requests: [request],
      );
      expect(state.tabBadgeCount, 3);
    });

    test('nothing a blocked account did is counted or shown', () {
      final state = InboxState(
        viewer: viewer.copyWithBlocked(['user6']),
        notifications: [item('a', actor: 'user6')],
      );
      expect(state.visible, isEmpty);
      expect(state.groups, isEmpty);
      expect(state.bellBadgeCount, 0);
    });

    test('only a follow row offers a follow back, never for the viewer', () {
      final state = InboxState(viewer: viewer);
      expect(
        state.showsFollowBack(
          item('f', type: ActivityType.follow, session: ''),
        ),
        isTrue,
      );
      expect(state.showsFollowBack(item('l')), isFalse);
      expect(
        state.showsFollowBack(
          item('self', type: ActivityType.follow, actor: uid, session: ''),
        ),
        isFalse,
      );
    });
  });

  group('opening the inbox', () {
    blocTest<InboxBloc, InboxState>(
      'logs the screen, loads, then marks everything read',
      setUp: () =>
          when(() => social.notifications(uid))
              .thenAnswer((_) async => [item('a'), item('b', minutesAgo: 1)]),
      build: build,
      seed: () => InboxState(viewer: viewer),
      act: (bloc) => bloc
        ..add(const InboxAppeared())
        ..add(const InboxDisappeared()),
      verify: (bloc) {
        expect(bloc.state.isLoading, isFalse);
        expect(bloc.state.hasLoadedOnce, isTrue);
        expect(bloc.state.loadFailed, isFalse);
        expect(bloc.state.notifications.every((n) => n.isRead), isTrue);
        verify(() => social.markAllNotificationsRead(uid)).called(1);
        expect(analytics.screenViews, ['NotificationsView_Appear']);
        expect(analytics.names, ['NotificationsView_Disappear']);
      },
    );

    blocTest<InboxBloc, InboxState>(
      'shows a spinner only for the first load',
      build: build,
      seed: () => InboxState(viewer: viewer, hasLoadedOnce: true),
      act: (bloc) => bloc.add(const InboxLoadRequested()),
      verify: (bloc) => expect(bloc.state.isLoading, isFalse),
      expect: () => everyElement(
        isA<InboxState>().having((s) => s.isLoading, 'isLoading', isFalse),
      ),
    );

    blocTest<InboxBloc, InboxState>(
      'a failed load says so instead of reading as empty, and still marks '
      'read; a failed mark is only logged',
      setUp: () {
        when(() => social.notifications(uid)).thenThrow(Exception('offline'));
        when(() => social.markAllNotificationsRead(uid))
            .thenThrow(Exception('offline'));
      },
      build: build,
      seed: () => InboxState(viewer: viewer),
      act: (bloc) => bloc.add(const InboxLoadRequested()),
      verify: (bloc) {
        expect(bloc.state.loadFailed, isTrue);
        expect(bloc.state.isLoading, isFalse);
        expect(analytics.events.map((e) => [e[0], e[2]]), [
          ['NotificationsView_LoadNotifications_Fail', LogType.severe],
          ['NotificationsView_MarkRead_Fail', LogType.warning],
        ]);
      },
    );

    blocTest<InboxBloc, InboxState>(
      'a load that works again clears the failure',
      build: build,
      seed: () => InboxState(viewer: viewer, loadFailed: true),
      act: (bloc) => bloc.add(const InboxLoadRequested()),
      verify: (bloc) => expect(bloc.state.loadFailed, isFalse),
    );
  });

  group('load more', () {
    List<ActivityNotificationModel> page(int from, int count) => [
      for (var index = from; index < from + count; index++)
        item('n$index', session: 's$index', minutesAgo: index),
    ];

    blocTest<InboxBloc, InboxState>(
      'walks back a page at a time until a short page',
      setUp: () {
        when(() => social.notifications(uid))
            .thenAnswer((_) async => page(0, 50));
        when(
          () => social.notifications(
            uid,
            before: now.subtract(const Duration(minutes: 49)),
          ),
        ).thenAnswer((_) async => page(50, 50));
        when(
          () => social.notifications(
            uid,
            before: now.subtract(const Duration(minutes: 99)),
          ),
          // The previous page's last again, which is skipped.
        ).thenAnswer((_) async => [...page(99, 1), ...page(100, 20)]);
      },
      build: build,
      seed: () => InboxState(viewer: viewer),
      act: (bloc) async {
        bloc.add(const InboxLoadRequested());
        await pumpEventQueue();
        expect(bloc.state.hasMore, isTrue);
        bloc.add(const InboxLoadMorePressed());
        await pumpEventQueue();
        expect(bloc.state.notifications, hasLength(100));
        expect(bloc.state.hasMore, isTrue);
        bloc.add(const InboxLoadMorePressed());
      },
      verify: (bloc) {
        expect(bloc.state.notifications.map((n) => n.id), [
          for (var index = 0; index < 120; index++) 'n$index',
        ]);
        expect(bloc.state.hasMore, isFalse);
        expect(analytics.names.where((name) => name.contains('LoadMore')), [
          'NotificationsView_LoadMore_Pressed',
          'NotificationsView_LoadMore_Pressed',
        ]);
      },
    );

    blocTest<InboxBloc, InboxState>(
      'a short first page offers no more',
      setUp: () =>
          when(() => social.notifications(uid))
              .thenAnswer((_) async => page(0, 3)),
      build: build,
      seed: () => InboxState(viewer: viewer),
      act: (bloc) => bloc.add(const InboxLoadRequested()),
      verify: (bloc) => expect(bloc.state.hasMore, isFalse),
    );

    blocTest<InboxBloc, InboxState>(
      'with nothing held there is nothing older to ask for',
      build: build,
      seed: () => InboxState(viewer: viewer),
      act: (bloc) => bloc.add(const InboxLoadMorePressed()),
      verify: (_) => verifyNever(
        () => social.notifications(uid, before: any(named: 'before')),
      ),
    );

    blocTest<InboxBloc, InboxState>(
      'a failed page says so',
      setUp: () =>
          when(() => social.notifications(uid, before: any(named: 'before')))
              .thenThrow(Exception('offline')),
      build: build,
      seed: () => seeded([item('a')]),
      act: (bloc) => bloc.add(const InboxLoadMorePressed()),
      verify: (bloc) {
        expect(bloc.state.notice, InboxNotice.loadMoreFailed);
        expect(analytics.names.last, 'NotificationsView_LoadMore_Fail');
      },
    );
  });

  group('tapping a row', () {
    setUp(() {
      when(() => social.sessionById('s1', authorId: uid))
          .thenAnswer((_) async => session);
      when(() => social.users(['user1'], viewer: any(named: 'viewer')))
          .thenAnswer((_) async => [maya]);
    });

    blocTest<InboxBloc, InboxState>(
      'a like opens the session',
      build: build,
      seed: () => seeded([item('a')]),
      act: (bloc) =>
          bloc.add(InboxGroupPressed(groupNotifications([item('a')]).single)),
      verify: (bloc) {
        expect(
          bloc.state.destination,
          InboxSessionDestination(session, openComments: false),
        );
        expect(bloc.state.openingId, isNull);
        expect(analytics.events.last, [
          'NotificationsView_Notification_Pressed',
          {'type': 'like'},
          LogType.analytic,
        ]);
      },
    );

    for (final type in [ActivityType.comment, ActivityType.mention]) {
      blocTest<InboxBloc, InboxState>(
        'a ${type.value} opens the thread',
        build: build,
        seed: () => seeded([item('a', type: type)]),
        act: (bloc) => bloc.add(
          InboxGroupPressed(groupNotifications([item('a', type: type)]).single),
        ),
        verify: (bloc) => expect(
          bloc.state.destination,
          InboxSessionDestination(session, openComments: true),
        ),
      );
    }

    for (final type in [
      ActivityType.follow,
      ActivityType.followAccepted,
      ActivityType.nudge,
    ]) {
      blocTest<InboxBloc, InboxState>(
        'a ${type.value} opens the actor’s profile',
        build: build,
        seed: () => seeded([item('a', type: type, session: '')]),
        act: (bloc) => bloc.add(
          InboxGroupPressed(
            groupNotifications([item('a', type: type, session: '')]).single,
          ),
        ),
        verify: (bloc) =>
            expect(bloc.state.destination, InboxProfileDestination(maya)),
      );
    }

    for (final type in [ActivityType.share, ActivityType.challengeComplete]) {
      blocTest<InboxBloc, InboxState>(
        'a ${type.value} only marks itself read until Social part 2',
        build: build,
        seed: () => seeded([item('a', type: type, session: '')]),
        act: (bloc) => bloc.add(
          InboxGroupPressed(
            groupNotifications([item('a', type: type, session: '')]).single,
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.destination, isNull);
          expect(bloc.state.notifications.single.isRead, isTrue);
        },
      );
    }

    blocTest<InboxBloc, InboxState>(
      'a session that cannot be found alerts and routes nowhere',
      setUp: () =>
          when(() => social.sessionById('s1', authorId: uid))
              .thenAnswer((_) async => null),
      build: build,
      seed: () => seeded([item('a')]),
      act: (bloc) =>
          bloc.add(InboxGroupPressed(groupNotifications([item('a')]).single)),
      verify: (bloc) {
        expect(bloc.state.destination, isNull);
        expect(bloc.state.notice, InboxNotice.openFailed);
        expect(bloc.state.openingId, isNull);
        expect(
          analytics.events.last[0],
          'NotificationsView_OpenNotification_Fail',
        );
        expect(
          (analytics.events.last[1]! as Map<String, Object?>)['type'],
          'like',
        );
      },
    );

    blocTest<InboxBloc, InboxState>(
      'a profile that cannot be read alerts',
      setUp: () =>
          when(() => social.users(['user1'], viewer: any(named: 'viewer')))
              .thenAnswer((_) async => []),
      build: build,
      seed: () => seeded([item('a', type: ActivityType.nudge, session: '')]),
      act: (bloc) => bloc.add(
        InboxGroupPressed(
          groupNotifications([item('a', type: ActivityType.nudge, session: '')])
              .single,
        ),
      ),
      verify: (bloc) => expect(bloc.state.notice, InboxNotice.openFailed),
    );

    blocTest<InboxBloc, InboxState>(
      'a group opens its session once and marks only its unread members',
      build: build,
      seed: () => seeded([
        item('a'),
        item('b', minutesAgo: 5, isRead: true),
        item('c', minutesAgo: 10),
        item('other', session: 's2'),
      ]),
      act: (bloc) => bloc.add(
        InboxGroupPressed(
          groupNotifications([
            item('a'),
            item('b', minutesAgo: 5, isRead: true),
            item('c', minutesAgo: 10),
          ]).single,
        ),
      ),
      verify: (bloc) {
        verify(() => social.markNotificationsRead(uid, ['a', 'c'])).called(1);
        verify(() => social.sessionById('s1', authorId: uid)).called(1);
        expect(bloc.state.notifications.map((n) => n.isRead), [
          true,
          true,
          true,
          false,
        ]);
      },
    );

    blocTest<InboxBloc, InboxState>(
      'a read group writes nothing',
      build: build,
      seed: () => seeded([item('a', isRead: true)]),
      act: (bloc) => bloc.add(
        InboxGroupPressed(groupNotifications([item('a', isRead: true)]).single),
      ),
      verify: (_) =>
          verifyNever(() => social.markNotificationsRead(any(), any())),
    );

    blocTest<InboxBloc, InboxState>(
      'a failed mark-read is only logged, and the row still opens',
      setUp: () =>
          when(() => social.markNotificationsRead(uid, ['a']))
              .thenThrow(Exception('offline')),
      build: build,
      seed: () => seeded([item('a')]),
      act: (bloc) =>
          bloc.add(InboxGroupPressed(groupNotifications([item('a')]).single)),
      verify: (bloc) {
        expect(bloc.state.notifications.single.isRead, isFalse);
        expect(bloc.state.destination, isNotNull);
        expect(analytics.events.first[2], LogType.warning);
      },
    );
  });

  group('deleting a row', () {
    blocTest<InboxBloc, InboxState>(
      'removes every member',
      setUp: () =>
          when(() => social.deleteNotification(uid, any()))
              .thenAnswer((_) async {}),
      build: build,
      seed: () => seeded([
        item('a'),
        item('b', minutesAgo: 1),
        item('c', session: 's2'),
      ]),
      act: (bloc) => bloc.add(
        InboxGroupDeleted(
          groupNotifications([item('a'), item('b', minutesAgo: 1)]).single,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.notifications.map((n) => n.id), ['c']);
        expect(analytics.names, [
          'NotificationsView_DeleteNotification_Start',
          'NotificationsView_DeleteNotification_Success',
          'NotificationsView_DeleteNotification_Start',
          'NotificationsView_DeleteNotification_Success',
        ]);
      },
    );

    blocTest<InboxBloc, InboxState>(
      'a failed delete alerts once, however many members failed',
      setUp: () =>
          when(() => social.deleteNotification(uid, any()))
              .thenThrow(Exception('offline')),
      build: build,
      seed: () => seeded([item('a'), item('b', minutesAgo: 1)]),
      act: (bloc) => bloc.add(
        InboxGroupDeleted(
          groupNotifications([item('a'), item('b', minutesAgo: 1)]).single,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.noticeId, 1);
        expect(bloc.state.notice, InboxNotice.deleteFailed);
        expect(bloc.state.notifications, hasLength(2));
      },
    );
  });

  group('follow back and follow requests', () {
    blocTest<InboxBloc, InboxState>(
      'follow back reads the actor as they are now and hands them over',
      setUp: () =>
          when(() => social.users(['user1'], viewer: any(named: 'viewer')))
              .thenAnswer((_) async => [maya]),
      build: build,
      seed: () => InboxState(viewer: viewer),
      act: (bloc) => bloc.add(
        InboxFollowBackPressed(
          item('f', type: ActivityType.follow, session: ''),
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.followBack, maya);
        expect(bloc.state.followBackId, 1);
        expect(analytics.names, ['NotificationsView_FollowBack_Pressed']);
      },
    );

    blocTest<InboxBloc, InboxState>(
      'a follow back that cannot read the actor alerts',
      setUp: () =>
          when(() => social.users(['user1'], viewer: any(named: 'viewer')))
              .thenAnswer((_) async => []),
      build: build,
      seed: () => InboxState(viewer: viewer),
      act: (bloc) => bloc.add(
        InboxFollowBackPressed(
          item('f', type: ActivityType.follow, session: ''),
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.followBack, isNull);
        expect(bloc.state.notice, InboxNotice.followBackFailed);
        expect(analytics.names.last, 'NotificationsView_FollowBack_Fail');
      },
    );

    for (final accept in [true, false]) {
      blocTest<InboxBloc, InboxState>(
        '${accept ? 'accept' : 'decline'} writes the status',
        setUp: () => when(
          () => social.answerFollowRequest(
            'user2',
            targetId: uid,
            accept: accept,
          ),
        ).thenAnswer((_) async {}),
        build: build,
        seed: () => InboxState(viewer: viewer, requests: [request]),
        act: (bloc) => bloc.add(InboxRequestAnswered(request, accept: accept)),
        verify: (_) {
          verify(
            () => social.answerFollowRequest(
              'user2',
              targetId: uid,
              accept: accept,
            ),
          ).called(1);
          expect(analytics.events, [
            for (final name in [
              'NotificationsView_FollowRequest_Answered',
              'NotificationsView_RespondToFollowRequest_Start',
              'NotificationsView_RespondToFollowRequest_Success',
            ])
              [
                name,
                {'accept': accept},
                LogType.analytic,
              ],
          ]);
        },
      );
    }

    blocTest<InboxBloc, InboxState>(
      'a failed answer alerts and keeps the request',
      setUp: () => when(
        () => social.answerFollowRequest('user2', targetId: uid, accept: true),
      ).thenThrow(Exception('offline')),
      build: build,
      seed: () => InboxState(viewer: viewer, requests: [request]),
      act: (bloc) => bloc.add(InboxRequestAnswered(request, accept: true)),
      verify: (bloc) {
        expect(bloc.state.notice, InboxNotice.answerFailed);
        expect(bloc.state.requests, [request]);
        expect(
          analytics.names.last,
          'NotificationsView_RespondToFollowRequest_Fail',
        );
      },
    );
  });
}

extension on UserModel {
  UserModel copyWithId(String id) =>
      UserModel.fromFirestore({...toFirestore(), UserModelKeys.userId: id});

  UserModel copyWithName(String name) => UserModel.fromFirestore({
    ...toFirestore(),
    UserModelKeys.firstName: name,
  });

  UserModel copyWithBlocked(List<String> ids) => UserModel.fromFirestore({
    ...toFirestore(),
    UserModelKeys.blockedUserIds: ids,
  });
}
