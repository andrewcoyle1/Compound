import 'package:compound/nutrition/foods/logic/create_food.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show EnergyUnit;
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 12);
  PortionInput portion({
    NutritionDefinitionOption option = NutritionDefinitionOption.serving,
    double? servingWeight,
    double? portionSize = 250,
    String? portionName = 'glass',
  }) => (
    option: option,
    servingWeight: servingWeight,
    portionSize: portionSize,
    portionName: portionName,
  );
  FoodModel create(
    Map<NutrientKey, double> nutrients, {
    PortionInput? serving,
  }) => createdFood(
    id: 'food-1',
    authorId: 'user-1',
    name: 'Oat Milk',
    brandName: 'Oatly',
    barcode: '5012345678900',
    portion: serving ?? portion(),
    nutrients: nutrients,
    now: now,
  );

  group('createdFood (FoodDefinitionPresenterTests)', () {
    test('entered nutrients are saved', () {
      final food = create({
        NutrientKey.calories: 250,
        NutrientKey.protein: 12,
        NutrientKey.carbs: 30,
        NutrientKey.fatTotal: 8,
      });
      expect(food.nutrients.values, {
        NutrientKey.calories: 250,
        NutrientKey.protein: 12,
        NutrientKey.carbs: 30,
        NutrientKey.fatTotal: 8,
      });
    });

    test('untouched nutrients are absent, not zero', () {
      final food = create({NutrientKey.calories: 250});
      expect(food.nutrients.values.containsKey(NutrientKey.ironMg), isFalse);
      expect(
        food.nutrients.values.containsKey(NutrientKey.vitaminCMg),
        isFalse,
      );
    });

    test('an entered zero is kept', () {
      final food = create({NutrientKey.calories: 250, NutrientKey.fatTotal: 0});
      expect(food.nutrients.values[NutrientKey.fatTotal], 0);
    });

    test('the food carries its identifying details', () {
      final food = create({NutrientKey.calories: 250});
      expect(food.ingredientId, 'food-1');
      expect(food.name, 'Oat Milk');
      expect(food.brandName, 'Oatly');
      expect(food.barcode, '5012345678900');
      expect(food.authorId, 'user-1');
      expect(food.portionSize, 250);
      expect(food.portionName, 'glass');
      expect(food.measurementMethod, MeasurementMethod.weight);
      expect(food.dateCreated, now);
      expect(food.dateModified, now);
    });

    test('per-serving figures are normalised to per 100 g', () {
      final food = create({
        NutrientKey.calories: 100,
        NutrientKey.protein: 5,
      }, serving: portion(servingWeight: 50));
      expect(food.nutrients.values[NutrientKey.calories], 200);
      expect(food.nutrients.values[NutrientKey.protein], 10);
      expect(food.servingWeight, 50);
    });

    test('a 100 g serving is unchanged', () {
      final food = create({
        NutrientKey.calories: 100,
      }, serving: portion(servingWeight: 100));
      expect(food.nutrients.values[NutrientKey.calories], 100);
    });

    test('standard mass figures are not scaled', () {
      final food = create(
        {NutrientKey.calories: 100},
        serving: portion(
          option: NutritionDefinitionOption.standardMass,
          servingWeight: 50,
        ),
      );
      expect(food.nutrients.values[NutrientKey.calories], 100);
    });

    test('a serving without a weight is not scaled', () {
      final food = create({NutrientKey.calories: 100});
      expect(food.nutrients.values[NutrientKey.calories], 100);
    });

    test('a zero serving weight is not scaled', () {
      final calories = create(
        {NutrientKey.calories: 100},
        serving: portion(servingWeight: 0),
      ).nutrients.values[NutrientKey.calories];
      expect(calories, 100);
      expect(calories!.isFinite, isTrue);
    });

    test('every collected nutrient is stored', () {
      final entered = {
        NutrientKey.calories: 250.0,
        for (final field in nutrientFields) field.key: 1.5,
      };
      expect(create(entered).nutrients.values, entered);
    });

    test('new nutrients are normalised too', () {
      final food = create({
        NutrientKey.calories: 100,
        NutrientKey.leucine: 1,
        NutrientKey.water: 20,
      }, serving: portion(servingWeight: 50));
      expect(food.nutrients.values[NutrientKey.leucine], 2);
      expect(food.nutrients.values[NutrientKey.water], 40);
    });
  });

  group('nutrientFields', () {
    test('are the form’s 53 fields, each once', () {
      expect(nutrientFields, hasLength(53));
      expect(nutrientFields.map((field) => field.key).toSet(), hasLength(53));
    });

    test('new nutrients belong to a drawn group, in grams', () {
      NutrientGroup groupOf(NutrientKey key) =>
          nutrientFields.firstWhere((field) => field.key == key).group;
      expect(groupOf(NutrientKey.fatTrans), NutrientGroup.fats);
      expect(groupOf(NutrientKey.omega3), NutrientGroup.fats);
      expect(groupOf(NutrientKey.starch), NutrientGroup.carbs);
      expect(groupOf(NutrientKey.addedSugars), NutrientGroup.carbs);
      expect(groupOf(NutrientKey.leucine), NutrientGroup.proteins);
      expect(groupOf(NutrientKey.alcohol), NutrientGroup.other);
      expect(groupOf(NutrientKey.water), NutrientGroup.other);
      expect(nutrientUnit(NutrientKey.leucine), 'g');
      expect(nutrientUnit(NutrientKey.omega3Dha), 'g');
    });

    test('units are the ones each nutrient is stored in', () {
      expect(nutrientUnit(NutrientKey.calories), 'kcal');
      expect(nutrientUnit(NutrientKey.sodiumMg), 'mg');
      expect(nutrientUnit(NutrientKey.vitaminDMcg), 'mcg');
      expect(nutrientUnit(NutrientKey.protein), 'g');
    });
  });

  group('energyInKilocalories', () {
    test('kilojoules are stored as kilocalories', () {
      expect(
        energyInKilocalories(418.4, EnergyUnit.kilojoule),
        closeTo(100, 0.0001),
      );
      expect(energyInKilocalories(250, EnergyUnit.kcal), 250);
    });
  });

  group('canContinuePortion', () {
    test('a serving needs a quantity that is not 0 and a name', () {
      expect(canContinuePortion(portion(portionSize: 1)), isTrue);
      expect(canContinuePortion(portion(portionSize: null)), isFalse);
      expect(canContinuePortion(portion(portionSize: 0)), isFalse);
      expect(canContinuePortion(portion(portionName: '')), isFalse);
      expect(
        canContinuePortion(
          portion(
            option: NutritionDefinitionOption.standardMass,
            portionSize: null,
          ),
        ),
        isTrue,
      );
    });
  });
}
