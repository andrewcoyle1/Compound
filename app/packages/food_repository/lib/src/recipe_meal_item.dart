import 'dart:math' as math;

import 'package:compound_models/compound_models.dart';
import 'package:food_repository/src/random_id.dart';

/// An ingredient's amount as the nutrition maths counts it (Swift
/// `NutritionScaling.baseAmount(of:)`).
extension RecipeIngredientAmount on RecipeIngredientModel {
  /// Grams (or millilitres) of the food: millilitres one for one with
  /// grams, and a counted unit as 100 g, the assumption the recipe builder
  /// makes.
  double get baseAmount => switch (unit) {
    IngredientAmountUnit.grams || IngredientAmountUnit.milliliters => amount,
    IngredientAmountUnit.units => amount * 100,
  };
}

/// A recipe's nutrition and the recipe as a meal item (Swift
/// `NutritionScaling` and `RecipeTemplateModel+MealItem`).
extension RecipeMealItem on RecipeTemplateModel {
  /// The whole dish's nutrients: every ingredient at the amount the recipe
  /// uses. A nutrient no ingredient records stays absent rather than
  /// reading as zero.
  NutrientMap get totalNutrients {
    final total = <NutrientKey, double>{};
    for (final ingredient in ingredients) {
      final factor = ingredient.baseAmount / 100;
      for (final MapEntry(:key, :value)
          in ingredient.ingredient.nutrients.values.entries) {
        total[key] = (total[key] ?? 0) + value * factor;
      }
    }
    return NutrientMap(total);
  }

  /// How many servings the recipe as written makes; at least one, so a
  /// recipe saved claiming none reads as a single serving.
  double get servingDivisor =>
      servingQuantity.isFinite ? math.max(servingQuantity, 1) : 1;

  /// One serving's nutrients: the dish divided across its servings.
  NutrientMap get perServing => _scaled(totalNutrients, 1 / servingDivisor);

  /// What to multiply the recipe's amounts by to make [servings] of it;
  /// anything that is not a usable serving count scales to nothing.
  double factorFor(double servings) =>
      servings.isFinite && servings > 0 ? servings / servingDivisor : 0;

  /// The whole of what [servings] servings hold.
  NutrientMap nutrientsFor(double servings) =>
      _scaled(totalNutrients, factorFor(servings));

  /// This recipe as a meal item of [servings] servings: per serving, then
  /// by how many were eaten. A count that is negative or not finite is 0.
  /// [itemId] defaults to a new UUID.
  MealItemModel mealItem(double servings, {String? itemId}) {
    final logged = servings.isFinite && servings > 0 ? servings : 0.0;
    return MealItemModel(
      itemId: itemId ?? randomUuid(),
      sourceType: MealItemSourceType.recipe,
      sourceId: recipeId,
      displayName: name,
      amount: logged,
      unit: 'serving',
      nutrients: nutrientsFor(logged),
    );
  }

  /// A picker row's "+": the servings last logged in [meals] (by meal
  /// date, the last such item in that meal), or one.
  MealItemModel quickAddItem(List<MealLogModel> meals, {String? itemId}) {
    bool isThisRecipe(MealItemModel item) =>
        item.sourceType == MealItemSourceType.recipe &&
        item.sourceId == recipeId;
    MealLogModel? latest;
    for (final meal in meals) {
      if (meal.items.any(isThisRecipe) &&
          (latest == null || meal.date.isAfter(latest.date))) {
        latest = meal;
      }
    }
    final last = latest?.items.lastWhere(isThisRecipe);
    return mealItem(last?.amount ?? 1, itemId: itemId);
  }
}

NutrientMap _scaled(NutrientMap map, double factor) =>
    NutrientMap(map.values.map((key, value) => MapEntry(key, value * factor)));
