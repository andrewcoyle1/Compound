import 'package:analytics_repository/analytics_repository.dart';

/// One analytics backend. Mirrors SwiftfulLogging's `LogService`.
abstract interface class AnalyticsService {
  /// Logs [event].
  Future<void> trackEvent(LoggableEvent event);

  /// Logs that the screen named by [event] appeared.
  Future<void> trackScreenView(LoggableEvent event);

  /// Attributes what follows to [userId].
  Future<void> identifyUser({
    required String userId,
    String? name,
    String? email,
  });

  /// Sets properties on the current user. Services with a small quota of
  /// user properties (Firebase, Crashlytics) only take [isHighPriority] ones.
  Future<void> addUserProperties(
    Map<String, Object?> properties, {
    bool isHighPriority = false,
  });

  /// Forgets the current user's profile, after account deletion.
  Future<void> deleteUserProfile();
}
