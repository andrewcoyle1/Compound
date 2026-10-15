import 'package:analytics_repository/analytics_repository.dart';
import 'package:mocktail/mocktail.dart';

/// An [AnalyticsRepository] that keeps every event as `[name, parameters,
/// type]`, a list so `expect` compares it deeply; screen views apart.
class RecordedAnalytics extends Fake implements AnalyticsRepository {
  final events = <List<Object?>>[];
  final screenViews = <String>[];

  /// The event names, screen views left out.
  List<String> get names => [for (final event in events) event[0]! as String];

  @override
  void trackEvent(LoggableEvent event) =>
      events.add([event.eventName, event.parameters, event.type]);

  @override
  void trackScreenView(LoggableEvent event) => screenViews.add(event.eventName);
}
