import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The repository's writes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy).
void main() {
  group('FirestoreFoodRepository offline', () {
    late OfflineFirestore firestore;
    late List<(String, String)> refused;
    late FirestoreFoodRepository subject;

    // FieldValue sentinels bind to whichever FieldValue factory is

    // installed when first used; fake_cloud_firestore installs its own

    // only when a fake is built. Build one first, or when this file runs

    // before the Firestore tests in one isolate (very_good test's

    // optimisation) they get the method-channel factory.

    setUpAll(FakeFirebaseFirestore.new);

    setUp(() {
      firestore = OfflineFirestore();
      refused = [];
      subject = FirestoreFoodRepository(
        firestore: firestore,
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
      );
    });

    test('saveFood complete offline; a refusal is reported', () async {
      final food = FoodModel.fromFirestore(modelFixture('food_model', 'full'));
      await subject.saveFood(food);
      expect(firestore.writes, [
        'users/${food.authorId}/foods/${food.ingredientId}',
      ]);
      expect(refused, isEmpty);

      firestore.refuse('permission-denied');
      await pumpEventQueue();

      expect(refused, [
        for (final path in [
          'users/${food.authorId}/foods/${food.ingredientId}',
        ])
          (path, 'permission-denied'),
      ]);
    });

    test('saveRecipe completes offline; a refusal is reported', () async {
      final recipe = RecipeTemplateModel.fromFirestore(
        modelFixture('recipe_template', 'full'),
      );
      final path =
          'users/${recipe.authorId}/recipe_templates/${recipe.recipeId}';
      await subject.saveRecipe(recipe);
      expect(firestore.writes, [path]);

      firestore.refuse('permission-denied');
      await pumpEventQueue();

      expect(refused, [(path, 'permission-denied')]);
    });

    test('deleteRecipe completes offline; a refusal is reported', () async {
      await subject.deleteRecipe('u', 'r');
      expect(firestore.writes, ['users/u/recipe_templates/r']);

      firestore.refuse('not-found');
      await pumpEventQueue();

      expect(refused, [('users/u/recipe_templates/r', 'not-found')]);
    });

    test('deleteFood completes offline; a refusal is reported', () async {
      await subject.deleteFood('u', 'f');
      expect(firestore.writes, ['users/u/foods/f']);

      firestore.refuse('not-found');
      await pumpEventQueue();

      expect(refused, [('users/u/foods/f', 'not-found')]);
    });
  });
}
