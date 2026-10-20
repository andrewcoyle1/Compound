import 'dart:async';
import 'dart:typed_data';

import 'package:app_ui/app_ui.dart';

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
/// ([loadShareCardImage]); the app icon at the top is loaded here.
/// Null when drawing fails.
Future<Uint8List?> renderShareCard(
  BuildContext context,
  Widget card, {
  required Size size,
}) async {
  final direction = Directionality.of(context);
  final locale = Localizations.localeOf(context);
  final icon = precacheImage(AppImages.appIcon, context);
  try {
    await icon;
    return await renderWidgetPng(
      Localizations(
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
      size: size,
      pixelRatio: shareCardScale,
    );
  } on Object catch (_) {
    return null;
  }
}
