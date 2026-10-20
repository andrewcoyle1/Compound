import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// Every local notification the app schedules. Each has one fixed [id], so
/// scheduling again replaces it and cancelling finds it: a repeating meal
/// reminder under an id no longer listed here could never be turned off, so
/// these numbers are permanent.
enum LocalReminderKind {
  /// "Keep the Momentum", a day after the app was last opened.
  comeBack1(1, NotificationChannel.reminders),

  /// "Stay Consistent", three days after.
  comeBack3(2, NotificationChannel.reminders),

  /// "Your Progress Is Waiting", five days after.
  comeBack5(3, NotificationChannel.reminders),

  /// Log breakfast, daily at 08:00.
  breakfast(4, NotificationChannel.reminders),

  /// Log lunch, daily at 12:30.
  lunch(5, NotificationChannel.reminders),

  /// Log dinner, daily at 18:30.
  dinner(6, NotificationChannel.reminders),

  /// "Rest Complete" (`RestOverNotifying.swift`).
  restOver(7, NotificationChannel.workout),

  /// "Still training?" (`IdleWorkoutReminder.swift`).
  idleWorkout(8, NotificationChannel.workout);

  new(this.id, this.channel);

  /// The notification id, as the platform plugin needs an int.
  final int id;

  /// The Android channel it posts to.
  final NotificationChannel channel;

  /// The come-back reminders, one, three and five days out.
  static const List<LocalReminderKind> comeBack = [
    comeBack1,
    comeBack3,
    comeBack5,
  ];

  /// The meal reminders, breakfast, lunch and dinner.
  static const List<LocalReminderKind> meals = [breakfast, lunch, dinner];
}

/// Android notification channels. Their user-visible names come from the
/// app's strings.
enum NotificationChannel {
  /// The rest timer and the idle-workout reminder: about now, so heads-up.
  workout,

  /// Come-back and meal reminders.
  reminders,

  /// Social activity and server pushes shown while the app is in front.
  social,
}

/// How much a notification interrupts (iOS interruption levels).
enum ReminderLevel {
  /// Waits in Notification Center without lighting the screen.
  passive,

  /// The default.
  active,

  /// Breaks through a Focus: something happening now.
  timeSensitive,
}

/// When a reminder fires.
sealed class ReminderSchedule extends Equatable {
  /// Subclasses only.
  const new();
}

/// Once, at [at].
class const ReminderAt(final DateTime at) extends ReminderSchedule {
  /// Fires at [at].
  this;

  @override
  List<Object?> get props => [at];
}

/// Every day at [hour]:[minute] on the device's clock.
class const ReminderDaily(final int hour, final int minute)
    extends ReminderSchedule {
  /// Fires daily at [hour]:[minute].
  this;

  @override
  List<Object?> get props => [hour, minute];
}

/// {@template local_reminder}
/// One local notification to schedule. Its words come from the app's strings
/// by [kind]; [body], when set, replaces the body (the rest timer's
/// "Next: …" line). [data] is read back with `DeepLink.fromData` on a tap.
/// {@endtemplate}
class const LocalReminder({
  required final LocalReminderKind kind,
  required final ReminderSchedule schedule,
  final ReminderLevel level = ReminderLevel.active,
  final bool sound = true,
  final String? body,
  final Map<String, String>? data,
}) extends Equatable {
  /// {@macro local_reminder}
  this;

  @override
  List<Object?> get props => [kind, schedule, level, sound, body, data];
}

/// The local notifications the Swift app schedules, as pure plans
/// (`PushManager.swift`, `RestOverNotifying.swift`,
/// `IdleWorkoutReminder.swift`).
abstract final class LocalReminders {
  /// A day is a fixed 24 hours, so the reminders keep their offset from the
  /// last launch across a clock change (an hour of drift, never a missing
  /// reminder), as in Swift.
  static const day = Duration(hours: 24);

  /// The come-back reminders, a day, three days and five days from [now].
  /// Rescheduled on every sign-in and return to the app, so they arrive only
  /// after that long away.
  static List<LocalReminder> comeBack(DateTime now) => [
    for (final (kind, days) in [
      (LocalReminderKind.comeBack1, 1),
      (LocalReminderKind.comeBack3, 3),
      (LocalReminderKind.comeBack5, 5),
    ])
      LocalReminder(kind: kind, schedule: ReminderAt(now.add(day * days))),
  ];

  /// Breakfast, lunch and dinner, daily and passive. A tap opens Nutrition.
  static List<LocalReminder> meals() => [
    for (final (kind, hour, minute) in [
      (LocalReminderKind.breakfast, 8, 0),
      (LocalReminderKind.lunch, 12, 30),
      (LocalReminderKind.dinner, 18, 30),
    ])
      LocalReminder(
        kind: kind,
        schedule: ReminderDaily(hour, minute),
        level: ReminderLevel.passive,
        data: const {'tab': 'nutrition'},
      ),
  ];

  /// "Rest Complete" at [at], time-sensitive; with [sound] off it is still
  /// delivered, as a silent banner. [body] is the "Next: …" line.
  static LocalReminder restOver({
    required DateTime at,
    String? body,
    bool sound = true,
  }) => LocalReminder(
    kind: LocalReminderKind.restOver,
    schedule: ReminderAt(at),
    level: ReminderLevel.timeSensitive,
    sound: sound,
    body: body ?? '',
  );

  /// "Still training?", an hour after [lastLog], or `null` when that is not
  /// after [now].
  static LocalReminder? idleWorkout({
    required DateTime lastLog,
    required DateTime now,
  }) {
    final at = lastLog.add(IdleWorkout.threshold);
    if (!at.isAfter(now)) return null;
    return LocalReminder(
      kind: LocalReminderKind.idleWorkout,
      schedule: ReminderAt(at),
    );
  }
}

/// When a workout counts as forgotten (`IdleWorkoutReminder.swift`).
abstract final class IdleWorkout {
  /// An hour after the last logged set.
  static const threshold = Duration(hours: 1);

  /// Whether [now] is at least [threshold] after [lastActivity]. A clock that
  /// went backwards is not a forgotten workout.
  static bool isIdle({
    required DateTime lastActivity,
    required DateTime now,
    Duration threshold = threshold,
  }) => now.difference(lastActivity) >= threshold;
}

/// Who says a rest is over, decided when it runs out (`RestOverAlert`).
enum RestOverAlert {
  /// The Live Activity (or ongoing notification) alerts; the stand-in
  /// notification is withdrawn.
  liveActivity,

  /// The activity is only cleared, since "Play Sound" is off; the
  /// notification is withdrawn all the same.
  clearLiveActivity,

  /// The notification is the alert: no activity, or the app got there late.
  notification;

  /// How long after a rest ends the stand-in notification waits for the app.
  static const standInDelay = Duration(seconds: 2);

  /// [lateBy] is how long after the rest's end the app's timer fired.
  static RestOverAlert channel({
    required bool showingLiveActivity,
    required Duration lateBy,
    required bool sound,
  }) {
    if (!showingLiveActivity || lateBy >= standInDelay) return notification;
    return sound ? liveActivity : clearLiveActivity;
  }

  /// When the notification is due: on the second with no activity, where it
  /// is the alert; [standInDelay] late with one, where it only stands in.
  static DateTime notificationDate({
    required DateTime restEnd,
    required bool showingLiveActivity,
  }) => showingLiveActivity ? restEnd.add(standInDelay) : restEnd;
}

/// How a notification shows while the app is in front
/// (`PushManager.foregroundPresentation`).
enum ForegroundPresentation {
  /// Not at all: the tracker plays its own rest-over sound and haptic.
  none,

  /// Quietly into the notification list: social activity already shows in
  /// the app.
  list,

  /// A banner with sound.
  banner;

  /// The `data.type` values `functions/lib.js` sends for social activity.
  static const socialTypes = {
    'like',
    'comment',
    'mention',
    'follow',
    'followAccepted',
    'follow_request',
    'nudge',
    'share',
    'challenge_complete',
  };

  /// The presentation for a local [kind] or a push of [type].
  static ForegroundPresentation of({LocalReminderKind? kind, String? type}) {
    if (kind == LocalReminderKind.restOver) return none;
    if (socialTypes.contains(type)) return list;
    return banner;
  }
}

/// The reminder switches, read as Swift reads absent fields.
extension ReminderSettings on PrivateUserSettings {
  /// Come-back reminders: absent means on.
  bool get isComeBackRemindersEnabled => pushComeBackReminders ?? true;

  /// Meal reminders: absent means never answered, so off.
  bool get isMealRemindersEnabled => pushMealReminders ?? false;

  /// The server's streak reminder: absent means off.
  bool get isStreakReminderEnabled => socialPushStreakReminder ?? false;
}

/// The two reminders offered once, in the app, when they become relevant
/// (`ReminderOfferFlow.swift`). The dialog and the "shown on this device"
/// flag belong to the app.
enum ReminderOffer {
  /// On the first visit to Nutrition.
  mealReminders,

  /// Once a two-week streak is reached.
  streakReminder;

  /// Two weeks: one is only this week's goal.
  static const streakThreshold = 2;

  /// Unanswered in the private settings (on any device) and not yet
  /// [shownOnDevice]; the streak offer also waits for [streakWeeks].
  bool shouldOffer({
    required PrivateUserSettings settings,
    required bool shownOnDevice,
    int streakWeeks = 0,
  }) {
    if (shownOnDevice) return false;
    return switch (this) {
      mealReminders => settings.pushMealReminders == null,
      streakReminder =>
        settings.socialPushStreakReminder == null &&
            streakWeeks >= streakThreshold,
    };
  }
}
