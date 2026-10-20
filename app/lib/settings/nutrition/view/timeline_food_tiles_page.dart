import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/nutrition/view/food_log_settings_page.dart';
import 'package:compound/settings/nutrition/view/food_log_toggles_list.dart';
import 'package:compound_models/compound_models.dart';

/// What a food on the timeline shows (Swift `TimelineFoodTilesView`).
class TimelineFoodTilesPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'timeline-tiles';
  static const name = 'settingsTimelineFoodTiles';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FoodLogSettingsProvider(
      screen: 'TimelineFoodTilesView',
      child: FoodLogTogglesView(
        title: l10n.foodLogSettingsTimelineTiles,
        toggles: [
          (
            key: FoodLogSettingsKeys.showFoodImageInTimeline,
            read: (s) => s.showFoodImageInTimeline,
            title: l10n.timelineTilesImage,
            subtitle: l10n.timelineTilesImageDetail,
          ),
          (
            key: FoodLogSettingsKeys.showCaloriesInTimeline,
            read: (s) => s.showCaloriesInTimeline,
            title: l10n.timelineTilesCalories,
            subtitle: l10n.timelineTilesCaloriesDetail,
          ),
          (
            key: FoodLogSettingsKeys.showMacrosInTimeline,
            read: (s) => s.showMacrosInTimeline,
            title: l10n.timelineTilesMacros,
            subtitle: l10n.timelineTilesMacrosDetail,
          ),
        ],
      ),
    );
  }
}
