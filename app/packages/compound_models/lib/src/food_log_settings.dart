import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/nutrition_enums.dart';

/// Field names of `users/{uid}/food_log_settings/food_log_settings`, exactly
/// as the Swift `CodingKeys` spell them.
abstract final class FoodLogSettingsKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `show_overages`.
  static const showOverages = 'show_overages';

  /// `shows_food_timestamps`.
  static const showsFoodTimestamps = 'shows_food_timestamps';

  /// `show_hourly_macro_totals`.
  static const showHourlyMacroTotals = 'show_hourly_macro_totals';

  /// `show_calendar_week_banner`.
  static const showCalendarWeekBanner = 'show_calendar_week_banner';

  /// `premove`.
  static const premove = 'premove';

  /// `timestamp_side`.
  static const timestampSide = 'timestamp_side';

  /// `show_add_foods_button`.
  static const showAddFoodsButton = 'show_add_foods_button';

  /// `start_hour`.
  static const startHour = 'start_hour';

  /// `end_hour`.
  static const endHour = 'end_hour';

  /// `hide_food_details`.
  static const hideFoodDetails = 'hide_food_details';

  /// `hide_empty_hours`.
  static const hideEmptyHours = 'hide_empty_hours';

  /// `show_branded_foods`.
  static const showBrandedFoods = 'show_branded_foods';

  /// `show_open_food_facts_foods`.
  static const showOpenFoodFactsFoods = 'show_open_food_facts_foods';

  /// `show_food_image_in_timeline`.
  static const showFoodImageInTimeline = 'show_food_image_in_timeline';

  /// `show_calories_in_timeline`.
  static const showCaloriesInTimeline = 'show_calories_in_timeline';

  /// `show_macros_in_timeline`.
  static const showMacrosInTimeline = 'show_macros_in_timeline';

  /// `show_food_image_in_logger`.
  static const showFoodImageInLogger = 'show_food_image_in_logger';

  /// `show_calories_in_logger`.
  static const showCaloriesInLogger = 'show_calories_in_logger';

  /// `show_macros_in_logger`.
  static const showMacrosInLogger = 'show_macros_in_logger';

  /// `show_portion_in_logger`.
  static const showPortionInLogger = 'show_portion_in_logger';

  /// `show_calories_ring`.
  static const showCaloriesRing = 'show_calories_ring';

  /// `show_protein_ring`.
  static const showProteinRing = 'show_protein_ring';

  /// `show_fat_ring`.
  static const showFatRing = 'show_fat_ring';

  /// `show_carbs_ring`.
  static const showCarbsRing = 'show_carbs_ring';

  /// `auto_set_current_time`.
  static const autoSetCurrentTime = 'auto_set_current_time';

  /// `favourite_measurements`.
  static const favouriteMeasurements = 'favourite_measurements';

  /// `favourite_food_ids`.
  static const favouriteFoodIds = 'favourite_food_ids';

  /// `favourite_recipe_ids`.
  static const favouriteRecipeIds = 'favourite_recipe_ids';

  /// `quick_add_enabled`.
  static const quickAddEnabled = 'quick_add_enabled';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    showOverages,
    showsFoodTimestamps,
    showHourlyMacroTotals,
    showCalendarWeekBanner,
    premove,
    timestampSide,
    showAddFoodsButton,
    startHour,
    endHour,
    hideFoodDetails,
    hideEmptyHours,
    showBrandedFoods,
    showOpenFoodFactsFoods,
    showFoodImageInTimeline,
    showCaloriesInTimeline,
    showMacrosInTimeline,
    showFoodImageInLogger,
    showCaloriesInLogger,
    showMacrosInLogger,
    showPortionInLogger,
    showCaloriesRing,
    showProteinRing,
    showFatRing,
    showCarbsRing,
    autoSetCurrentTime,
    favouriteMeasurements,
    favouriteFoodIds,
    favouriteRecipeIds,
    quickAddEnabled,
  ];
}

/// The food log's display and search settings (Swift `FoodLogSettings`),
/// one document per user. The defaults are Swift's, which the app uses when
/// the user has no document.
class const FoodLogSettings({
  /// The owner.
  required final String authorId,

  /// The document id, always `food_log_settings`.
  final String id = 'food_log_settings',

  /// Show how far over a target the day is.
  final bool showOverages = false,

  /// Show each food's time on the timeline.
  final bool showsFoodTimestamps = true,

  /// Show each hour's macro totals.
  final bool showHourlyMacroTotals = true,

  /// Show the week strip above the timeline.
  final bool showCalendarWeekBanner = true,

  /// Pre-log meals on the timeline; saved, but nothing reads it yet.
  final bool premove = false,

  /// Which side of the timeline times sit on.
  final TimestampSide timestampSide = TimestampSide.left,

  /// Show the add-foods button.
  final bool showAddFoodsButton = true,

  /// The timeline's first hour (0-23).
  final int startHour = 7,

  /// The timeline's last hour (0-23).
  final int endHour = 23,

  /// Collapse each row to its name.
  final bool hideFoodDetails = false,

  /// Leave hours with nothing logged off the timeline.
  final bool hideEmptyHours = false,

  /// Include branded foods in search.
  final bool showBrandedFoods = true,

  /// Include Open Food Facts in search.
  final bool showOpenFoodFactsFoods = true,

  /// Timeline tiles show the food's image.
  final bool showFoodImageInTimeline = true,

  /// Timeline tiles show calories.
  final bool showCaloriesInTimeline = true,

  /// Timeline tiles show macros.
  final bool showMacrosInTimeline = true,

  /// Logger tiles show the food's image.
  final bool showFoodImageInLogger = true,

  /// Logger tiles show calories.
  final bool showCaloriesInLogger = true,

  /// Logger tiles show macros.
  final bool showMacrosInLogger = true,

  /// Logger tiles show the portion.
  final bool showPortionInLogger = true,

  /// The logger banner shows the calories ring.
  final bool showCaloriesRing = true,

  /// The logger banner shows the protein ring.
  final bool showProteinRing = true,

  /// The logger banner shows the fat ring.
  final bool showFatRing = true,

  /// The logger banner shows the carbs ring.
  final bool showCarbsRing = true,

  /// New food takes the current time.
  final bool autoSetCurrentTime = false,

  /// Units offered first.
  final List<String> favouriteMeasurements = const [
    'g',
    'oz',
    'ml',
    'cup',
    'serving',
  ],

  /// The user's favourite foods, as ids.
  final List<String> favouriteFoodIds = const [],

  /// The user's favourite recipes, as ids.
  final List<String> favouriteRecipeIds = const [],

  /// Offer quick add in the logger.
  final bool quickAddEnabled = false,
}) {
  /// Creates a [FoodLogSettings].
  this;

  /// Decodes as Swift's synthesized decoder does: **every field is
  /// required**, the defaults above notwithstanding, so a document missing
  /// any key throws, as it fails to decode on iOS.
  factory fromFirestore(Map<String, Object?> data) => FoodLogSettings(
    id: data[FoodLogSettingsKeys.id]! as String,
    authorId: data[FoodLogSettingsKeys.authorId]! as String,
    showOverages: data[FoodLogSettingsKeys.showOverages]! as bool,
    showsFoodTimestamps: data[FoodLogSettingsKeys.showsFoodTimestamps]! as bool,
    showHourlyMacroTotals:
        data[FoodLogSettingsKeys.showHourlyMacroTotals]! as bool,
    showCalendarWeekBanner:
        data[FoodLogSettingsKeys.showCalendarWeekBanner]! as bool,
    premove: data[FoodLogSettingsKeys.premove]! as bool,
    timestampSide: enumFromValue(
      TimestampSide.values,
      data[FoodLogSettingsKeys.timestampSide]! as String,
    ),
    showAddFoodsButton: data[FoodLogSettingsKeys.showAddFoodsButton]! as bool,
    startHour: readInt(data[FoodLogSettingsKeys.startHour]),
    endHour: readInt(data[FoodLogSettingsKeys.endHour]),
    hideFoodDetails: data[FoodLogSettingsKeys.hideFoodDetails]! as bool,
    hideEmptyHours: data[FoodLogSettingsKeys.hideEmptyHours]! as bool,
    showBrandedFoods: data[FoodLogSettingsKeys.showBrandedFoods]! as bool,
    showOpenFoodFactsFoods:
        data[FoodLogSettingsKeys.showOpenFoodFactsFoods]! as bool,
    showFoodImageInTimeline:
        data[FoodLogSettingsKeys.showFoodImageInTimeline]! as bool,
    showCaloriesInTimeline:
        data[FoodLogSettingsKeys.showCaloriesInTimeline]! as bool,
    showMacrosInTimeline:
        data[FoodLogSettingsKeys.showMacrosInTimeline]! as bool,
    showFoodImageInLogger:
        data[FoodLogSettingsKeys.showFoodImageInLogger]! as bool,
    showCaloriesInLogger:
        data[FoodLogSettingsKeys.showCaloriesInLogger]! as bool,
    showMacrosInLogger: data[FoodLogSettingsKeys.showMacrosInLogger]! as bool,
    showPortionInLogger: data[FoodLogSettingsKeys.showPortionInLogger]! as bool,
    showCaloriesRing: data[FoodLogSettingsKeys.showCaloriesRing]! as bool,
    showProteinRing: data[FoodLogSettingsKeys.showProteinRing]! as bool,
    showFatRing: data[FoodLogSettingsKeys.showFatRing]! as bool,
    showCarbsRing: data[FoodLogSettingsKeys.showCarbsRing]! as bool,
    autoSetCurrentTime: data[FoodLogSettingsKeys.autoSetCurrentTime]! as bool,
    favouriteMeasurements: readStringList(
      data[FoodLogSettingsKeys.favouriteMeasurements],
    ),
    favouriteFoodIds: readStringList(
      data[FoodLogSettingsKeys.favouriteFoodIds],
    ),
    favouriteRecipeIds: readStringList(
      data[FoodLogSettingsKeys.favouriteRecipeIds],
    ),
    quickAddEnabled: data[FoodLogSettingsKeys.quickAddEnabled]! as bool,
  );

  /// The Firestore-shaped map Swift writes: every field.
  Map<String, Object?> toFirestore() => {
    FoodLogSettingsKeys.id: id,
    FoodLogSettingsKeys.authorId: authorId,
    FoodLogSettingsKeys.showOverages: showOverages,
    FoodLogSettingsKeys.showsFoodTimestamps: showsFoodTimestamps,
    FoodLogSettingsKeys.showHourlyMacroTotals: showHourlyMacroTotals,
    FoodLogSettingsKeys.showCalendarWeekBanner: showCalendarWeekBanner,
    FoodLogSettingsKeys.premove: premove,
    FoodLogSettingsKeys.timestampSide: timestampSide.value,
    FoodLogSettingsKeys.showAddFoodsButton: showAddFoodsButton,
    FoodLogSettingsKeys.startHour: startHour,
    FoodLogSettingsKeys.endHour: endHour,
    FoodLogSettingsKeys.hideFoodDetails: hideFoodDetails,
    FoodLogSettingsKeys.hideEmptyHours: hideEmptyHours,
    FoodLogSettingsKeys.showBrandedFoods: showBrandedFoods,
    FoodLogSettingsKeys.showOpenFoodFactsFoods: showOpenFoodFactsFoods,
    FoodLogSettingsKeys.showFoodImageInTimeline: showFoodImageInTimeline,
    FoodLogSettingsKeys.showCaloriesInTimeline: showCaloriesInTimeline,
    FoodLogSettingsKeys.showMacrosInTimeline: showMacrosInTimeline,
    FoodLogSettingsKeys.showFoodImageInLogger: showFoodImageInLogger,
    FoodLogSettingsKeys.showCaloriesInLogger: showCaloriesInLogger,
    FoodLogSettingsKeys.showMacrosInLogger: showMacrosInLogger,
    FoodLogSettingsKeys.showPortionInLogger: showPortionInLogger,
    FoodLogSettingsKeys.showCaloriesRing: showCaloriesRing,
    FoodLogSettingsKeys.showProteinRing: showProteinRing,
    FoodLogSettingsKeys.showFatRing: showFatRing,
    FoodLogSettingsKeys.showCarbsRing: showCarbsRing,
    FoodLogSettingsKeys.autoSetCurrentTime: autoSetCurrentTime,
    FoodLogSettingsKeys.favouriteMeasurements: favouriteMeasurements,
    FoodLogSettingsKeys.favouriteFoodIds: favouriteFoodIds,
    FoodLogSettingsKeys.favouriteRecipeIds: favouriteRecipeIds,
    FoodLogSettingsKeys.quickAddEnabled: quickAddEnabled,
  };
}
