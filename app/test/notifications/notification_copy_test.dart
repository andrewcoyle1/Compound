import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';

void main() {
  group(AppNotificationCopy, () {
    final english = AppNotificationCopy(
      () => lookupAppLocalizations(const Locale('en')),
    );

    test("words every reminder as Swift's PushManager does", () {
      expect(english.reminder(LocalReminderKind.comeBack1), (
        title: 'Keep the Momentum',
        body: 'Your training plan is ready for your next session.',
      ));
      expect(
        english.reminder(LocalReminderKind.restOver).title,
        'Rest Complete',
      );
      expect(english.reminder(LocalReminderKind.idleWorkout), (
        title: 'Still training?',
        body: 'No set logged in the last hour.',
      ));
      for (final kind in LocalReminderKind.values) {
        expect(english.reminder(kind).title, isNotEmpty);
      }
    });

    test('names every channel, in Spanish too', () {
      final spanish = AppNotificationCopy(
        () => lookupAppLocalizations(const Locale('es')),
      );
      expect(NotificationChannel.values.map(english.channelName), [
        'Workout',
        'Reminders',
        'Social',
      ]);
      expect(spanish.channelName(NotificationChannel.workout), 'Entrenamiento');
      expect(spanish.reminder(LocalReminderKind.lunch).title, 'Almuerzo');
    });

    test("defaults to the device's language", () {
      expect(AppNotificationCopy().l10n.localeName, isNotEmpty);
    });
  });
}
