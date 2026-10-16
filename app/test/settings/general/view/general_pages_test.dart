import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/settings/general/view/about_page.dart';
import 'package:compound/settings/general/view/customise_analytics_page.dart';
import 'package:compound/settings/general/view/legal_page.dart';
import 'package:compound/settings/general/view/licences_page.dart';
import 'package:compound/settings/general/view/methods_and_sources_page.dart';
import 'package:compound/settings/general/view/notification_settings_page.dart';
import 'package:compound/settings/general/view/units_page.dart';
import 'package:compound/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../../helpers/helpers.dart';
import '../recorded_analytics.dart';

String hour(int hour) => DateFormat.j('en').format(DateTime(2000, 1, 1, hour));

void main() {
  const user = AuthUser(uid: 'uid', isAnonymous: false);
  late AppBloc appBloc;
  late InMemoryUserRepository users;
  late InMemoryBodyRepository body;
  late RecordedAnalytics analytics;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    analytics = RecordedAnalytics();
    users = InMemoryUserRepository(
      users: {
        'uid': const UserModel(
          userId: 'uid',
          submittedWeightUnitPreference: WeightUnitPreference.kilograms,
          submittedLengthUnitPreference: LengthUnitPreference.centimeters,
          submittedDistanceUnitPreference: DistanceUnitPreference.kilometers,
        ),
      },
    );
    body = InMemoryBodyRepository();
  });

  Future<void> pump(
    WidgetTester tester,
    String location, {
    PushPermission permission = PushPermission.authorized,
    FakeNotificationsRepository? notifications,
  }) async {
    when(() => appBloc.state).thenReturn(
      AppAuthenticated(
        user,
        profile: await users.watchUser('uid').first,
        profileStatus: AppProfileStatus.ready,
      ),
    );
    tester.view.physicalSize = const Size(2400, 9000);
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      userRepository: users,
      bodyRepository: body,
      analyticsRepository: analytics,
      notificationsRepository:
          notifications ??
          FakeNotificationsRepository(permissionState: permission),
      router: GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => const SizedBox(),
            routes: profileRoutes,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  group(UnitsPage, () {
    testWidgets('shows the stored units and saves a change', (tester) async {
      await pump(tester, '/profile/settings/units');
      expect(find.byType(UnitsView), findsOneWidget);
      await tester.tap(find.text('Pounds'));
      await tester.tap(find.text('Inches'));
      await tester.tap(find.text('Miles'));
      await tester.pumpAndSettle();
      final stored = (await users.watchUser('uid').first)!;
      expect(stored.submittedWeightUnitPreference, WeightUnitPreference.pounds);
      expect(stored.submittedLengthUnitPreference, LengthUnitPreference.inches);
      expect(
        stored.submittedDistanceUnitPreference,
        DistanceUnitPreference.miles,
      );
      expect(analytics.screenViews.last, 'UnitsView_Appear');
    });

    testWidgets('says when a save fails', (tester) async {
      // No profile: the update is refused with not-found.
      users = InMemoryUserRepository();
      await pump(tester, '/profile/settings/units');
      await tester.tap(find.text('Pounds'));
      await tester.pump();
      expect(find.text('Unable to Save Settings'), findsOneWidget);
    });
  });

  group(CustomiseAnalyticsPage, () {
    testWidgets('hides a section, then shows them all', (tester) async {
      await pump(tester, '/profile/settings/analytics');
      expect(find.text('Show All Sections'), findsNothing);
      await tester.tap(find.text('Habits'));
      await tester.pumpAndSettle();
      expect(
        (await body.watchAnalyticsSettings('uid').first).hiddenSectionIds,
        ['habits'],
      );
      await tester.tap(find.text('Show All Sections'));
      await tester.pumpAndSettle();
      expect(
        (await body.watchAnalyticsSettings('uid').first).hiddenSectionIds,
        isEmpty,
      );
      expect(find.text('Show All Sections'), findsNothing);
    });

    testWidgets('the last visible section cannot be switched off', (
      tester,
    ) async {
      body = InMemoryBodyRepository(
        analyticsSettings: const AnalyticsSettings(
          authorId: 'uid',
          hiddenSectionIds: [
            'insights_and_analytics',
            'nutrition',
            'body_metrics',
            'muscle_groups',
            'exercises',
          ],
        ),
      );
      await pump(tester, '/profile/settings/analytics');
      await tester.tap(find.text('Habits'));
      await tester.pumpAndSettle();
      expect(
        (await body.watchAnalyticsSettings('uid').first).hiddenSectionIds,
        hasLength(5),
      );
    });

    testWidgets('says when a save fails', (tester) async {
      body = _FailingBody();
      await pump(tester, '/profile/settings/analytics');
      await tester.tap(find.text('Habits'));
      await tester.pump();
      expect(find.text('Unable to Save Settings'), findsOneWidget);
    });
  });

  group(NotificationSettingsPage, () {
    testWidgets('each switch saves its key; the hour shows once the streak '
        'reminder is on', (tester) async {
      await pump(tester, '/profile/settings/notifications');
      expect(find.text('Remind me at'), findsNothing);
      await tester.tap(find.text('Likes'));
      await tester.tap(find.text('Streak reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Remind me at'), findsOneWidget);
      expect(find.text(hour(19)), findsOneWidget);

      await tester.tap(find.text('Remind me at'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(hour(7)));
      await tester.pumpAndSettle();
      // Choosing the hour already chosen saves nothing.
      await tester.tap(find.text('Remind me at'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(hour(7)).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weekly digest'));
      await tester.tap(find.text('Workout reminders'));
      await tester.tap(find.text('Meal reminders'));
      for (final title in [
        'Comments',
        'Mentions',
        'New followers',
        'Nudges',
        'Shares',
        'Challenges',
      ]) {
        await tester.tap(find.text(title));
      }
      await tester.pumpAndSettle();
      expect((await users.watchPrivateSettings('uid').first)!.toFirestore(), {
        'social_push_likes': false,
        'social_push_comments': false,
        'social_push_mentions': false,
        'social_push_follows': false,
        'social_push_nudges': false,
        'social_push_shares': false,
        'social_push_challenges': false,
        'social_push_streak_reminder': true,
        'reminder_hour': 7,
        'social_push_weekly_digest': false,
        'push_come_back_reminders': false,
        'push_meal_reminders': true,
      });
      expect(analytics.names.where((name) => name.endsWith('_Changed')), [
        'NotificationsView_ReminderHour_Changed',
      ]);
    });

    testWidgets('says when a save fails', (tester) async {
      users = _FailingUsers();
      await pump(tester, '/profile/settings/notifications');
      await tester.tap(find.text('Likes'));
      await tester.pump();
      expect(find.text('Unable to Save Setting'), findsOneWidget);
    });

    testWidgets('never asked: offers to ask, and the switches wait until '
        'it is allowed', (tester) async {
      final notifications = FakeNotificationsRepository();
      await pump(
        tester,
        '/profile/settings/notifications',
        notifications: notifications,
      );
      expect(
        find.text(
          'Notifications are off. Turn them on to get the alerts below.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Likes'));
      await tester.pumpAndSettle();
      expect(await users.watchPrivateSettings('uid').first, isNull);

      await tester.tap(find.text('Turn On Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Turn On Notifications'), findsNothing);
      await tester.tap(find.text('Likes'));
      await tester.pumpAndSettle();
      expect(
        (await users.watchPrivateSettings('uid').first)!.socialPushLikes,
        isFalse,
      );
    });

    testWidgets('refused: Open Settings, and the answer is read again on '
        'return', (tester) async {
      final notifications = FakeNotificationsRepository(
        permissionState: PushPermission.denied,
      );
      await pump(
        tester,
        '/profile/settings/notifications',
        notifications: notifications,
      );
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();
      expect(notifications.settingsOpened, 1);

      notifications.permissionState = PushPermission.authorized;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Open Settings'), findsNothing);
    });

    testWidgets('says when the permission cannot be read', (tester) async {
      await pump(
        tester,
        '/profile/settings/notifications',
        notifications: _FailingNotifications(),
      );
      expect(
        find.text('Unable to Check Notification Permission'),
        findsOneWidget,
      );
    });

    testWidgets('says when asking fails', (tester) async {
      await pump(
        tester,
        '/profile/settings/notifications',
        notifications: _FailingRequest(),
      );
      await tester.tap(find.text('Turn On Notifications'));
      await tester.pump();
      expect(find.text('Unable to Enable Notifications'), findsOneWidget);
    });
  });

  group(MethodsAndSourcesPage, () {
    testWidgets('lists every method and opens its sheet', (tester) async {
      await pump(tester, '/profile/settings/methods');
      for (final title in [
        'Weight Trend',
        'Planned Sets per Muscle',
        'Weekly Goal and Streak',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      await tester.tap(find.text('Weekly Goal and Streak'));
      await tester.pumpAndSettle();
      expect(find.text('Sources'), findsOneWidget);
      expect(analytics.events, [
        [
          'MethodsAndSourcesView_Method_Press',
          {'method': 'habits.weeklyGoal'},
          LogType.analytic,
        ],
      ]);
    });
  });

  group(LegalPage, () {
    testWidgets('lists the agreements', (tester) async {
      await pump(tester, '/profile/settings/legal');
      for (final title in [
        'Terms of Service',
        'Privacy Policy',
        'Health Disclaimer',
        'Consumer Health Privacy',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(analytics.screenViews.last, 'LegalView_Appear');
    });
  });

  group(AboutPage, () {
    testWidgets('says what Compound is and opens the licences', (tester) async {
      await pump(tester, '/profile/settings/about');
      expect(find.textContaining('training and nutrition'), findsOneWidget);
      await tester.tap(find.text('View Licenses'));
      await tester.pumpAndSettle();
      expect(find.byType(LicencesPage), findsOneWidget);
      expect(find.textContaining('open-source packages'), findsOneWidget);
      expect(analytics.screenViews.skip(1), [
        'AboutView_Appear',
        'LicencesView_Appear',
      ]);
    });
  });
}

class _FailingBody extends InMemoryBodyRepository {
  @override
  Future<void> saveAnalyticsSettings(AnalyticsSettings settings) =>
      throw StateError('no');
}

class _FailingUsers extends InMemoryUserRepository {
  @override
  Future<void> mergePrivateSettings(String uid, PrivateUserSettings settings) =>
      throw StateError('no');
}

class _FailingNotifications extends FakeNotificationsRepository {
  @override
  Future<PushPermission> permission() async => throw StateError('no');
}

class _FailingRequest extends FakeNotificationsRepository {
  @override
  Future<bool> requestPermission() async => throw StateError('no');
}
