import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

void main() {
  group('sampleMealLogs', () {
    final now = DateTime(2026, 10, 14, 13);
    late List<MealLogModel> meals;

    setUp(() => meals = sampleMealLogs(uid: 'me', now: now));

    test("is a week of the user's meals, none after now", () {
      final days = mealsByDay(meals);
      expect(days.keys, [
        for (var daysAgo = 6; daysAgo >= 0; daysAgo--)
          _dayKey(now.subtract(Duration(days: daysAgo))),
      ]);
      for (final meal in meals) {
        expect(meal.authorId, 'me');
        expect(meal.date.isAfter(now), isFalse);
        expect(meal.dayKey, _dayKey(meal.date));
      }
      // Today: breakfast and lunch, not yet the snack or dinner.
      expect(days['2026-10-14'], hasLength(2));
    });

    test('are documents the Swift app can read', () {
      for (final meal in meals) {
        expect(
          MealLogModel.fromFirestore(meal.toFirestore()).toFirestore(),
          equals(meal.toFirestore()),
        );
      }
    });

    test('show the Apple Health rule both ways', () {
      final counted = mealsByDay(withoutDuplicateHealthImports(meals));
      final sixDaysAgo = counted['2026-10-08']!;
      expect(sixDaysAgo.single.isHealthKitImport, isTrue);
      expect(meals.where((m) => m.isHealthKitImport), hasLength(2));
      expect(counted['2026-10-12']!.where((m) => m.isHealthKitImport), isEmpty);
      expect(counted['2026-10-12'], hasLength(4));
    });

    test('cover every source type and realistic totals', () {
      final items = [for (final meal in meals) ...meal.items];
      expect(
        items.map((item) => item.sourceType).toSet(),
        MealItemSourceType.values.toSet(),
      );
      expect(meals.where((m) => m.notes != null), isNotEmpty);
      final logged = withoutDuplicateHealthImports(meals)
          .where((m) => !m.isHealthKitImport);
      for (final MapEntry(key: day, value: dayMeals) in mealsByDay(
        logged,
      ).entries) {
        if (day == '2026-10-14') continue;
        final kcal = [
          for (final meal in dayMeals)
            for (final item in meal.items)
              item.nutrients.values[NutrientKey.calories]!,
        ].reduce((a, b) => a + b);
        expect(kcal, inInclusiveRange(1700, 2900), reason: day);
      }
    });
  });

  test('sampleMealHistory is about two months before the sample week', () {
    final now = DateTime(2026, 10, 14, 13);
    final meals = sampleMealHistory(uid: 'me', now: now);
    final days = mealsByDay(meals);
    final week = {
      for (var daysAgo = 0; daysAgo < 7; daysAgo++)
        _dayKey(now.subtract(Duration(days: daysAgo))),
    };
    expect(days.keys.toSet().intersection(week), isEmpty);
    expect(days.length, inInclusiveRange(48, 56));
    for (final MapEntry(key: day, value: dayMeals) in days.entries) {
      expect(dayMeals, hasLength(3));
      final kcal = [
        for (final meal in dayMeals)
          for (final item in meal.items)
            item.nutrients.values[NutrientKey.calories]!,
      ].reduce((a, b) => a + b);
      expect(kcal, inInclusiveRange(2100, 2500), reason: day);
    }
    for (final meal in meals) {
      expect(meal.authorId, 'me');
      expect(meal.dayKey, _dayKey(meal.date));
      expect(
        MealLogModel.fromFirestore(meal.toFirestore()).toFirestore(),
        equals(meal.toFirestore()),
      );
    }
  });

  test('sampleDietPlan is seven days of targets, Monday first', () {
    final now = DateTime(2026, 10, 14);
    final plan = sampleDietPlan(uid: 'me', now: now);
    expect(plan.planId, 'me');
    expect(plan.userId, 'me');
    expect(plan.days, hasLength(7));
    expect(plan.days.first.calories, greaterThan(plan.days[2].calories));
    for (final day in plan.days) {
      final kcal = day.proteinGrams * 4 + day.carbGrams * 4 + day.fatGrams * 9;
      expect(kcal, closeTo(day.calories, 1e-9));
    }
    expect(
      DietPlan.fromFirestore(plan.toFirestore()).toFirestore(),
      equals(plan.toFirestore()),
    );
  });
}

String _dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
