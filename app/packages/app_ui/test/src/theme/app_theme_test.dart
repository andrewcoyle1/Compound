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
        // The accent as text, on its own, and on its tint.
        for (final background in [colors.surface, colors.canvas]) {
          final tint = Color.alphaBlend(
            AppColors.tintedSurface(colors.accentInk),
            background,
          );
          expect(_contrast(colors.accentInk, background), greaterThan(4.5));
          expect(_contrast(colors.accentInk, tint), greaterThan(4.5));
        }
      });

      test('the accent is volt, with black on it, in both modes', () {
        expect(scheme.primary, const Color(0xFFC8F31D));
        expect(scheme.onPrimary, const Color(0xFF000000));
      });

      test('wires the theme roles to the colour tokens', () {
        expect(scheme.onSurfaceVariant, colors.secondaryLabel);
        expect(scheme.outlineVariant, colors.separator);
        expect(scheme.surfaceContainerHighest, colors.raised);
        expect(theme.dividerTheme.color, colors.separator);
        expect(theme.inputDecorationTheme.fillColor, colors.raised);
        expect(theme.progressIndicatorTheme.color, colors.accentInk);
        expect(theme.textSelectionTheme.cursorColor, colors.accentInk);
        expect(
          theme.textButtonTheme.style?.foregroundColor?.resolve({}),
          colors.accentInk,
        );
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

      test('the tab bar marks the selected tab on a volt capsule', () {
        final on = {WidgetState.selected};
        final tabs = theme.navigationBarTheme;
        expect(tabs.backgroundColor, const Color(0x00000000));
        expect(tabs.indicatorColor, scheme.primary);
        expect(tabs.indicatorShape, const StadiumBorder());
        expect(tabs.iconTheme?.resolve(on)?.color, scheme.onPrimary);
        expect(tabs.iconTheme?.resolve({})?.color, scheme.onSurfaceVariant);
        expect(tabs.labelTextStyle?.resolve(on)?.color, scheme.onSurface);
        expect(tabs.labelTextStyle?.resolve(on)?.fontWeight, FontWeight.w600);
        expect(
          tabs.labelTextStyle?.resolve(on)?.overflow,
          TextOverflow.ellipsis,
        );
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

  group('AppTheme.lightHighContrast', () {
    final theme = AppTheme.lightHighContrast;

    test("darkens the accent's ink and outlines volt fills", () {
      final colors = theme.extension<AppColors>()!;
      expect(colors.accentInk, const Color(0xFF3A4D00));
      expect(theme.colorScheme.primary, AppTheme.light.colorScheme.primary);
      const edge = BorderSide();
      expect(
        theme.navigationBarTheme.indicatorShape,
        const StadiumBorder(side: edge),
      );
      final shape = theme.filledButtonTheme.style?.shape?.resolve({});
      expect(shape!.side, edge);
    });

    test('the standard light theme has no outline', () {
      final shape = AppTheme.light.filledButtonTheme.style?.shape?.resolve({});
      expect(shape!.side, BorderSide.none);
    });
  });
}
