import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/nutrition/view/food_log_settings_page.dart';
import 'package:compound/settings/nutrition/view/food_log_toggles_list.dart';
import 'package:compound_models/compound_models.dart';

/// What a food search result shows (Swift `LoggerFoodTilesView`).
class LoggerFoodTilesPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'logger-tiles';
  static const name = 'settingsLoggerFoodTiles';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FoodLogSettingsProvider(
      screen: 'LoggerFoodTilesView',
      child: FoodLogTogglesView(
        title: l10n.foodLogSettingsLoggerTiles,
        toggles: [
          (
            key: FoodLogSettingsKeys.showFoodImageInLogger,
            read: (s) => s.showFoodImageInLogger,
            title: l10n.loggerTilesImage,
            subtitle: l10n.loggerTilesImageDetail,
          ),
          (
            key: FoodLogSettingsKeys.showCaloriesInLogger,
            read: (s) => s.showCaloriesInLogger,
            title: l10n.loggerTilesCalories,
            subtitle: l10n.loggerTilesCaloriesDetail,
          ),
          (
            key: FoodLogSettingsKeys.showMacrosInLogger,
            read: (s) => s.showMacrosInLogger,
            title: l10n.loggerTilesMacros,
            subtitle: l10n.loggerTilesMacrosDetail,
          ),
          (
            key: FoodLogSettingsKeys.showPortionInLogger,
            read: (s) => s.showPortionInLogger,
            title: l10n.loggerTilesPortion,
            subtitle: l10n.loggerTilesPortionDetail,
          ),
        ],
      ),
    );
  }
}
