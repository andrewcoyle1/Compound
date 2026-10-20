/// A day's calories and macros, whether a target or what was eaten
/// (`DailyMacroTarget`), and the sums the Today and Nutrition screens show.
library;

import 'package:compound_maths/src/day_key.dart';

/// Calories and the three macros, in kcal and grams. The Swift uses
/// `DailyMacroTarget` for both a plan's day and a day's totals.
typedef Macros = ({
  double calories,
  double proteinGrams,
  double carbGrams,
  double fatGrams,
});

/// Nothing eaten.
const Macros zeroMacros = (
  calories: 0,
  proteinGrams: 0,
  carbGrams: 0,
  fatGrams: 0,
);

/// The sum of [items]: a meal's items, or a day's meals
/// (`MealLogManager.getDailyTotals`).
Macros sumMacros(Iterable<Macros> items) => items.fold(
  zeroMacros,
  (a, b) => (
    calories: a.calories + b.calories,
    proteinGrams: a.proteinGrams + b.proteinGrams,
    carbGrams: a.carbGrams + b.carbGrams,
    fatGrams: a.fatGrams + b.fatGrams,
  ),
);

/// What is left of [target] after [total], as the remaining page prints it:
/// never below zero unless the user asked to see overages
/// (`MacroHeader.remaining`).
double macroRemaining({
  required double total,
  required double target,
  required bool showOverages,
}) {
  final left = target - total;
  return showOverages || left > 0 ? left : 0;
}

/// [value] as a share of [target] for a progress bar, held to 0–1; 0 for a
/// target of zero, as for a macro the plan does not set (`MacroHeader`).
double macroProgress(double value, double target) =>
    target > 0 ? (value / target).clamp(0, 1).toDouble() : 0;

/// [total] as a share of [target], unclamped, so 1.2 is 20% over; 0 without a
/// target (`NutritionPresenter.caloriePercentage` and the rest).
double macroShare(double total, double? target) =>
    target != null && target > 0 ? total / target : 0;

/// The plan's day for [dayKey]: a plan holds seven days, Monday first
/// (`NutritionManager.getDailyTarget`). `null` when the plan is short.
Macros? planDayTarget(List<Macros> days, String dayKey) {
  final index = isoWeekday(dayKey) - 1;
  return index < days.length ? days[index] : null;
}
