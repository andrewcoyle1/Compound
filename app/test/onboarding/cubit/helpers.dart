import 'package:analytics_repository/analytics_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

class MockTrainingSetupService extends Mock implements TrainingSetupService;

/// Records every event and screen view, in order.
class RecordingAnalytics implements AnalyticsService {
  final events = <LoggableEvent>[];

  /// Every name, screen views and events interleaved as they were made.
  List<String> get names => [for (final event in events) event.eventName];

  /// The last event named [name].
  LoggableEvent last(String name) =>
      events.lastWhere((event) => event.eventName == name);

  AnalyticsRepository get repository => AnalyticsRepository(services: [this]);

  @override
  Future<void> trackEvent(LoggableEvent event) async => events.add(event);

  @override
  Future<void> trackScreenView(LoggableEvent event) async => events.add(event);

  @override
  Future<void> identifyUser({
    required String userId,
    String? name,
    String? email,
  }) async {}

  @override
  Future<void> addUserProperties(
    Map<String, Object?> properties, {
    bool isHighPriority = false,
  }) async {}

  @override
  Future<void> deleteUserProfile() async {}
}

/// A partial update as the map of fields it writes.
Map<String, Object?> fieldsOf(Object? captured) => {
  for (final field in captured! as List<UserFieldValue>) field.key: field.value,
};
