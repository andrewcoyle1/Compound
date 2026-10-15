import 'dart:async';

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

    group('saveMeal', () {
      test('adds a meal, and watchers see it', () async {
        final expectation = expectLater(
          subject
              .watchMeals('me')
              .map((meals) => [for (final m in meals) m.mealId]),
          emitsInOrder([
            ['a', 'healthkit-nutrition-2026-10-11'],
            ['a', 'healthkit-nutrition-2026-10-11', 'c'],
          ]),
        );

        await subject.saveMeal(meal('c', 'me', '2026-10-13'));

        await expectation;
      });

      test('merges over the stored meal, as Firestore', () async {
        await subject.saveMeal(
          MealLogModel(
            mealId: 'a',
            authorId: 'me',
            dayKey: '2026-10-12',
            date: DateTime.utc(2026, 10, 12),
            items: const [],
            notes: 'Lunch',
          ),
        );

        final meals = await subject.watchMeals('me').first;
        expect(
          [for (final m in meals) (m.mealId, m.notes)],
          [('a', 'Lunch'), ('healthkit-nutrition-2026-10-11', null)],
        );
      });

      test("leaves another user's meal with the same id alone", () async {
        await subject.saveMeal(meal('b', 'me', '2026-10-13'));

        expect(
          (await subject.watchMeals('you').first).single.dayKey,
          '2026-10-12',
        );
      });
    });

    group('saveDietPlan', () {
      test('stores a plan under its id, and watchers see it', () async {
        final repository = InMemoryNutritionRepository();
        final expectation = expectLater(
          repository.watchDietPlan('me').map((plan) => plan?.toFirestore()),
          emitsInOrder([isNull, plan.toFirestore()]),
        );

        await repository.saveDietPlan(plan);

        await expectation;
      });

      test('merges over the stored plan, as Firestore', () async {
        final edited = DietPlan(
          planId: 'me',
          createdAt: DateTime.utc(2026, 10, 2),
          tdeeEstimate: 2400.5,
          preferredDiet: 'keto',
          calorieFloor: 'standard',
          trainingType: 'moderate',
          calorieDistribution: 'even',
          proteinIntake: 'high',
          days: const [],
        );

        await subject.saveDietPlan(edited);

        final saved = await subject.watchDietPlan('me').first;
        expect(saved!.toFirestore(), {...edited.toFirestore(), 'userId': 'me'});
      });
    });
  });

  testWidgets("a watcher's first value arrives under a fake clock", (
    tester,
  ) async {
    // A bloc awaits `.first`; it must not wait on anything outside the
    // widget test's zone.
    var arrived = false;
    unawaited(
      InMemoryNutritionRepository()
          .watchMeals('x')
          .first
          .then((_) => arrived = true),
    );
    await tester.pump();
    expect(arrived, isTrue);
  });
}
