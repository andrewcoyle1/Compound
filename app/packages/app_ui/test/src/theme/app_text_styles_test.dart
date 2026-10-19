import 'dart:convert';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppTextStyles', () {
    test('metrics use tabular figures', () {
      for (final style in [
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
      expect(AppTextStyles.display.fontSize, 34);
      expect(AppTextStyles.rowTitle.fontSize, 17);
      expect(AppTextStyles.rowDetail.fontSize, 15);
      expect(AppTextStyles.label.fontSize, 12);
      expect(AppTextStyles.labelEmphasized.fontSize, 12);
      expect(AppTextStyles.labelEmphasized.fontWeight, FontWeight.w600);
    });

    test('numbers are set in the bundled rounded face', () {
      for (final style in [
        AppTextStyles.display,
        AppTextStyles.metricLarge,
        AppTextStyles.metric,
        AppTextStyles.metricSmall,
      ]) {
        expect(style.fontFamily, 'packages/app_ui/Nunito');
        expect(style.letterSpacing, 0);
      }
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

    test("registers Nunito's licence", () async {
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
      final nunito = entries.singleWhere(
        (entry) => entry.packages.contains('Nunito'),
      );
      expect(
        nunito.paragraphs.map((paragraph) => paragraph.text).join(),
        contains('Open Font License'),
      );
    });

    test('carry no colour, so text takes the theme', () {
      expect(AppTextStyles.textTheme.bodyMedium?.color, isNull);
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
