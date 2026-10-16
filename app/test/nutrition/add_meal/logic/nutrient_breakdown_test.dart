import 'package:compound/nutrition/add_meal/logic/nutrient_breakdown.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show NutritionScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Swift `AddMealPresenterTests`' nutrient breakdown cases, case for case.
void main() {
  MealLogModel meal(String id, Map<NutrientKey, double> nutrients) =>
      MealLogModel(
        mealId: id,
        authorId: 'me',
        dayKey: '2026-03-14',
        date: DateTime(2026, 3, 14, 12),
        items: [
          MealItemModel(
            itemId: '$id-item',
            sourceType: MealItemSourceType.quickAdd,
            sourceId: 'quick_add',
            displayName: 'Food',
            amount: 1,
            unit: 'serving',
            nutrients: NutrientMap(nutrients),
          ),
        ],
      );

  test('unrecorded nutrients are left out', () {
    final plate = meal('p', {
      NutrientKey.calories: 400,
      NutrientKey.ironMg: 2.5,
    });
    final nutrients = scopedNutrients(plate, const [], NutritionScope.plate);
    expect(breakdown(nutrients, NutrientCategory.minerals), [
      (NutrientKey.ironMg, 2.5),
    ]);
  });

  test('a category with nothing recorded is empty', () {
    final plate = meal('p', {NutrientKey.ironMg: 2.5});
    final nutrients = scopedNutrients(plate, const [], NutritionScope.plate);
    expect(breakdown(nutrients, NutrientCategory.vitamins), isEmpty);
  });

  test("day scope adds the other meals' micronutrients", () {
    final plate = meal('p', {NutrientKey.ironMg: 2});
    final earlier = meal('e', {NutrientKey.ironMg: 3});
    final nutrients = scopedNutrients(plate, [earlier], NutritionScope.day);
    expect(nutrients[NutrientKey.ironMg], 5);
    expect(
      scopedNutrients(plate, [
        earlier,
      ], NutritionScope.plate)[NutrientKey.ironMg],
      2,
    );
  });

  test('the plate is not counted twice at day scope', () {
    final plate = meal('p', {NutrientKey.ironMg: 2});
    final nutrients = scopedNutrients(plate, [plate], NutritionScope.day);
    expect(nutrients[NutrientKey.ironMg], 2);
  });

  test('calories are printed whole', () {
    expect(
      formatNutrient(NutrientKey.calories, 499.6, locale: 'en'),
      '500 kcal',
    );
  });

  test('small amounts keep a decimal', () {
    expect(
      formatNutrient(NutrientKey.ironMg, 3.7, locale: 'en'),
      startsWith('3.7'),
    );
  });

  test('large amounts drop the decimal', () {
    expect(
      formatNutrient(NutrientKey.protein, 24.6, locale: 'en'),
      startsWith('25'),
    );
  });

  test('every nutrient but calories has a category, totals first', () {
    expect(nutrientCategory(NutrientKey.calories), isNull);
    for (final key in NutrientKey.values.skip(1)) {
      expect(nutrientCategory(key), isNotNull, reason: key.value);
    }
    final all = {for (final key in NutrientKey.values) key: 1.0};
    expect(
      breakdown(all, NutrientCategory.protein).first.$1,
      NutrientKey.protein,
    );
    expect(breakdown(all, NutrientCategory.fat).first.$1, NutrientKey.fatTotal);
    expect(breakdown(all, NutrientCategory.carbs).first.$1, NutrientKey.carbs);
    expect(
      breakdown(all, NutrientCategory.vitamins).map((e) => e.$1),
      contains(NutrientKey.biotinMcg),
    );
    expect(breakdown(all, NutrientCategory.other).map((e) => e.$1), [
      NutrientKey.caffeineMg,
      NutrientKey.cholesterolMg,
      NutrientKey.alcohol,
      NutrientKey.water,
    ]);
  });
}
