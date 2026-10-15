import 'package:compound_models/compound_models.dart';
import 'package:nutrition_repository/src/meal_days.dart';

/// The signed-in user's nutrition data.
abstract interface class NutritionRepository {
  /// The meals at `users/{uid}/meal_logs` whose author is [uid], as the
  /// Swift app's listener reads them, less the Apple Health imports
  /// [withoutDuplicateHealthImports] drops. Re-emitted on every change.
  Stream<List<MealLogModel>> watchMeals(String uid);

  /// The plan at `diet_plans/{uid}`, or null when there is none or it
  /// cannot be read.
  Stream<DietPlan?> watchDietPlan(String uid);

  /// The settings at `users/{uid}/food_log_settings/food_log_settings`, or
  /// Swift's defaults when there is no document or it cannot be read, as
  /// `FoodLogSettingsManager` falls back.
  Stream<FoodLogSettings> watchFoodLogSettings(String uid);

  /// Saves [meal] to `users/{meal.authorId}/meal_logs/{meal.mealId}`,
  /// merged over anything there, as `MealLogManager.saveMeal` does
  /// (`MealLogManager.swift:88`; `saveDocument` is `setData(merge: true)`).
  /// `items` is a list, so a save replaces it whole.
  Future<void> saveMeal(MealLogModel meal);

  /// Saves [plan] to `diet_plans/{plan.planId}`, merged, as
  /// `NutritionManager.saveDietPlan` does (`NutritionManager.swift:51`).
  /// The plan id must be the user's id: that is where [watchDietPlan]
  /// reads, and the rules refuse any other.
  Future<void> saveDietPlan(DietPlan plan);
}
