import 'package:compound/nutrition/foods/cubit/food_detail_cubit.dart';
import 'package:compound/nutrition/foods/cubit/foods_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../../helpers/helpers.dart';

class _MockFoodRepository extends Mock implements FoodRepository;

class _FakeSettings extends Fake implements FoodLogSettings;

void main() {
  const uid = 'user-1';
  final now = DateTime.utc(2026, 9, 14, 12);
  FoodModel food(
    String id,
    String name, {
    String? brand,
    String? description,
    String? authorId = uid,
  }) => FoodModel(
    ingredientId: id,
    authorId: authorId,
    name: name,
    brandName: brand,
    description: description,
    dateCreated: now,
    dateModified: now,
  );

  late AnalyticsRecorder analytics;

  setUpAll(() => registerFallbackValue(_FakeSettings()));
  setUp(() => analytics = AnalyticsRecorder());

  group(FoodsCubit, () {
    Future<FoodsCubit> build({
      List<FoodModel> foods = const [],
      bool showBranded = true,
      bool showImage = true,
    }) async {
      final cubit = FoodsCubit(
        uid: uid,
        foods: InMemoryFoodRepository(foods: foods),
        nutrition: InMemoryNutritionRepository(
          foodLogSettings: FoodLogSettings(
            authorId: uid,
            showBrandedFoods: showBranded,
            showFoodImageInLogger: showImage,
          ),
        ),
        analytics: analytics,
      );
      await pumpEventQueue();
      return cubit;
    }

    test('lists the foods by name and logs the screen', () async {
      final cubit = await build(
        foods: [food('b', 'banana'), food('a', 'Apple'), food('c', 'Carrot')],
      );

      expect(cubit.state.visibleFoods.map((f) => f.name), [
        'Apple',
        'banana',
        'Carrot',
      ]);
      await cubit.close();
      expect(analytics.names, ['FoodsView_Appear', 'FoodsView_Disappear']);
    });

    test('rows show pictures as the logger’s Show Food Image says '
        '(IngredientListBuilderView)', () async {
      expect((await build()).state.showFoodImage, isTrue);
      expect((await build(showImage: false)).state.showFoodImage, isFalse);
    });

    test('hides branded foods when the setting is off', () async {
      final cubit = await build(
        foods: [
          food('a', 'Oats'),
          food('b', 'Cola', brand: 'Coca-Cola'),
        ],
        showBranded: false,
      );

      expect(cubit.state.visibleFoods.map((f) => f.name), ['Oats']);
    });

    test('filters on name or description, name matches first', () async {
      final cubit =
          await build(
              foods: [
                food('a', 'Rolled Oats'),
                food('b', 'Porridge', description: 'made with OATS'),
                food('c', 'Egg'),
              ],
            )
            ..filterChanged('oats');

      expect(cubit.state.visibleFoods.map((f) => f.name), [
        'Rolled Oats',
        'Porridge',
      ]);
    });

    test('an unreadable library lists nothing rather than loading', () async {
      final foods = _MockFoodRepository();
      when(() => foods.watchFoods(uid))
          .thenAnswer((_) => Stream.error(StateError('denied')));
      final cubit = FoodsCubit(
        uid: uid,
        foods: foods,
        nutrition: InMemoryNutritionRepository(),
        analytics: analytics,
      );
      await pumpEventQueue();

      expect(cubit.state.foods, isEmpty);
    });

    test('opening a food and adding one are tracked', () async {
      final oats = food('a', 'Oats');
      final cubit = await build(foods: [oats]);

      cubit
        ..foodSelected(oats)
        ..addPressed();

      expect(analytics.names, [
        'FoodsView_Appear',
        'IngredientsView_Ingredient_Selected',
        'IngredientsView_AddIngredientPressed',
      ]);
      expect(analytics.parameters('IngredientsView_Ingredient_Selected'), {
        'ingredient_id': 'a',
        'ingredient_name': 'Oats',
        'method': 'amount',
      });
    });
  });

  group(FoodDetailCubit, () {
    late InMemoryFoodRepository foods;
    late InMemoryNutritionRepository nutrition;

    Future<FoodDetailCubit> build({
      String foodId = 'oats',
      FoodRepository? foodRepository,
      NutritionRepository? nutritionRepository,
    }) async {
      final cubit = FoodDetailCubit(
        uid: uid,
        foodId: foodId,
        foods: foodRepository ?? foods,
        nutrition: nutritionRepository ?? nutrition,
        analytics: analytics,
      );
      await pumpEventQueue();
      return cubit;
    }

    setUp(() {
      foods = InMemoryFoodRepository(
        foods: [
          food('oats', 'Oats'),
          food('shared', 'Shared', authorId: 'someone-else'),
        ],
      );
      nutrition = InMemoryNutritionRepository(
        foodLogSettings: const FoodLogSettings(
          authorId: uid,
          favouriteFoodIds: ['egg'],
          startHour: 5,
        ),
      );
    });

    test('reads the food and whether it is a favourite', () async {
      final cubit = await build();

      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.food?.name, 'Oats');
      expect(cubit.state.isFavourited, isFalse);
      await cubit.close();
      expect(analytics.names, [
        'FoodDetailView_Appear',
        'FoodDetailView_Disappear',
      ]);
    });

    test('a food that is not in the library is missing', () async {
      final cubit = await build(foodId: 'gone');
      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.food, isNull);
    });

    test('an unreadable library still finishes loading', () async {
      final failing = _MockFoodRepository();
      when(() => failing.watchFoods(uid))
          .thenAnswer((_) => Stream.error(StateError('denied')));
      final cubit = await build(foodRepository: failing);
      expect(cubit.state.loaded, isTrue);
    });

    test('only the author’s food can be deleted', () async {
      expect((await build()).canDelete, isTrue);
      expect((await build(foodId: 'shared')).canDelete, isFalse);
      expect((await build(foodId: 'gone')).canDelete, isFalse);
    });

    test('favouriting saves the id with the other settings', () async {
      final cubit = await build();

      await cubit.favouriteToggled();

      final settings = await nutrition.watchFoodLogSettings(uid).first;
      expect(settings.favouriteFoodIds, ['egg', 'oats']);
      expect(settings.startHour, 5);
      expect(cubit.state.isFavourited, isTrue);
      expect(analytics.names, [
        'FoodDetailView_Appear',
        'FoodDetailView_Favourite_Start',
        'FoodDetailView_Favourite_Success',
      ]);

      await cubit.favouriteToggled();
      expect(
        (await nutrition.watchFoodLogSettings(uid).first).favouriteFoodIds,
        ['egg'],
      );
      expect(cubit.state.isFavourited, isFalse);
    });

    test('a failed favourite is put back and reported', () async {
      final failing = MockNutritionRepository();
      when(
        () => failing.watchFoodLogSettings(uid),
      ).thenAnswer((_) => Stream.value(const FoodLogSettings(authorId: uid)));
      when(() => failing.saveFoodLogSettings(any()))
          .thenThrow(StateError('offline'));
      final cubit = await build(nutritionRepository: failing);

      await cubit.favouriteToggled();

      expect(cubit.state.isFavourited, isFalse);
      expect(cubit.state.favouriteFailures, 1);
      expect(analytics.names.last, 'FoodDetailView_Favourite_Fail');
    });

    test('favouriting waits for the settings', () async {
      final silent = MockNutritionRepository();
      when(() => silent.watchFoodLogSettings(uid))
          .thenAnswer((_) => const Stream.empty());
      final cubit = await build(nutritionRepository: silent);

      await cubit.favouriteToggled();

      verifyNever(() => silent.saveFoodLogSettings(any()));
    });

    test('a confirmed delete removes the food, then leaves', () async {
      final cubit = await build();

      await cubit.deleteConfirmed();

      expect(await foods.watchFoods(uid).first, isEmpty);
      expect(cubit.state.deleteStatus, FoodDetailDeleteStatus.deleted);
      expect(analytics.names, [
        'FoodDetailView_Appear',
        'FoodDetailView_Delete_Start',
        'FoodDetailView_Delete_Success',
      ]);
      // A second delete does nothing.
      await cubit.deleteConfirmed();
      expect(analytics.names, hasLength(3));
    });

    test('someone else’s food is never deleted', () async {
      final cubit = await build(foodId: 'shared');
      await cubit.deleteConfirmed();
      expect(analytics.names, ['FoodDetailView_Appear']);
    });

    test('a failed delete says so and stays', () async {
      final failing = _MockFoodRepository();
      when(() => failing.watchFoods(uid))
          .thenAnswer((_) => Stream.value([food('oats', 'Oats')]));
      when(() => failing.deleteFood(uid, 'oats'))
          .thenThrow(StateError('offline'));
      final cubit = await build(foodRepository: failing);

      await cubit.deleteConfirmed();

      expect(cubit.state.deleteStatus, FoodDetailDeleteStatus.idle);
      expect(cubit.state.deleteFailures, 1);
      expect(analytics.names.last, 'FoodDetailView_Delete_Fail');
    });
  });
}
