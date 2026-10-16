import 'package:analytics_repository/analytics_repository.dart';
import 'package:analytics_repository/src/parameters.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// {@template firebase_analytics_service}
/// Firebase Analytics, cleaned to its limits as the Swift
/// `FirebaseAnalyticsService` does.
///
/// Unlike the Swift service it never sends a name or email: Google
/// Analytics' terms forbid personal data.
/// {@endtemplate}
class FirebaseAnalyticsService implements AnalyticsService {
  /// {@macro firebase_analytics_service}
  const new({required this._analytics});

  final FirebaseAnalytics _analytics;

  @override
  Future<void> trackEvent(LoggableEvent event) {
    final parameters = firebaseParameters(event.parameters);
    return _analytics.logEvent(
      name: clean(event.eventName, firebaseNameLength),
      parameters: parameters.isEmpty ? null : parameters,
    );
  }

  @override
  Future<void> trackScreenView(LoggableEvent event) => _analytics.logScreenView(
    screenName: clean(event.eventName, firebaseNameLength),
  );

  @override
  Future<void> identifyUser({
    required String userId,
    String? name,
    String? email,
  }) => _analytics.setUserId(id: userId);

  /// Only [isHighPriority] properties are set: Firebase allows 25.
  @override
  Future<void> addUserProperties(
    Map<String, Object?> properties, {
    bool isHighPriority = false,
  }) async {
    if (!isHighPriority) return;
    for (final MapEntry(:key, :value) in properties.entries) {
      if (describe(value) case final text?) {
        await _analytics.setUserProperty(
          name: clean(key, firebaseUserPropertyNameLength),
          value: clean(text, firebaseValueLength),
        );
      }
    }
  }

  /// Nothing to delete: as in the Swift service.
  @override
  Future<void> deleteUserProfile() async {}

  /// This install's app instance id, or null when analytics collection is
  /// off (Swift `FirebaseAnalyticsService.appInstanceID`).
  Future<String?> appInstanceId() => _analytics.appInstanceId;
}
