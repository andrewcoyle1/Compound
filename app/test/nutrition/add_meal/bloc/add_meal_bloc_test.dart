import 'package:bloc_test/bloc_test.dart';
import 'package:compound/nutrition/add_meal/bloc/add_meal_bloc.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../recording_analytics.dart';

class _MockNutritionRepository extends Mock implements NutritionRepository;

class _MockFoodRepository extends Mock implements FoodRepository;

class _FakeMeal extends Fake implements MealLogModel;

class _FakeFood extends Fake implements FoodModel;

void main() {
  const uid = 'uid';
  final date = DateTime(2026, 9, 21, 13);
  final empty = newMeal(uid: uid, date: date, mealId: 'MEAL');

  MealItemModel item(
    String id, {
    String sourceId = 'oats',
    double kcal = 150,
  }) => MealItemModel(
    itemId: id,
    sourceType: MealItemSourceType.ingredient,
    sourceId: sourceId,
    displayName: 'Oats',
    amount: 40,
    unit: 'g',
    resolvedGrams: 40,
    nutrients: NutrientMap({NutrientKey.calories: kcal}),
  );

  final oats = FoodModel(
    ingredientId: 'oats',
    authorId: uid,
    name: 'Oats',
    nutrients: const NutrientMap({NutrientKey.calories: 375}),
    servingWeight: 40,
    dateCreated: DateTime.utc(2026),
    dateModified: DateTime.utc(2026),
  );
  final external = FoodModel(
    ingredientId: 'off-5010029000061',
    name: 'Weetabix',
    nutrients: const NutrientMap({NutrientKey.calories: 362}),
    barcode: '5010029000061',
    dateCreated: DateTime.utc(2026),
    dateModified: DateTime.utc(2026),
  );
  final yesterday = MealLogModel(
    mealId: 'Y',
    authorId: uid,
    dayKey: '2026-09-20',
    date: DateTime(2026, 9, 20, 8),
    items: [
      const MealItemModel(
        itemId: 'old',
        sourceType: MealItemSourceType.ingredient,
        sourceId: 'oats',
        displayName: 'Oats',
        amount: 60,
        unit: 'g',
        resolvedGrams: 60,
        nutrients: NutrientMap({NutrientKey.calories: 225}),
      ),
    ],
  );
  const settings = FoodLogSettings(authorId: uid);

  late NutritionRepository nutrition;
  late FoodRepository foods;
  late RecordingAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(_FakeMeal());
    registerFallbackValue(_FakeFood());
  });

  setUp(() {
    nutrition = _MockNutritionRepository();
    foods = _MockFoodRepository();
    analytics = RecordingAnalytics();
    when(() => nutrition.watchMeals(uid))
        .thenAnswer((_) => Stream.value([yesterday]));
    when(() => nutrition.watchDietPlan(uid))
        .thenAnswer((_) => Stream.value(null));
    when(() => nutrition.watchFoodLogSettings(uid))
        .thenAnswer((_) => Stream.value(settings));
    when(() => foods.watchFoods(uid)).thenAnswer((_) => Stream.value([oats]));
    when(() => nutrition.saveMeal(any())).thenAnswer((_) async {});
    when(() => foods.saveFood(any())).thenAnswer((_) async {});
  });

  AddMealBloc build([MealLogModel? meal]) => AddMealBloc(
    nutritionRepository: nutrition,
    foodRepository: foods,
    analyticsRepository: analytics,
    meal: meal ?? empty,
  );

  MealLogModel withPlate(List<MealItemModel> items) => withItems(empty, items);

  group(AddMealBloc, () {
    test('a new meal opens on the picker; a draft on its plate', () {
      expect(build().state.pickerOpen, isTrue);
      expect(build(withPlate([item('a')])).state.pickerOpen, isFalse);
    });

    blocTest<AddMealBloc, AddMealState>(
      'follows the meals, plan, settings and foods',
      build: build,
      act: (bloc) => bloc.add(const AddMealSubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.meals, [yesterday]);
        expect(bloc.state.foods, [oats]);
        expect(bloc.state.settings, settings);
        expect(bloc.state.dietPlan, isNull);
        expect(analytics.names.first, 'AddMealView_Appear');
      },
    );

    blocTest<AddMealBloc, AddMealState>(
      'a stream that fails leaves the plate usable',
      setUp: () {
        when(() => foods.watchFoods(uid))
            .thenAnswer((_) => Stream.error(Exception('offline')));
        when(() => nutrition.watchFoodLogSettings(uid))
            .thenAnswer((_) => Stream.error(Exception('offline')));
        when(() => nutrition.watchDietPlan(uid))
            .thenAnswer((_) => Stream.error(Exception('offline')));
        when(() => nutrition.watchMeals(uid))
            .thenAnswer((_) => Stream.error(Exception('offline')));
      },
      build: build,
      act: (bloc) => bloc.add(const AddMealSubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.foods, isEmpty);
        expect(bloc.state.effectiveSettings.authorId, uid);
        expect(bloc.state.meals, isNull);
      },
    );

    blocTest<AddMealBloc, AddMealState>(
      'adding a library food puts it on the plate and saves nothing else',
      build: build,
      act: (bloc) => bloc.add(AddMealItemAdded(item('a'), food: oats)),
      verify: (bloc) {
        expect(bloc.state.meal.items.single.itemId, 'a');
        verifyNever(() => foods.saveFood(any()));
      },
    );

    blocTest<AddMealBloc, AddMealState>(
      'logging an Open Food Facts food saves it to the library as the user',
      build: build,
      act: (bloc) => bloc.add(AddMealItemAdded(item('a'), food: external)),
      verify: (_) {
        final saved =
            verify(() => foods.saveFood(captureAny())).captured.single
                as FoodModel;
        expect(saved.toFirestore(), {
          ...external.toFirestore(),
          FoodModelKeys.authorId: uid,
        });
      },
    );

    blocTest<AddMealBloc, AddMealState>(
      'a failed library save does not touch the plate',
      setUp: () =>
          when(() => foods.saveFood(any()))
              .thenAnswer((_) async => throw Exception('refused')),
      build: build,
      act: (bloc) => bloc.add(AddMealFoodQuickAdded(external)),
      verify: (bloc) => expect(bloc.state.meal.items, hasLength(1)),
    );

    blocTest<AddMealBloc, AddMealState>(
      "a row's + adds the amount the food was last logged at",
      build: build,
      act: (bloc) => bloc
        ..add(const AddMealSubscriptionRequested())
        ..add(AddMealFoodQuickAdded(oats)),
      wait: Duration.zero,
      verify: (bloc) {
        final added = bloc.state.meal.items.single;
        expect(added.amount, 60);
        expect(added.sourceId, 'oats');
        expect(added.nutrients.values[NutrientKey.calories], 225);
      },
    );

    blocTest<AddMealBloc, AddMealState>(
      'removing an item keeps the others',
      build: () => build(withPlate([item('a'), item('b'), item('c')])),
      act: (bloc) => bloc.add(const AddMealItemRemoved('b')),
      verify: (bloc) =>
          expect([for (final i in bloc.state.meal.items) i.itemId], ['a', 'c']),
    );

    blocTest<AddMealBloc, AddMealState>(
      'a corrected item replaces only itself',
      build: () => build(withPlate([item('a'), item('b')])),
      act: (bloc) => bloc.add(AddMealItemChanged(item('b', kcal: 999))),
      verify: (bloc) => expect(
        [
          for (final i in bloc.state.meal.items)
            i.nutrients.values[NutrientKey.calories],
        ],
        [150, 999],
      ),
    );

    blocTest<AddMealBloc, AddMealState>(
      'closing the picker over an empty plate closes the logger',
      build: build,
      act: (bloc) => bloc.add(const AddMealPickerClosed()),
      verify: (bloc) => expect(bloc.state.status, AddMealStatus.discarded),
    );

    blocTest<AddMealBloc, AddMealState>(
      'closing the picker over a full plate goes back to it',
      build: () => build(withPlate([item('a')])),
      act: (bloc) => bloc
        ..add(const AddMealPickerOpened())
        ..add(const AddMealPickerClosed()),
      verify: (bloc) {
        expect(bloc.state.pickerOpen, isFalse);
        expect(bloc.state.status, AddMealStatus.editing);
      },
    );

    blocTest<AddMealBloc, AddMealState>(
      'choosing a tab is tracked once',
      build: build,
      act: (bloc) => bloc
        ..add(const AddMealModeSelected(FoodPickerMode.barcode))
        ..add(const AddMealModeSelected(FoodPickerMode.barcode)),
      verify: (bloc) {
        expect(bloc.state.mode, FoodPickerMode.barcode);
        expect(analytics.names, [
          'NutritionLibraryPickerView_Tab_Selected',
          'AddMealView_Disappear',
        ]);
        expect(analytics.events.first.$2, {'tab': 'barcode'});
      },
    );

    blocTest<AddMealBloc, AddMealState>(
      'scope and time change what is shown and when it was eaten',
      build: () => build(withPlate([item('a')])),
      act: (bloc) => bloc
        ..add(const AddMealSubscriptionRequested())
        ..add(const AddMealScopeChanged(NutritionScope.day))
        ..add(AddMealTimeChanged(DateTime(2026, 9, 20, 22))),
      wait: Duration.zero,
      verify: (bloc) {
        expect(bloc.state.meal.dayKey, '2026-09-20');
        expect(bloc.state.meal.date, DateTime(2026, 9, 20, 22));
        // Now on yesterday, with yesterday's breakfast.
        expect(bloc.state.totals.calories, 375);
        expect(bloc.state.target, fallbackTarget);
      },
    );

    blocTest<AddMealBloc, AddMealState>(
      'logging saves exactly the meal Swift builds',
      build: () => build(withPlate([item('a')])),
      act: (bloc) => bloc.add(const AddMealSaveRequested()),
      expect: () => [
        isA<AddMealState>().having(
          (s) => s.status,
          'status',
          AddMealStatus.saving,
        ),
        isA<AddMealState>().having(
          (s) => s.status,
          'status',
          AddMealStatus.saved,
        ),
      ],
      verify: (_) {
        final saved =
            verify(() => nutrition.saveMeal(captureAny())).captured.single
                as MealLogModel;
        expect(saved.toFirestore(), {
          'meal_id': 'MEAL',
          'author_id': uid,
          'day_key': '2026-09-21',
          'date': date,
          'items': [
            {
              'itemId': 'a',
              'sourceType': 'ingredient',
              'sourceId': 'oats',
              'displayName': 'Oats',
              'amount': 40.0,
              'unit': 'g',
              'resolvedGrams': 40.0,
              'nutrients': {'calories': 150.0},
            },
          ],
        });
        expect(analytics.names, [
          'AddMealView_SaveMeal_Start',
          'AddMealView_SaveMeal_Success',
          'AddMealView_Disappear',
        ]);
      },
    );

    blocTest<AddMealBloc, AddMealState>(
      'an empty plate is not logged, nor one already saving',
      build: build,
      act: (bloc) => bloc.add(const AddMealSaveRequested()),
      expect: () => const <AddMealState>[],
    );

    blocTest<AddMealBloc, AddMealState>(
      'a second Log while saving saves once',
      build: () => build(withPlate([item('a')])),
      act: (bloc) => bloc
        ..add(const AddMealSaveRequested())
        ..add(const AddMealSaveRequested()),
      verify: (_) => verify(() => nutrition.saveMeal(any())).called(1),
    );

    blocTest<AddMealBloc, AddMealState>(
      'a failed save keeps the plate and says so; a change starts over',
      setUp: () =>
          when(() => nutrition.saveMeal(any()))
              .thenAnswer((_) async => throw Exception('refused')),
      build: () => build(withPlate([item('a')])),
      act: (bloc) async {
        bloc.add(const AddMealSaveRequested());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, AddMealStatus.failure);
        expect(bloc.state.meal.items, hasLength(1));
        bloc.add(AddMealItemAdded(item('b')));
      },
      verify: (bloc) {
        expect(bloc.state.status, AddMealStatus.editing);
        expect(analytics.names, contains('AddMealView_SaveMeal_Fail'));
      },
    );

    test('closing is tracked', () async {
      await build().close();
      expect(analytics.names, ['AddMealView_Disappear']);
    });
  });
}
