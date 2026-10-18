import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/app_repositories.dart';

/// The reminder offers end to end on the staging flavor's in-memory data:
/// meal reminders on the first visit to Nutrition, the streak reminder on
/// Today at a two-week streak, each once per device, the answer saved to
/// the private settings and the meal reminders scheduled from it.
void main() {
  final now = DateTime.now();

  late InMemoryUserRepository users;
  late List<WorkoutSessionModel> sessions;
  late FakeNotificationsRepository notifications;
  late InMemoryDeviceStore store;

  Widget app() => App(
    socialRepository: emptySocialRepository(),
    coachRepository: silentCoachRepository(),
    purchasesRepository: FakePurchasesRepository(),
    programRepository: InMemoryProgramRepository(),
    trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
    authRepository: InMemoryAuthRepository(
      user: InMemoryAuthRepository.sampleUser,
    ),
    userRepository: users,
    workoutSessionRepository: InMemoryWorkoutSessionRepository(
      sessions: sessions,
    ),
    nutritionRepository: InMemoryNutritionRepository(),
    bodyRepository: InMemoryBodyRepository(),
    notificationsRepository: notifications,
    deviceStore: store,
  );

  /// The staging sample, with [settings] in place of its private settings.
  InMemoryUserRepository usersWith(PrivateUserSettings settings) =>
      InMemoryUserRepository(
        users: {sampleUserId: sampleUser(now: now)},
        settings: {sampleUserId: settings},
      );

  setUp(() {
    // The sample has answered the streak reminder; meal reminders not yet.
    users = usersWith(sampleUserSettings(now: now));
    sessions = [
      ...sampleEarlierWorkoutSessions(uid: sampleUserId, now: now),
      ...sampleWorkoutSessions(uid: sampleUserId, now: now),
    ];
    notifications = FakeNotificationsRepository();
    store = InMemoryDeviceStore();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
  }

  void go(WidgetTester tester, String location) =>
      GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);

  Future<PrivateUserSettings?> settings(WidgetTester tester) =>
      tester.runAsync<PrivateUserSettings?>(
        () => users.watchPrivateSettings(sampleUserId).first,
      );

  group('meal reminders', () {
    testWidgets('are offered on the first visit to Nutrition; turning them on '
        'asks for permission and schedules them, and they are not offered '
        'again on this device', (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);
      // Today offers nothing: the streak reminder is answered.
      expect(find.byType(AlertDialog), findsNothing);

      go(tester, '/nutrition');
      await settle(tester);
      expect(find.text('Meal Reminders'), findsOneWidget);
      expect(
        find.text(
          'Compound can remind you to log breakfast, lunch and dinner each '
          'day. You can change this in Notification Settings.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Turn On Meal Reminders'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(notifications.permissionState, PushPermission.authorized);
      expect((await settings(tester))?.pushMealReminders, isTrue);
      expect(
        notifications.scheduled.keys,
        containsAll(<LocalReminderKind>[
          LocalReminderKind.breakfast,
          LocalReminderKind.lunch,
          LocalReminderKind.dinner,
        ]),
      );

      // Back to Today and to Nutrition again: shown once.
      go(tester, '/today');
      await settle(tester);
      go(tester, '/nutrition');
      await settle(tester);
      expect(find.text('Meal Reminders'), findsNothing);
    });

    testWidgets('Not Now saves the answer and asks for nothing; a later '
        'launch on the device does not offer them again', (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);
      go(tester, '/nutrition');
      await settle(tester);

      await tester.tap(find.text('Not Now'));
      await settle(tester);
      expect(notifications.permissionState, PushPermission.notDetermined);
      expect((await settings(tester))?.pushMealReminders, isFalse);
      expect(notifications.scheduled, isNot(contains(LocalReminderKind.lunch)));

      // Answered on another device is the same as answered here; this
      // checks the device flag alone, with the answer taken back.
      users = usersWith(sampleUserSettings(now: now));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await settle(tester);
      go(tester, '/nutrition');
      await settle(tester);
      expect(find.text('Meal Reminders'), findsNothing);
    });

    testWidgets('dismissing the offer answers nothing, and it is not made '
        'again on this device', (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);
      go(tester, '/nutrition');
      await settle(tester);
      expect(find.text('Meal Reminders'), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      expect(find.text('Meal Reminders'), findsNothing);
      expect((await settings(tester))?.pushMealReminders, isNull);
      expect(store.getBool('hasShownReminderOffer_meal_reminders'), isTrue);
    });
  });

  group('the streak reminder', () {
    testWidgets('is offered on Today at a two-week streak, and saved when '
        'turned on', (tester) async {
      users = usersWith(const PrivateUserSettings(pushMealReminders: false));
      notifications = FakeNotificationsRepository(
        permissionState: PushPermission.authorized,
      );
      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.text('Streak Reminder'), findsOneWidget);
      expect(
        find.textContaining(
          RegExp(
            r"^You're on a \d+-week streak\. Compound can remind you in the "
            r"evening when this week's goal needs a session that day\.$",
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Turn On Streak Reminder'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect((await settings(tester))?.socialPushStreakReminder, isTrue);
      expect(store.getBool('hasShownReminderOffer_streak_reminder'), isTrue);
    });

    testWidgets('waits for a two-week streak', (tester) async {
      users = usersWith(const PrivateUserSettings(pushMealReminders: false));
      sessions = [];
      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.text('Streak Reminder'), findsNothing);
      expect(store.getBool('hasShownReminderOffer_streak_reminder'), isNull);
    });
  });
}
