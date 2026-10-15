/// The goal screens' arithmetic: `GoalTimeline.swift`, and the pure parts of
/// `TargetWeightPresenter`, `WeightRatePresenter` and `GoalSummaryPresenter`.
library;

import 'dart:math';

import 'package:body_repository/body_repository.dart';
import 'package:compound/onboarding/logic/body_units.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:user_repository/user_repository.dart' show WeightUnitPreference;

/// `GoalTimeline`'s constants: rates as a percentage of body weight a week
/// (Helms 2014, Garthe 2011, Iraki 2019).
abstract final class GoalTimeline {
  /// Change in daily expenditure per kilogram (Hall 2011).
  static const expenditureKcalPerKg = 24.0;
  static const lossMinimumPercent = 0.25;
  static const gainMinimumPercent = 0.1;
  static const maximumPercent = 1.0;

  /// Never faster than this, however heavy the person.
  static const absoluteMaximumKg = 1.5;
  static const leanLossDefaultPercent = 0.5;
  static const lossDefaultPercent = 0.75;
  static const gainDefaultPercent = 0.25;
  static const leanLossWarningPercent = 0.75;
  static const gainWarningPercent = 0.5;
  static const leanBmi = 25.0;

  /// A weight-loss target stops at the weight giving this BMI.
  static const lowestHealthyBmi = 18.5;

  /// The rate wheel's step, in kilograms a week.
  static const rateStep = 0.05;
}

/// Under a BMI of 25, or with no usable height (`GoalTimeline.isLean`).
bool isLean({required double weightKg, double? heightCm}) {
  if (heightCm == null ||
      !heightCm.isFinite ||
      heightCm <= 0 ||
      !weightKg.isFinite ||
      weightKg <= 0) {
    return true;
  }
  final metres = heightCm / 100;
  return weightKg / (metres * metres) < GoalTimeline.leanBmi;
}

/// Whole weeks to cover [distanceKg] at [weeklyRateKg], rounded up; zero
/// with nothing to cover or no rate (`GoalTimeline.weeks`).
int goalWeeks({required double distanceKg, required double weeklyRateKg}) {
  final weeks = (distanceKg.abs() / weeklyRateKg).ceilToDouble();
  if (!weeks.isFinite || weeks <= 0 || weeks >= 2147483647) return 0;
  return weeks.toInt();
}

/// How far the daily target moves by the goal weight
/// (`GoalTimeline.targetChangeKcal`).
double targetChangeKcal(double distanceKg) =>
    distanceKg.abs() * GoalTimeline.expenditureKcalPerKg;

/// The weight giving a BMI of 18.5 for [heightCm], or null without a usable
/// height (`TargetWeightPresenter.lowestHealthyKilograms`).
double? lowestHealthyKilograms(double? heightCm) {
  if (heightCm == null || !heightCm.isFinite || heightCm <= 0) return null;
  final metres = heightCm / 100;
  return GoalTimeline.lowestHealthyBmi * metres * metres;
}

/// The user's weight as the target wheels use it: missing or unusable reads
/// as 0, and it is capped at 1,000 kg.
double _wheelWeight(double? currentKg) =>
    currentKg == null || !currentKg.isFinite ? 0 : currentKg.clamp(0, 1000);

/// The target wheel's kilograms (`TargetWeightPresenter.kilogramRange`). The
/// bound facing the user's own weight rounds away from the objective, so no
/// stop is on the wrong side of a fractional weight.
({int min, int max}) targetKilogramRange(
  OverarchingObjective objective, {
  required double? currentKg,
  required double? heightCm,
}) {
  final weight = _wheelWeight(currentKg);
  final floorKg = weight.floor();
  final ceilKg = weight.ceil();
  const minKg = 30;
  const maxKg = 200;
  switch (objective) {
    case OverarchingObjective.gainWeight:
      final lower = max(minKg, ceilKg > 0 ? ceilKg : minKg);
      return (min: min(lower, maxKg), max: maxKg);
    case OverarchingObjective.loseWeight:
      final healthy = min(
        maxKg,
        max(minKg, (lowestHealthyKilograms(heightCm) ?? 0).ceil()),
      );
      final upper = min(maxKg, floorKg > 0 ? floorKg : maxKg);
      return (min: healthy, max: max(upper, healthy));
    case OverarchingObjective.maintain:
      final base = weight.round();
      final lower = max(minKg, base > 0 ? base - 10 : 70);
      final upper = min(maxKg, base > 0 ? base + 10 : 90);
      return (min: lower, max: max(upper, lower));
  }
}

/// The target wheel's pounds (`TargetWeightPresenter.poundRange`).
({int min, int max}) targetPoundRange(
  OverarchingObjective objective, {
  required double? currentKg,
  required double? heightCm,
}) {
  const minLb = 66;
  const maxLb = 440;
  final weightLb = kgToLbs(_wheelWeight(currentKg));
  final floorLb = weightLb.floor();
  final ceilLb = weightLb.ceil();
  switch (objective) {
    case OverarchingObjective.gainWeight:
      final lower = max(minLb, ceilLb > 0 ? ceilLb : minLb);
      return (min: min(lower, maxLb), max: maxLb);
    case OverarchingObjective.loseWeight:
      final healthy = min(
        maxLb,
        max(minLb, kgToLbs(lowestHealthyKilograms(heightCm) ?? 0).ceil()),
      );
      final upper = min(maxLb, floorLb > 0 ? floorLb : maxLb);
      return (min: healthy, max: max(upper, healthy));
    case OverarchingObjective.maintain:
      final baseLb = weightLb.round();
      final lower = max(minLb, baseLb > 0 ? baseLb - 22 : 154 - 22);
      final upper = min(maxLb, baseLb > 0 ? baseLb + 22 : 154 + 22);
      return (min: lower, max: max(upper, lower));
  }
}

/// Where the target wheel opens (`TargetWeightPresenter.onAppear`): the
/// user's weight, truncated, clamped into the range. A whole number of
/// kilograms or pounds, in [unit].
int initialTargetWheelValue(
  OverarchingObjective objective, {
  required WeightUnitPreference unit,
  required double? currentKg,
  required double? heightCm,
}) {
  final weight = _wheelWeight(currentKg);
  if (unit == WeightUnitPreference.kilograms) {
    final current = max(1, weight.toInt());
    final range = targetKilogramRange(
      objective,
      currentKg: currentKg,
      heightCm: heightCm,
    );
    return current.clamp(range.min, range.max);
  }
  final current = max(1, kgToLbs(weight).toInt());
  final range = targetPoundRange(
    objective,
    currentKg: currentKg,
    heightCm: heightCm,
  );
  return current.clamp(range.min, range.max);
}

/// Whether [targetKg] can be continued with
/// (`TargetWeightPresenter.canContinue`): a target that differs from the
/// current weight (70 kg when unknown), and below it to lose.
bool canContinueWithTarget(
  OverarchingObjective objective, {
  required double targetKg,
  required double? currentKg,
}) {
  final current = currentKg != null && currentKg.isFinite ? currentKg : 70.0;
  if (targetKg == 0 || targetKg == current) return false;
  return objective != OverarchingObjective.loseWeight || targetKg < current;
}

/// The rate screen's limits and default for [objective], at [currentKg]
/// (70 when unknown), all in kilograms a week (`WeightRatePresenter`).
class WeightRateRules {
  new({
    required this.objective,
    required double? currentKg,
    required double? heightCm,
  }) : currentKg = currentKg ?? 70,
       lean = isLean(weightKg: currentKg ?? 70, heightCm: heightCm);

  final OverarchingObjective objective;
  final double currentKg;
  final bool lean;

  double _kilograms(double percent) => currentKg * percent / 100;

  /// The slowest rate offered, snapped up to the step.
  double get minimum {
    final percent = objective == OverarchingObjective.gainWeight
        ? GoalTimeline.gainMinimumPercent
        : GoalTimeline.lossMinimumPercent;
    final snapped =
        (_kilograms(percent) / GoalTimeline.rateStep - 1e-9).ceilToDouble() *
        GoalTimeline.rateStep;
    return max(snapped, GoalTimeline.rateStep);
  }

  /// The fastest rate offered: 1% a week, never above 1.5 kg.
  double get maximum {
    final onePercent = min(
      _kilograms(GoalTimeline.maximumPercent),
      GoalTimeline.absoluteMaximumKg,
    );
    final snapped =
        (onePercent / GoalTimeline.rateStep + 1e-9).floorToDouble() *
        GoalTimeline.rateStep;
    return max(snapped, minimum + GoalTimeline.rateStep);
  }

  /// The rate the screen opens on.
  double get initial => switch (objective) {
    OverarchingObjective.maintain => 0,
    OverarchingObjective.loseWeight => snapped(
      _kilograms(
        lean
            ? GoalTimeline.leanLossDefaultPercent
            : GoalTimeline.lossDefaultPercent,
      ),
    ),
    OverarchingObjective.gainWeight => snapped(
      _kilograms(GoalTimeline.gainDefaultPercent),
    ),
  };

  /// [kilograms] on the step, within the limits.
  double snapped(double kilograms) {
    final value =
        (kilograms / GoalTimeline.rateStep).roundToDouble() *
        GoalTimeline.rateStep;
    return min(max(value, minimum), maximum);
  }

  /// [rateKg] as a percentage of body weight a week.
  double percentOfBodyWeight(double rateKg) =>
      currentKg > 0 ? rateKg / currentKg * 100 : 0;

  /// Whether [rateKg] is above the screen's warning line: 0.75% a week for
  /// a lean person losing, 1% for anyone else losing, 0.5% gaining.
  bool isAggressive(double rateKg) {
    final threshold = switch (objective) {
      OverarchingObjective.gainWeight => GoalTimeline.gainWarningPercent,
      _ =>
        lean
            ? GoalTimeline.leanLossWarningPercent
            : GoalTimeline.maximumPercent,
    };
    return percentOfBodyWeight(rateKg) > threshold + 1e-6;
  }

  /// Whether [rateKg] is below the conservative line.
  bool isConservative(double rateKg) {
    final threshold = objective == OverarchingObjective.gainWeight
        ? GoalTimeline.gainDefaultPercent
        : GoalTimeline.leanLossDefaultPercent;
    return percentOfBodyWeight(rateKg) < threshold - 1e-6;
  }
}

/// The daily target the rate screen estimates, and whether the deficit was
/// capped at a quarter of expenditure
/// (`WeightRatePresenter.estimatedCalorieTarget`).
({double kcal, bool isDeficitCapped}) estimatedCalorieTarget(
  OverarchingObjective objective, {
  required double rateKg,
  required double expenditureKcal,
  required double floorKcal,
}) {
  final dailyChange = maths.dailyKcalForWeeklyChange(rateKg);
  switch (objective) {
    case OverarchingObjective.loseWeight:
      final largest =
          maths.NutritionTargets.maximumDeficitShare * expenditureKcal;
      return (
        kcal: max(expenditureKcal - min(dailyChange, largest), floorKcal),
        isDeficitCapped: dailyChange > largest,
      );
    case OverarchingObjective.gainWeight:
      return (
        kcal: max(expenditureKcal + dailyChange, floorKcal),
        isDeficitCapped: false,
      );
    case OverarchingObjective.maintain:
      return (kcal: max(expenditureKcal, floorKcal), isDeficitCapped: false);
  }
}
