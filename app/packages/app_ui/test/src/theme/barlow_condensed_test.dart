import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Barlow Condensed', () {
    // The bundled files, grouped as the pubspec's two families, under names
    // of their own: loading the real names would leave Barlow in the engine
    // for every later test in very_good's merged run, and the CI goldens
    // would lay their text out in it.
    const families = {
      'packages/app_ui/BarlowCondensed': 'BarlowCheck',
      'packages/app_ui/BarlowCondensedBold': 'BarlowCheckBold',
    };
    setUpAll(() async {
      for (final (family, weights) in [
        // copyWith keeps the style's package, so the names take it too.
        ('packages/app_ui/BarlowCheck', ['ExtraBold', 'Black']),
        ('packages/app_ui/BarlowCheckBold', ['Bold', 'ExtraBold', 'Black']),
      ]) {
        final loader = FontLoader(family);
        for (final weight in weights) {
          loader.addFont(
            File('assets/fonts/BarlowCondensed-$weight.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
          );
        }
        await loader.load();
      }
    });

    double width(String text, TextStyle style) {
      expect(families, contains(style.fontFamily));
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(fontFamily: families[style.fontFamily]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(painter.dispose);
      return painter.width;
    }

    test('draws every figure the same width', () {
      for (final style in [AppTextStyles.display, AppTextStyles.metric]) {
        expect(width('1111', style), width('0000', style));
        expect(
          width('1111', style.copyWith(fontFeatures: [])),
          lessThan(width('0000', style.copyWith(fontFeatures: []))),
        );
      }
    });

    test('Bold Text never draws an extra-bold style lighter', () {
      // Text answers Bold Text by merging FontWeight.bold into every style.
      const bold = TextStyle(fontWeight: FontWeight.bold);
      for (final style in [
        AppTextStyles.largeTitle,
        AppTextStyles.display,
        AppTextStyles.metricLarge,
        AppTextStyles.metric,
      ]) {
        expect(width('WEIGHT', style.merge(bold)), width('WEIGHT', style));
      }
      // Bold and extra-bold are drawn at different widths, so the check
      // above would see a lighter face.
      expect(
        width('WEIGHT', AppTextStyles.metric),
        lessThan(
          width(
            'WEIGHT',
            AppTextStyles.metric.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      );
    });
  });
}
