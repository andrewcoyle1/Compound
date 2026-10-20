import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:screenshot/screenshot.dart';

/// Draws [widget], laid out at exactly [size] points, to a PNG at
/// [pixelRatio] without putting it on screen. Pictures in it must already
/// be loaded: it is drawn in a single pass. Throws when drawing fails.
Future<Uint8List> renderWidgetPng(
  Widget widget, {
  required Size size,
  required double pixelRatio,
}) => ScreenshotController().captureFromWidget(
  SizedBox.fromSize(size: size, child: widget),
  targetSize: size,
  pixelRatio: pixelRatio,
  // The package waits after drawing for a rebuild; nothing here rebuilds.
  delay: Duration.zero,
);
