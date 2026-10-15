import 'package:ai_repository/ai_repository.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 8);
  var ids = 0;
  String newId() => 'id-${ids++}';

  setUp(() => ids = 0);

  const chicken = FoodAnalysisItem(
    id: '1',
    name: 'Chicken',
    amountGrams: 150,
    calories: 248,
    proteinGrams: 46.5,
    carbGrams: 0,
    fatGrams: 5.4,
    ingredientId: 'ing-1',
  );

  group('mealItem', () {
    test('logs the estimate as is, in grams', () {
      final item = chicken.mealItem(newId: newId);

      expect(item.itemId, 'id-0');
      expect(item.sourceType, MealItemSourceType.ingredient);
      expect(item.sourceId, 'ing-1');
      expect(item.displayName, 'Chicken');
      expect(item.amount, 150);
      expect(item.unit, 'g');
      expect(item.resolvedGrams, 150);
      expect(item.resolvedMilliliters, isNull);
      expect(item.nutrients.values, {
        NutrientKey.calories: 248.0,
        NutrientKey.protein: 46.5,
        NutrientKey.carbs: 0.0,
        NutrientKey.fatTotal: 5.4,
      });
    });

    test('names a new source when the function filed none, and leaves '
        'missing nutrients out', () {
      final item = const FoodAnalysisItem(
        id: '2',
        name: 'Rice',
        amountGrams: 100,
      ).mealItem();

      expect(item.sourceId, matches(RegExp(r'^[0-9A-F]{8}-[0-9A-F-]{27}$')));
      expect(item.sourceId, isNot(item.itemId));
      expect(item.nutrients.values, isEmpty);
    });
  });

  group('estimatedFood', () {
    test('scales the estimate to per 100 g', () {
      final food = chicken.estimatedFood(now: now, newId: newId);

      expect(food.ingredientId, 'ing-1');
      expect(food.name, 'Chicken');
      expect(food.dateCreated, now);
      expect(food.dateModified, now);
      expect(food.nutrients.values[NutrientKey.calories], closeTo(165.33, .01));
      expect(food.nutrients.values[NutrientKey.protein], closeTo(31, 1e-9));
    });

    test('leaves the figures unscaled for no amount, under a new id', () {
      final food = const FoodAnalysisItem(
        id: '3',
        name: 'Sauce',
        amountGrams: 0,
        calories: 40,
      ).estimatedFood(now: now, newId: newId);

      expect(food.ingredientId, 'id-0');
      expect(food.nutrients.values, {NutrientKey.calories: 40.0});
    });

    test('names a new food by default', () {
      expect(
        const FoodAnalysisItem(
          id: '4',
          name: 'Egg',
          amountGrams: 50,
        ).estimatedFood(now: now).ingredientId,
        hasLength(36),
      );
    });
  });
}
