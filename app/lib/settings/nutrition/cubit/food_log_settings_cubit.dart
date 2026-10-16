import 'package:compound/settings/nutrition/cubit/settings_document_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// The food log settings (`users/{uid}/food_log_settings/food_log_settings`)
/// for the Food Log screen and the four it opens, each tracked under its
/// Swift view's name (Swift `FoodLogSettingsPresenter`,
/// `LoggerBannerPresenter`, `LoggerFoodTilesPresenter`,
/// `TimelineFoodTilesPresenter` and `FavouriteMeasurementsPresenter`).
class FoodLogSettingsCubit extends SettingsDocumentCubit<FoodLogSettings> {
  new({
    required NutritionRepository nutritionRepository,
    required super.analytics,
    required String uid,
    required super.screen,
  }) : super(
         document: nutritionRepository.watchFoodLogSettings(uid),
         save: nutritionRepository.saveFoodLogSettings,
         decode: FoodLogSettings.fromFirestore,
         encode: (settings) => settings.toFirestore(),
       );

  /// The units Favorite Measurements offers, in Swift's order.
  static const measurements = [
    'g',
    'oz',
    'ml',
    'cup',
    'tbsp',
    'tsp',
    'serving',
    'kcal',
    'kJ',
  ];

  /// Pins [measurement] to serving sizes, or unpins it: added at the end,
  /// removed wherever it is.
  Future<void> toggleMeasurement(String measurement) => update((data) {
    final current = state.settings!.favouriteMeasurements;
    data[FoodLogSettingsKeys.favouriteMeasurements] =
        current.contains(measurement)
        ? [
            for (final m in current)
              if (m != measurement) m,
          ]
        : [...current, measurement];
  });
}
