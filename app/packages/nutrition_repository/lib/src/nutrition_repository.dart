import 'package:compound_models/compound_models.dart';
import 'package:nutrition_repository/src/meal_days.dart';

/// The signed-in user's nutrition data.
abstract interface class NutritionRepository {
  /// The meals at `users/{uid}/meal_logs` whose author is [uid], as the
  /// Swift app's listener reads them, less the Apple Health imports
  /// [withoutDuplicateHealthImports] drops. Re-emitted on every change.
  ///
  /// [includeHiddenHealthImports] keeps those imports, as Swift's import
  /// reads the sync engine's whole collection: an import hidden behind a
  /// logged meal is still kept current, so it is right again if the meal is
  /// deleted. Screens leave it false.
  Stream<List<MealLogModel>> watchMeals(
    String uid, {
    bool includeHiddenHealthImports = false,
  });

  /// The plan at `diet_plans/{uid}`, or null when there is none or it
  /// cannot be read.
  Stream<DietPlan?> watchDietPlan(String uid);

  /// The settings at `users/{uid}/food_log_settings/food_log_settings`, or
  /// Swift's defaults when there is no document or it cannot be read, as
  /// `FoodLogSettingsManager` falls back.
  Stream<FoodLogSettings> watchFoodLogSettings(String uid);

  /// Saves [settings] whole to
  /// `users/{settings.authorId}/food_log_settings/food_log_settings`, merged,
  /// as `FoodLogSettingsManager.saveSettings` does (`saveDocument` is
  /// `setData(merge: true)`). Every field is written, the favourites lists
  /// whole, so a document an older build wrote without the later fields
  /// becomes one Swift's strict decoder reads again (`swift-findings.md`).
  Future<void> saveFoodLogSettings(FoodLogSettings settings);

  /// Saves [meal] to `users/{meal.authorId}/meal_logs/{meal.mealId}`,
  /// merged over anything there, as `MealLogManager.saveMeal` does
  /// (`MealLogManager.swift:88`; `saveDocument` is `setData(merge: true)`).
  /// `items` is a list, so a save replaces it whole.
  Future<void> saveMeal(MealLogModel meal);

  /// Deletes `users/{uid}/meal_logs/{mealId}`, as `MealLogManager
  /// .deleteMeal` does (`deleteDocument` is a plain `delete()`). Deleting a
  /// meal that is not there is not an error, as in Firestore.
  Future<void> deleteMeal(String uid, String mealId);

  /// Saves [plan] to `diet_plans/{plan.planId}`, merged, as
  /// `NutritionManager.saveDietPlan` does (`NutritionManager.swift:51`).
  /// The plan id must be the user's id: that is where [watchDietPlan]
  /// reads, and the rules refuse any other.
  Future<void> saveDietPlan(DietPlan plan);
}
