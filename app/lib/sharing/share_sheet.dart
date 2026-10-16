import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// The system share sheet (Swift's `ShareSheet` and `ShareLink`), behind a
/// class the app provides so tests can stand in for the platform.
class ShareSheet {
  /// The share sheet on [SharePlus.instance].
  const new();

  /// Shares [text]. On an iPad the sheet points at [context]'s widget.
  Future<void> shareText(BuildContext context, String text) => SharePlus
      .instance
      .share(ShareParams(text: text, sharePositionOrigin: _origin(context)));

  /// Shares a PNG image, [bytes], named [name].
  Future<void> shareImage(
    BuildContext context,
    Uint8List bytes, {
    required String name,
  }) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
      fileNameOverrides: [name],
      sharePositionOrigin: _origin(context),
    ),
  );

  static Rect? _origin(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
