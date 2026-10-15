import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';

class _FailingFoods implements FoodRepository {
  @override
  Future<void> saveFood(FoodModel food) async => throw StateError('offline');

  @override
  Stream<List<FoodModel>> watchFoods(String uid) => const Stream.empty();
}

void main() {
  final now = DateTime.utc(2026, 10, 15, 8);
  final openFoodFacts = FakeOpenFoodFacts(now: () => now);

  group(FakeOpenFoodFacts, () {
    test('finds products by any word of the name or brand', () async {
      Future<List<String>> names(String query) async => [
        for (final food in await openFoodFacts.searchFoods(query)) food.name,
      ];

      expect(await names('weetabix'), ['Weetabix Original']);
      expect(await names('  BREAD   orchard '), [
        'Wholemeal Bread',
        'Apple Juice',
      ]);
      expect(await names('   '), isEmpty);
      expect(await names('caviar'), isEmpty);
    });

    test('looks up its barcodes, mapped like the real lookup', () async {
      final food = await openFoodFacts.lookupBarcode('2000000000039');

      expect(food.ingredientId, 'off-2000000000039');
      expect(food.authorId, isNull);
      expect(food.portionName, 'slice (40 g)');
      expect(
        food.nutrients.values[NutrientKey.calories],
        closeTo(1033 / 4.184, 1e-9),
      );
      expect(food.dateCreated, now);
      await expectLater(
        openFoodFacts.lookupBarcode('0'),
        throwsA(
          isA<FoodDataException>().having(
            (error) => error.failure,
            'failure',
            FoodDataFailure.notFound,
          ),
        ),
      );
    });

    test('stamps the time by default', () async {
      final food = await FakeOpenFoodFacts().lookupBarcode('5010029000061');

      expect(food.dateCreated.isUtc, isTrue);
    });
  });

  group('lookUpBarcode', () {
    late InMemoryFoodRepository foods;
    late List<Object> saveErrors;
    final library = sampleFoods(uid: 'alice', now: now);

    setUp(() {
      foods = InMemoryFoodRepository();
      saveErrors = [];
    });

    Future<(FoodModel, BarcodeSource)> lookUp(
      String code, {
      FoodRepository? into,
    }) => lookUpBarcode(
      code,
      uid: 'alice',
      library: library,
      openFoodFacts: openFoodFacts,
      foods: into ?? foods,
      onSaveError: (error, _) => saveErrors.add(error),
    );

    test('finds the library food first, saving nothing', () async {
      final (food, source) = await lookUp('5000000000011');

      expect(source, BarcodeSource.library);
      expect(food.name, 'Rolled Oats');
      expect(await foods.watchFoods('alice').first, isEmpty);
    });

    test('otherwise saves the Open Food Facts product as the user', () async {
      final (food, source) = await lookUp('5010029000061');

      expect(source, BarcodeSource.openFoodFacts);
      expect(food.ingredientId, 'off-5010029000061');
      expect(food.authorId, 'alice');
      final saved = (await foods.watchFoods('alice').first).single;
      expect(saved.toFirestore(), food.toFirestore());
      expect(saveErrors, isEmpty);
    });

    test('a failed save is reported and the scan still succeeds', () async {
      final (food, source) = await lookUp(
        '5010029000061',
        into: _FailingFoods(),
      );

      expect(source, BarcodeSource.openFoodFacts);
      expect(food.authorId, 'alice');
      expect(saveErrors.single, isA<StateError>());
    });

    test("Open Food Facts' failure reaches the caller", () async {
      await expectLater(lookUp('0'), throwsA(isA<FoodDataException>()));
      expect(await foods.watchFoods('alice').first, isEmpty);
    });
  });
}
