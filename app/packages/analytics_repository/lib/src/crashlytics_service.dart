import 'package:analytics_repository/analytics_repository.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// {@template crashlytics_service}
/// Crashlytics: a [LogType.severe] event is recorded as a non-fatal error,
/// and every other event is left as a breadcrumb in the log that goes with
/// the next report.
/// {@endtemplate}
class CrashlyticsService implements AnalyticsService {
  /// {@macro crashlytics_service}
  const new({required this._crashlytics});

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> trackEvent(LoggableEvent event) {
    if (event.type != LogType.severe) {
      return _crashlytics.log('${event.type.name}: ${event.eventName}');
    }
    return _crashlytics.recordError(
      event.eventName,
      // The caller's frames, so each call site is its own issue.
      StackTrace.current,
      reason: event.eventName,
      information: [
        for (final MapEntry(:key, :value) in (event.parameters ?? {}).entries)
          '$key: $value',
      ],
    );
  }

  @override
  Future<void> trackScreenView(LoggableEvent event) => trackEvent(event);

  @override
  Future<void> identifyUser({
    required String userId,
    String? name,
    String? email,
  }) => _crashlytics.setUserIdentifier(userId);

  /// Only [isHighPriority] properties are set, as custom keys: Crashlytics
  /// allows 64.
  @override
  Future<void> addUserProperties(
    Map<String, Object?> properties, {
    bool isHighPriority = false,
  }) async {
    if (!isHighPriority) return;
    for (final MapEntry(:key, :value) in properties.entries) {
      if (value == null) continue;
      await _crashlytics.setCustomKey(
        key,
        value is String || value is num || value is bool ? value : '$value',
      );
    }
  }

  @override
  Future<void> deleteUserProfile() => _crashlytics.setUserIdentifier('');
}
