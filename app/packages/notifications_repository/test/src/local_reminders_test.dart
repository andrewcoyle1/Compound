import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 9);

  group(LocalReminderKind, () {
    // PushManagerTests: a renamed id could never be cancelled.
    test('ids are distinct and permanent', () {
      expect(LocalReminderKind.values.map((k) => k.id), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      ]);
      expect(LocalReminderKind.comeBack.map((k) => k.channel).toSet(), {
        NotificationChannel.reminders,
      });
      expect(LocalReminderKind.restOver.channel, NotificationChannel.workout);
      expect(
        LocalReminderKind.idleWorkout.channel,
        NotificationChannel.workout,
      );
    });
  });

  group(LocalReminders, () {
    // PushManagerTests.testTheComeBackRemindersLandOneThreeAndFiveDaysOut
    test('come-back reminders land one, three and five days out', () {
      final reminders = LocalReminders.comeBack(now);
      expect(reminders.map((r) => r.kind), LocalReminderKind.comeBack);
      expect(reminders.map((r) => r.schedule), [
        ReminderAt(now.add(const Duration(hours: 24))),
        ReminderAt(now.add(const Duration(hours: 72))),
        ReminderAt(now.add(const Duration(hours: 120))),
      ]);
      expect(reminders.every((r) => r.level == ReminderLevel.active), isTrue);
    });

    // PushManagerTests.testMealRemindersArePassiveDailyReminders
    test('meal reminders are passive daily reminders that open Nutrition', () {
      final reminders = LocalReminders.meals();
      expect(reminders.map((r) => r.kind), LocalReminderKind.meals);
      expect(reminders.map((r) => r.schedule), const [
        ReminderDaily(8, 0),
        ReminderDaily(12, 30),
        ReminderDaily(18, 30),
      ]);
      expect(reminders.every((r) => r.level == ReminderLevel.passive), isTrue);
      expect(
        reminders.map((r) => DeepLink.fromData(r.data!)),
        everyElement(const TabLink(DeepLinkTab.nutrition)),
      );
    });

    // PushManagerTests.testASilentTimeSensitiveNotification
    test('rest over is time sensitive and can be silent', () {
      final at = now.add(const Duration(minutes: 2));
      expect(
        LocalReminders.restOver(at: at, body: 'Next: Squat', sound: false),
        LocalReminder(
          kind: LocalReminderKind.restOver,
          schedule: ReminderAt(at),
          level: ReminderLevel.timeSensitive,
          sound: false,
          body: 'Next: Squat',
        ),
      );
      expect(LocalReminders.restOver(at: at).body, '');
      expect(LocalReminders.restOver(at: at).sound, isTrue);
    });

    test('the idle reminder is an hour after the last set, if still ahead', () {
      expect(
        LocalReminders.idleWorkout(lastLog: now, now: now),
        LocalReminder(
          kind: LocalReminderKind.idleWorkout,
          schedule: ReminderAt(now.add(const Duration(hours: 1))),
        ),
      );
      expect(
        LocalReminders.idleWorkout(
          lastLog: now.subtract(const Duration(hours: 1)),
          now: now,
        ),
        isNull,
      );
    });
  });

  // IdleWorkoutReminderTests
  group(IdleWorkout, () {
    test('a workout is idle from an hour after the last set', () {
      for (final seconds in [3540, 3600, 14400]) {
        expect(
          IdleWorkout.isIdle(
            lastActivity: now,
            now: now.add(Duration(seconds: seconds)),
          ),
          seconds >= 3600,
        );
      }
    });

    test('a last set in the future is not idle', () {
      expect(
        IdleWorkout.isIdle(
          lastActivity: now,
          now: now.subtract(const Duration(hours: 1)),
        ),
        isFalse,
      );
    });

    test('the threshold can be shortened', () {
      expect(
        IdleWorkout.isIdle(
          lastActivity: now,
          now: now.add(const Duration(minutes: 45)),
          threshold: const Duration(minutes: 45),
        ),
        isTrue,
      );
    });
  });

  // RestOverAlertTests
  group(RestOverAlert, () {
    test('on time with a live activity, the activity alerts', () {
      for (final ms in [0, 100, 1900]) {
        expect(
          RestOverAlert.channel(
            showingLiveActivity: true,
            lateBy: Duration(milliseconds: ms),
            sound: true,
          ),
          RestOverAlert.liveActivity,
        );
      }
    });

    test('late with a live activity, the notification has already alerted', () {
      for (final seconds in [2, 30]) {
        expect(
          RestOverAlert.channel(
            showingLiveActivity: true,
            lateBy: Duration(seconds: seconds),
            sound: true,
          ),
          RestOverAlert.notification,
        );
      }
    });

    test('without a live activity the notification is the alert', () {
      expect(
        RestOverAlert.channel(
          showingLiveActivity: false,
          lateBy: Duration.zero,
          sound: true,
        ),
        RestOverAlert.notification,
      );
    });

    test('with sound off the activity is only cleared', () {
      expect(
        RestOverAlert.channel(
          showingLiveActivity: true,
          lateBy: Duration.zero,
          sound: false,
        ),
        RestOverAlert.clearLiveActivity,
      );
    });

    test('the stand-in is due two seconds after the end', () {
      expect(
        RestOverAlert.notificationDate(restEnd: now, showingLiveActivity: true),
        now.add(const Duration(seconds: 2)),
      );
      expect(
        RestOverAlert.notificationDate(
          restEnd: now,
          showingLiveActivity: false,
        ),
        now,
      );
    });
  });

  // PushManagerTests.testForegroundPresentation
  group(ForegroundPresentation, () {
    test('social pushes go quietly to the list while the app is in front', () {
      for (final type in ForegroundPresentation.socialTypes) {
        expect(
          ForegroundPresentation.of(type: type),
          ForegroundPresentation.list,
        );
      }
      expect(ForegroundPresentation.socialTypes, hasLength(9));
      expect(
        ForegroundPresentation.of(kind: LocalReminderKind.restOver),
        ForegroundPresentation.none,
      );
      expect(
        ForegroundPresentation.of(type: 'streakReminder'),
        ForegroundPresentation.banner,
      );
      expect(ForegroundPresentation.of(), ForegroundPresentation.banner);
    });
  });

  // ReminderOfferFlowTests.testDefaults
  group('ReminderSettings', () {
    test('absent settings read as come-back on, meals and streak off', () {
      const settings = PrivateUserSettings();
      expect(settings.isComeBackRemindersEnabled, isTrue);
      expect(settings.isMealRemindersEnabled, isFalse);
      expect(settings.isStreakReminderEnabled, isFalse);
      const set = PrivateUserSettings(
        pushComeBackReminders: false,
        pushMealReminders: true,
        socialPushStreakReminder: true,
      );
      expect(set.isComeBackRemindersEnabled, isFalse);
      expect(set.isMealRemindersEnabled, isTrue);
      expect(set.isStreakReminderEnabled, isTrue);
    });
  });

  // ReminderOfferFlowTests
  group(ReminderOffer, () {
    const unanswered = PrivateUserSettings();

    test('meal reminders are offered once, until answered on any device', () {
      expect(
        ReminderOffer.mealReminders.shouldOffer(
          settings: unanswered,
          shownOnDevice: false,
        ),
        isTrue,
      );
      expect(
        ReminderOffer.mealReminders.shouldOffer(
          settings: unanswered,
          shownOnDevice: true,
        ),
        isFalse,
      );
      expect(
        ReminderOffer.mealReminders.shouldOffer(
          settings: const PrivateUserSettings(pushMealReminders: false),
          shownOnDevice: false,
        ),
        isFalse,
      );
    });

    test('the streak reminder waits for a two-week streak', () {
      bool offer(int weeks, [PrivateUserSettings settings = unanswered]) =>
          ReminderOffer.streakReminder.shouldOffer(
            settings: settings,
            shownOnDevice: false,
            streakWeeks: weeks,
          );
      expect(offer(1), isFalse);
      expect(offer(2), isTrue);
      expect(
        offer(5, const PrivateUserSettings(socialPushStreakReminder: false)),
        isFalse,
      );
    });
  });
}
