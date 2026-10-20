import 'dart:typed_data';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/integrations/link_opener.dart';
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

  /// Every image shared, by name, with its PNG bytes.
  final images = <(String, Uint8List)>[];

  @override
  Future<void> shareText(BuildContext context, String text) async =>
      texts.add(text);

  @override
  Future<void> shareImage(
    BuildContext context,
    Uint8List bytes, {
    required String name,
  }) async => images.add((name, bytes));

  @override
  Future<void> shareImages(
    BuildContext context,
    List<(String, Uint8List)> images,
  ) async => this.images.addAll(images);
}

/// A [LinkOpener] that keeps the links it was asked to open.
class LinkRecorder extends LinkOpener {
  new();

  /// Every link opened, in order.
  final opened = <Uri>[];

  @override
  Future<void> open(Uri uri) async => opened.add(uri);
}
