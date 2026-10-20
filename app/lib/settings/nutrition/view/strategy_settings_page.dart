import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/nutrition/cubit/strategy_settings_cubit.dart';
import 'package:compound/settings/nutrition/logic/nutrition_settings_labels.dart';
import 'package:compound/settings/nutrition/view/nutrition_settings_widgets.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The weekly check-in: its day, and which modules it may show (Swift
/// `StrategySettingsView`). Every change saves at once.
class StrategySettingsPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'strategy';
  static const name = 'settingsStrategy';

  @override
  Widget build(BuildContext context) {
    final uid = signedInUid(context);
    if (uid == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => StrategySettingsCubit(
        checkInRepository: context.read<CheckInRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        uid: uid,
        screen: 'StrategySettingsView',
      ),
      child: const StrategySettingsView(),
    );
  }
}

class StrategySettingsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StrategySettingsCubit>();
    Widget toggle(
      String key,
      String title, {
      required bool value,
      IconData? icon,
    }) => AppListRowToggle(
      title: title,
      icon: icon,
      value: value,
      onChanged: (value) => unawaited(cubit.set(key, value)),
    );
    return SettingsDocumentScaffold<
      StrategySettingsCubit,
      NutritionStrategySettings
    >(
      title: l10n.strategySettingsTitle,
      sections: (context, s) => [
        AppSection(
          header: l10n.strategySettingsGeneralHeader,
          children: [
            ChoiceRow<int>(
              title: l10n.strategySettingsCheckInDay,
              icon: AppSymbols.calendar,
              value: s.checkInWeekday,
              // 1 to 7, Sunday first, as Swift's `Calendar` counts.
              options: const [1, 2, 3, 4, 5, 6, 7],
              label: (weekday) => weekdayName(weekday, context.dateLocale),
              onChanged: (weekday) => unawaited(
                cubit.set(
                  NutritionStrategySettingsKeys.checkInWeekday,
                  weekday,
                ),
              ),
            ),
            toggle(
              NutritionStrategySettingsKeys.fastCheckIn,
              l10n.strategySettingsFastCheckIn,
              value: s.fastCheckIn,
              icon: AppSymbols.skip,
            ),
          ],
        ),
        AppSection(
          header: l10n.strategySettingsModulesHeader,
          footer: l10n.strategySettingsModulesFooter,
          children: [
            toggle(
              NutritionStrategySettingsKeys.partialLoggingEnabled,
              l10n.strategySettingsPartialLogging,
              value: s.partialLoggingEnabled,
            ),
            toggle(
              NutritionStrategySettingsKeys.weighInEnabled,
              l10n.strategySettingsWeighIn,
              value: s.weighInEnabled,
            ),
            toggle(
              NutritionStrategySettingsKeys.fastingEnabled,
              l10n.strategySettingsFasting,
              value: s.fastingEnabled,
            ),
            toggle(
              NutritionStrategySettingsKeys.loggingBreakEnabled,
              l10n.strategySettingsLoggingBreak,
              value: s.loggingBreakEnabled,
            ),
          ],
        ),
      ],
    );
  }
}
