/// The Nutrition analytics screens' arithmetic (Swift `NutritionMetric`,
/// `NutritionAnalyticsPresenter`, `NutritionMetricDetailPresenter` and
/// `FoodLoggingConsistencyPresenter`): which metrics there are, each logged
/// day's value of one, and the cards' figures. Pure, so the bloc and the
/// widgets only read it.
library;

import 'dart:math' as math;

import 'package:checkin_repository/checkin_repository.dart' show localMidnight;
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition_overview/logic/nutrition_overview.dart';
import 'package:compound_maths/compound_maths.dart' show Macros, addDays;
import 'package:nutrition_repository/nutrition_repository.dart';

/// A section of the Nutrition screen, in Swift's order.
enum NutritionMetricSection { macros, carbs, fats, vitamins, minerals, other }

/// One nutrition metric with a card and a detail screen. Only those the
/// meal model records: Swift drops the cards of the ones it does not
/// (starch, omega-3s, amino acids, alcohol and the rest), so they are not
/// ported. [name] is Swift's case name, its analytics `metric`.
enum NutritionMetric {
  macros(NutritionMetricSection.macros),
  calories(NutritionMetricSection.macros),
  protein(NutritionMetricSection.macros),
  fat(NutritionMetricSection.macros),
  carbs(NutritionMetricSection.macros),
  fiber(NutritionMetricSection.carbs, NutrientLine.fiber),
  netCarbs(NutritionMetricSection.carbs, NutrientLine.netCarbs),
  sugars(NutritionMetricSection.carbs, NutrientLine.sugar),
  fatMono(NutritionMetricSection.fats, NutrientLine.monounsaturated),
  fatPoly(NutritionMetricSection.fats, NutrientLine.polyunsaturated),
  fatSaturated(NutritionMetricSection.fats, NutrientLine.saturated),
  thiamin(NutritionMetricSection.vitamins, NutrientLine.thiamin),
  riboflavin(NutritionMetricSection.vitamins, NutrientLine.riboflavin),
  niacin(NutritionMetricSection.vitamins, NutrientLine.niacin),
  pantothenicAcid(
    NutritionMetricSection.vitamins,
    NutrientLine.pantothenicAcid,
  ),
  vitaminB6(NutritionMetricSection.vitamins, NutrientLine.vitaminB6),
  vitaminB12(NutritionMetricSection.vitamins, NutrientLine.vitaminB12),
  folate(NutritionMetricSection.vitamins, NutrientLine.folate),
  vitaminA(NutritionMetricSection.vitamins, NutrientLine.vitaminA),
  vitaminC(NutritionMetricSection.vitamins, NutrientLine.vitaminC),
  vitaminD(NutritionMetricSection.vitamins, NutrientLine.vitaminD),
  vitaminE(NutritionMetricSection.vitamins, NutrientLine.vitaminE),
  vitaminK(NutritionMetricSection.vitamins, NutrientLine.vitaminK),
  calcium(NutritionMetricSection.minerals, NutrientLine.calcium),
  copper(NutritionMetricSection.minerals, NutrientLine.copper),
  iron(NutritionMetricSection.minerals, NutrientLine.iron),
  magnesium(NutritionMetricSection.minerals, NutrientLine.magnesium),
  manganese(NutritionMetricSection.minerals, NutrientLine.manganese),
  phosphorus(NutritionMetricSection.minerals, NutrientLine.phosphorus),
  potassium(NutritionMetricSection.minerals, NutrientLine.potassium),
  selenium(NutritionMetricSection.minerals, NutrientLine.selenium),
  sodium(NutritionMetricSection.minerals, NutrientLine.sodium),
  zinc(NutritionMetricSection.minerals, NutrientLine.zinc),
  caffeine(NutritionMetricSection.other, NutrientLine.caffeine),
  cholesterol(NutritionMetricSection.other, NutrientLine.cholesterol);

  new(this.section, [this.line]);

  /// Where its card is.
  final NutritionMetricSection section;

  /// The breakdown line it reads; null for calories and the macros, which
  /// come from the day's totals.
  final NutrientLine? line;

  /// The unit its values are in.
  String get unit => switch (this) {
    macros || calories => 'kcal',
    protein || fat || carbs => 'g',
    _ => line!.unit,
  };

  /// A day's value of this metric, from its [totals] and [breakdown];
  /// macros count the day's calories.
  double valueOf(Macros totals, Map<NutrientLine, double> breakdown) =>
      switch (this) {
        macros || calories => totals.calories,
        protein => totals.proteinGrams,
        fat => totals.fatGrams,
        carbs => totals.carbGrams,
        _ => breakdown[line] ?? 0,
      };

  /// The metric whose case name is [name], if any.
  static NutritionMetric? tryParse(String? name) =>
      values.where((metric) => metric.name == name).firstOrNull;
}

/// One logged day: its date and what was eaten.
typedef NutritionDay = ({
  DateTime date,
  Macros totals,
  Map<NutrientLine, double> breakdown,
});

/// How far back the detail screens read (Swift: a year before today).
const nutritionHistoryDays = 365;

/// Every day of [meals] from a year before [now]'s day through it, oldest
/// first (`getDailyTotals(startDayKey:endDayKey:)`).
List<NutritionDay> nutritionDays(Iterable<MealLogModel> meals, DateTime now) {
  final today = dayKeyOf(now);
  final first = addDays(today, -nutritionHistoryDays);
  final byDay = <String, List<MealLogModel>>{};
  for (final meal in meals) {
    if (meal.dayKey.compareTo(first) < 0 || meal.dayKey.compareTo(today) > 0) {
      continue;
    }
    (byDay[meal.dayKey] ??= []).add(meal);
  }
  final keys = byDay.keys.toList()..sort();
  return [
    for (final key in keys)
      (
        date: localMidnight(key),
        totals: totalsOf(byDay[key]!),
        breakdown: nutrientBreakdown(byDay[key]!),
      ),
  ];
}

/// Whether a day counts as logged for consistency and the macros chart:
/// any protein, carbohydrate or fat; calories alone are not a logged day.
bool hasMacros(Macros totals) =>
    totals.proteinGrams + totals.carbGrams + totals.fatGrams > 0;

/// [metric]'s value on each of [days] that has one above zero, oldest
/// first: an unlogged day is not a day of eating none
/// (`NutritionMetricDetailPresenter.onAppear`). Macros keep only days with
/// any macros.
List<MetricPoint> metricPoints(
  NutritionMetric metric,
  List<NutritionDay> days,
) => [
  for (final day in days)
    if (metric != NutritionMetric.macros || hasMacros(day.totals))
      if (metric.valueOf(day.totals, day.breakdown) case final value
          when value > 0)
        (date: day.date, value: value),
];

/// The days with any macros, as consistency's squares.
List<DateTime> foodLoggedDates(List<NutritionDay> days) => [
  for (final day in days)
    if (hasMacros(day.totals)) day.date,
];

/// A breakdown card's figure (`formatBreakdown`): nothing for a missing,
/// non-finite or zero amount, a whole number from 100 or when whole, else
/// one decimal place.
({double value, int decimals})? breakdownFigure(double? value) {
  if (value == null || !value.isFinite || value <= 0) return null;
  return (
    value: value >= 100 ? value.truncateToDouble() : value,
    decimals: value >= 100 || value == value.floorToDouble() ? 0 : 1,
  );
}

/// A breakdown card's bar width: 20% past what was eaten, at least
/// [defaultMax] (`breakdownChartMax`).
double breakdownChartMax(double? current, {double defaultMax = 50}) =>
    math.max((current ?? 0) * 1.2, defaultMax);

/// A macro card's bar width: 20% past the target, or past [fallback]
/// without one, or what was eaten if more.
double macroChartMax(double current, double? target, double fallback) =>
    math.max(current, (target ?? fallback) * 1.2);

/// The fallback ceilings Swift gives each macro card without a plan.
double macroFallback(NutritionMetric metric) => switch (metric) {
  NutritionMetric.calories => 2000,
  NutritionMetric.protein => 150,
  NutritionMetric.fat => 80,
  _ => 250,
};
