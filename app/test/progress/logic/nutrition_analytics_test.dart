// AnalyticsNutritionMetricDetailTests, AnalyticsFoodLoggingConsistencyTests
// and the figure cases of AnalyticsNutritionOverviewTests.
import 'package:compound/nutrition_overview/logic/nutrition_overview.dart';
import 'package:compound/progress/logic/nutrition_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

void main() {
  // Saturday 14 March 2026.
  final now = DateTime(2026, 3, 14, 18);

  MealLogModel meal(
    String dayKey, {
    double calories = 500,
    double protein = 40,
    double carbs = 50,
    double fat = 15,
    double? iron,
  }) => MealLogModel(
    mealId: 'meal-$dayKey-$calories',
    authorId: 'me',
    dayKey: dayKey,
    date: DateTime.parse('${dayKey}T12:00:00'),
    items: [
      MealItemModel(
        itemId: 'item-$dayKey-$calories',
        sourceType: MealItemSourceType.ingredient,
        sourceId: 'food',
        displayName: 'Food',
        amount: 100,
        unit: 'g',
        nutrients: NutrientMap({
          NutrientKey.calories: calories,
          NutrientKey.protein: protein,
          NutrientKey.carbs: carbs,
          NutrientKey.fatTotal: fat,
          NutrientKey.ironMg: ?iron,
        }),
      ),
    ],
  );

  group('nutrition days', () {
    test('runs from a year ago through today, oldest first', () {
      final days = nutritionDays([
        meal('2026-03-14'),
        meal('2025-03-14'),
        meal('2025-03-13'),
        meal('2026-03-15'),
        meal('2026-03-10'),
        meal('2026-03-10', calories: 300),
      ], now);
      expect(
        [for (final d in days) d.date],
        [DateTime(2025, 3, 14), DateTime(2026, 3, 10), DateTime(2026, 3, 14)],
      );
      // A day's meals add up.
      expect(days[1].totals.calories, 800);
    });
  });

  group('metric points', () {
    test('an unlogged day is not plotted as zero', () {
      final days = nutritionDays([meal('2026-03-10')], now);
      expect(metricPoints(NutritionMetric.calories, days), hasLength(1));
    });

    test('macros keep only days with any macros', () {
      final days = nutritionDays([
        meal('2026-03-10'),
        meal('2026-03-11', protein: 0, carbs: 0, fat: 0),
      ], now);
      expect(metricPoints(NutritionMetric.macros, days), hasLength(1));
      // Calories alone still plot as calories.
      expect(metricPoints(NutritionMetric.calories, days), hasLength(2));
    });

    test('protein plots grams of protein', () {
      final days = nutritionDays([meal('2026-03-10', protein: 42)], now);
      expect(metricPoints(NutritionMetric.protein, days).single.value, 42);
      expect(metricPoints(NutritionMetric.fat, days).single.value, 15);
      expect(metricPoints(NutritionMetric.carbs, days).single.value, 50);
    });

    test('a micronutrient comes from the breakdown', () {
      final days = nutritionDays([meal('2026-03-10', iron: 8.5)], now);
      expect(metricPoints(NutritionMetric.iron, days).single.value, 8.5);
    });

    test('a zero reading is not plotted', () {
      final days = nutritionDays([meal('2026-03-10')], now);
      expect(metricPoints(NutritionMetric.iron, days), isEmpty);
    });

    test('food logging counts days with macros, not calories alone', () {
      final days = nutritionDays([
        meal('2026-03-10'),
        meal('2026-03-11', protein: 0, carbs: 0, fat: 0),
      ], now);
      expect(foodLoggedDates(days), [DateTime(2026, 3, 10)]);
    });
  });

  group(NutritionMetric, () {
    test('reads each metric from its own field and unit', () {
      const totals = (
        calories: 2000.0,
        proteinGrams: 150.0,
        carbGrams: 200.0,
        fatGrams: 60.0,
      );
      final breakdown = {NutrientLine.sodium: 1200.0};
      expect(NutritionMetric.macros.valueOf(totals, breakdown), 2000);
      expect(NutritionMetric.calories.valueOf(totals, breakdown), 2000);
      expect(NutritionMetric.protein.valueOf(totals, breakdown), 150);
      expect(NutritionMetric.fat.valueOf(totals, breakdown), 60);
      expect(NutritionMetric.carbs.valueOf(totals, breakdown), 200);
      expect(NutritionMetric.sodium.valueOf(totals, breakdown), 1200);
      expect(NutritionMetric.zinc.valueOf(totals, breakdown), 0);
      expect(NutritionMetric.macros.unit, 'kcal');
      expect(NutritionMetric.protein.unit, 'g');
      expect(NutritionMetric.selenium.unit, 'mcg');
    });

    test('parses its case name', () {
      expect(NutritionMetric.tryParse('fatMono'), NutritionMetric.fatMono);
      expect(NutritionMetric.tryParse('starch'), isNull);
    });
  });

  group('card figures', () {
    test('an unlogged or unreadable micronutrient reads as missing', () {
      expect(breakdownFigure(null), isNull);
      expect(breakdownFigure(0), isNull);
      expect(breakdownFigure(double.nan), isNull);
      expect(breakdownFigure(double.infinity), isNull);
    });

    test('small amounts keep a decimal, large or whole ones do not', () {
      expect(breakdownFigure(2.5), (value: 2.5, decimals: 1));
      expect(breakdownFigure(3), (value: 3.0, decimals: 0));
      expect(breakdownFigure(120.7), (value: 120.0, decimals: 0));
    });

    test('a breakdown ceiling clears what was logged', () {
      expect(breakdownChartMax(null), 50);
      expect(breakdownChartMax(10), 50);
      expect(breakdownChartMax(100), 120);
    });

    test('a macro ceiling clears an overshoot and defaults without a plan', () {
      expect(macroChartMax(100, 150, 80), 180);
      expect(macroChartMax(300, 150, 80), 300);
      expect(macroChartMax(10, null, 80), 96);
      expect(macroFallback(NutritionMetric.calories), 2000);
      expect(macroFallback(NutritionMetric.protein), 150);
      expect(macroFallback(NutritionMetric.fat), 80);
      expect(macroFallback(NutritionMetric.carbs), 250);
    });
  });
}
