import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

Map<String, Object?> _fixture(String model, String name) =>
    taggedJsonToFirestore(
      jsonDecode(
        File('../../../contracts/firestore/$model/$name.json')
            .readAsStringSync(),
      ) as Map<String, Object?>,
    );

void main() {
  group('NutrientMap', () {
    test('rejects a value that is not a number, whatever its key', () {
      expect(
        () => NutrientMap.fromFirestore({'calories': '250'}),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => NutrientMap.fromFirestore({'vitamin_z': null}),
        throwsA(isA<TypeError>()),
      );
    });

    test('reads an integer as a double', () {
      final map = NutrientMap.fromFirestore({'calories': 250});
      expect(map.values[NutrientKey.calories], isA<double>());
      expect(map.toFirestore(), {'calories': 250.0});
    });

    test('never writes a NaN or infinity built in Dart', () {
      expect(
        const NutrientMap({
          NutrientKey.calories: double.nan,
          NutrientKey.protein: double.infinity,
          NutrientKey.carbs: 12.5,
        }).toFirestore(),
        {'carbs': 12.5},
      );
    });
  });

  group('MealItemModel', () {
    test('requires a string source type, as Swift does', () {
      final item = _fixture('meal_item', 'minimal')..['sourceType'] = 3;
      expect(
        () => MealItemModel.fromFirestore(item),
        throwsA(isA<TypeError>()),
      );
    });

    test('requires nutrients, as Swift does', () {
      final item = _fixture('meal_item', 'minimal')..remove('nutrients');
      expect(
        () => MealItemModel.fromFirestore(item),
        throwsA(isA<TypeError>()),
      );
    });

    test('defaults to no nutrients when built in Dart', () {
      const item = MealItemModel(
        itemId: 'i',
        sourceType: MealItemSourceType.quickAdd,
        sourceId: 's',
        displayName: 'd',
        amount: 1,
        unit: 'g',
      );
      expect(item.nutrients.values, isEmpty);
    });
  });

  group('MealLogModel', () {
    MealLogModel meal(String id, String dayKey) => MealLogModel(
      mealId: id,
      authorId: 'u',
      dayKey: dayKey,
      date: DateTime.utc(2026, 10, 12),
      items: const [],
    );

    test("is a HealthKit import only under its day's derived id", () {
      expect(
        MealLogModel.healthKitMealId('2026-10-12'),
        'healthkit-nutrition-2026-10-12',
      );
      expect(
        meal('healthkit-nutrition-2026-10-12', '2026-10-12').isHealthKitImport,
        isTrue,
      );
      expect(
        meal('healthkit-nutrition-2026-10-11', '2026-10-12').isHealthKitImport,
        isFalse,
      );
      expect(meal('m1', '2026-10-12').isHealthKitImport, isFalse);
    });

    test('rejects a meal with no date', () {
      final data = _fixture('meal_log', 'minimal')..remove('date');
      expect(() => MealLogModel.fromFirestore(data), throwsA(isA<TypeError>()));
    });
  });

  group('DietPlan', () {
    test('reads whole-number targets written as integers', () {
      final data = _fixture('diet_plan', 'full')
        ..['tdeeEstimate'] = 2500
        ..['days'] = [
          {
            'calories': 2000,
            'proteinGrams': 150,
            'carbGrams': 200,
            'fatGrams': 70,
          },
        ];
      final plan = DietPlan.fromFirestore(data);
      expect(plan.tdeeEstimate, 2500.0);
      expect(plan.days.single.calories, isA<double>());
    });
  });

  group('FoodLogSettings', () {
    test("defaults are Swift's, as the minimal fixture records them", () {
      final minimal = _fixture('food_log_settings', 'minimal');
      expect(
        FoodLogSettings(authorId: minimal['author_id']! as String)
            .toFirestore(),
        minimal,
      );
    });

    test('requires every field, as Swift does', () {
      for (final key in FoodLogSettingsKeys.all) {
        final data = _fixture('food_log_settings', 'full')..remove(key);
        expect(
          () => FoodLogSettings.fromFirestore(data),
          throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
          reason: key,
        );
      }
    });

    test('rejects a timestamp side Swift does not know', () {
      final data = _fixture('food_log_settings', 'full')
        ..['timestamp_side'] = 'middle';
      expect(() => FoodLogSettings.fromFirestore(data), throwsFormatException);
    });
  });
}
