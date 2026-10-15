import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/nutrition/view/food_log_settings_page.dart';
import 'package:compound/settings/nutrition/view/food_log_toggles_list.dart';
import 'package:compound_models/compound_models.dart';

/// Which rings the top of the plate shows (Swift `LoggerBannerView`).
class LoggerBannerPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'banner';
  static const name = 'settingsLoggerBanner';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FoodLogSettingsProvider(
      screen: 'LoggerBannerView',
      child: FoodLogTogglesView(
        title: l10n.foodLogSettingsLoggerBanner,
        toggles: [
          (
            key: FoodLogSettingsKeys.showCaloriesRing,
            read: (s) => s.showCaloriesRing,
            title: l10n.loggerBannerCalories,
            subtitle: l10n.loggerBannerCaloriesDetail,
          ),
          (
            key: FoodLogSettingsKeys.showProteinRing,
            read: (s) => s.showProteinRing,
            title: l10n.loggerBannerProtein,
            subtitle: l10n.loggerBannerProteinDetail,
          ),
          (
            key: FoodLogSettingsKeys.showFatRing,
            read: (s) => s.showFatRing,
            title: l10n.loggerBannerFat,
            subtitle: l10n.loggerBannerFatDetail,
          ),
          (
            key: FoodLogSettingsKeys.showCarbsRing,
            read: (s) => s.showCarbsRing,
            title: l10n.loggerBannerCarbs,
            subtitle: l10n.loggerBannerCarbsDetail,
          ),
        ],
      ),
    );
  }
}
