import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('copyWith replaces only what is passed', () {
      const red = Color(0xFFFF0000);
      final copy = AppColors.light.copyWith(protein: red);
      expect(copy.protein, red);
      expect(copy.carbs, AppColors.light.carbs);
      expect(copy.habits, AppColors.light.habits);
    });

    test('copyWith with nothing keeps every colour', () {
      final copy = AppColors.light.copyWith();
      expect(copy.canvas, AppColors.light.canvas);
      expect(copy.exercises, AppColors.light.exercises);
    });

    test('lerp blends towards the other palette', () {
      final halfway = AppColors.light.lerp(AppColors.dark, 0.5);
      expect(
        halfway.canvas,
        Color.lerp(AppColors.light.canvas, AppColors.dark.canvas, 0.5),
      );
      expect(
        AppColors.light.lerp(AppColors.dark, 1).surface,
        AppColors.dark.surface,
      );
    });

    test('lerp with nothing returns itself', () {
      expect(AppColors.light.lerp(null, 0.5), same(AppColors.light));
    });

    test('tintedSurface is the colour at 15%', () {
      final tinted = AppColors.tintedSurface(AppColors.light.protein);
      expect(tinted.a, closeTo(0.15, 0.001));
      expect(tinted.r, AppColors.light.protein.r);
    });

    test('fromHex reads a stored #RRGGBB, and nothing else', () {
      expect(AppColors.fromHex('#FF9500'), const Color(0xFFFF9500));
      expect(AppColors.fromHex('0000ff'), const Color(0xFF0000FF));
      expect(AppColors.fromHex(null), isNull);
      expect(AppColors.fromHex('#FFF'), isNull);
      expect(AppColors.fromHex('#GGGGGG'), isNull);
      expect(AppColors.fromHex('-12345'), isNull);
    });

    test('warm-up and superset differ, as the contract requires', () {
      expect(AppColors.light.warmup, isNot(AppColors.light.superset));
    });

    test('no metric shares a macro colour', () {
      const c = AppColors.light;
      final macros = {c.calories, c.protein, c.carbs, c.fat};
      for (final metric in [
        c.workouts,
        c.steps,
        c.expenditure,
        c.scaleWeight,
        c.bodyFat,
        c.measurements,
        c.nutrition,
        c.muscleGroups,
        c.exercises,
        c.habits,
      ]) {
        expect(macros, isNot(contains(metric)));
      }
    });
  });
}
