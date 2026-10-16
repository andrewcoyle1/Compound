import 'dart:ui';

import 'package:compound/l10n/l10n.dart';
import 'package:flutter/widgets.dart' show basicLocaleListResolution;
import 'package:notifications_repository/notifications_repository.dart';

/// The words of the app's notifications, in the device's language. Read
/// outside any widget (a notification is scheduled from a cubit, or shown
/// while the app is in the background), so [l10n] resolves the locale itself
/// rather than from a `BuildContext`.
class AppNotificationCopy implements NotificationCopy {
  /// [l10n] defaults to the device's preferred supported language.
  new([AppLocalizations Function()? l10n]) : _l10n = l10n ?? _deviceStrings;

  final AppLocalizations Function() _l10n;

  static AppLocalizations _deviceStrings() => lookupAppLocalizations(
    basicLocaleListResolution(
      PlatformDispatcher.instance.locales,
      AppLocalizations.supportedLocales,
    ),
  );

  /// The strings, looked up now (the language may have changed).
  AppLocalizations get l10n => _l10n();

  @override
  ({String title, String body}) reminder(LocalReminderKind kind) {
    final l10n = this.l10n;
    return switch (kind) {
      LocalReminderKind.comeBack1 => (
        title: l10n.notifComeBack1Title,
        body: l10n.notifComeBack1Body,
      ),
      LocalReminderKind.comeBack3 => (
        title: l10n.notifComeBack3Title,
        body: l10n.notifComeBack3Body,
      ),
      LocalReminderKind.comeBack5 => (
        title: l10n.notifComeBack5Title,
        body: l10n.notifComeBack5Body,
      ),
      LocalReminderKind.breakfast => (
        title: l10n.notifBreakfastTitle,
        body: l10n.notifBreakfastBody,
      ),
      LocalReminderKind.lunch => (
        title: l10n.notifLunchTitle,
        body: l10n.notifLunchBody,
      ),
      LocalReminderKind.dinner => (
        title: l10n.notifDinnerTitle,
        body: l10n.notifDinnerBody,
      ),
      LocalReminderKind.restOver => (title: l10n.notifRestOverTitle, body: ''),
      LocalReminderKind.idleWorkout => (
        title: l10n.notifIdleTitle,
        body: l10n.notifIdleBody,
      ),
    };
  }

  @override
  String channelName(NotificationChannel channel) => switch (channel) {
    NotificationChannel.workout => l10n.notifChannelWorkout,
    NotificationChannel.reminders => l10n.notifChannelReminders,
    NotificationChannel.social => l10n.notifChannelSocial,
  };
}
