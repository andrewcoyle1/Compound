import 'package:compound_models/compound_models.dart';

/// A dozen everyday foods in [uid]'s library, for the staging flavor, made
/// at [now]. Their ids are the `sample-food-…` ids the staging meals in
/// `nutrition_repository` log, so recent foods and quick add find them.
/// Rolled oats carry the barcode `5000000000011`, for a library hit when
/// scanning.
List<FoodModel> sampleFoods({required String uid, required DateTime now}) => [
  for (final sample in _samples)
    FoodModel(
      ingredientId:
          'sample-food-${sample.name.toLowerCase().replaceAll(_nonWord, '-')}',
      authorId: uid,
      name: sample.name,
      brandName: sample.brand,
      measurementMethod: sample.method,
      nutrients: NutrientMap({
        for (final (index, key) in _keys.indexed) key: sample.per100[index],
      }),
      barcode: sample.barcode,
      servingWeight: sample.method == MeasurementMethod.weight
          ? sample.serving?.$1
          : null,
      portionSize: sample.method == MeasurementMethod.weight
          ? sample.serving?.$2
          : null,
      portionName: sample.method == MeasurementMethod.weight
          ? sample.serving?.$3
          : null,
      portionVolume: sample.method == MeasurementMethod.volume
          ? sample.serving?.$1
          : null,
      volumePortionSize: sample.method == MeasurementMethod.volume
          ? sample.serving?.$2
          : null,
      volumePortionName: sample.method == MeasurementMethod.volume
          ? sample.serving?.$3
          : null,
      dateCreated: now,
      dateModified: now,
    ),
];

final _nonWord = RegExp('[^a-z0-9]+');

/// The order of each sample's `per100` figures.
const _keys = <NutrientKey>[
  NutrientKey.calories,
  NutrientKey.protein,
  NutrientKey.carbs,
  NutrientKey.fatTotal,
  NutrientKey.fiber,
  NutrientKey.sugar,
  NutrientKey.sodiumMg,
];

typedef _Sample = ({
  String name,
  String? brand,
  MeasurementMethod method,
  List<double> per100,
  (double, double, String)? serving,
  String? barcode,
});

const MeasurementMethod _weight = MeasurementMethod.weight;

const List<_Sample> _samples = [
  (
    name: 'Rolled Oats',
    brand: 'Flahavan’s',
    method: _weight,
    per100: [379, 13.2, 67.7, 6.5, 10.1, 1, 6],
    serving: (40, 0.5, 'cup'),
    barcode: '5000000000011',
  ),
  (
    name: 'Semi-Skimmed Milk',
    brand: null,
    method: MeasurementMethod.volume,
    per100: [46, 3.5, 4.7, 1.7, 0, 4.7, 44],
    serving: (250, 1, 'glass'),
    barcode: null,
  ),
  (
    name: 'Banana',
    brand: null,
    method: _weight,
    per100: [89, 1.1, 22.8, 0.3, 2.6, 12.2, 1],
    serving: (118, 1, 'medium banana'),
    barcode: null,
  ),
  (
    name: 'Greek Yogurt (0%)',
    brand: 'Fage',
    method: _weight,
    per100: [59, 10.3, 3.6, 0.4, 0, 3.2, 36],
    serving: (170, 1, 'pot'),
    barcode: null,
  ),
  (
    name: 'Whole Egg',
    brand: null,
    method: _weight,
    per100: [143, 12.6, 0.7, 9.5, 0, 0.4, 142],
    serving: (50, 1, 'egg'),
    barcode: null,
  ),
  (
    name: 'Wholemeal Bread',
    brand: null,
    method: _weight,
    per100: [247, 13, 41, 3.4, 7, 6, 450],
    serving: (40, 1, 'slice'),
    barcode: null,
  ),
  (
    name: 'Chicken Breast',
    brand: null,
    method: _weight,
    per100: [165, 31, 0, 3.6, 0, 0, 74],
    serving: (150, 1, 'breast'),
    barcode: null,
  ),
  (
    name: 'Basmati Rice (cooked)',
    brand: null,
    method: _weight,
    per100: [121, 3.5, 25.2, 0.4, 0.4, 0.1, 1],
    serving: null,
    barcode: null,
  ),
  (
    name: 'Broccoli',
    brand: null,
    method: _weight,
    per100: [34, 2.8, 6.6, 0.4, 2.6, 1.7, 33],
    serving: null,
    barcode: null,
  ),
  (
    name: 'Atlantic Salmon',
    brand: null,
    method: _weight,
    per100: [208, 20.4, 0, 13.4, 0, 0, 59],
    serving: (125, 1, 'fillet'),
    barcode: null,
  ),
  (
    name: 'Almonds',
    brand: null,
    method: _weight,
    per100: [579, 21.2, 21.6, 49.9, 12.5, 4.4, 1],
    serving: (30, 1, 'handful'),
    barcode: null,
  ),
  (
    name: 'Avocado',
    brand: null,
    method: _weight,
    per100: [160, 2, 8.5, 14.7, 6.7, 0.7, 7],
    serving: (75, 1, 'half'),
    barcode: null,
  ),
];

/// Three recipes in [uid]'s library made from [foods] (`sampleFoods`), for
/// the staging flavor, made at [now]. Their ids are `sample-recipe-…`.
List<RecipeTemplateModel> sampleRecipes({
  required String uid,
  required DateTime now,
  required List<FoodModel> foods,
}) {
  final byName = {for (final food in foods) food.name: food};
  RecipeIngredientModel use(String name, double amount) =>
      RecipeIngredientModel.forFood(byName[name]!, amount);
  RecipeTemplateModel recipe(
    String id,
    String name, {
    required List<RecipeIngredientModel> ingredients,
    required double servings,
    String? description,
    List<String> steps = const [],
    double? prep,
    double? cook,
  }) => RecipeTemplateModel(
    recipeId: 'sample-recipe-$id',
    authorId: uid,
    name: name,
    description: description,
    dateCreated: now,
    dateModified: now,
    ingredients: ingredients,
    servingQuantity: servings,
    preparationSteps: steps,
    prepTimeMins: prep,
    cookTimeMins: cook,
  );
  return [
    recipe(
      'overnight-oats',
      'Overnight Oats',
      description: 'Oats soaked in milk with banana and yogurt.',
      ingredients: [
        use('Rolled Oats', 80),
        use('Semi-Skimmed Milk', 300),
        use('Greek Yogurt (0%)', 170),
        use('Banana', 118),
      ],
      servings: 2,
      steps: ['Stir everything together in a jar.', 'Chill overnight.'],
      prep: 5,
    ),
    recipe(
      'chicken-rice-bowl',
      'Chicken Rice Bowl',
      description: 'Meal-prep chicken with rice and broccoli.',
      ingredients: [
        use('Chicken Breast', 600),
        use('Basmati Rice (cooked)', 800),
        use('Broccoli', 400),
      ],
      servings: 4,
      steps: [
        'Cook the rice.',
        'Grill the chicken and slice it.',
        'Steam the broccoli and divide everything between four boxes.',
      ],
      prep: 10,
      cook: 25,
    ),
    recipe(
      'salmon-avocado-toast',
      'Salmon Avocado Toast',
      ingredients: [
        use('Wholemeal Bread', 80),
        use('Avocado', 75),
        use('Atlantic Salmon', 125),
      ],
      servings: 1,
    ),
  ];
}
