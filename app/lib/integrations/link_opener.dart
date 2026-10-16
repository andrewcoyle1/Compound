import 'package:url_launcher/url_launcher.dart';

/// Opens a web link outside the app (SwiftUI's `Link`), behind a class the
/// app provides so tests can stand in for the platform.
class LinkOpener {
  /// Opens links with url_launcher.
  const new();

  /// Opens [uri] in the app that handles it (the Strava app when installed)
  /// or the browser.
  Future<void> open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
