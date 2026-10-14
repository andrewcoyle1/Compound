import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSymbols', () {
    test('share and more follow the platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppSymbols.share, Icons.ios_share);
      expect(AppSymbols.more, Icons.more_horiz);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppSymbols.share, Icons.share);
      expect(AppSymbols.more, Icons.more_vert);
      debugDefaultTargetPlatformOverride = null;
    });

    test('steps along a strip mirror right to left', () {
      expect(AppSymbols.moveEarlier.matchTextDirection, isTrue);
      expect(AppSymbols.disclosure.matchTextDirection, isTrue);
    });
  });
}
