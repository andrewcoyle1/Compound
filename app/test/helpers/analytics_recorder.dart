import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/sharing/share_sheet.dart';
import 'package:flutter/widgets.dart';

/// An [AnalyticsRepository] that keeps every event it is given, in order.
class AnalyticsRecorder extends AnalyticsRepository {
  new();

  /// Every event and screen view, as given.
  final events = <LoggableEvent>[];

  /// The events' names.
  List<String> get names => [for (final event in events) event.eventName];

  /// The parameters of the last event named [name].
  Map<String, Object?>? parameters(String name) =>
      events.lastWhere((event) => event.eventName == name).parameters;

  @override
  void trackEvent(LoggableEvent event) => events.add(event);

  @override
  void trackScreenView(LoggableEvent event) => events.add(event);
}

/// A [ShareSheet] that keeps what it was asked to share.
class ShareRecorder extends ShareSheet {
  new();

  /// Every text shared, in order.
  final texts = <String>[];

  @override
  Future<void> shareText(BuildContext context, String text) async =>
      texts.add(text);
}
