/// The logger's "Show all nutrients" (Swift `AddMealPresenter`'s
/// `displayNutrients`, `breakdown(for:)` and `formatted(_:)`): every
/// nutrient the plate's foods record, by category. Pure, so the view only
/// reads it.
library;

import 'package:app_ui/app_ui.dart' show AppFormat;
import 'package:compound/nutrition/foods/logic/create_food.dart'
    show nutrientUnit;
import 'package:compound/nutrition/logic/meal_day.dart' show mealsOnDay;
import 'package:compound/nutrition/logic/meal_logging.dart' show NutritionScope;
import 'package:nutrition_repository/nutrition_repository.dart';

/// The breakdown's sections, in Swift `Macros`' order.
enum NutrientCategory { protein, fat, carbs, vitamins, minerals, other }

/// [key]'s section, or null for calories, which is never listed
/// (`NutrientKey.category`).
NutrientCategory? nutrientCategory(NutrientKey key) => switch (key) {
  NutrientKey.calories => null,
  NutrientKey.protein ||
  NutrientKey.cysteine ||
  NutrientKey.histidine ||
  NutrientKey.isoleucine ||
  NutrientKey.leucine ||
  NutrientKey.lysine ||
  NutrientKey.methionine ||
  NutrientKey.phenylalanine ||
  NutrientKey.threonine ||
  NutrientKey.tryptophan ||
  NutrientKey.tyrosine ||
  NutrientKey.valine => NutrientCategory.protein,
  NutrientKey.fatTotal ||
  NutrientKey.fatSaturated ||
  NutrientKey.fatMonounsaturated ||
  NutrientKey.fatPolyunsaturated ||
  NutrientKey.fatTrans ||
  NutrientKey.omega3 ||
  NutrientKey.omega3Ala ||
  NutrientKey.omega3Dha ||
  NutrientKey.omega3Epa ||
  NutrientKey.omega6 => NutrientCategory.fat,
  NutrientKey.carbs ||
  NutrientKey.fiber ||
  NutrientKey.sugar ||
  NutrientKey.addedSugars ||
  NutrientKey.starch => NutrientCategory.carbs,
  NutrientKey.sodiumMg ||
  NutrientKey.potassiumMg ||
  NutrientKey.calciumMg ||
  NutrientKey.ironMg ||
  NutrientKey.magnesiumMg ||
  NutrientKey.zincMg ||
  NutrientKey.copperMg ||
  NutrientKey.manganeseMg ||
  NutrientKey.phosphorusMg ||
  NutrientKey.seleniumMcg ||
  NutrientKey.chlorideMg ||
  NutrientKey.chromiumMcg ||
  NutrientKey.molybdenumMcg => NutrientCategory.minerals,
  NutrientKey.caffeineMg ||
  NutrientKey.cholesterolMg ||
  NutrientKey.alcohol ||
  NutrientKey.water => NutrientCategory.other,
  _ => NutrientCategory.vitamins,
};

/// What [meal]'s foods record at [scope]: the plate, or the plate plus the
/// other meals logged on its day in [meals], each counted once. A nutrient
/// no food records is absent, not zero.
Map<NutrientKey, double> scopedNutrients(
  MealLogModel meal,
  List<MealLogModel> meals,
  NutritionScope scope,
) {
  final total = <NutrientKey, double>{};
  final counted = [
    meal,
    if (scope == NutritionScope.day)
      for (final other in mealsOnDay(meals, meal.dayKey))
        if (other.mealId != meal.mealId) other,
  ];
  for (final item in counted.expand((meal) => meal.items)) {
    item.nutrients.values.forEach(
      (key, value) => total[key] = (total[key] ?? 0) + value,
    );
  }
  return total;
}

/// [category]'s recorded nutrients in [nutrients], in declaration order:
/// its total first.
List<(NutrientKey, double)> breakdown(
  Map<NutrientKey, double> nutrients,
  NutrientCategory category,
) => [
  for (final key in NutrientKey.values)
    if (nutrientCategory(key) == category)
      if (nutrients[key] case final value?) (key, value),
];

/// "500 kcal"; "3.7 mg" below ten; "25 g" from ten.
String formatNutrient(NutrientKey key, double value, {String? locale}) {
  final digits = key == NutrientKey.calories || value >= 10 ? 0 : 1;
  return '${AppFormat.number(value, maxFractionDigits: digits, locale: locale)}'
      ' ${nutrientUnit(key)}';
}
