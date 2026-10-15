import 'dart:async';

import 'package:compound_models/compound_models.dart';
import 'package:nutrition_repository/src/meal_days.dart';
import 'package:nutrition_repository/src/nutrition_repository.dart';
import 'package:nutrition_repository/src/sample_nutrition.dart';

/// [NutritionRepository] in memory, for the staging flavor and tests. Seed
/// it with [sampleMealLogs] and [sampleDietPlan].
///
/// Saves behave as Firestore's do, so staging behaves as the real app: they
/// merge over the stored document field by field, and every watcher sees
/// the change.
class InMemoryNutritionRepository implements NutritionRepository {
  /// Creates an [InMemoryNutritionRepository] holding `meals`, a
  /// `dietPlan` (stored, like Firestore's, under its `planId`) and
  /// `foodLogSettings`.
  new({
    List<MealLogModel> meals = const [],
    DietPlan? dietPlan,
    this._foodLogSettings,
  }) : _meals = List.of(meals),
       _dietPlans = {?dietPlan?.planId: ?dietPlan};

  final List<MealLogModel> _meals;
  final Map<String, DietPlan> _dietPlans;
  final FoodLogSettings? _foodLogSettings;
  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<List<MealLogModel>> watchMeals(String uid) => _watch(
    () => withoutDuplicateHealthImports([
      for (final meal in _meals)
        if (meal.authorId == uid) meal,
    ]),
  );

  @override
  Stream<DietPlan?> watchDietPlan(String uid) => _watch(() => _dietPlans[uid]);

  @override
  Stream<FoodLogSettings> watchFoodLogSettings(String uid) => Stream.value(
    _foodLogSettings?.authorId == uid
        ? _foodLogSettings!
        : FoodLogSettings(authorId: uid),
  );

  @override
  Future<void> saveMeal(MealLogModel meal) async {
    final index = _meals.indexWhere(
      (stored) =>
          stored.authorId == meal.authorId && stored.mealId == meal.mealId,
    );
    if (index < 0) {
      _meals.add(meal);
    } else {
      _meals[index] = MealLogModel.fromFirestore({
        ..._meals[index].toFirestore(),
        ...meal.toFirestore(),
      });
    }
    _changes.add(null);
  }

  @override
  Future<void> saveDietPlan(DietPlan plan) async {
    _dietPlans[plan.planId] = DietPlan.fromFirestore({
      ...?_dietPlans[plan.planId]?.toFirestore(),
      ...plan.toFirestore(),
    });
    _changes.add(null);
  }

  /// [read] now and after every write, as a Firestore listener emits.
  Stream<T> _watch<T>(T Function() read) => Stream.multi((listener) {
    listener.add(read());
    final subscription = _changes.stream.listen((_) => listener.add(read()));
    // Not `subscription.cancel` itself: `first` would wait on the Future
    // that returns, which never completes under a widget test's fake clock.
    listener.onCancel = () => unawaited(subscription.cancel());
  });
}
