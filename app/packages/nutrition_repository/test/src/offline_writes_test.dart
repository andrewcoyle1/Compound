import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The repository's writes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy).
void main() {
  group('FirestoreNutritionRepository offline', () {
    late OfflineFirestore firestore;
    late List<(String, String)> refused;
    late FirestoreNutritionRepository subject;

    // FieldValue sentinels bind to whichever FieldValue factory is

    // installed when first used; fake_cloud_firestore installs its own

    // only when a fake is built. Build one first, or when this file runs

    // before the Firestore tests in one isolate (very_good test's

    // optimisation) they get the method-channel factory.

    setUpAll(FakeFirebaseFirestore.new);


    setUp(() {
      firestore = OfflineFirestore();
      refused = [];
      subject = FirestoreNutritionRepository(
        firestore: firestore,
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
      );
    });

    test(
      'saveMeal and saveDietPlan complete offline; a refusal is reported',
      () async {
        final meal = MealLogModel.fromFirestore(
          modelFixture('meal_log', 'full'),
        );
        final plan = DietPlan.fromFirestore(modelFixture('diet_plan', 'full'));
        await subject.saveMeal(meal);
        await subject.saveDietPlan(plan);
        expect(firestore.writes, [
          'users/${meal.authorId}/meal_logs/${meal.mealId}',
          'diet_plans/${plan.planId}',
        ]);
        expect(refused, isEmpty);

        firestore.refuse('permission-denied');
        await pumpEventQueue();

        expect(refused, [
          for (final path in [
            'users/${meal.authorId}/meal_logs/${meal.mealId}',
            'diet_plans/${plan.planId}',
          ])
            (path, 'permission-denied'),
        ]);
      },
    );

    test('deleteMeal completes offline; a refusal is reported', () async {
      await subject.deleteMeal('u', 'm');
      expect(firestore.writes, ['users/u/meal_logs/m']);

      firestore.refuse('permission-denied');
      await pumpEventQueue();

      expect(refused, [('users/u/meal_logs/m', 'permission-denied')]);
    });
  });
}
