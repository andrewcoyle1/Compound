import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';

// Ported from the Swift `RecipeTemplateModelTests` and the recipe cases of
// `RecipeFlowPresenterTests` (`RecipeAmountPresenterTests`) and
// `RecipePreparationPresenterTests`.
void main() {
  final date = DateTime.utc(2026, 10, 1, 8);

  FoodModel food({
    String name = 'Rolled Oats',
    double calories = 379,
    double? protein = 13.2,
    MeasurementMethod method = MeasurementMethod.weight,
  }) => FoodModel(
    ingredientId: 'food-$name',
    name: name,
    measurementMethod: method,
    nutrients: NutrientMap({
      NutrientKey.calories: calories,
      NutrientKey.protein: ?protein,
    }),
    dateCreated: date,
    dateModified: date,
  );

  RecipeIngredientModel ingredient(
    FoodModel food,
    double amount, [
    IngredientAmountUnit unit = IngredientAmountUnit.grams,
  ]) => RecipeIngredientModel(ingredient: food, amount: amount, unit: unit);

  RecipeTemplateModel recipe(
    List<RecipeIngredientModel> ingredients, {
    double servings = 1,
  }) => RecipeTemplateModel(
    recipeId: 'recipe-1',
    authorId: 'author-1',
    name: 'Porridge',
    dateCreated: date,
    dateModified: date,
    ingredients: ingredients,
    servingQuantity: servings,
  );

  double? calories(RecipeTemplateModel recipe) =>
      recipe.perServing.values[NutrientKey.calories];

  group('totalling', () {
    test('one hundred grams is the per-hundred value', () {
      final subject = recipe([ingredient(food(), 100)]);

      expect(calories(subject), 379);
      expect(subject.perServing.values[NutrientKey.protein], 13.2);
    });

    test('amounts scale the nutrients', () {
      expect(calories(recipe([ingredient(food(), 50)])), 189.5);
      expect(calories(recipe([ingredient(food(), 200)])), 758);
    });

    test('ingredients add up, millilitres one for one with grams', () {
      final subject = recipe([
        ingredient(food(name: 'Oats'), 50),
        ingredient(
          food(name: 'Milk', calories: 61),
          200,
          IngredientAmountUnit.milliliters,
        ),
      ]);

      expect(calories(subject), 189.5 + 122);
    });

    test('whole units count as a hundred grams each', () {
      final subject = recipe([
        ingredient(food(), 2, IngredientAmountUnit.units),
      ]);

      expect(calories(subject), 758);
    });
  });

  group('servings', () {
    test('nutrition is divided across the servings', () {
      final ingredients = [ingredient(food(calories: 400), 100)];

      expect(calories(recipe(ingredients)), 400);
      expect(calories(recipe(ingredients, servings: 2)), 200);
      expect(calories(recipe(ingredients, servings: 4)), 100);
    });

    test('fewer than one serving, or not a number, divides by one', () {
      final ingredients = [ingredient(food(calories: 400), 100)];

      expect(calories(recipe(ingredients, servings: 0)), 400);
      expect(calories(recipe(ingredients, servings: 0.5)), 400);
      expect(calories(recipe(ingredients, servings: double.nan)), 400);
    });

    test('the factor for a serving count that is not usable is 0', () {
      final subject = recipe(const [], servings: 4);

      expect(subject.factorFor(2), 0.5);
      for (final servings in [0.0, -1.0, double.nan, double.infinity]) {
        expect(subject.factorFor(servings), 0);
      }
    });
  });

  group('missing data', () {
    final blank = FoodModel(
      ingredientId: 'blank',
      name: 'Mystery',
      dateCreated: date,
      dateModified: date,
    );

    test('a recipe with no recorded nutrients is unknown', () {
      final subject = recipe([ingredient(blank, 100)]);

      expect(calories(subject), isNull);
      expect(subject.perServing.values[NutrientKey.protein], isNull);
    });

    test('an empty recipe is unknown', () {
      expect(calories(recipe(const [])), isNull);
    });

    test('one ingredient with data is enough for a total', () {
      final subject = recipe([ingredient(food(), 100), ingredient(blank, 100)]);

      expect(calories(subject), 379);
    });

    test('nutrients are answered independently', () {
      final subject = recipe([ingredient(food(protein: null), 100)]);

      expect(calories(subject), 379);
      expect(subject.perServing.values[NutrientKey.protein], isNull);
    });
  });

  group('ingredients', () {
    test('an ingredient takes its unit from the food', () {
      expect(
        RecipeIngredientModel.forFood(food(), 100).unit,
        IngredientAmountUnit.grams,
      );
      expect(
        RecipeIngredientModel.forFood(
          food(method: MeasurementMethod.volume),
          100,
        ).unit,
        IngredientAmountUnit.milliliters,
      );
    });

    test('an ingredient is identified by its food', () {
      final oats = food();
      final subject = RecipeIngredientModel.forFood(oats, 100);

      expect(subject.id, oats.ingredientId);
      expect(subject.name, oats.name);
    });
  });

  // RecipeAmountPresenterTests: a recipe making four servings from 400 g of
  // a 150 kcal/100 g food, 600 kcal in the pot.
  group('mealItem', () {
    RecipeTemplateModel chilli({double servings = 4}) => recipe([
      ingredient(food(name: 'Mince', calories: 150, protein: null), 400),
    ], servings: servings);

    test('one serving is one serving, not the whole recipe', () {
      expect(chilli().mealItem(1).nutrients.values[NutrientKey.calories], 150);
    });

    test('two servings log twice as much', () {
      expect(chilli().mealItem(2).nutrients.values[NutrientKey.calories], 300);
    });

    test('a single-serving recipe logs the whole recipe', () {
      final item = chilli(servings: 1).mealItem(1);

      expect(item.nutrients.values[NutrientKey.calories], 600);
    });

    test('a recipe claiming no servings does not divide by zero', () {
      final item = chilli(servings: 0).mealItem(1);

      expect(item.nutrients.values[NutrientKey.calories], 600);
    });

    test('a nutrient no ingredient has stays absent', () {
      expect(
        chilli().mealItem(1).nutrients.values[NutrientKey.protein],
        isNull,
      );
    });

    test('a serving count that is not a number logs nothing finite', () {
      for (final servings in [double.nan, double.infinity, -2.0]) {
        final item = chilli().mealItem(servings);

        expect(item.amount, 0);
        expect(item.nutrients.values.values.every((v) => v.isFinite), isTrue);
      }
    });

    test('the item points at the recipe as one serving unit', () {
      final dish = chilli();
      final item = dish.mealItem(2, itemId: 'item-1');

      expect(item.itemId, 'item-1');
      expect(item.sourceType, MealItemSourceType.recipe);
      expect(item.sourceId, dish.recipeId);
      expect(item.displayName, dish.name);
      expect(item.amount, 2);
      expect(item.unit, 'serving');
      expect(item.resolvedGrams, isNull);
      expect(item.resolvedMilliliters, isNull);
    });

    test('a new item gets an id of its own', () {
      expect(chilli().mealItem(1).itemId, isNot(chilli().mealItem(1).itemId));
    });
  });

  group('quickAddItem', () {
    final dish = recipe([ingredient(food(calories: 400), 100)], servings: 2);
    MealLogModel meal(String id, DateTime at, List<MealItemModel> items) =>
        MealLogModel(
          mealId: id,
          authorId: 'author-1',
          dayKey: '2026-10-01',
          date: at,
          items: items,
        );

    test('one serving when it has never been logged', () {
      final item = dish.quickAddItem(const [], itemId: 'q');

      expect(item.itemId, 'q');
      expect(item.amount, 1);
      expect(item.nutrients.values[NutrientKey.calories], 200);
    });

    test('the servings last logged, by meal date', () {
      final meals = [
        meal('later', DateTime.utc(2026, 10, 2), [dish.mealItem(3)]),
        meal('earlier', DateTime.utc(2026, 9, 30), [dish.mealItem(5)]),
        meal('other', DateTime.utc(2026, 10, 3), [
          food().mealItem(100),
          recipe(const []).mealItem(1).withSource('another-recipe'),
        ]),
      ];

      expect(dish.quickAddItem(meals).amount, 3);
    });

    test('within a meal, the last of it', () {
      final meals = [
        meal('m', DateTime.utc(2026, 10, 2), [
          dish.mealItem(2),
          dish.mealItem(1.5),
        ]),
      ];

      expect(dish.quickAddItem(meals).amount, 1.5);
    });
  });
}

extension on MealItemModel {
  MealItemModel withSource(String sourceId) => MealItemModel(
    itemId: itemId,
    sourceType: sourceType,
    sourceId: sourceId,
    displayName: displayName,
    amount: amount,
    unit: unit,
    nutrients: nutrients,
  );
}
