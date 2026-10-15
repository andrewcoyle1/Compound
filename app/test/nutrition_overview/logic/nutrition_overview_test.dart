import 'package:compound/nutrition_overview/logic/nutrition_overview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

MealItemModel _item(String id, String name, Map<NutrientKey, double> values) =>
    MealItemModel(
      itemId: id,
      sourceType: MealItemSourceType.quickAdd,
      sourceId: 'quick_add',
      displayName: name,
      amount: 1,
      unit: 'serving',
      nutrients: NutrientMap(values),
    );

MealLogModel _meal(List<MealItemModel> items) => MealLogModel(
  mealId: 'm',
  authorId: 'me',
  dayKey: '2026-10-15',
  date: DateTime(2026, 10, 15, 12),
  items: items,
);

void main() {
  group('nutrientBreakdown', () {
    test('adds each nutrient above zero, and works out net carbs', () {
      final breakdown = nutrientBreakdown([
        _meal([
          _item('a', 'Oats', {
            NutrientKey.carbs: 50,
            NutrientKey.fiber: 8,
            NutrientKey.sodiumMg: 0,
            NutrientKey.vitaminB12Mcg: 0.4,
          }),
          _item('b', 'Milk', {NutrientKey.carbs: 12, NutrientKey.fiber: 2}),
        ]),
      ]);
      expect(breakdown, {
        NutrientLine.fiber: 10,
        NutrientLine.netCarbs: 52,
        NutrientLine.vitaminB12: 0.4,
      });
    });

    test('has no net carbs without fibre, and never below zero', () {
      expect(
        nutrientBreakdown([
          _meal([
            _item('a', 'Sugar', {NutrientKey.carbs: 10}),
          ]),
        ]),
        isEmpty,
      );
      expect(
        nutrientBreakdown([
          _meal([
            _item('a', 'Bran', {NutrientKey.fiber: 10}),
          ]),
        ])[NutrientLine.netCarbs],
        0,
      );
    });

    test('every line has a section and a unit', () {
      for (final line in NutrientLine.values) {
        expect(line.unit, isIn(['g', 'mg', 'mcg']));
        expect(line.key == null, line == NutrientLine.netCarbs);
      }
    });
  });

  test('contributors adds foods up by name, most calories first', () {
    final top = contributors([
      _meal([
        _item('a', 'Rice', {NutrientKey.calories: 200, NutrientKey.carbs: 44}),
        _item('b', 'Chicken', {
          NutrientKey.calories: 300,
          NutrientKey.protein: 50,
        }),
        _item('c', 'Rice', {NutrientKey.calories: 150, NutrientKey.carbs: 33}),
      ]),
    ]);
    expect([for (final food in top) food.name], ['Rice', 'Chicken']);
    expect(top.first.macros.calories, 350);
    expect(top.first.macros.carbGrams, 77);
  });
}
