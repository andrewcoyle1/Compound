import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The pixel density cards are drawn at: a 360-point card comes out 1080
/// pixels wide, as Swift's `ShareCardRenderer.scale`.
const shareCardScale = 3.0;

/// [url]'s picture, loaded for a card, or null when it is not an http
/// address or does not arrive in five seconds: the drawing is a single pass
/// that would not wait for it (`ShareCardRenderer.loadAvatar`).
Future<ImageProvider?> loadShareCardImage(
  BuildContext context,
  String? url,
) async {
  if (url == null || !url.startsWith('http')) return null;
  final image = NetworkImage(url);
  var failed = false;
  try {
    await precacheImage(
      image,
      context,
      onError: (_, _) => failed = true,
    ).timeout(const Duration(seconds: 5));
  } on Object catch (_) {
    failed = true;
  }
  return failed ? null : image;
}

/// Draws [card], [size] points, to a PNG at [shareCardScale] without
/// putting it on screen (Swift's `ImageRenderer`), in [context]'s text
/// direction and locale. Pictures in it must already be loaded
/// ([loadShareCardImage]). Null when drawing fails.
Future<Uint8List?> renderShareCard(
  BuildContext context,
  Widget card, {
  required Size size,
}) async {
  final view = View.of(context);
  final direction = Directionality.of(context);
  final locale = Localizations.localeOf(context);
  try {
    final boundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: view,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size * shareCardScale),
        devicePixelRatio: shareCardScale,
      ),
      child: RenderPositionedBox(child: boundary),
    );
    final pipeline = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();
    final build = BuildOwner(focusManager: FocusManager());
    final root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: Localizations(
        locale: locale,
        delegates: const [
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
        ],
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: Directionality(textDirection: direction, child: card),
        ),
      ),
    ).attachToRenderTree(build);
    build
      ..buildScope(root)
      ..finalizeTree();
    pipeline
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    final image = await boundary.toImage(pixelRatio: shareCardScale);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } on Object catch (_) {
    return null;
  }
}
