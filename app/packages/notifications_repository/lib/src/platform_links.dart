import 'dart:async';

import 'package:app_links/app_links.dart';

/// The URLs the platform opens the app with: `compound://` links and
/// workout web pages.
abstract interface class PlatformLinks {
  /// The link that launched the app, if any, then each one opened after.
  Stream<Uri> get links;
}

/// {@template app_links_platform_links}
/// [PlatformLinks] through `app_links`, which hands over the launch link on
/// the first listen.
/// {@endtemplate}
class AppLinksPlatformLinks implements PlatformLinks {
  /// {@macro app_links_platform_links}
  new([AppLinks? appLinks]) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Stream<Uri> get links => _appLinks.uriLinkStream;
}

/// {@template fake_platform_links}
/// [PlatformLinks] with no platform: [open] plays a link.
/// {@endtemplate}
class FakePlatformLinks implements PlatformLinks {
  /// {@macro fake_platform_links}
  new();

  final _links = StreamController<Uri>.broadcast(sync: true);

  @override
  Stream<Uri> get links => _links.stream;

  /// Opens the app with [uri].
  void open(Uri uri) => _links.add(uri);
}
