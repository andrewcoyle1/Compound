// Swift's ReminderOfferFlowTests, case for case, plus what Flutter adds:
// waiting for the settings, the permission already answered, a failed
// permission request and a failed save.
import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/notifications/reminder_offer/reminder_offer_cubit.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../settings/general/recorded_analytics.dart';

const _uid = 'me';

class _FailingUsers extends InMemoryUserRepository {
  @override
  Future<void> mergePrivateSettings(
    String uid,
    PrivateUserSettings settings, {
    Set<String> clearing = const {},
  }) => throw StateError('no');
}

class _RefusingNotifications extends FakeNotificationsRepository {
  @override
  Future<bool> requestPermission() => throw StateError('no');
}

void main() {
  late InMemoryUserRepository users;
  late FakeNotificationsRepository notifications;
  late RecordedAnalytics analytics;
  late InMemoryDeviceStore store;

  setUp(() {
    users = InMemoryUserRepository(
      settings: {_uid: const PrivateUserSettings()},
    );
    notifications = FakeNotificationsRepository();
    analytics = RecordedAnalytics();
    store = InMemoryDeviceStore();
  });

  ReminderOfferCubit build() => ReminderOfferCubit(
    users: users,
    notifications: notifications,
    analytics: analytics,
    store: store,
    uid: _uid,
  );

  Future<PrivateUserSettings?> settings() =>
      users.watchPrivateSettings(_uid).first;

  test("the device keys are Swift's", () {
    expect(
      ReminderOffer.mealReminders.shownKey,
      'hasShownReminderOffer_meal_reminders',
    );
    expect(
      ReminderOffer.streakReminder.shownKey,
      'hasShownReminderOffer_streak_reminder',
    );
  });

  group('meal reminders', () {
    // testMealRemindersAreOfferedOnce
    blocTest<ReminderOfferCubit, ReminderOfferState>(
      'are offered once, on the first visit',
      build: build,
      act: (cubit) => cubit
        ..offerMealRemindersIfNeeded()
        ..offerMealRemindersIfNeeded(),
      expect: () => [
        const ReminderOfferState(
          offer: ReminderOffer.mealReminders,
          offerId: 1,
        ),
      ],
      verify: (_) {
        expect(analytics.events, [
          [
            'ReminderOffer_Shown',
            {'offer': 'meal_reminders'},
            LogType.analytic,
          ],
        ]);
        expect(store.getBool('hasShownReminderOffer_meal_reminders'), isTrue);
      },
    );

    // testMealRemindersAreNotOfferedOnceAnswered
    blocTest<ReminderOfferCubit, ReminderOfferState>(
      'are not offered once answered on any device',
      setUp: () => users = InMemoryUserRepository(
        settings: {_uid: const PrivateUserSettings(pushMealReminders: false)},
      ),
      build: build,
      act: (cubit) => cubit.offerMealRemindersIfNeeded(),
      expect: () => <ReminderOfferState>[],
    );

    blocTest<ReminderOfferCubit, ReminderOfferState>(
      'are not offered again on a device that showed them',
      setUp: () => store = InMemoryDeviceStore({
        'hasShownReminderOffer_meal_reminders': true,
      }),
      build: build,
      act: (cubit) => cubit.offerMealRemindersIfNeeded(),
      expect: () => <ReminderOfferState>[],
    );

    blocTest<ReminderOfferCubit, ReminderOfferState>(
      'wait for the settings before offering, and are offered without a '
      'settings document',
      setUp: () => users = InMemoryUserRepository(),
      build: build,
      act: (cubit) {
        expect(cubit.shouldOffer(ReminderOffer.mealReminders), isFalse);
        cubit.offerMealRemindersIfNeeded();
      },
      expect: () => [
        const ReminderOfferState(
          offer: ReminderOffer.mealReminders,
          offerId: 1,
        ),
      ],
    );

    // testAcceptingMealReminders
    test('accepting asks for permission, then turns them on', () async {
      final cubit = build();
      await pumpEventQueue();

      await cubit.answer(ReminderOffer.mealReminders, accepted: true);

      expect(notifications.permissionState, PushPermission.authorized);
      expect((await settings())?.pushMealReminders, isTrue);
      expect((await settings())?.isMealRemindersEnabled, isTrue);
      expect(cubit.shouldOffer(ReminderOffer.mealReminders), isFalse);
      await cubit.close();
    });

    // testDecliningMealReminders
    test('Not Now records the answer and asks for nothing', () async {
      final cubit = build();
      await pumpEventQueue();

      await cubit.answer(ReminderOffer.mealReminders, accepted: false);

      expect(notifications.permissionState, PushPermission.notDetermined);
      expect((await settings())?.pushMealReminders, isFalse);
      expect(cubit.shouldOffer(ReminderOffer.mealReminders), isFalse);
      await cubit.close();
    });

    test('accepting with permission already answered asks again for '
        'nothing', () async {
      notifications = FakeNotificationsRepository(
        permissionState: PushPermission.denied,
      );
      final cubit = build();

      await cubit.answer(ReminderOffer.mealReminders, accepted: true);

      expect(notifications.permissionState, PushPermission.denied);
      expect((await settings())?.pushMealReminders, isTrue);
      await cubit.close();
    });

    test('a failed permission request is a warning, and the answer is still '
        'saved', () async {
      notifications = _RefusingNotifications();
      final cubit = build();

      await cubit.answer(ReminderOffer.mealReminders, accepted: true);

      expect(analytics.events[1], [
        'ReminderOffer_RequestPermission_Fail',
        {'offer': 'meal_reminders', 'error_description': 'Bad state: no'},
        LogType.warning,
      ]);
      expect((await settings())?.pushMealReminders, isTrue);
      await cubit.close();
    });
  });

  group('the streak reminder', () {
    // testTheStreakReminderWaitsForATwoWeekStreak
    blocTest<ReminderOfferCubit, ReminderOfferState>(
      'waits for a two-week streak',
      build: build,
      act: (cubit) async {
        await pumpEventQueue();
        cubit.offerStreakReminderIfNeeded(1);
        expect(cubit.state.offer, isNull);
        cubit
          ..offerStreakReminderIfNeeded(2)
          ..offerStreakReminderIfNeeded(2);
      },
      expect: () => [
        const ReminderOfferState(
          offer: ReminderOffer.streakReminder,
          streakWeeks: 2,
          offerId: 1,
        ),
      ],
    );

    // TodayPresenterTests.testBelowThresholdOrAlreadyAnsweredOffersNothing
    blocTest<ReminderOfferCubit, ReminderOfferState>(
      'is not offered once answered',
      setUp: () => users = InMemoryUserRepository(
        settings: {
          _uid: const PrivateUserSettings(socialPushStreakReminder: false),
        },
      ),
      build: build,
      act: (cubit) => cubit.offerStreakReminderIfNeeded(5),
      expect: () => <ReminderOfferState>[],
    );

    // testAcceptingTheStreakReminder
    test("accepting turns on the server's switch", () async {
      notifications = FakeNotificationsRepository(
        permissionState: PushPermission.authorized,
      );
      final cubit = build();

      await cubit.answer(ReminderOffer.streakReminder, accepted: true);

      expect((await settings())?.socialPushStreakReminder, isTrue);
      expect((await settings())?.pushMealReminders, isNull);
      expect(analytics.events, [
        [
          'ReminderOffer_Answered',
          {'offer': 'streak_reminder', 'accepted': true},
          LogType.analytic,
        ],
        [
          'ReminderOffer_Save_Start',
          {'offer': 'streak_reminder', 'accepted': true},
          LogType.analytic,
        ],
        [
          'ReminderOffer_Save_Success',
          {'offer': 'streak_reminder', 'accepted': true},
          LogType.analytic,
        ],
      ]);
      await cubit.close();
    });
  });

  group('a failed save', () {
    blocTest<ReminderOfferCubit, ReminderOfferState>(
      'is severe and says so',
      setUp: () => users = _FailingUsers(),
      build: build,
      act: (cubit) =>
          cubit.answer(ReminderOffer.streakReminder, accepted: false),
      expect: () => [const ReminderOfferState(saveFailures: 1)],
      verify: (_) => expect(analytics.events.last, [
        'ReminderOffer_Save_Fail',
        {'offer': 'streak_reminder', 'error_description': 'Bad state: no'},
        LogType.severe,
      ]),
    );

    test('after closing emits nothing', () async {
      users = _FailingUsers();
      final cubit = build();
      await cubit.close();

      await cubit.answer(ReminderOffer.mealReminders, accepted: false);

      expect(cubit.state.saveFailures, 0);
    });
  });

  // testDefaults lives in notifications_repository's local_reminders_test.
}
