import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';

void main() {
  group(InMemoryFoodRepository, () {
    final now = DateTime.utc(2026, 10, 15, 8);
    FoodModel food(String id, {String? authorId = 'alice', String? name}) =>
        FoodModel(
          ingredientId: id,
          authorId: authorId,
          name: name ?? id,
          nutrients: const NutrientMap({
            NutrientKey.calories: 100.5,
            NutrientKey.protein: 10.5,
          }),
          dateCreated: now,
          dateModified: now,
        );

    test("serves each user's own seeded foods", () async {
      final subject = InMemoryFoodRepository(
        foods: [
          food('a'),
          food('b', authorId: 'bob'),
        ],
      );

      expect(
        (await subject.watchFoods('alice').first).map((f) => f.ingredientId),
        ['a'],
      );
      expect(
        (await subject.watchFoods('bob').first).map((f) => f.ingredientId),
        ['b'],
      );
    });

    test('refuses to hold a food with no author', () {
      expect(
        () => InMemoryFoodRepository(foods: [food('a', authorId: null)]),
        throwsArgumentError,
      );
      expect(
        () => InMemoryFoodRepository().saveFood(food('a', authorId: '')),
        throwsArgumentError,
      );
      expect(
        () => InMemoryFoodRepository().saveFood(food('')),
        throwsArgumentError,
      );
    });

    test('saves a new food and every watcher sees it', () async {
      final subject = InMemoryFoodRepository();
      final emissions = subject.watchFoods('alice').take(2).toList();

      await subject.saveFood(food('a'));

      final [before, after] = await emissions;
      expect(before, isEmpty);
      expect(after.single.toFirestore(), food('a').toFirestore());
    });

    test('merges as Firestore does, nutrients key by key', () async {
      final subject = InMemoryFoodRepository(foods: [food('a')]);

      await subject.saveFood(
        FoodModel(
          ingredientId: 'a',
          authorId: 'alice',
          name: 'Renamed',
          barcode: '123',
          nutrients: const NutrientMap({NutrientKey.calories: 42.5}),
          dateCreated: now,
          dateModified: now,
        ),
      );

      final saved = (await subject.watchFoods('alice').first).single;
      expect(saved.name, 'Renamed');
      expect(saved.barcode, '123');
      expect(saved.nutrients.values, {
        NutrientKey.calories: 42.5,
        NutrientKey.protein: 10.5,
      });
    });
  });

  group('deleteFood', () {
    final now = DateTime.utc(2026, 10, 15, 8);
    FoodModel food(String id, String authorId) => FoodModel(
      ingredientId: id,
      authorId: authorId,
      name: id,
      dateCreated: now,
      dateModified: now,
    );

    test("removes only that user's food, and watchers see it", () async {
      final subject = InMemoryFoodRepository(
        foods: [food('a', 'alice'), food('b', 'alice'), food('a', 'bob')],
      );
      final emissions = subject.watchFoods('alice').take(2).toList();

      await subject.deleteFood('alice', 'a');

      final [before, after] = await emissions;
      expect(before.map((f) => f.ingredientId), ['a', 'b']);
      expect(after.map((f) => f.ingredientId), ['b']);
      expect((await subject.watchFoods('bob').first).single.ingredientId, 'a');
    });

    test('a food that is not there is not an error', () async {
      final subject = InMemoryFoodRepository();
      await expectLater(subject.deleteFood('alice', 'missing'), completes);
    });
  });

  group('sampleFoods', () {
    final now = DateTime.utc(2026, 10, 15, 8);
    final foods = sampleFoods(uid: 'mock_user_123', now: now);

    test('are a dozen foods owned by the user, each round-tripping', () {
      expect(foods, hasLength(12));
      expect(foods.map((f) => f.ingredientId).toSet(), hasLength(12));
      for (final food in foods) {
        expect(food.authorId, 'mock_user_123');
        expect(food.ingredientId, startsWith('sample-food-'));
        expect(food.nutrients.values, hasLength(7));
        expect(
          FoodModel.fromFirestore(food.toFirestore()).toFirestore(),
          food.toFirestore(),
        );
      }
    });

    test("use the staging meals' ids and offer their portions", () {
      final byName = {for (final food in foods) food.name: food};

      expect(byName['Rolled Oats']!.ingredientId, 'sample-food-rolled-oats');
      expect(byName['Rolled Oats']!.barcode, '5000000000011');
      expect(byName['Rolled Oats']!.servingUnits.single.grams, 80);
      expect(byName['Semi-Skimmed Milk']!.loggedUnitLabel, 'ml');
      expect(byName['Semi-Skimmed Milk']!.servingUnits.single.name, 'glass');
      expect(byName['Broccoli']!.servingUnits, isEmpty);
    });

    test('can seed the in-memory repository', () async {
      final subject = InMemoryFoodRepository(foods: foods);

      expect(await subject.watchFoods('mock_user_123').first, hasLength(12));
    });
  });

  group('recipes', () {
    final now = DateTime.utc(2026, 10, 15, 8);
    RecipeTemplateModel recipe(
      String id, {
      String? authorId = 'alice',
      String name = 'Chilli',
      String? description,
    }) => RecipeTemplateModel(
      recipeId: id,
      authorId: authorId,
      name: name,
      description: description,
      dateCreated: now,
      dateModified: now,
    );

    test("serves each user's own seeded recipes", () async {
      final subject = InMemoryFoodRepository(
        recipes: [
          recipe('a'),
          recipe('b', authorId: 'bob'),
        ],
      );

      expect(
        (await subject.watchRecipes('alice').first).map((r) => r.recipeId),
        ['a'],
      );
      expect((await subject.watchRecipes('bob').first).map((r) => r.recipeId), [
        'b',
      ]);
    });

    test('refuses a recipe with no author or no id', () {
      expect(
        () => InMemoryFoodRepository(recipes: [recipe('a', authorId: null)]),
        throwsArgumentError,
      );
      expect(
        () => InMemoryFoodRepository().saveRecipe(recipe('a', authorId: '')),
        throwsArgumentError,
      );
      expect(
        () => InMemoryFoodRepository().saveRecipe(recipe('')),
        throwsArgumentError,
      );
    });

    test('saves, merging over what is stored, and watchers see it', () async {
      final subject = InMemoryFoodRepository(
        recipes: [recipe('a', description: 'Hot')],
      );
      final emissions = subject.watchRecipes('alice').take(2).toList();

      await subject.saveRecipe(recipe('a', name: 'Renamed'));

      final [before, after] = await emissions;
      expect(before.single.name, 'Chilli');
      expect(after.single.name, 'Renamed');
      expect(after.single.description, 'Hot');
    });

    test(
      "deletes only that user's recipe; a missing one is no error",
      () async {
        final subject = InMemoryFoodRepository(
          recipes: [
            recipe('a'),
            recipe('b'),
            recipe('a', authorId: 'bob'),
          ],
        );

        await subject.deleteRecipe('alice', 'a');
        await subject.deleteRecipe('alice', 'missing');

        expect(
          (await subject.watchRecipes('alice').first).map((r) => r.recipeId),
          ['b'],
        );
        expect(await subject.watchRecipes('bob').first, hasLength(1));
      },
    );
  });

  group('sampleRecipes', () {
    final now = DateTime.utc(2026, 10, 15, 8);
    final foods = sampleFoods(uid: 'mock_user_123', now: now);
    final recipes = sampleRecipes(uid: 'mock_user_123', now: now, foods: foods);

    test('are three recipes from the sample foods, each round-tripping', () {
      expect(recipes.map((r) => r.name), [
        'Overnight Oats',
        'Chicken Rice Bowl',
        'Salmon Avocado Toast',
      ]);
      for (final recipe in recipes) {
        expect(recipe.authorId, 'mock_user_123');
        expect(recipe.recipeId, startsWith('sample-recipe-'));
        expect(recipe.ingredients, isNotEmpty);
        expect(recipe.perServing.values[NutrientKey.calories], greaterThan(0));
        expect(
          RecipeTemplateModel.fromFirestore(recipe.toFirestore()).toFirestore(),
          recipe.toFirestore(),
        );
      }
    });

    test('can seed the in-memory repository', () async {
      final subject = InMemoryFoodRepository(recipes: recipes);

      expect(await subject.watchRecipes('mock_user_123').first, hasLength(3));
    });
  });
}
