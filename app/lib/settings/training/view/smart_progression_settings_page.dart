import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/settings/training/view/workout_settings_screen.dart';
import 'package:compound_models/compound_models.dart';

/// Smart Progression (Swift `SmartProgressionSettingsView`): how a session's
/// sets are first filled, whether targets update as sets are logged, and
/// whether weight or reps go up first.
class SmartProgressionSettingsPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'smart-progression';
  static const name = 'settingsSmartProgression';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WorkoutSettingsScreen(
      screen: 'SmartProgressionSettingsView',
      title: l10n.workoutSettingsSmartProgression,
      sections: (context, settings, change) => [
        MethodInfoHeader(
          title: l10n.smartProgressionBehaviorHeader,
          info: MethodInfo.smartProgression(l10n),
        ),
        AppSection(
          children: [
            SettingsMenuRow<InitialLogFillOption>(
              title: l10n.smartProgressionInitialLogFill,
              icon: AppSymbols.note,
              value: settings.smartProgressionInitialLogFill,
              options: [
                for (final option in InitialLogFillOption.values)
                  (
                    option,
                    switch (option) {
                      InitialLogFillOption.smartProgression =>
                        l10n.smartProgressionFillSmart,
                      InitialLogFillOption.previousValues =>
                        l10n.smartProgressionFillPrevious,
                      InitialLogFillOption.empty =>
                        l10n.smartProgressionFillEmpty,
                    },
                  ),
              ],
              onChanged: (option) => change({
                WorkoutSettingsKeys.smartProgressionInitialLogFill:
                    option.value,
              }),
            ),
            AppListRowToggle(
              title: l10n.smartProgressionApplyInSession,
              subtitle: l10n.smartProgressionApplyInSessionSubtitle,
              icon: AppSymbols.smartProgression,
              value: settings.smartProgressionApplyInSession,
              onChanged: (value) => change({
                WorkoutSettingsKeys.smartProgressionApplyInSession: value,
              }),
            ),
            SettingsMenuRow<ProgressionAdjustmentMode>(
              title: l10n.smartProgressionAdjustmentMode,
              icon: AppSymbols.weight,
              value: settings.smartProgressionAdjustmentMode,
              options: [
                for (final mode in ProgressionAdjustmentMode.values)
                  (
                    mode,
                    switch (mode) {
                      ProgressionAdjustmentMode.weightFirst =>
                        l10n.smartProgressionWeightFirst,
                      ProgressionAdjustmentMode.repsFirst =>
                        l10n.smartProgressionRepsFirst,
                    },
                  ),
              ],
              onChanged: (mode) => change({
                WorkoutSettingsKeys.smartProgressionAdjustmentMode: mode.value,
              }),
            ),
          ],
        ),
      ],
    );
  }
}
