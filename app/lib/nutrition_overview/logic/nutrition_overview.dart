/// The Nutrition Overview's arithmetic (Swift `NutritionOverviewPresenter`
/// and `MealLogManager.getDailyNutritionBreakdown`): a day's nutrient
/// breakdown and the foods that contributed most. Pure, so the bloc and the
/// view only read it.
library;

import 'dart:math' as math;

import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound_maths/compound_maths.dart' show Macros, sumMacros;
import 'package:nutrition_repository/nutrition_repository.dart';

/// A section of nutrient rows, in the Swift view's order.
enum NutrientSection { carbs, fats, vitamins, minerals, other }

/// One row of the breakdown: the nutrient it reads, or none for net carbs,
/// which is worked out; its unit; and its section.
enum NutrientLine {
  fiber(NutrientKey.fiber, 'g', NutrientSection.carbs),
  sugar(NutrientKey.sugar, 'g', NutrientSection.carbs),
  netCarbs(null, 'g', NutrientSection.carbs),
  saturated(NutrientKey.fatSaturated, 'g', NutrientSection.fats),
  monounsaturated(NutrientKey.fatMonounsaturated, 'g', NutrientSection.fats),
  polyunsaturated(NutrientKey.fatPolyunsaturated, 'g', NutrientSection.fats),
  vitaminA(NutrientKey.vitaminAMcg, 'mcg', NutrientSection.vitamins),
  vitaminB6(NutrientKey.vitaminB6Mg, 'mg', NutrientSection.vitamins),
  vitaminB12(NutrientKey.vitaminB12Mcg, 'mcg', NutrientSection.vitamins),
  vitaminC(NutrientKey.vitaminCMg, 'mg', NutrientSection.vitamins),
  vitaminD(NutrientKey.vitaminDMcg, 'mcg', NutrientSection.vitamins),
  vitaminE(NutrientKey.vitaminEMg, 'mg', NutrientSection.vitamins),
  vitaminK(NutrientKey.vitaminKMcg, 'mcg', NutrientSection.vitamins),
  thiamin(NutrientKey.thiaminMg, 'mg', NutrientSection.vitamins),
  riboflavin(NutrientKey.riboflavinMg, 'mg', NutrientSection.vitamins),
  niacin(NutrientKey.niacinMg, 'mg', NutrientSection.vitamins),
  pantothenicAcid(
    NutrientKey.pantothenicAcidMg,
    'mg',
    NutrientSection.vitamins,
  ),
  folate(NutrientKey.folateMcg, 'mcg', NutrientSection.vitamins),
  sodium(NutrientKey.sodiumMg, 'mg', NutrientSection.minerals),
  potassium(NutrientKey.potassiumMg, 'mg', NutrientSection.minerals),
  calcium(NutrientKey.calciumMg, 'mg', NutrientSection.minerals),
  iron(NutrientKey.ironMg, 'mg', NutrientSection.minerals),
  magnesium(NutrientKey.magnesiumMg, 'mg', NutrientSection.minerals),
  zinc(NutrientKey.zincMg, 'mg', NutrientSection.minerals),
  copper(NutrientKey.copperMg, 'mg', NutrientSection.minerals),
  manganese(NutrientKey.manganeseMg, 'mg', NutrientSection.minerals),
  phosphorus(NutrientKey.phosphorusMg, 'mg', NutrientSection.minerals),
  selenium(NutrientKey.seleniumMcg, 'mcg', NutrientSection.minerals),
  cholesterol(NutrientKey.cholesterolMg, 'mg', NutrientSection.other),
  caffeine(NutrientKey.caffeineMg, 'mg', NutrientSection.other);

  new(this.key, this.unit, this.section);

  /// The stored nutrient, or null for [netCarbs].
  final NutrientKey? key;

  /// The unit shown after the amount.
  final String unit;

  /// Where the row is shown.
  final NutrientSection section;
}

/// [meals]' amount of each nutrient line, leaving out a line nothing
/// recorded. Each item counts its own stored snapshot, only where above
/// zero; net carbs is the day's carbohydrate less its fibre, never below
/// zero, and only once there is fibre to take away.
Map<NutrientLine, double> nutrientBreakdown(Iterable<MealLogModel> meals) {
  final result = <NutrientLine, double>{};
  for (final item in meals.expand((meal) => meal.items)) {
    for (final line in NutrientLine.values) {
      final value = item.nutrients.values[line.key];
      if (value != null && value > 0) {
        result[line] = (result[line] ?? 0) + value;
      }
    }
  }
  final fiber = result[NutrientLine.fiber];
  if (fiber != null) {
    result[NutrientLine.netCarbs] = math.max(
      0,
      totalsOf(meals).carbGrams - fiber,
    );
  }
  return result;
}

/// A food's share of the day: its name and what it added up to.
typedef Contributor = ({String name, Macros macros});

/// [meals]' items added up by name, most calories first
/// (`topContributors`).
List<Contributor> contributors(Iterable<MealLogModel> meals) {
  final byName = <String, List<Macros>>{};
  for (final item in meals.expand((meal) => meal.items)) {
    (byName[item.displayName] ??= []).add(item.macros);
  }
  return [
    for (final MapEntry(:key, :value) in byName.entries)
      (name: key, macros: sumMacros(value)),
  ]..sort((a, b) => b.macros.calories.compareTo(a.macros.calories));
}
