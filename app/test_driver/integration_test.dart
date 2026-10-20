import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Writes each screenshot the test takes to `$SHOTS_DIR/<name>.png`
/// (`build/screenshots` by default). Run through
/// `scripts/flutter-screenshots.sh`.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final dir = Platform.environment['SHOTS_DIR'] ?? 'build/screenshots';
    File('$dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return true;
  },
);
