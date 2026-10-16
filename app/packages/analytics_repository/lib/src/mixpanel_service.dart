import 'package:analytics_repository/analytics_repository.dart';
import 'package:analytics_repository/src/parameters.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

/// {@template mixpanel_service}
/// Mixpanel, sharing the Swift app's project. Create it with [init].
/// {@endtemplate}
class MixpanelService implements AnalyticsService {
  /// {@macro mixpanel_service}
  const new({required this._mixpanel});

  /// The project keeps its data in the EU, which only accepts events sent
  /// here.
  static const euServerUrl = 'https://api-eu.mixpanel.com';

  /// Starts Mixpanel with the project [token], on the EU servers. Every event
  /// carries `build_configuration` ([buildConfiguration], e.g. "dev"), as in
  /// the Swift app, so reports can leave development traffic out.
  static Future<MixpanelService> init({
    required String token,
    required String buildConfiguration,
  }) async => MixpanelService(
    mixpanel: await Mixpanel.init(
      token,
      trackAutomaticEvents: true,
      superProperties: {'build_configuration': buildConfiguration},
      serverURL: euServerUrl,
    ),
  );

  final Mixpanel _mixpanel;

  @override
  Future<void> trackEvent(LoggableEvent event) {
    final properties = mixpanelProperties(event.parameters);
    return _mixpanel.track(
      event.eventName,
      properties: properties.isEmpty ? null : properties,
    );
  }

  @override
  Future<void> trackScreenView(LoggableEvent event) => trackEvent(event);

  @override
  Future<void> identifyUser({
    required String userId,
    String? name,
    String? email,
  }) async {
    await _mixpanel.identify(userId);
    final people = _mixpanel.getPeople();
    if (name != null) people.set(r'$name', name);
    if (email != null) people.set(r'$email', email);
  }

  @override
  Future<void> addUserProperties(
    Map<String, Object?> properties, {
    bool isHighPriority = false,
  }) async {
    final people = _mixpanel.getPeople();
    mixpanelProperties(properties).forEach(people.set);
  }

  @override
  Future<void> deleteUserProfile() async => _mixpanel.getPeople().deleteUser();

  /// This device's distinct id (Swift `MixpanelService.distinctId`).
  Future<String> distinctId() => _mixpanel.getDistinctId();
}
