import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

// The Swift `RecipeTemplateModelTests` that concern the stored shape.
void main() {
  final date = DateTime.utc(2026, 10, 1, 8);
  FoodModel food({MeasurementMethod method = MeasurementMethod.weight}) =>
      FoodModel(
        ingredientId: 'food-oats',
        name: 'Rolled Oats',
        measurementMethod: method,
        dateCreated: date,
        dateModified: date,
      );

  Map<String, Object?> stored(Object? amount) => {
    RecipeIngredientModelKeys.ingredient: food().toFirestore(),
    RecipeIngredientModelKeys.amount: amount,
    RecipeIngredientModelKeys.unit: 'grams',
  };

  group(RecipeIngredientModel, () {
    test('takes its unit from the food when none is given', () {
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

    test('is identified by its food', () {
      final ingredient = RecipeIngredientModel.forFood(food(), 100);

      expect(ingredient.id, 'food-oats');
      expect(ingredient.name, 'Rolled Oats');
    });

    test('a stored amount that is not finite reads as 0', () {
      for (final amount in [double.nan, double.infinity]) {
        expect(RecipeIngredientModel.fromFirestore(stored(amount)).amount, 0);
      }
    });

    test('a stored amount too large to print is capped', () {
      expect(
        RecipeIngredientModel.fromFirestore(stored(1e30)).amount,
        RecipeIngredientModel.maximumAmount,
      );
      expect(RecipeIngredientModel.fromFirestore(stored(-5)).amount, 0);
    });

    test('an ordinary amount is unchanged, an int widening', () {
      expect(RecipeIngredientModel.fromFirestore(stored(47.5)).amount, 47.5);
      expect(RecipeIngredientModel.fromFirestore(stored(40)).amount, 40.0);
    });
  });

  group(RecipeTemplateModel, () {
    test('a recipe missing its lists and servings reads with defaults', () {
      final recipe = RecipeTemplateModel.fromFirestore({
        RecipeTemplateModelKeys.recipeId: 'r',
        RecipeTemplateModelKeys.name: 'Toast',
        RecipeTemplateModelKeys.dateCreated: date,
        RecipeTemplateModelKeys.dateModified: date,
      });

      expect(recipe.ingredients, isEmpty);
      expect(recipe.preparationSteps, isEmpty);
      expect(recipe.servingQuantity, 1);
    });
  });
}
