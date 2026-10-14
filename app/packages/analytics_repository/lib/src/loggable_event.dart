/// How serious an event is. Mirrors SwiftfulLogging's `LogType`.
enum LogType {
  /// Informative, such as tracking a function. Not an issue.
  info('👋', 800),

  /// An analytic event: the default.
  analytic('📈', 800),

  /// Shouldn't happen, but doesn't hurt the user.
  warning('⚠️', 900),

  /// Hurts the user, such as a failed save. Reported to Crashlytics as a
  /// non-fatal error.
  severe('🚨', 1000);

  new(this.emoji, this.level);

  /// The prefix the console prints, as in the Swift app.
  final String emoji;

  /// The `dart:developer` log level.
  final int level;
}

/// Something worth logging. Feature blocs declare their events as an enum
/// implementing this, as the Swift presenters' `enum Event: LoggableEvent`
/// do; use the same [eventName]s (e.g. `TodayView_Appear`) so analytics stay
/// continuous across the two apps.
abstract interface class LoggableEvent {
  /// The event's name, e.g. `TodayView_StartEmptyWorkout_Press`.
  String get eventName;

  /// Extra values. Each service drops or converts what its backend can't
  /// take.
  Map<String, Object?>? get parameters;

  /// How serious it is.
  LogType get type;
}

/// {@template analytics_event}
/// A [LoggableEvent] built in place, like Swift's `AnyLoggableEvent`.
/// {@endtemplate}
class const AnalyticsEvent(
  @override final String eventName, {
  @override final Map<String, Object?>? parameters,
  @override final LogType type = LogType.analytic,
}) implements LoggableEvent {
  /// {@macro analytics_event}
  this;
}
