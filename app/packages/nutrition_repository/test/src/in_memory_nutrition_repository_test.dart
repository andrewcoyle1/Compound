import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

void main() {
  group(InMemoryNutritionRepository, () {
    MealLogModel meal(String id, String authorId, String dayKey) =>
        MealLogModel(
          mealId: id,
          authorId: authorId,
          dayKey: dayKey,
          date: DateTime.utc(2026, 10, 12),
          items: const [],
        );
    final plan = DietPlan(
      planId: 'me',
      userId: 'me',
      createdAt: DateTime.utc(2026, 10),
      tdeeEstimate: 2500,
      preferredDiet: 'balanced',
      calorieFloor: 'standard',
      trainingType: 'moderate',
      calorieDistribution: 'even',
      proteinIntake: 'high',
      days: const [],
    );
    const settings = FoodLogSettings(authorId: 'me', startHour: 5);

    late InMemoryNutritionRepository subject;

    setUp(() {
      subject = InMemoryNutritionRepository(
        meals: [
          meal('a', 'me', '2026-10-12'),
          meal('b', 'you', '2026-10-12'),
          meal(MealLogModel.healthKitMealId('2026-10-12'), 'me', '2026-10-12'),
          meal(MealLogModel.healthKitMealId('2026-10-11'), 'me', '2026-10-11'),
        ],
        dietPlan: plan,
        foodLogSettings: settings,
      );
    });

    test("watchMeals emits the user's meals, Apple Health rule applied", () {
      expect(
        subject
            .watchMeals('me')
            .map((meals) => [for (final m in meals) m.mealId]),
        emits(['a', 'healthkit-nutrition-2026-10-11']),
      );
    });

    group('watchDietPlan', () {
      test("emits the user's plan", () {
        expect(subject.watchDietPlan('me'), emits(plan));
      });

      test('emits null for another user, or with no plan', () {
        expect(subject.watchDietPlan('you'), emits(isNull));
        expect(
          InMemoryNutritionRepository().watchDietPlan('me'),
          emits(isNull),
        );
      });
    });

    group('watchFoodLogSettings', () {
      test("emits the user's settings", () {
        expect(subject.watchFoodLogSettings('me'), emits(settings));
      });

      test("emits Swift's defaults for another user, or with none", () {
        expect(
          subject.watchFoodLogSettings('you').map((s) => s.toFirestore()),
          emits(const FoodLogSettings(authorId: 'you').toFirestore()),
        );
        expect(
          InMemoryNutritionRepository()
              .watchFoodLogSettings('me')
              .map((s) => (s.authorId, s.startHour)),
          emits(('me', 7)),
        );
      });
    });
  });
}
