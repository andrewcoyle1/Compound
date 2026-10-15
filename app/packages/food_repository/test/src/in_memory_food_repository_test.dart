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
}
