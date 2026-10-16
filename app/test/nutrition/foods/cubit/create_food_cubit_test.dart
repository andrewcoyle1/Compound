import 'package:bloc_test/bloc_test.dart';
import 'package:compound/nutrition/foods/cubit/create_food_cubit.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show EnergyUnit;
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/helpers.dart';

class _MockFoodRepository extends Mock implements FoodRepository;

class _FakeFood extends Fake implements FoodModel;

void main() {
  final now = DateTime.utc(2026, 9, 14, 12);
  late FoodRepository foods;
  late AnalyticsRecorder analytics;
  final saved = <FoodModel>[];

  setUpAll(() => registerFallbackValue(_FakeFood()));

  setUp(() {
    saved.clear();
    foods = _MockFoodRepository();
    analytics = AnalyticsRecorder();
    when(() => foods.saveFood(any())).thenAnswer((invocation) async {
      saved.add(invocation.positionalArguments.single as FoodModel);
    });
  });

  CreateFoodCubit build({String? uid = 'user-1'}) => CreateFoodCubit(
    uid: uid,
    foods: foods,
    analytics: analytics,
    now: () => now,
    newId: () => 'food-1',
  );

  group('CreateFoodCubit (CreateFoodFlowPresenterTests)', () {
    test('a food cannot be saved without a name', () {
      final cubit = build()..nameChanged('   ');
      expect(cubit.state.canContinue, isFalse);
    });

    test('a named food can be saved', () {
      final cubit = build()..nameChanged('Oat Milk');
      expect(cubit.state.canContinue, isTrue);
    });

    test('a scanned barcode lands in the field and reaches the save', () async {
      final cubit = build()
        ..nameChanged('Oat Milk')
        ..barcodeScanned('5012345678900')
        ..energyChanged(250);
      expect(cubit.state.barcode, '5012345678900');

      await cubit.create();

      expect(saved.single.barcode, '5012345678900');
    });

    test('only an edited food has something to lose', () {
      final cubit = build();
      final untouched = cubit.state.hasUnsavedChanges;
      cubit.barcodeScanned('5012345678900');

      expect(untouched, isFalse);
      expect(cubit.state.hasUnsavedChanges, isTrue);
      expect((build()..brandChanged('Oatly')).state.hasUnsavedChanges, isTrue);
      expect((build()..nameChanged('Oats')).state.hasUnsavedChanges, isTrue);
    });

    test('an empty brand is none', () {
      final cubit = build()
        ..brandChanged('Oatly')
        ..brandChanged('');
      expect(cubit.state.brandName, isNull);
    });

    test('appearing and going are tracked under each step’s name', () {
      build()
        ..appeared('CreateFoodView')
        ..disappeared('CreateFoodView');
      expect(analytics.names, [
        'CreateFoodView_Appear',
        'CreateFoodView_Disappear',
      ]);
    });
  });

  group('portion step (PortionDefinitionPresenter)', () {
    test('opens on 1 portion, and needs a quantity and a name', () {
      final cubit = build();
      expect(cubit.state.portionSize, 1);
      expect(cubit.state.portionName, 'portion');
      expect(cubit.state.canContinuePortionStep, isTrue);

      cubit.portionSizeChanged(0);
      expect(cubit.state.canContinuePortionStep, isFalse);
      cubit
        ..portionSizeChanged(4)
        ..portionNameChanged('');
      expect(cubit.state.canContinuePortionStep, isFalse);
      cubit.portionNameChanged('pieces');
      expect(cubit.state.canContinuePortionStep, isTrue);
    });
  });

  group('create (FoodDefinitionPresenterTests)', () {
    test('the food carries every step’s details', () async {
      final cubit = build()
        ..nameChanged('Oat Milk')
        ..brandChanged('Oatly')
        ..servingWeightChanged(250)
        ..portionSizeChanged(1)
        ..portionNameChanged('glass')
        ..energyChanged(250)
        ..nutrientChanged(NutrientKey.protein, 5);

      await cubit.create();

      final food = saved.single;
      expect(food.ingredientId, 'food-1');
      expect(food.authorId, 'user-1');
      expect(food.name, 'Oat Milk');
      expect(food.brandName, 'Oatly');
      expect(food.servingWeight, 250);
      expect(food.portionName, 'glass');
      expect(food.nutrients.values, {
        NutrientKey.calories: 100,
        NutrientKey.protein: 2,
      });
      expect(cubit.state.status, CreateFoodStatus.created);
      expect(cubit.state.created?.ingredientId, 'food-1');
    });

    test('a cleared nutrient is not stored', () async {
      final cubit = build()
        ..nameChanged('Oats')
        ..energyChanged(250)
        ..nutrientChanged(NutrientKey.ironMg, 2)
        ..nutrientChanged(NutrientKey.ironMg, null);

      await cubit.create();

      expect(saved.single.nutrients.values.keys, [NutrientKey.calories]);
    });

    test('kilojoules are stored as kilocalories', () async {
      final cubit = build()
        ..nameChanged('Oats')
        ..energyUnitChanged(EnergyUnit.kilojoule)
        ..energyChanged(418.4);

      await cubit.create();

      expect(
        saved.single.nutrients.values[NutrientKey.calories],
        closeTo(100, 0.0001),
      );
    });

    test('a food without energy cannot be created', () async {
      final cubit = build()
        ..nameChanged('Oats')
        ..nutrientChanged(NutrientKey.protein, 12);

      expect(cubit.state.canCreate, isFalse);
      await cubit.create();

      expect(saved, isEmpty);
    });

    test('a second tap while saving saves once', () async {
      final cubit = build()
        ..nameChanged('Oats')
        ..energyChanged(250);

      final first = cubit.create();
      expect(cubit.state.isSaving, isTrue);
      await cubit.create();
      await first;

      expect(saved, hasLength(1));
    });

    test(
      'create and add is remembered, so the food goes on the plate',
      () async {
        final cubit = build()
          ..nameChanged('Oat Milk')
          ..energyChanged(250);

        await cubit.create(addToPlate: true);

        expect(cubit.state.addToPlate, isTrue);
        final item = cubit.state.created!.mealItem(100);
        expect(item.displayName, 'Oat Milk');
        expect(item.sourceId, 'food-1');
        expect(item.amount, 100);
        expect(item.unit, 'g');
        expect(item.resolvedGrams, 100);
        expect(item.nutrients.values[NutrientKey.calories], 250);
      },
    );

    test('plain create leaves the plate alone', () async {
      final cubit = build()
        ..nameChanged('Oats')
        ..energyChanged(250);

      await cubit.create();

      expect(cubit.state.addToPlate, isFalse);
    });

    test('success is logged between a start and a success', () async {
      final cubit = build()
        ..nameChanged('Oats')
        ..energyChanged(250);

      await cubit.create();

      expect(analytics.names, [
        'FoodDefinitionView_CreateFood_Start',
        'FoodDefinitionView_CreateFood_Success',
      ]);
    });

    test('no user means no food is created, and no start', () async {
      final cubit = build(uid: null)
        ..nameChanged('Oats')
        ..energyChanged(250);

      await cubit.create();

      expect(saved, isEmpty);
      expect(analytics.names, isEmpty);
    });

    blocTest<CreateFoodCubit, CreateFoodState>(
      'a failed save is reported, and the form stays open to retry',
      setUp: () =>
          when(() => foods.saveFood(any())).thenThrow(StateError('offline')),
      build: build,
      seed: () => const CreateFoodState(name: 'Oats', energy: 250),
      act: (cubit) => cubit.create(),
      expect: () => [
        const CreateFoodState(
          name: 'Oats',
          energy: 250,
          status: CreateFoodStatus.saving,
        ),
        const CreateFoodState(
          name: 'Oats',
          energy: 250,
          status: CreateFoodStatus.failed,
        ),
      ],
      verify: (_) {
        expect(analytics.names, [
          'FoodDefinitionView_CreateFood_Start',
          'FoodDefinitionView_CreateFood_Fail',
        ]);
        expect(
          analytics.parameters('FoodDefinitionView_CreateFood_Fail'),
          containsPair('error_description', 'Bad state: offline'),
        );
      },
    );
  });
}
