import 'package:body_repository/body_repository.dart';
import 'package:compound/onboarding/logic/goal_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

/// Mirrors `OnboardingGoalSettingPresenterTests`,
/// `OnboardingWeightRatePresenterTests` and
/// `OnboardingGoalSummaryEstimateTests`.
void main() {
  const lose = OverarchingObjective.loseWeight;
  const gain = OverarchingObjective.gainWeight;
  const maintain = OverarchingObjective.maintain;

  group('target ranges', () {
    test('losing stops at a BMI of 18.5 and below the current weight', () {
      expect(targetKilogramRange(lose, currentKg: 80, heightCm: 180), (
        min: 60,
        max: 80,
      ));
      expect(targetPoundRange(lose, currentKg: 80, heightCm: 180).min, 133);
    });

    test('without a height the wheel keeps its 30 kg floor', () {
      expect(targetKilogramRange(lose, currentKg: 80, heightCm: null).min, 30);
      expect(lowestHealthyKilograms(null), isNull);
      expect(lowestHealthyKilograms(double.nan), isNull);
    });

    test('a weight already under the floor offers one stop, not lower', () {
      expect(targetKilogramRange(lose, currentKg: 55, heightCm: 180), (
        min: 60,
        max: 60,
      ));
      expect(canContinueWithTarget(lose, targetKg: 60, currentKg: 55), isFalse);
    });

    test('gaining is above, maintaining a window either side', () {
      expect(targetKilogramRange(gain, currentKg: 80, heightCm: 180), (
        min: 80,
        max: 200,
      ));
      expect(targetKilogramRange(maintain, currentKg: 80, heightCm: 180), (
        min: 70,
        max: 90,
      ));
      expect(targetPoundRange(gain, currentKg: 80, heightCm: 180).max, 440);
      expect(targetPoundRange(maintain, currentKg: 80, heightCm: 180), (
        min: 154,
        max: 198,
      ));
    });

    test('a fractional weight never puts a target on the wrong side', () {
      expect(targetKilogramRange(lose, currentKg: 72.6, heightCm: 180).max, 72);
      expect(targetKilogramRange(gain, currentKg: 72.6, heightCm: 180).min, 73);
      expect(targetPoundRange(lose, currentKg: 80, heightCm: 180).max, 176);
      expect(targetPoundRange(gain, currentKg: 80, heightCm: 180).min, 177);
    });

    test('a missing, huge or unusable weight still gives valid ranges', () {
      for (final weight in [null, 2000.0, double.nan, double.infinity]) {
        for (final objective in OverarchingObjective.values) {
          final kg = targetKilogramRange(
            objective,
            currentKg: weight,
            heightCm: 175,
          );
          final lb = targetPoundRange(
            objective,
            currentKg: weight,
            heightCm: 175,
          );
          expect(kg.min, lessThanOrEqualTo(kg.max));
          expect(lb.min, lessThanOrEqualTo(lb.max));
        }
      }
    });

    test('the wheel opens on the user own weight, within its range', () {
      expect(
        initialTargetWheelValue(
          lose,
          unit: WeightUnitPreference.kilograms,
          currentKg: 72,
          heightCm: 175,
        ),
        72,
      );
      expect(
        initialTargetWheelValue(
          gain,
          unit: WeightUnitPreference.pounds,
          currentKg: 72.6,
          heightCm: 175,
        ),
        161,
      );
      expect(
        initialTargetWheelValue(
          lose,
          unit: WeightUnitPreference.kilograms,
          currentKg: null,
          heightCm: 175,
        ),
        57,
      );
    });

    test('continuing needs a target that differs, below it to lose', () {
      expect(canContinueWithTarget(lose, targetKg: 70, currentKg: 75), isTrue);
      expect(canContinueWithTarget(lose, targetKg: 75, currentKg: 75), isFalse);
      expect(canContinueWithTarget(lose, targetKg: 76, currentKg: 75), isFalse);
      expect(canContinueWithTarget(gain, targetKg: 76, currentKg: 75), isTrue);
      expect(canContinueWithTarget(gain, targetKg: 0, currentKg: 75), isFalse);
      // Unknown reads as 70.
      expect(
        canContinueWithTarget(gain, targetKg: 70, currentKg: null),
        isFalse,
      );
    });
  });

  group(WeightRateRules, () {
    WeightRateRules rules(
      OverarchingObjective objective, {
      double? weight = 80,
      double? height = 180,
    }) => WeightRateRules(
      objective: objective,
      currentKg: weight,
      heightCm: height,
    );

    test('the default rate depends on the objective and on leanness', () {
      expect(rules(lose).initial, closeTo(0.4, 1e-9));
      expect(rules(gain).initial, closeTo(0.2, 1e-9));
      expect(rules(maintain).initial, 0);
      final heavy = rules(lose, weight: 100);
      expect(heavy.lean, isFalse);
      expect(heavy.initial, closeTo(0.75, 1e-9));
      expect(heavy.isAggressive(1), isFalse);
      expect(rules(lose, weight: 50).initial, closeTo(0.25, 1e-9));
    });

    test('the minimum is a share of body weight, snapped up', () {
      expect(rules(lose).minimum, closeTo(0.2, 1e-9));
      expect(rules(gain).minimum, closeTo(0.1, 1e-9));
    });

    test('the maximum is 1% of body weight, capped at 1.5 kg', () {
      for (final (weight, expected) in [
        (80.0, 0.8),
        (60.0, 0.6),
        (30.0, 0.3),
        (150.0, 1.5),
        (220.0, 1.5),
        (73.0, 0.7),
      ]) {
        final rate = rules(lose, weight: weight);
        expect(rate.maximum, closeTo(expected, 1e-9));
        expect(rate.initial, lessThanOrEqualTo(rate.maximum));
      }
    });

    test('a missing weight falls back to 70 kg', () {
      expect(rules(lose, weight: null).currentKg, 70);
      expect(
        WeightRateRules(
          objective: lose,
          currentKg: 0,
          heightCm: null,
        ).percentOfBodyWeight(1),
        0,
      );
    });

    test('the category changes at its thresholds', () {
      final rate = rules(lose);
      expect(rate.isConservative(0.35), isTrue);
      expect(rate.isConservative(0.4), isFalse);
      expect(rate.isAggressive(0.6), isFalse);
      expect(rate.isAggressive(0.65), isTrue);
      expect(rules(gain).isConservative(0.15), isTrue);
      expect(rules(gain).isAggressive(0.45), isTrue);
    });

    test('snaps onto the step within the limits', () {
      expect(rules(lose).snapped(0.43), closeTo(0.45, 1e-9));
      expect(rules(lose).snapped(5), closeTo(0.8, 1e-9));
      expect(rules(lose).snapped(0), closeTo(0.2, 1e-9));
    });
  });

  group('timeline', () {
    test('ten kilos at half a kilo a week is twenty weeks either way', () {
      expect(goalWeeks(distanceKg: -10, weeklyRateKg: 0.5), 20);
      expect(goalWeeks(distanceKg: 10, weeklyRateKg: 0.5), 20);
    });

    test('maintaining or a zero rate is zero weeks, not a trap', () {
      expect(goalWeeks(distanceKg: 0, weeklyRateKg: 0), 0);
      expect(goalWeeks(distanceKg: 5, weeklyRateKg: 0), 0);
    });

    test('the target moves about 24 kcal a day per kilogram', () {
      expect(targetChangeKcal(-10), 240);
    });

    test('lean is a BMI under 25, or no usable height', () {
      expect(isLean(weightKg: 80, heightCm: 180), isTrue);
      expect(isLean(weightKg: 90, heightCm: 180), isFalse);
      expect(isLean(weightKg: 90), isTrue);
      expect(isLean(weightKg: double.nan, heightCm: 180), isTrue);
    });
  });

  group('estimatedCalorieTarget', () {
    test('losing takes the deficit, capped at a quarter of expenditure', () {
      final target = estimatedCalorieTarget(
        lose,
        rateKg: 0.5,
        expenditureKcal: 2500,
        floorKcal: 1500,
      );
      expect(target.kcal, closeTo(2500 - 550, 1e-9));
      expect(target.isDeficitCapped, isFalse);
      final capped = estimatedCalorieTarget(
        lose,
        rateKg: 1.5,
        expenditureKcal: 2000,
        floorKcal: 1200,
      );
      expect(capped.kcal, 1500);
      expect(capped.isDeficitCapped, isTrue);
    });

    test('never below the floor; gaining adds the surplus', () {
      expect(
        estimatedCalorieTarget(
          lose,
          rateKg: 0.5,
          expenditureKcal: 1600,
          floorKcal: 1500,
        ).kcal,
        1500,
      );
      expect(
        estimatedCalorieTarget(
          gain,
          rateKg: 0.35,
          expenditureKcal: 2500,
          floorKcal: 1500,
        ).kcal,
        closeTo(2885, 1e-9),
      );
      expect(
        estimatedCalorieTarget(
          maintain,
          rateKg: 0,
          expenditureKcal: 1000,
          floorKcal: 1200,
        ).kcal,
        1200,
      );
    });
  });
}
