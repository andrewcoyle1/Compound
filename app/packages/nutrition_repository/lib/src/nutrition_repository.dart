import 'package:compound_models/compound_models.dart';
import 'package:nutrition_repository/src/meal_days.dart';

/// The signed-in user's nutrition data, read-only.
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
}
