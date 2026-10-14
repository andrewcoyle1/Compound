import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
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

      test('switches use the accent when on', () {
        final on = {WidgetState.selected};
        final switches = theme.switchTheme;
        expect(switches.trackColor?.resolve(on), scheme.primary);
        expect(switches.thumbColor?.resolve(on), scheme.onPrimary);
        expect(
          switches.trackColor?.resolve({}),
          scheme.surfaceContainerHighest,
        );
        expect(switches.thumbColor?.resolve({}), colors.surface);
      });

      test('cards have continuous corners', () {
        expect(theme.cardTheme.shape, isA<RoundedSuperellipseBorder>());
        expect(theme.dialogTheme.shape, isA<RoundedSuperellipseBorder>());
        expect(theme.popupMenuTheme.shape, isA<RoundedSuperellipseBorder>());
      });
    });
  }
}
