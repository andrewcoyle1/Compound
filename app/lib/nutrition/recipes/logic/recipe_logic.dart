/// Recipes in the library, ported from the Swift `CreateRecipePresenter`,
/// `RecipePreparationPresenter`, `RecipeListBuilderPresenter`,
/// `RecipeDetailPresenter`, `IngredientListBuilderPresenter`,
/// `FoodLibraryPresenter` and `RecentPick`. Pure, so the cubits and views
/// only read it.
library;

import 'package:food_repository/food_repository.dart';

/// [name] as Swift's `String.capitalized` writes it: each word, split on
/// white space, with its first letter in upper case and the rest in lower,
/// so the library does not fill with the same dish spelled three ways.
String capitalizedName(String name) => name.splitMapJoin(
  RegExp(r'\S+'),
  onMatch: (match) {
    final word = match[0]!;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  },
);

/// [items] sorted by name, ignoring case.
List<T> sortedByName<T>(Iterable<T> items, String Function(T) name) =>
    [...items]
      ..sort((a, b) => name(a).toLowerCase().compareTo(name(b).toLowerCase()));

/// Whether [recipe] matches the recipe list's [filter]
/// (`RecipeListBuilderPresenter.filteredRecipeTemplates`): its name,
/// description or an ingredient's name, ignoring case.
bool matchesRecipeFilter(RecipeTemplateModel recipe, String filter) {
  final needle = filter.toLowerCase();
  bool has(String? text) => text != null && text.toLowerCase().contains(needle);
  return has(recipe.name) ||
      has(recipe.description) ||
      recipe.ingredients.any((ingredient) => has(ingredient.name));
}

/// The total of the ingredients measured in grams, which Create Recipe
/// shows under its Ingredients header; null when nothing is weighed
/// (`CreateRecipePresenter.ingredientsWeightText`).
double? weighedTotal(List<RecipeIngredientModel> ingredients) {
  final weighed = [
    for (final ingredient in ingredients)
      if (ingredient.unit == IngredientAmountUnit.grams) ingredient.amount,
  ];
  if (weighed.isEmpty) return null;
  return weighed.fold<double>(0, (sum, amount) => sum + amount);
}

/// [food] as a recipe ingredient at its declared portion, what an
/// ingredient row's + adds (`IngredientListBuilderPresenter.quickAdd` with
/// a recipe): grams or millilitres by the food, 100 with no portion.
RecipeIngredientModel quickAddIngredient(FoodModel food) =>
    RecipeIngredientModel.forFood(
      food,
      food.portionGrams ?? food.portionMilliliters ?? 100,
    );

/// [ingredients] with [ingredient] in place of the one made from the same
/// food, or added (`CreateRecipePresenter.onAddIngredientPressed`'s
/// callback): confirming a food again changes its amount.
List<RecipeIngredientModel> withIngredient(
  List<RecipeIngredientModel> ingredients,
  RecipeIngredientModel ingredient,
) {
  final index = ingredients.indexWhere((each) => each.id == ingredient.id);
  if (index < 0) return [...ingredients, ingredient];
  return [...ingredients]..[index] = ingredient;
}

/// The unit's short name (`RecipeDetailPresenter.displayUnit`).
String unitLabel(IngredientAmountUnit unit) => switch (unit) {
  IngredientAmountUnit.grams => 'g',
  IngredientAmountUnit.milliliters => 'ml',
  IngredientAmountUnit.units => 'units',
};

/// The fewest and most servings the detail's stepper offers, and its step
/// (`RecipeDetailPresenter.servingsRange` and `.servingsStep`).
const minimumServings = 0.5;
const maximumServings = 100.0;
const servingsStep = 0.5;

/// [servings] in the stepper's range; not a number reads as the least.
double clampedServings(double servings) => servings.isFinite
    ? servings.clamp(minimumServings, maximumServings)
    : minimumServings;

/// How many times the recipe [recipeId] is on [items].
int addedRecipeCount(List<MealItemModel> items, String recipeId) => items
    .where(
      (item) =>
          item.sourceType == MealItemSourceType.recipe &&
          item.sourceId == recipeId,
    )
    .length;

/// A food or recipe recently eaten, for the search screen's "Recent".
sealed class const RecentPick();

/// A food recently eaten.
final class const RecentFood(final FoodModel food) extends RecentPick;

/// A recipe recently eaten.
final class const RecentRecipe(final RecipeTemplateModel recipe)
    extends RecentPick;

/// The foods and recipes most recently eaten, newest first and each once
/// (`[MealLogModel].recentPicks`): by the meals' dates, then the last item
/// first. Quick adds, and anything since deleted, are left out.
List<RecentPick> recentPicks(
  List<MealLogModel> meals,
  List<FoodModel> foods,
  List<RecipeTemplateModel> recipes, {
  int limit = 20,
}) {
  final foodsById = <String, FoodModel>{};
  for (final food in foods) {
    foodsById.putIfAbsent(food.ingredientId, () => food);
  }
  final recipesById = <String, RecipeTemplateModel>{};
  for (final recipe in recipes) {
    recipesById.putIfAbsent(recipe.recipeId, () => recipe);
  }
  final seen = <String>{};
  final result = <RecentPick>[];
  final sorted = [...meals]..sort((a, b) => b.date.compareTo(a.date));
  for (final meal in sorted) {
    for (final item in meal.items.reversed) {
      final food = item.sourceType == MealItemSourceType.ingredient
          ? foodsById[item.sourceId]
          : null;
      final recipe = item.sourceType == MealItemSourceType.recipe
          ? recipesById[item.sourceId]
          : null;
      final pick = food != null
          ? RecentFood(food)
          : recipe != null
          ? RecentRecipe(recipe)
          : null;
      final key = '${item.sourceType.value}-${item.sourceId}';
      if (pick == null || !seen.add(key)) continue;
      result.add(pick);
      if (result.length == limit) return result;
    }
  }
  return result;
}

/// The user's recipes matching [query] by name, ignoring case, at most 20
/// (`FoodItemSearchPresenter.recipeResults`). A blank query finds nothing.
List<RecipeTemplateModel> recipeMatches(
  List<RecipeTemplateModel> recipes,
  String query,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  return recipes
      .where((recipe) => recipe.name.toLowerCase().contains(needle))
      .take(20)
      .toList();
}

/// The favourites among [items] (`FoodLibraryPresenter.favouriteFoods` and
/// `.favouriteRecipes`): those whose id is in [ids], an id whose item has
/// gone dropped, filtered by [query] on the name and sorted by name.
List<T> favourites<T>(
  Iterable<T> items,
  Iterable<String> ids,
  String query, {
  required String Function(T) id,
  required String Function(T) name,
}) {
  final wanted = ids.toSet();
  final needle = query.trim().toLowerCase();
  return sortedByName([
    for (final item in items)
      if (wanted.contains(id(item)) &&
          (needle.isEmpty || name(item).toLowerCase().contains(needle)))
        item,
  ], name);
}
