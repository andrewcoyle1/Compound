import 'package:compound_models/compound_models.dart';

/// A week of [uid]'s meals up to [now], for the staging flavor: breakfast,
/// lunch, dinner and snacks from a varied food list, a recipe, a quick add
/// and notes. Today holds only the meals already eaten by [now]. Six days
/// ago has only an Apple Health import (kept), and two days ago has one
/// beside logged meals (dropped by `withoutDuplicateHealthImports`).
List<MealLogModel> sampleMealLogs({
  required String uid,
  required DateTime now,
}) {
  final meals = <MealLogModel>[];
  for (final (daysAgo, day) in _week.indexed) {
    final date = now.subtract(Duration(days: daysAgo));
    final dayKey = _dayKey(date);
    for (final (index, meal) in day.indexed) {
      final at = DateTime(
        date.year,
        date.month,
        date.day,
        meal.hour,
        meal.minute,
      );
      if (at.isAfter(now)) continue;
      final mealId = 'sample-meal-$dayKey-$index';
      meals.add(
        MealLogModel(
          mealId: mealId,
          authorId: uid,
          dayKey: dayKey,
          date: at,
          notes: meal.notes,
          items: [
            for (final (n, item) in meal.items.indexed) item('$mealId-$n'),
          ],
        ),
      );
    }
  }
  for (final (daysAgo, kcal) in [(6, 2310.5), (2, 1180.25)]) {
    final date = now.subtract(Duration(days: daysAgo));
    final dayKey = _dayKey(date);
    meals.add(
      MealLogModel(
        mealId: MealLogModel.healthKitMealId(dayKey),
        authorId: uid,
        dayKey: dayKey,
        date: DateTime(date.year, date.month, date.day, 12),
        items: [
          _quickAdd(
            'Apple Health',
            kcal: kcal,
            protein: kcal * 0.06,
            carbs: kcal * 0.11,
            fat: kcal * 0.035,
          )('healthkit-$dayKey'),
        ],
      ),
    );
  }
  return meals;
}

/// [uid]'s plan, made a fortnight before [now]: seven days of targets,
/// Monday first, with more carbohydrate on the five training days.
DietPlan sampleDietPlan({required String uid, required DateTime now}) {
  DailyMacroTarget target(double calories) => DailyMacroTarget(
    calories: calories,
    proteinGrams: 165,
    carbGrams: (calories - 165 * 4 - 75 * 9) / 4,
    fatGrams: 75,
  );
  final training = target(2550);
  final rest = target(2250);
  return DietPlan(
    planId: uid,
    userId: uid,
    createdAt: now.subtract(const Duration(days: 14)),
    tdeeEstimate: 2650,
    preferredDiet: 'balanced',
    calorieFloor: 'standard',
    trainingType: 'moderate',
    calorieDistribution: 'varied',
    proteinIntake: 'high',
    days: [training, training, rest, training, training, training, rest],
  );
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// An item waiting for its id.
typedef _ItemDraft = MealItemModel Function(String itemId);

typedef _Meal = ({int hour, int minute, List<_ItemDraft> items, String? notes});

_Meal _meal(int hour, int minute, List<_ItemDraft> items, {String? notes}) =>
    (hour: hour, minute: minute, items: items, notes: notes);

/// A food per 100 g: kcal, protein, carbs, fat, fibre, sugar, sodium (mg).
typedef _Food = (
  String,
  double,
  double,
  double,
  double,
  double,
  double,
  double,
);

const _oats = ('Rolled Oats', 379.0, 13.2, 67.7, 6.5, 10.1, 1.0, 6.0);
const _milk = ('Semi-Skimmed Milk', 46.0, 3.5, 4.7, 1.7, 0.0, 4.7, 44.0);
const _banana = ('Banana', 89.0, 1.1, 22.8, 0.3, 2.6, 12.2, 1.0);
const _blueberries = ('Blueberries', 57.0, 0.7, 14.5, 0.3, 2.4, 10.0, 1.0);
const _greekYogurt = (
  'Greek Yogurt (0%)',
  59.0,
  10.3,
  3.6,
  0.4,
  0.0,
  3.2,
  36.0,
);
const _eggs = ('Whole Egg', 143.0, 12.6, 0.7, 9.5, 0.0, 0.4, 142.0);
const _toast = ('Wholemeal Bread', 247.0, 13.0, 41.0, 3.4, 7.0, 6.0, 450.0);
const _chicken = ('Chicken Breast', 165.0, 31.0, 0.0, 3.6, 0.0, 0.0, 74.0);
const _rice = ('Basmati Rice (cooked)', 121.0, 3.5, 25.2, 0.4, 0.4, 0.1, 1.0);
const _broccoli = ('Broccoli', 34.0, 2.8, 6.6, 0.4, 2.6, 1.7, 33.0);
const _salmon = ('Atlantic Salmon', 208.0, 20.4, 0.0, 13.4, 0.0, 0.0, 59.0);
const _potato = ('Sweet Potato', 86.0, 1.6, 20.1, 0.1, 3.0, 4.2, 55.0);
const _beef = ('Lean Beef Mince (5%)', 137.0, 21.4, 0.0, 5.5, 0.0, 0.0, 66.0);
const _pasta = (
  'Wholewheat Pasta (cooked)',
  149.0,
  5.9,
  30.0,
  1.7,
  3.9,
  0.8,
  4.0,
);
const _tomatoSauce = ('Tomato Sauce', 29.0, 1.4, 5.3, 0.2, 1.5, 4.0, 380.0);
const _tuna = ('Tuna in Spring Water', 109.0, 25.0, 0.0, 1.0, 0.0, 0.0, 320.0);
const _wrap = ('Wholemeal Wrap', 299.0, 9.4, 47.0, 7.2, 6.3, 2.4, 760.0);
const _avocado = ('Avocado', 160.0, 2.0, 8.5, 14.7, 6.7, 0.7, 7.0);
const _almonds = ('Almonds', 579.0, 21.2, 21.6, 49.9, 12.5, 4.4, 1.0);
const _apple = ('Apple', 52.0, 0.3, 13.8, 0.2, 2.4, 10.4, 1.0);
const _tofu = ('Firm Tofu', 144.0, 15.8, 2.8, 8.7, 2.3, 0.6, 14.0);
const _noodles = ('Egg Noodles (cooked)', 138.0, 4.5, 25.2, 2.1, 1.2, 0.4, 5.0);
const _peppers = ('Red Pepper', 31.0, 1.0, 6.0, 0.3, 2.1, 4.2, 4.0);
const _darkChocolate = (
  'Dark Chocolate (70%)',
  598.0,
  7.8,
  45.9,
  42.6,
  10.9,
  24.0,
  20.0,
);

final _nonWord = RegExp('[^a-z0-9]+');

_ItemDraft _food(_Food food, double grams) => (itemId) {
  final (name, kcal, protein, carbs, fat, fiber, sugar, sodium) = food;
  final factor = grams / 100;
  return MealItemModel(
    itemId: itemId,
    sourceType: MealItemSourceType.ingredient,
    sourceId: 'sample-food-${name.toLowerCase().replaceAll(_nonWord, '-')}',
    displayName: name,
    amount: grams,
    unit: 'g',
    resolvedGrams: grams,
    nutrients: NutrientMap({
      NutrientKey.calories: kcal * factor,
      NutrientKey.protein: protein * factor,
      NutrientKey.carbs: carbs * factor,
      NutrientKey.fatTotal: fat * factor,
      NutrientKey.fiber: fiber * factor,
      NutrientKey.sugar: sugar * factor,
      NutrientKey.sodiumMg: sodium * factor,
    }),
  );
};

_ItemDraft _smoothie() =>
    (itemId) => MealItemModel(
      itemId: itemId,
      sourceType: MealItemSourceType.recipe,
      sourceId: 'sample-recipe-protein-smoothie',
      displayName: 'Protein Smoothie',
      amount: 1,
      unit: 'serving',
      resolvedMilliliters: 350,
      nutrients: const NutrientMap({
        NutrientKey.calories: 280,
        NutrientKey.protein: 32,
        NutrientKey.carbs: 25,
        NutrientKey.fatTotal: 8,
        NutrientKey.fiber: 4,
        NutrientKey.sugar: 18,
      }),
    );

_ItemDraft _quickAdd(
  String name, {
  required double kcal,
  required double protein,
  required double carbs,
  required double fat,
}) =>
    (itemId) => MealItemModel(
      itemId: itemId,
      sourceType: MealItemSourceType.quickAdd,
      sourceId: 'quick_add',
      displayName: name,
      amount: 1,
      unit: 'serving',
      nutrients: NutrientMap({
        NutrientKey.calories: kcal,
        NutrientKey.protein: protein,
        NutrientKey.carbs: carbs,
        NutrientKey.fatTotal: fat,
      }),
    );

/// Meals for today, yesterday and so on back to five days ago. Six days ago
/// has none: only its Apple Health import.
final List<List<_Meal>> _week = [
  [
    _meal(7, 30, [_food(_oats, 85), _food(_milk, 350), _food(_banana, 170)]),
    _meal(12, 45, [
      _food(_chicken, 210),
      _food(_rice, 280),
      _food(_broccoli, 140),
    ]),
    _meal(15, 30, [_food(_greekYogurt, 240), _food(_blueberries, 110)]),
    _meal(19, 15, [
      _food(_salmon, 195),
      _food(_potato, 350),
      _food(_broccoli, 125),
    ]),
  ],
  [
    _meal(8, 0, [_food(_eggs, 150), _food(_toast, 80), _food(_avocado, 70)]),
    _meal(13, 0, [_food(_tuna, 155), _food(_wrap, 64), _food(_peppers, 85)]),
    _meal(16, 0, [_smoothie()], notes: 'After training'),
    _meal(19, 45, [
      _food(_beef, 210),
      _food(_pasta, 310),
      _food(_tomatoSauce, 170),
    ]),
  ],
  [
    _meal(7, 15, [
      _food(_greekYogurt, 280),
      _food(_oats, 55),
      _food(_blueberries, 140),
    ]),
    _meal(12, 30, [
      _food(_chicken, 195),
      _food(_wrap, 64),
      _food(_avocado, 55),
    ]),
    _meal(18, 50, [
      _food(_tofu, 250),
      _food(_noodles, 280),
      _food(_peppers, 140),
    ]),
    _meal(21, 0, [_food(_darkChocolate, 20)]),
  ],
  [
    _meal(9, 30, [_food(_eggs, 100), _food(_toast, 80)], notes: 'Late start'),
    _meal(13, 30, [
      _quickAdd('Café sandwich', kcal: 455, protein: 24, carbs: 48, fat: 17.5),
      _food(_apple, 210),
    ]),
    _meal(16, 15, [_food(_almonds, 30)]),
    _meal(20, 0, [
      _food(_salmon, 180),
      _food(_rice, 250),
      _food(_broccoli, 170),
    ]),
  ],
  [
    _meal(7, 0, [
      _food(_oats, 100),
      _food(_milk, 420),
      _food(_blueberries, 85),
    ]),
    _meal(12, 15, [_food(_beef, 170), _food(_rice, 310), _food(_peppers, 110)]),
    _meal(15, 45, [_smoothie(), _food(_banana, 155)]),
    _meal(19, 30, [
      _food(_chicken, 225),
      _food(_potato, 310),
      _food(_broccoli, 140),
    ]),
  ],
  [
    _meal(8, 15, [
      _food(_greekYogurt, 240),
      _food(_banana, 140),
      _food(_almonds, 15),
    ]),
    _meal(13, 10, [
      _food(_tuna, 170),
      _food(_pasta, 250),
      _food(_tomatoSauce, 140),
    ]),
    _meal(19, 0, [
      _food(_tofu, 210),
      _food(_noodles, 310),
      _food(_broccoli, 110),
    ]),
    _meal(21, 30, [_food(_apple, 195), _food(_darkChocolate, 15)]),
  ],
];
