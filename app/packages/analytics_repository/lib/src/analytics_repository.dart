import 'dart:async';
import 'dart:developer' as developer;

import 'package:analytics_repository/analytics_repository.dart';

/// {@template analytics_repository}
/// Sends each call to every one of its [AnalyticsService]s. Mirrors
/// SwiftfulLogging's `LogManager`.
///
/// Calls return immediately. A service that fails is logged and never stops
/// the others or reaches the caller: analytics must not break the app.
/// {@endtemplate}
class AnalyticsRepository {
  /// {@macro analytics_repository}
  const new({this._services = const []});

  final List<AnalyticsService> _services;

  /// Logs [event].
  void trackEvent(LoggableEvent event) =>
      _forEach((service) => service.trackEvent(event));

  /// Logs that the screen named by [event] appeared.
  void trackScreenView(LoggableEvent event) =>
      _forEach((service) => service.trackScreenView(event));

  /// Attributes what follows to [userId].
  void identifyUser({required String userId, String? name, String? email}) =>
      _forEach(
        (service) =>
            service.identifyUser(userId: userId, name: name, email: email),
      );

  /// Sets properties on the current user.
  void addUserProperties(
    Map<String, Object?> properties, {
    bool isHighPriority = false,
  }) => _forEach(
    (service) =>
        service.addUserProperties(properties, isHighPriority: isHighPriority),
  );

  /// Forgets the current user's profile, after account deletion.
  void deleteUserProfile() =>
      _forEach((service) => service.deleteUserProfile());

  void _forEach(Future<void> Function(AnalyticsService service) call) {
    for (final service in _services) {
      unawaited(
        Future.sync(() => call(service)).catchError(
          (Object error, StackTrace stackTrace) => developer.log(
            '${service.runtimeType} failed',
            name: 'analytics',
            error: error,
            stackTrace: stackTrace,
          ),
        ),
      );
    }
  }
}
