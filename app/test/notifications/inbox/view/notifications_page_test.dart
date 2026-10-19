import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/notifications/inbox/inbox_bloc.dart';
import 'package:compound/notifications/inbox/view/notifications_page.dart';
import 'package:compound/settings/settings_routes.dart';
import 'package:compound/social/comments/comments_page.dart';
import 'package:compound/social/profile/social_profile_page.dart';
import 'package:compound/social/social.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../../helpers/helpers.dart';

class _MockSocial extends Mock implements SocialRepository;

/// The inbox over the staging world: Bob's request, Charlie's and Priya's
/// likes grouped, Charlie's mention, Maya's comment and share, Dev's nudge
/// and Priya's follow.
void main() {
  late SocialWorld world;
  late InboxBloc inbox;

  setUpAll(() => registerFallbackValue(sampleUser(now: DateTime(2026))));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    String location = '/social/notifications',
    SocialRepository? social,
  }) async {
    world = (await tester.runAsync(SocialWorld.create))!;
    inbox = InboxBloc(
      social: social ?? world.social,
      analytics: const AnalyticsRepository(),
    )..add(InboxViewerChanged(world.viewer));
    final appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      AppAuthenticated(
        const AuthUser(uid: sampleUserId, isAnonymous: false),
        profile: world.viewer,
        profileStatus: AppProfileStatus.ready,
      ),
    );
    tester.view.physicalSize = const Size(1200, 4000);
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      userRepository: world.users,
      workoutSessionRepository: world.sessions,
      socialRepository: social ?? world.social,
      circleBloc: world.circle,
      inboxBloc: inbox,
      router: GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/social',
            builder: (_, _) => const SocialPage(),
            routes: [
              GoRoute(
                path: NotificationsPage.path,
                name: NotificationsPage.name,
                builder: (_, _) => const NotificationsPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const SizedBox(),
            routes: profileRoutes,
          ),
          ...socialRoutes,
        ],
      ),
    );
    await settle(tester);
  }

  testWidgets('shows the requests and the grouped activity, all read once '
      'opened', (tester) async {
    await pump(tester);

    expect(find.text('Follow Requests'), findsOneWidget);
    expect(find.text('Bob Martinez'), findsOneWidget);
    expect(find.text('Wants to follow you'), findsOneWidget);
    expect(
      find.text('Charlie Nguyen and Priya Shah liked your workout'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Charlie Nguyen mentioned you: "@alice.cooper teach me your '
        'ways"',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Maya Chen commented: "Those pushdowns 🔥"'),
      findsOneWidget,
    );
    expect(find.text('Dev Patel nudged you to train'), findsOneWidget);
    expect(find.text('Priya Shah started following you'), findsOneWidget);
    // Alice already follows Priya.
    expect(find.text('Following'), findsOneWidget);
    expect(inbox.state.visible.every((n) => n.isRead), isTrue);
    expect(inbox.state.bellBadgeCount, 1);
  });

  testWidgets('accepting a request answers it', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Accept'));
    await settle(tester);
    expect(find.text('Bob Martinez'), findsNothing);
  });

  testWidgets('declining, following back and pulling to refresh', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Decline'));
    await settle(tester);
    expect(find.text('Bob Martinez'), findsNothing);

    // Priya is followed already, so the button unfollows her.
    await tester.tap(find.text('Following'));
    await settle(tester);
    final viewer = await tester.runAsync(
      () => world.users.watchUser(sampleUserId).first,
    );
    expect(viewer!.followingIds, isNot(contains('user4')));

    await tester.fling(
      find.text('Dev Patel nudged you to train'),
      const Offset(0, 400),
      1000,
    );
    await settle(tester);
    expect(find.text('Dev Patel nudged you to train'), findsOneWidget);
  });

  testWidgets('a like opens the workout', (tester) async {
    await pump(tester);
    await tester.tap(
      find.text('Charlie Nguyen and Priya Shah liked your workout'),
    );
    await settle(tester);
    expect(find.byType(WorkoutSessionDetailPage), findsOneWidget);
    expect(find.byType(CommentsPage), findsNothing);
  });

  testWidgets('a mention opens the thread over the workout', (tester) async {
    await pump(tester);
    await tester.tap(find.textContaining('mentioned you'));
    await settle(tester);
    expect(find.byType(CommentsPage), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(WorkoutSessionDetailPage), findsOneWidget);
  });

  testWidgets('a nudge opens the profile', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Dev Patel nudged you to train'));
    await settle(tester);
    expect(find.byType(SocialProfilePage), findsOneWidget);
  });

  testWidgets('swiping a row away deletes it', (tester) async {
    await pump(tester);
    await tester.drag(
      find.text('Dev Patel nudged you to train'),
      const Offset(-1000, 0),
    );
    await settle(tester);
    expect(find.text('Dev Patel nudged you to train'), findsNothing);
    final held = await tester.runAsync(
      () => world.social.notifications(sampleUserId),
    );
    expect(held!.where((n) => n.type == ActivityType.nudge), isEmpty);
  });

  testWidgets('the gear opens Notification Settings', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Notification Settings'));
    await settle(tester);
    expect(find.text('Social'), findsWidgets);
    expect(find.text('Streak reminder'), findsOneWidget);
  });

  testWidgets('a failed load says so, and Try Again reads again', (
    tester,
  ) async {
    final social = _MockSocial();
    when(() => social.watchIncomingFollowRequests(any()))
        .thenAnswer((_) => const Stream.empty());
    when(() => social.watchNewNotifications(any()))
        .thenAnswer((_) => const Stream.empty());
    when(() => social.notifications(sampleUserId))
        .thenThrow(Exception('offline'));
    when(() => social.markAllNotificationsRead(sampleUserId))
        .thenAnswer((_) async {});
    await pump(tester, social: social);
    expect(find.text('Unable to Load Notifications'), findsOneWidget);

    when(() => social.notifications(sampleUserId)).thenAnswer((_) async => []);
    await tester.tap(find.text('Try Again'));
    await settle(tester);
    expect(find.text('No Notifications'), findsOneWidget);
  });

  testWidgets('a row that cannot be opened says so', (tester) async {
    final social = _MockSocial();
    when(() => social.watchIncomingFollowRequests(any()))
        .thenAnswer((_) => const Stream.empty());
    when(() => social.watchNewNotifications(any()))
        .thenAnswer((_) => const Stream.empty());
    when(() => social.notifications(sampleUserId)).thenAnswer(
      (_) async => [
        ActivityNotificationModel(
          id: 'like_gone',
          type: ActivityType.like,
          actorId: 'user1',
          actorName: 'Maya Chen',
          sessionId: 'gone',
          sessionAuthorId: sampleUserId,
          dateCreated: DateTime.now(),
          isRead: true,
        ),
      ],
    );
    when(() => social.markAllNotificationsRead(sampleUserId))
        .thenAnswer((_) async {});
    when(() => social.sessionById('gone', authorId: sampleUserId))
        .thenAnswer((_) async => null);
    await pump(tester, social: social);
    await tester.tap(find.text('Maya Chen liked your workout'));
    await settle(tester);
    expect(
      find.text('Unable to Open. It may have been deleted. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('the Social bell shows the unread count and opens the inbox', (
    tester,
  ) async {
    await pump(tester, location: '/social');
    // Five unread rows (the grouped likes count once) and Bob's request.
    expect(
      find.descendant(
        of: find.byTooltip('Notifications'),
        matching: find.text('6'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Notifications'));
    await settle(tester);
    expect(find.byType(NotificationsPage), findsOneWidget);
  });
}
