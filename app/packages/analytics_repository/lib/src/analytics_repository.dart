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

  /// Mixpanel's distinct id for this device, for RevenueCat's customer
  /// profile (Swift `Constants.mixpanelDistinctId`); null without Mixpanel
  /// or when it cannot say.
  Future<String?> mixpanelDistinctId() =>
      _read<MixpanelService>((service) => service.distinctId());

  /// Firebase Analytics' app instance id, for RevenueCat's customer profile
  /// (Swift `Constants.firebaseAnalyticsAppInstanceID`); null without
  /// Firebase Analytics or when it cannot say.
  Future<String?> firebaseAppInstanceId() =>
      _read<FirebaseAnalyticsService>((service) => service.appInstanceId());

  /// What the first service of type [T] answers; null when there is none or
  /// it fails, which is logged.
  Future<String?> _read<T extends AnalyticsService>(
    Future<String?> Function(T service) read,
  ) async {
    for (final service in _services.whereType<T>()) {
      try {
        return await read(service);
      } on Object catch (error, stackTrace) {
        _log(service, error, stackTrace);
        return null;
      }
    }
    return null;
  }

  void _forEach(Future<void> Function(AnalyticsService service) call) {
    for (final service in _services) {
      unawaited(
        Future.sync(() => call(service)).catchError(
          (Object error, StackTrace stackTrace) =>
              _log(service, error, stackTrace),
        ),
      );
    }
  }

  void _log(AnalyticsService service, Object error, StackTrace stackTrace) =>
      developer.log(
        '${service.runtimeType} failed',
        name: 'analytics',
        error: error,
        stackTrace: stackTrace,
      );
}
