import 'dart:async';

import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:notifications_repository/src/deep_link.dart';
import 'package:notifications_repository/src/local_reminders.dart';

/// Whether the system lets the app notify.
enum PushPermission {
  /// Never asked: asking shows the system prompt.
  notDetermined,

  /// Refused; only the system settings can change it.
  denied,

  /// Allowed.
  authorized,

  /// Allowed quietly, on trial (iOS).
  provisional;

  /// Whether a notification would be delivered.
  bool get canDeliver => this == authorized || this == provisional;
}

/// {@template push_message}
/// A push that arrived while the app was in front: its `data.type`, the
/// alert text, and where a tap on it would go.
/// {@endtemplate}
class const PushMessage({
  final String? type,
  final String? title,
  final String? body,
  final DeepLink? link,
}) extends Equatable {
  /// {@macro push_message}
  this;

  @override
  List<Object?> get props => [type, title, body, link];
}

/// {@template ongoing_workout}
/// The workout under way as Android shows it, in an ongoing notification:
/// the Live Activity's stand-in. [title] is the workout's name and [body]
/// what is next. The clock counts up from [clock] (the workout's start, less
/// any pause), or down to it while resting ([countsDown]); none while
/// paused. [alert] posts it with sound, once, as the rest-over alert.
/// {@endtemplate}
class const OngoingWorkout({
  required final String title,
  final String? body,
  final DateTime? clock,
  final bool countsDown = false,
  final bool alert = false,
}) extends Equatable {
  /// {@macro ongoing_workout}
  this;

  @override
  List<Object?> get props => [title, body, clock, countsDown, alert];
}

/// The words of a local notification and a channel's name, from the app's
/// strings (translations live in the app, not in packages).
abstract interface class NotificationCopy {
  /// The title and body for [kind]. The rest-over body is replaced by the
  /// reminder's own "Next: …" line.
  ({String title, String body}) reminder(LocalReminderKind kind);

  /// The user-visible name of an Android [channel].
  String channelName(NotificationChannel channel);
}

/// {@template deep_link_inbox}
/// Where a tapped notification wants to go, held until the app can navigate
/// (`PushManager.pendingDeepLink`). A tap that launches the app arrives
/// before anything is signed in or on screen, so a broadcast alone is lost.
///
/// The app listens to [changes], then calls [consume]; [setReady] is `true`
/// once signed in and listening, and `false` on sign-out, which drops a link
/// meant for the previous account.
/// {@endtemplate}
class DeepLinkInbox {
  /// {@macro deep_link_inbox}
  new();

  final _changes = StreamController<void>.broadcast(sync: true);
  DeepLink? _pending;
  bool _ready = false;

  /// The link waiting, if any.
  DeepLink? get pending => _pending;

  /// Emits when a link is stored, and when the inbox becomes ready.
  Stream<void> get changes => _changes.stream;

  /// Holds [link]; `null` (a payload with nowhere to go) leaves any earlier
  /// link alone.
  void store(DeepLink? link) {
    if (link == null) return;
    _pending = link;
    _changes.add(null);
  }

  /// Hands over the pending link exactly once, and only once ready.
  DeepLink? consume() {
    if (!_ready) return null;
    final link = _pending;
    _pending = null;
    return link;
  }

  /// Marks links routable (signed in) or not (signed out).
  void setReady({required bool ready}) {
    _ready = ready;
    if (ready) {
      _changes.add(null);
    } else {
      _pending = null;
    }
  }
}

/// Push and local notifications: permission, the push token, messages and
/// taps, and the local reminders.
abstract class NotificationsRepository {
  /// Taps on notifications, waiting for the app to route them.
  final DeepLinkInbox deepLinks = DeepLinkInbox();

  /// Sets up the platform plugins and picks up a tap that launched the app.
  /// Call once, before anything else.
  Future<void> initialize();

  /// Whether the app may notify.
  Future<PushPermission> permission();

  /// Asks for permission (the system prompt the first time; Android 13's
  /// POST_NOTIFICATIONS too). True when allowed.
  Future<bool> requestPermission();

  /// Keeps [uid]'s push token (and the device's time zone, which the streak
  /// reminder reads) in `users/{uid}/private/settings`, now and whenever it
  /// changes. Never on the public profile.
  Future<void> startPushTokenSync(String uid);

  /// Stops syncing on sign-out and retires this device's token, so the next
  /// account signed in here does not receive the last one's pushes.
  Future<void> stopPushTokenSync();

  /// Pushes that arrive while the app is in front.
  Stream<PushMessage> get foregroundMessages;

  /// Schedules [reminder], replacing any of its kind. The rest timer's is
  /// the first notification the app sends, so it asks for permission first
  /// when it never has.
  Future<void> schedule(LocalReminder reminder);

  /// Withdraws a pending [kind] (and a delivered one, where it can).
  Future<void> cancel(LocalReminderKind kind);

  /// The notification id of the ongoing workout; permanent, as the
  /// reminders' are.
  static const ongoingWorkoutId = 9;

  /// Whether the workout under way shows as an ongoing notification
  /// (Android). When it does, it is the rest-over channel and the rest-over
  /// notification only stands in (`RestOverAlert`).
  bool get showsOngoingWorkout;

  /// Shows, or updates, the ongoing workout notification; nothing where
  /// [showsOngoingWorkout] is false. A tap opens the tracker.
  Future<void> showOngoingWorkout(OngoingWorkout workout);

  /// Withdraws the ongoing workout notification.
  Future<void> clearOngoingWorkout();

  /// Brings the come-back and meal reminders into line with [settings]:
  /// withdrawn, then scheduled again when on and allowed. Call once signed
  /// in and on each return to the app, which moves the come-back reminders
  /// out to a day, three and five days from [now].
  Future<void> applyReminderSettings(
    PrivateUserSettings settings, {
    DateTime? now,
  }) async {
    for (final kind in [
      ...LocalReminderKind.comeBack,
      ...LocalReminderKind.meals,
    ]) {
      await cancel(kind);
    }
    if (!(await permission()).canDeliver) return;
    final reminders = [
      if (settings.isComeBackRemindersEnabled)
        ...LocalReminders.comeBack(now ?? DateTime.now()),
      if (settings.isMealRemindersEnabled) ...LocalReminders.meals(),
    ];
    for (final reminder in reminders) {
      await schedule(reminder);
    }
  }
}
