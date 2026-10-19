import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('AppTheme app bar', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is as tall as the navigation bar on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        AppTheme.light.appBarTheme.toolbarHeight,
        AppControlSize.iosToolbar,
      );
    });

    test("keeps Material's height on Android", () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppTheme.light.appBarTheme.toolbarHeight, isNull);
    });
  });

  group('AppTheme press feedback', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('has no ripple on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppTheme.light.splashFactory, NoSplash.splashFactory);
    });

    test('ripples on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppTheme.light.splashFactory, isNot(NoSplash.splashFactory));
    });
  });

  for (final (name, theme, brightness) in [
    ('light', AppTheme.light, Brightness.light),
    ('dark', AppTheme.dark, Brightness.dark),
  ]) {
    group('AppTheme.$name', () {
      final scheme = theme.colorScheme;
      final colors = theme.extension<AppColors>()!;

      test('has the brightness and the colour tokens', () {
        expect(theme.brightness, brightness);
        expect(
          colors,
          same(
            brightness == Brightness.light ? AppColors.light : AppColors.dark,
          ),
        );
      });

      test('screens sit on the canvas and cards on the surface', () {
        expect(theme.scaffoldBackgroundColor, colors.canvas);
        expect(theme.cardTheme.color, colors.surface);
        expect(scheme.surface, colors.surface);
        expect(scheme.error, colors.danger);
      });

      test('text passes WCAG AA on every surface', () {
        for (final background in [colors.surface, colors.canvas]) {
          expect(_contrast(scheme.onSurface, background), greaterThan(4.5));
          expect(
            _contrast(scheme.onSurfaceVariant, background),
            greaterThan(4.5),
          );
        }
        expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
      });

      test('buttons meet the 44 pt minimum', () {
        const minimum = Size(AppControlSize.row, AppControlSize.row);
        expect(
          theme.filledButtonTheme.style?.minimumSize?.resolve({}),
          minimum,
        );
        expect(theme.textButtonTheme.style?.minimumSize?.resolve({}), minimum);
      });

      test('call-to-action labels are body text, as in Swift', () {
        expect(
          theme.filledButtonTheme.style?.textStyle?.resolve({}),
          AppTextStyles.rowTitle,
        );
      });

      test('app bar titles are centred on both platforms', () {
        expect(theme.appBarTheme.centerTitle, isTrue);
      });

      test('switches use the accent when on', () {
        final on = {WidgetState.selected};
        final switches = theme.switchTheme;
        expect(switches.trackColor?.resolve(on), scheme.primary);
        expect(switches.thumbColor?.resolve(on), scheme.onPrimary);
        expect(
          switches.trackColor?.resolve({}),
          scheme.surfaceContainerHighest,
        );
        expect(switches.thumbColor?.resolve({}), scheme.onSurfaceVariant);
        expect(
          switches.trackColor?.resolve({...on, WidgetState.disabled}),
          scheme.primary.withValues(alpha: 0.38),
        );
      });

      test('the tab bar marks the selected tab with the accent only', () {
        final on = {WidgetState.selected};
        final tabs = theme.navigationBarTheme;
        expect(tabs.indicatorColor, const Color(0x00000000));
        expect(tabs.iconTheme?.resolve(on)?.color, scheme.primary);
        expect(tabs.iconTheme?.resolve({})?.color, scheme.onSurfaceVariant);
        expect(tabs.labelTextStyle?.resolve(on)?.color, scheme.primary);
        expect(
          tabs.labelTextStyle?.resolve({})?.color,
          scheme.onSurfaceVariant,
        );
      });

      test('cards have continuous corners', () {
        expect(theme.cardTheme.shape, isA<RoundedSuperellipseBorder>());
        expect(theme.dialogTheme.shape, isA<RoundedSuperellipseBorder>());
        expect(theme.popupMenuTheme.shape, isA<RoundedSuperellipseBorder>());
      });
    });
  }
}
