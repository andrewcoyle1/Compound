import 'package:compound_models/compound_models.dart';
import 'package:nutrition_repository/src/meal_days.dart';
import 'package:nutrition_repository/src/nutrition_repository.dart';
import 'package:nutrition_repository/src/sample_nutrition.dart';

/// [NutritionRepository] over fixed data, for the staging flavor and tests.
/// Seed it with [sampleMealLogs] and [sampleDietPlan].
class InMemoryNutritionRepository implements NutritionRepository {
  /// Creates an [InMemoryNutritionRepository] holding `meals`, a
  /// `dietPlan` (stored, like Firestore's, under its `planId`) and
  /// `foodLogSettings`.
  new({
    List<MealLogModel> meals = const [],
    this._dietPlan,
    this._foodLogSettings,
  }) : _meals = List.unmodifiable(meals);

  final List<MealLogModel> _meals;
  final DietPlan? _dietPlan;
  final FoodLogSettings? _foodLogSettings;

  @override
  Stream<List<MealLogModel>> watchMeals(String uid) => Stream.value(
    withoutDuplicateHealthImports([
      for (final meal in _meals)
        if (meal.authorId == uid) meal,
    ]),
  );

  @override
  Stream<DietPlan?> watchDietPlan(String uid) =>
      Stream.value(_dietPlan?.planId == uid ? _dietPlan : null);

  @override
  Stream<FoodLogSettings> watchFoodLogSettings(String uid) => Stream.value(
    _foodLogSettings?.authorId == uid
        ? _foodLogSettings!
        : FoodLogSettings(authorId: uid),
  );
}
