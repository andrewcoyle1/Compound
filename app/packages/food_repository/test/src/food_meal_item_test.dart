import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:food_repository/src/random_id.dart';

final _now = DateTime.utc(2026, 10, 15, 8);

FoodModel _food({
  String id = 'food-1',
  String name = 'Food',
  MeasurementMethod method = MeasurementMethod.weight,
  Map<NutrientKey, double> nutrients = const {
    NutrientKey.calories: 380,
    NutrientKey.protein: 13,
  },
  double? servingWeight,
  double? portionSize,
  String? portionName,
  double? portionWeight,
  double? weightPortionSize,
  String? weightPortionName,
  double? portionVolume,
  double? volumePortionSize,
  String? volumePortionName,
}) => FoodModel(
  ingredientId: id,
  name: name,
  measurementMethod: method,
  nutrients: NutrientMap(nutrients),
  servingWeight: servingWeight,
  portionSize: portionSize,
  portionName: portionName,
  portionWeight: portionWeight,
  weightPortionSize: weightPortionSize,
  weightPortionName: weightPortionName,
  portionVolume: portionVolume,
  volumePortionSize: volumePortionSize,
  volumePortionName: volumePortionName,
  dateCreated: _now,
  dateModified: _now,
);

/// Swift's `FoodModel.mockRolledOats`: 40 g is half a cup.
final FoodModel _oats = _food(
  name: 'Rolled Oats',
  portionWeight: 40,
  weightPortionSize: 0.5,
  weightPortionName: 'cup',
);

/// Swift's `FoodModel.mockOliveOil`: one tbsp is 14 ml.
final FoodModel _oliveOil = _food(
  name: 'Olive Oil',
  method: MeasurementMethod.volume,
  portionVolume: 14,
  volumePortionSize: 1,
  volumePortionName: 'tbsp',
);

final FoodModel _bread = _food(
  id: 'bread',
  name: 'Bread',
  nutrients: const {NutrientKey.calories: 250},
  servingWeight: 40,
  portionSize: 1,
  portionName: 'slice',
);

MealLogModel _meal(int daysAgo, List<MealItemModel> items) => MealLogModel(
  mealId: 'meal-$daysAgo',
  authorId: 'user-1',
  dayKey: 'day-$daysAgo',
  date: _now.subtract(Duration(days: daysAgo)),
  items: items,
);

void main() {
  // NutritionScalingTests, serving units.
  group('serving units', () {
    test("a food's units come from its declared portions", () {
      expect(_oats.servingUnits.single.name, 'cup');
      expect(_oats.servingUnits.single.grams, 80);
      expect(_oliveOil.servingUnits.single.name, 'tbsp');
      expect(_oliveOil.servingUnits.single.grams, 14);
      expect(_food().servingUnits, isEmpty);
    });

    test('a meal item in a serving unit resolves to grams', () {
      final item = _bread.mealItem(
        2,
        unit: const ServingUnit(name: 'slice', grams: 40),
      );

      expect(item.amount, 2);
      expect(item.unit, 'slice');
      expect(item.resolvedGrams, 80);
      expect(item.nutrients.values[NutrientKey.calories], 200);
    });
  });

  // AmountPresenterTests, the ingredient's pure parts.
  group('mealItem', () {
    test('scales from per 100 g', () {
      final item = _food().mealItem(50);

      expect(item.nutrients.values[NutrientKey.calories], 190);
      expect(item.nutrients.values[NutrientKey.protein], 6.5);
    });

    test("the unit follows the food's measurement", () {
      expect(_food().loggedUnitLabel, 'g');
      expect(_oliveOil.loggedUnitLabel, 'ml');
    });

    test('builds a scaled item of the food', () {
      final item = _food().mealItem(200, itemId: 'item-1');

      expect(item.itemId, 'item-1');
      expect(item.sourceType, MealItemSourceType.ingredient);
      expect(item.sourceId, 'food-1');
      expect(item.displayName, 'Food');
      expect(item.nutrients.values[NutrientKey.calories], 760);
      expect(item.amount, 200);
      expect(item.unit, 'g');
      expect(item.resolvedGrams, 200);
      expect(item.resolvedMilliliters, isNull);
    });

    test('a liquid resolves to millilitres', () {
      final item = _oliveOil.mealItem(2, unit: _oliveOil.servingUnits.single);

      expect(item.resolvedMilliliters, 28);
      expect(item.resolvedGrams, isNull);
      expect(item.unit, 'tbsp');
    });

    test('a negative amount scales to nothing', () {
      final item = _food().mealItem(-50);

      expect(item.amount, 0);
      expect(item.nutrients.values[NutrientKey.calories], 0);
    });

    test('a missing nutrient stays missing after scaling', () {
      final item = _food(nutrients: const {}).mealItem(100);

      expect(item.nutrients.values, isEmpty);
    });

    test('an amount that is not a number is logged as finite figures', () {
      for (final amount in [double.nan, double.infinity, -double.infinity]) {
        final item = _food().mealItem(amount);

        expect(item.amount, 0);
        expect(item.resolvedGrams, 0);
        expect(item.nutrients.values.values.every((v) => v.isFinite), isTrue);
      }
    });

    test('a new item gets a new UUID', () {
      final first = _food().mealItem(1).itemId;

      expect(first, hasLength(36));
      expect(_food().mealItem(1).itemId, isNot(first));
    });
  });

  group('portions', () {
    test('the portion helpers read the fields Swift reads', () {
      final food = _food(
        servingWeight: 30,
        portionWeight: 40,
        weightPortionSize: 2,
        weightPortionName: 'scoop',
        portionName: '',
        portionVolume: 250,
        volumePortionSize: 3,
      );

      expect(food.portionGrams, 30);
      expect(food.portionMilliliters, 250);
      expect(food.portionQuantity, 2);
      expect(food.portionNameShown, 'scoop');
      expect(_food(portionWeight: 40).portionGrams, 40);
      expect(_food(volumePortionSize: 3).portionQuantity, 3);
      expect(_food().portionNameShown, isNull);
    });

    test('the default amount is the declared portion, else 100', () {
      expect(_bread.defaultPortionAmount, 40);
      expect(_oliveOil.defaultPortionAmount, 14);
      expect(_food().defaultPortionAmount, 100);
      expect(_food(servingWeight: 0).defaultPortionAmount, 100);
      expect(_food(servingWeight: double.nan).defaultPortionAmount, 100);
    });

    test('the default portion is the named unit, else grams', () {
      final bread = _bread.defaultPortion;
      expect(bread.amount, 1);
      expect(bread.unit?.name, 'slice');

      final oats = _oats.defaultPortion;
      expect(oats.amount, 0.5);
      expect(oats.unit?.grams, 80);

      // A named portion with no weight offers no unit.
      final named = _food(portionSize: 0.5, portionName: 'cup').defaultPortion;
      expect(named.amount, 100);
      expect(named.unit, isNull);
    });

    test('a named unit with no count is one of it', () {
      final food = _food(servingWeight: 30, portionName: 'bar');

      expect(food.defaultPortion.amount, 1);
    });

    // FoodPickerRowDetailTests: olive oil's row reads per tbsp, not 100 g.
    test("a row's figures scale to the default portion", () {
      final oil = _food(
        servingWeight: 13.5,
        portionSize: 1,
        portionName: 'tbsp',
      );

      expect(oil.rowNutrientScale, 0.135);
      expect(_food().rowNutrientScale, 1);
    });
  });

  // FoodQuickAddItemTests.
  group('quickAddItem', () {
    test('repeats the last logged amount, in its unit', () {
      final slice = _bread.servingUnits.single;
      final meals = [
        _meal(5, [_bread.mealItem(80)]),
        _meal(0, [_bread.mealItem(3, unit: slice)]),
        _meal(2, [_food(id: 'other').mealItem(10)]),
      ];

      final item = _bread.quickAddItem(meals, itemId: 'again');

      expect(item.itemId, 'again');
      expect(item.amount, 3);
      expect(item.unit, 'slice');
      expect(item.resolvedGrams, 120);
    });

    test('takes the last such item in the latest meal', () {
      final meals = [
        _meal(1, [_bread.mealItem(50), _bread.mealItem(70)]),
        _meal(1, [_bread.mealItem(90)]),
      ];

      expect(_bread.quickAddItem(meals).amount, 70);
    });

    test('a unit no longer offered goes on in grams', () {
      final logged = _meal(0, [
        _bread.mealItem(2, unit: const ServingUnit(name: 'loaf', grams: 800)),
      ]);

      final item = _bread.quickAddItem([logged]);

      expect(item.amount, 2);
      expect(item.unit, 'g');
    });

    test('a never-logged food uses its named portion', () {
      final item = _bread.quickAddItem(const []);

      expect(item.amount, 1);
      expect(item.unit, 'slice');
      expect(item.resolvedGrams, 40);
    });

    test('falls back to the default portion', () {
      final oats = _food(
        id: 'oats',
        nutrients: const {NutrientKey.calories: 380},
      );
      final other = _food(id: 'milk').mealItem(250);
      const recipe = MealItemModel(
        itemId: 'r',
        sourceType: MealItemSourceType.recipe,
        sourceId: 'oats',
        displayName: 'Oats recipe',
        amount: 1,
        unit: 'serving',
      );

      final item = oats.quickAddItem([
        _meal(0, [other, recipe]),
      ]);

      expect(item.amount, oats.defaultPortionAmount);
      expect(item.unit, 'g');
    });
  });

  test('randomUuid is a version 4 UUID in upper case', () {
    final id = randomUuid(Random(1));

    expect(
      id,
      matches(
        RegExp(r'^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB]\w{3}-\w{12}$'),
      ),
    );
    expect(randomUuid(Random(1)), id);
  });
}
