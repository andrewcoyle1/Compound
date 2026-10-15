import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/nutrition/cubit/food_log_settings_cubit.dart';
import 'package:compound/settings/nutrition/logic/nutrition_settings_labels.dart';
import 'package:compound/settings/nutrition/view/favourite_measurements_page.dart';
import 'package:compound/settings/nutrition/view/logger_banner_page.dart';
import 'package:compound/settings/nutrition/view/logger_food_tiles_page.dart';
import 'package:compound/settings/nutrition/view/nutrition_settings_widgets.dart';
import 'package:compound/settings/nutrition/view/timeline_food_tiles_page.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Provides a [FoodLogSettingsCubit] tracked as [screen] to [child]: the
/// Food Log screen and each one it opens.
class FoodLogSettingsProvider extends StatelessWidget {
  const new({required this.screen, required this.child, super.key});

  /// The Swift view's name, for analytics.
  final String screen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final uid = signedInUid(context);
    if (uid == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => FoodLogSettingsCubit(
        nutritionRepository: context.read<NutritionRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        uid: uid,
        screen: screen,
      ),
      child: child,
    );
  }
}

/// How the food log looks and logs (Swift `FoodLogSettingsView`). Every
/// change saves at once. The Premove switch stays hidden, as in Swift:
/// nothing reads it yet.
class FoodLogSettingsPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'food-log';
  static const name = 'settingsFoodLog';

  @override
  Widget build(BuildContext context) => const FoodLogSettingsProvider(
    screen: 'FoodLogSettingsView',
    child: FoodLogSettingsView(),
  );
}

class FoodLogSettingsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<FoodLogSettingsCubit>();
    final locale = Localizations.localeOf(context).toLanguageTag();
    void open(String name) => unawaited(context.pushNamed(name));
    Widget toggle(
      String key,
      String title, {
      required bool value,
      String? subtitle,
      IconData? icon,
    }) => AppListRowToggle(
      title: title,
      subtitle: subtitle,
      icon: icon,
      value: value,
      onChanged: (value) => unawaited(cubit.set(key, value)),
    );
    Widget hourRow(String key, int value, String title) => ChoiceRow<int>(
      title: title,
      value: value,
      options: [for (var hour = 0; hour < 24; hour++) hour],
      label: (hour) => hourLabel(hour, locale),
      onChanged: (hour) => unawaited(cubit.set(key, hour)),
    );
    return SettingsDocumentScaffold<FoodLogSettingsCubit, FoodLogSettings>(
      title: l10n.foodLogSettingsTitle,
      sections: (context, s) => [
        AppSection(
          header: l10n.foodLogSettingsReportingHeader,
          children: [
            toggle(
              FoodLogSettingsKeys.showOverages,
              l10n.foodLogSettingsShowOverages,
              value: s.showOverages,
              subtitle: s.showOverages
                  ? l10n.foodLogSettingsOveragesOn
                  : l10n.foodLogSettingsOveragesOff,
            ),
          ],
        ),
        AppSection(
          header: l10n.foodLogSettingsTimelineHeader,
          children: [
            hourRow(
              FoodLogSettingsKeys.startHour,
              s.startHour,
              l10n.foodLogSettingsStartHour,
            ),
            hourRow(
              FoodLogSettingsKeys.endHour,
              s.endHour,
              l10n.foodLogSettingsEndHour,
            ),
            ChoiceRow<TimestampSide>(
              title: l10n.foodLogSettingsTimestampSide,
              value: s.timestampSide,
              options: TimestampSide.values,
              label: (side) => switch (side) {
                TimestampSide.left => l10n.foodLogSettingsLeft,
                TimestampSide.right => l10n.foodLogSettingsRight,
              },
              onChanged: (side) =>
                  unawaited(cubit.set(FoodLogSettingsKeys.timestampSide, side)),
            ),
            toggle(
              FoodLogSettingsKeys.showAddFoodsButton,
              l10n.foodLogSettingsAddFoods,
              value: s.showAddFoodsButton,
              subtitle: l10n.foodLogSettingsAddFoodsDetail,
              icon: AppSymbols.add,
            ),
            toggle(
              FoodLogSettingsKeys.showsFoodTimestamps,
              l10n.foodLogSettingsTimestamps,
              value: s.showsFoodTimestamps,
              subtitle: l10n.foodLogSettingsTimestampsDetail,
              icon: AppSymbols.duration,
            ),
            toggle(
              FoodLogSettingsKeys.showHourlyMacroTotals,
              l10n.foodLogSettingsHourlyTotals,
              value: s.showHourlyMacroTotals,
            ),
            toggle(
              FoodLogSettingsKeys.showCalendarWeekBanner,
              l10n.foodLogSettingsWeekBanner,
              value: s.showCalendarWeekBanner,
            ),
          ],
        ),
        AppSection(
          header: l10n.foodLogSettingsSearchHeader,
          children: [
            toggle(
              FoodLogSettingsKeys.showBrandedFoods,
              l10n.foodLogSettingsBranded,
              value: s.showBrandedFoods,
            ),
            toggle(
              FoodLogSettingsKeys.showOpenFoodFactsFoods,
              l10n.foodLogSettingsOpenFoodFacts,
              value: s.showOpenFoodFactsFoods,
            ),
          ],
        ),
        AppSection(
          header: l10n.foodLogSettingsTilesHeader,
          children: [
            AppListRowButton(
              title: l10n.foodLogSettingsTimelineTiles,
              subtitle: l10n.foodLogSettingsTimelineTilesDetail,
              onPressed: () => open(TimelineFoodTilesPage.name),
            ),
            AppListRowButton(
              title: l10n.foodLogSettingsLoggerTiles,
              subtitle: l10n.foodLogSettingsLoggerTilesDetail,
              onPressed: () => open(LoggerFoodTilesPage.name),
            ),
          ],
        ),
        AppSection(
          header: l10n.foodLogSettingsLoggerHeader,
          children: [
            AppListRowButton(
              title: l10n.foodLogSettingsLoggerBanner,
              subtitle: l10n.foodLogSettingsLoggerBannerDetail,
              onPressed: () => open(LoggerBannerPage.name),
            ),
            toggle(
              FoodLogSettingsKeys.autoSetCurrentTime,
              l10n.foodLogSettingsAutoTime,
              value: s.autoSetCurrentTime,
              subtitle: l10n.foodLogSettingsAutoTimeDetail,
            ),
            AppListRowButton(
              title: l10n.foodLogSettingsFavourites,
              subtitle: l10n.foodLogSettingsFavouritesDetail,
              onPressed: () => open(FavouriteMeasurementsPage.name),
            ),
            toggle(
              FoodLogSettingsKeys.quickAddEnabled,
              l10n.foodLogSettingsQuickAdd,
              value: s.quickAddEnabled,
              subtitle: l10n.foodLogSettingsQuickAddDetail,
            ),
          ],
        ),
      ],
    );
  }
}
