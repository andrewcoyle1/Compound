import 'package:analytics_repository/analytics_repository.dart';
import 'package:mocktail/mocktail.dart';

/// An [AnalyticsRepository] that remembers every event, as
/// `(name, parameters)`.
class RecordingAnalytics extends Fake implements AnalyticsRepository {
  final events = <(String, Map<String, Object?>?)>[];

  /// The names of the events, in order.
  List<String> get names => [for (final (name, _) in events) name];

  @override
  void trackEvent(LoggableEvent event) =>
      events.add((event.eventName, event.parameters));

  @override
  void trackScreenView(LoggableEvent event) => trackEvent(event);
}
