// Ported from the Swift `CreateRecipePresenterTests`,
// `RecipeDetailPresenterTests`, `FoodLibraryPresenterTests`,
// `FoodItemSearchPresenterTests` (recipes) and `RecentPick`'s cases.
import 'package:compound/nutrition/add_meal/view/food_picker.dart'
    show LibrarySegment, initialLibrarySegment;
import 'package:compound/nutrition/recipes/logic/recipe_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart'
    show FoodLogSettings;

void main() {
  const uid = 'uid';
  final now = DateTime.utc(2026, 9, 2);

  FoodModel food(
    String id, {
    String? name,
    double? servingWeight,
    double? portionVolume,
    MeasurementMethod method = MeasurementMethod.weight,
  }) => FoodModel(
    ingredientId: id,
    authorId: uid,
    name: name ?? id,
    measurementMethod: method,
    servingWeight: servingWeight,
    portionVolume: portionVolume,
    dateCreated: now,
    dateModified: now,
  );

  RecipeTemplateModel recipe(
    String id, {
    String? name,
    String? description,
    List<RecipeIngredientModel> ingredients = const [],
  }) => RecipeTemplateModel(
    recipeId: id,
    authorId: uid,
    name: name ?? id,
    description: description,
    dateCreated: now,
    dateModified: now,
    ingredients: ingredients,
  );

  MealItemModel item(String sourceId, MealItemSourceType type) => MealItemModel(
    itemId: '$type-$sourceId',
    sourceType: type,
    sourceId: sourceId,
    displayName: sourceId,
    amount: 1,
    unit: 'g',
  );

  MealLogModel meal(DateTime date, List<MealItemModel> items) => MealLogModel(
    mealId: '$date',
    authorId: uid,
    dayKey: '2026-09-0${date.day}',
    date: date,
    items: items,
  );

  test('names are capitalised word by word, as Swift does', () {
    expect(capitalizedName('chilli con carne'), 'Chilli Con Carne');
    expect(capitalizedName('BBQ  ribs'), 'Bbq  Ribs');
    expect(capitalizedName(''), '');
  });

  test('sortedByName ignores case', () {
    expect(sortedByName(['b', 'A', 'c'], (s) => s), ['A', 'b', 'c']);
  });

  test('the recipe search matches name, description or an ingredient', () {
    final chilli = recipe(
      'c',
      name: 'Chilli',
      description: 'Hot',
      ingredients: [RecipeIngredientModel.forFood(food('beans'), 100)],
    );
    final other = recipe('x', name: 'Rice');
    expect(searchRecipes([chilli, other], 'CHIL'), [chilli]);
    expect(searchRecipes([chilli, other], 'hot'), [chilli]);
    expect(searchRecipes([chilli, other], 'bean'), [chilli]);
    expect(searchRecipes([chilli, other], 'rice'), [other]);
    expect(searchRecipes([chilli, other], ''), [chilli, other]);
  });

  test('the weighed total counts grams only, or is absent', () {
    expect(weighedTotal(const []), isNull);
    expect(
      weighedTotal([
        RecipeIngredientModel.forFood(
          food('milk', method: MeasurementMethod.volume),
          250,
        ),
      ]),
      isNull,
    );
    expect(
      weighedTotal([
        RecipeIngredientModel.forFood(food('a'), 400),
        RecipeIngredientModel.forFood(food('b'), 120),
      ]),
      520,
    );
  });

  test("an ingredient row's + adds its portion, or 100", () {
    final weighed = quickAddIngredient(food('bread', servingWeight: 40));
    expect(weighed.amount, 40);
    expect(weighed.unit, IngredientAmountUnit.grams);
    final poured = quickAddIngredient(
      food('milk', method: MeasurementMethod.volume, portionVolume: 250),
    );
    expect(poured.amount, 250);
    expect(poured.unit, IngredientAmountUnit.milliliters);
    expect(quickAddIngredient(food('rice')).amount, 100);
  });

  test('each ingredient unit has a display name', () {
    expect(unitLabel(IngredientAmountUnit.grams), 'g');
    expect(unitLabel(IngredientAmountUnit.milliliters), 'ml');
    expect(unitLabel(IngredientAmountUnit.units), 'units');
  });

  test('a recipe on the plate is counted', () {
    final items = [
      item('chilli', MealItemSourceType.recipe),
      item('chilli', MealItemSourceType.ingredient),
      item('chilli', MealItemSourceType.recipe),
    ];
    expect(addedRecipeCount(items, 'chilli'), 2);
    expect(addedRecipeCount(items, 'stew'), 0);
  });

  group('recentPicks', () {
    final foods = [food('oats'), food('rice'), food('egg')];
    final recipes = [recipe('chilli')];

    test('foods and recipes eaten, newest first, each once', () {
      final meals = [
        meal(DateTime(2026, 9, 3), [
          item('egg', MealItemSourceType.ingredient),
        ]),
        meal(DateTime(2026, 9, 4), [
          item('oats', MealItemSourceType.ingredient),
          item('chilli', MealItemSourceType.recipe),
          item('gone', MealItemSourceType.ingredient),
          item('gone', MealItemSourceType.recipe),
          item('q', MealItemSourceType.quickAdd),
        ]),
        meal(DateTime(2026, 8, 5), [
          item('chilli', MealItemSourceType.recipe),
          item('rice', MealItemSourceType.ingredient),
        ]),
      ];
      expect(
        [
          for (final pick in recentPicks(meals, foods, recipes))
            switch (pick) {
              RecentFood(:final food) => food.ingredientId,
              RecentRecipe(:final recipe) => 'recipe ${recipe.recipeId}',
            },
        ],
        ['recipe chilli', 'oats', 'egg', 'rice'],
      );
    });

    test('a food and a recipe sharing an id are both listed', () {
      final meals = [
        meal(DateTime(2026, 9, 2), [
          item('oats', MealItemSourceType.ingredient),
          item('oats', MealItemSourceType.recipe),
        ]),
      ];
      expect(
        recentPicks(meals, foods, [recipe('oats')], limit: 5),
        hasLength(2),
      );
    });

    test('stops at the limit', () {
      final meals = [
        meal(DateTime(2026, 9, 2), [
          item('oats', MealItemSourceType.ingredient),
          item('rice', MealItemSourceType.ingredient),
        ]),
      ];
      expect(recentPicks(meals, foods, recipes, limit: 1), hasLength(1));
    });
  });

  test('saved recipes match the search by name, at most 20', () {
    final recipes = [
      recipe('a', name: 'Chilli'),
      recipe('b', name: 'Curry'),
      for (var i = 0; i < 25; i++) recipe('s$i', name: 'Stew $i'),
    ];
    expect(recipeMatches(recipes, '  '), isEmpty);
    expect(recipeMatches(recipes, 'CHIL').map((r) => r.name), ['Chilli']);
    expect(recipeMatches(recipes, 'stew'), hasLength(20));
  });

  group('favourites', () {
    List<FoodModel> pick(List<String> ids, String query) => favourites(
      [food('b', name: 'banana'), food('a', name: 'Apple'), food('c')],
      ids,
      query,
      id: (food) => food.ingredientId,
      name: (food) => food.name,
    );

    test('are resolved from their ids, sorted by name', () {
      expect(pick(['b', 'a'], '').map((f) => f.name), ['Apple', 'banana']);
    });

    test('a favourite whose item is gone is dropped', () {
      expect(pick(['gone', 'c'], '').map((f) => f.name), ['c']);
    });

    test('the filter matches part of a name regardless of case', () {
      expect(pick(['a', 'b'], ' APP ').map((f) => f.name), ['Apple']);
    });
  });

  group('initialLibrarySegment', () {
    test('opens on favourites when there are any, else recipes', () {
      expect(
        initialLibrarySegment(const FoodLogSettings(authorId: uid)),
        LibrarySegment.recipes,
      );
      expect(
        initialLibrarySegment(
          const FoodLogSettings(authorId: uid, favouriteFoodIds: ['a']),
        ),
        LibrarySegment.favourites,
      );
      expect(
        initialLibrarySegment(
          const FoodLogSettings(authorId: uid, favouriteRecipeIds: ['r']),
        ),
        LibrarySegment.favourites,
      );
    });
  });

  test('servings are kept between half and a hundred', () {
    expect(clampedServings(0), 0.5);
    expect(clampedServings(double.nan), 0.5);
    expect(clampedServings(3), 3);
    expect(clampedServings(1000), 100);
  });
}
