import 'dart:convert';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppTextStyles', () {
    test('number styles use tabular figures', () {
      for (final style in [
        AppTextStyles.largeTitle,
        AppTextStyles.display,
        AppTextStyles.metricLarge,
        AppTextStyles.metric,
        AppTextStyles.metricSmall,
      ]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    test('match iOS text styles at the default size', () {
      expect(AppTextStyles.rowTitle.fontSize, 17);
      expect(AppTextStyles.rowDetail.fontSize, 15);
      expect(AppTextStyles.label.fontSize, 12);
    });

    test('titles and numbers are set in Barlow Condensed, a step up', () {
      for (final (style, size, weight) in [
        (AppTextStyles.largeTitle, 40, FontWeight.w800),
        (AppTextStyles.display, 44, FontWeight.w800),
        (AppTextStyles.metricLarge, 34, FontWeight.w800),
        (AppTextStyles.metric, 24, FontWeight.w700),
      ]) {
        expect(style.fontFamily, startsWith('packages/app_ui/BarlowCondensed'));
        expect(style.fontSize, size);
        expect(style.fontWeight, weight);
        expect(style.letterSpacing, 0);
      }
    });

    test('a compact stat is in the system face, semibold', () {
      expect(
        AppTextStyles.metricSmall.fontFamily,
        AppTextStyles.rowDetail.fontFamily,
      );
      expect(AppTextStyles.metricSmall.fontSize, 15);
      expect(AppTextStyles.metricSmall.fontWeight, FontWeight.w600);
    });

    test('an overline is 12 pt semibold, tracked', () {
      expect(AppTextStyles.overline.fontSize, 12);
      expect(AppTextStyles.overline.fontWeight, FontWeight.w600);
      expect(AppTextStyles.overline.letterSpacing, 0.6);
    });

    group('system text', () {
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      test("takes San Francisco's tracking on iOS", () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(AppTextStyles.sectionTitle.letterSpacing, -0.43);
        expect(AppTextStyles.rowTitle.letterSpacing, -0.43);
        expect(AppTextStyles.rowDetail.letterSpacing, -0.23);
        expect(AppTextStyles.label.letterSpacing, 0);
        expect(AppTextStyles.textTheme.bodyMedium?.letterSpacing, -0.43);
        expect(AppTextStyles.rowTitle.fontFamily, 'CupertinoSystemText');
      });

      test("keeps Roboto's own spacing on Android", () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(AppTextStyles.rowTitle.letterSpacing, 0);
        expect(AppTextStyles.rowDetail.letterSpacing, 0);
        expect(AppTextStyles.rowTitle.fontFamily, 'Roboto');
      });
    });

    test("registers Barlow Condensed's licence", () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
            final key = utf8.decode(message!.buffer.asUint8List());
            expect(key, 'packages/app_ui/assets/fonts/OFL.txt');
            return ByteData.sublistView(utf8.encode('SIL Open Font License'));
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null),
      );
      AppTextStyles.registerFontLicense();
      final entries = await LicenseRegistry.licenses.toList();
      final barlow = entries.singleWhere(
        (entry) => entry.packages.contains('Barlow Condensed'),
      );
      expect(
        barlow.paragraphs.map((paragraph) => paragraph.text).join(),
        contains('Open Font License'),
      );
    });

    test('emphasized sets a style in semibold and keeps its size', () {
      final style = AppTextStyles.emphasized(AppTextStyles.rowDetail);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontSize, AppTextStyles.rowDetail.fontSize);
    });

    test('a formula is rowDetail in a monospaced face', () {
      expect(AppTextStyles.formula.fontSize, AppTextStyles.rowDetail.fontSize);
      expect(AppTextStyles.formula.fontFamily, 'monospace');
      expect(AppTextStyles.formula.fontFamilyFallback, contains('Menlo'));
    });

    test('carry no colour, so text takes the theme', () {
      expect(AppTextStyles.textTheme.bodyMedium?.color, isNull);
    });
  });

  group('AppTextStyleWeight', () {
    test('semibold keeps the style and changes only its weight', () {
      final label = AppTextStyles.label;
      expect(label.semibold.fontWeight, FontWeight.w600);
      expect(label.semibold.fontSize, label.fontSize);
      expect(label.semibold.fontFamily, label.fontFamily);
    });
  });

  group('AppTextStyleColor', () {
    testWidgets('secondary takes the secondary text grey', (tester) async {
      late TextStyle style;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            style = AppTextStyles.rowDetail.secondary(context);
            return const SizedBox();
          },
        ),
      );
      expect(style.color, AppColors.light.secondaryLabel);
      expect(style.fontSize, AppTextStyles.rowDetail.fontSize);
    });

    testWidgets('accent is the accent as text, onAccent text on its fill', (
      tester,
    ) async {
      late TextStyle accent;
      late TextStyle onAccent;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            accent = AppTextStyles.label.accent(context);
            onAccent = AppTextStyles.label.onAccent(context);
            return const SizedBox();
          },
        ),
      );
      expect(accent.color, AppColors.light.accentInk);
      expect(onAccent.color, AppTheme.light.colorScheme.onPrimary);
      expect(accent.fontSize, AppTextStyles.label.fontSize);
    });
  });

  group('AppTextStyleFigures', () {
    test('tabular adds tabular figures and keeps the style', () {
      final style = AppTextStyles.rowDetail.tabular;
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(style.fontSize, AppTextStyles.rowDetail.fontSize);
    });
  });

  group('AppIconSize', () {
    testWidgets('scales with the text size', (tester) async {
      late double size;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            size = AppIconSize.medium.of(context);
            return const SizedBox();
          },
        ),
        textScale: 2,
      );
      expect(size, 48);
      expect(AppIconSize.hero.points, 64);
    });
  });
}
