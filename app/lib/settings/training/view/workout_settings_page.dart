import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/training/logic/workout_settings_rules.dart';
import 'package:compound/settings/training/view/rest_timer_settings_page.dart';
import 'package:compound/settings/training/view/smart_progression_settings_page.dart';
import 'package:compound/settings/training/view/workout_settings_screen.dart';
import 'package:compound_models/compound_models.dart';
import 'package:go_router/go_router.dart';

/// Workout Settings (Swift `WorkoutSettingsView`): the tracker's switches,
/// the previous-values reference, and the way into Rest Timer and Smart
/// Progression. Each change saves at once. Exercise Assessment, which Swift
/// keeps unreachable, is not ported.
class WorkoutSettingsPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'workout';
  static const name = 'settingsWorkout';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WorkoutSettingsScreen(
      screen: 'WorkoutSettingsView',
      title: l10n.settingsWorkoutSettings,
      sections: (context, settings, change) {
        AppListRowToggle toggle(
          String title,
          String subtitle,
          String key, {
          required bool value,
        }) => AppListRowToggle(
          title: title,
          subtitle: subtitle,
          value: value,
          onChanged: (value) => change({key: value}),
        );
        return [
          AppSection(
            header: l10n.settingsGeneralHeader,
            children: [
              AppListRowButton(
                title: l10n.workoutSettingsRestTimer,
                subtitle: l10n.workoutSettingsRestTimerSubtitle,
                onPressed: () => context.pushNamed(RestTimerSettingsPage.name),
              ),
              AppListRowButton(
                title: l10n.workoutSettingsSmartProgression,
                subtitle: l10n.workoutSettingsSmartProgressionSubtitle,
                onPressed: () =>
                    context.pushNamed(SmartProgressionSettingsPage.name),
              ),
              toggle(
                l10n.workoutSettingsPropagateChanges,
                l10n.workoutSettingsPropagateChangesSubtitle,
                WorkoutSettingsKeys.propagateChanges,
                value: settings.propagateChanges,
              ),
              toggle(
                l10n.workoutSettingsRirTracking,
                l10n.workoutSettingsRirTrackingSubtitle,
                WorkoutSettingsKeys.rirTracking,
                value: settings.rirTracking,
              ),
              toggle(
                l10n.workoutSettingsSupersetAutoScroll,
                l10n.workoutSettingsSupersetAutoScrollSubtitle,
                WorkoutSettingsKeys.supersetAutoScroll,
                value: settings.supersetAutoScroll,
              ),
              SettingsMenuRow<int?>(
                title: l10n.workoutSettingsSupersetRest,
                value: settings.supersetTransitionRestSeconds,
                options: [
                  for (final seconds in supersetTransitionRestOptions)
                    (
                      seconds,
                      seconds == null
                          ? l10n.workoutSettingsOff
                          : l10n.workoutSettingsSeconds(seconds),
                    ),
                ],
                onChanged: (seconds) => change({
                  WorkoutSettingsKeys.supersetTransitionRestSeconds: seconds,
                }),
              ),
              toggle(
                l10n.workoutSettingsExerciseAutoNext,
                l10n.workoutSettingsExerciseAutoNextSubtitle,
                WorkoutSettingsKeys.exerciseAutoNext,
                value: settings.exerciseAutoNext,
              ),
            ],
          ),
          AppSection(
            header: l10n.workoutSettingsPreviousReferenceHeader,
            footer: l10n.workoutSettingsPreviousReferenceFooter,
            children: [
              for (final option in PreviousWorkoutReferenceOption.values)
                AppSelectableRow(
                  title: switch (option) {
                    PreviousWorkoutReferenceOption.anyExercise =>
                      l10n.workoutSettingsAnyExercise,
                    PreviousWorkoutReferenceOption.sameWorkout =>
                      l10n.workoutSettingsSameWorkout,
                    PreviousWorkoutReferenceOption.workoutsInMesocycle =>
                      l10n.workoutSettingsInMesocycle,
                  },
                  subtitle: switch (option) {
                    PreviousWorkoutReferenceOption.anyExercise =>
                      l10n.workoutSettingsAnyExerciseSubtitle,
                    PreviousWorkoutReferenceOption.sameWorkout =>
                      l10n.workoutSettingsSameWorkoutSubtitle,
                    PreviousWorkoutReferenceOption.workoutsInMesocycle =>
                      l10n.workoutSettingsInMesocycleSubtitle,
                  },
                  selected: settings.previousWorkoutReference == option,
                  onPressed: () => change({
                    WorkoutSettingsKeys.previousWorkoutReference: option.value,
                  }),
                ),
            ],
          ),
          AppSection(
            header: l10n.workoutSettingsDisplayHeader,
            children: [
              toggle(
                l10n.workoutSettingsKeepAlive,
                l10n.workoutSettingsKeepAliveSubtitle,
                WorkoutSettingsKeys.keepAlive,
                value: settings.keepAlive,
              ),
              toggle(
                l10n.workoutSettingsWorkoutTimer,
                l10n.workoutSettingsWorkoutTimerSubtitle,
                WorkoutSettingsKeys.showWorkoutTimer,
                value: settings.showWorkoutTimer,
              ),
              toggle(
                l10n.workoutSettingsBodyweight,
                l10n.workoutSettingsBodyweightSubtitle,
                WorkoutSettingsKeys.showBodyweightContribution,
                value: settings.showBodyweightContribution,
              ),
              toggle(
                l10n.workoutSettingsLockScreen,
                l10n.workoutSettingsLockScreenSubtitle,
                WorkoutSettingsKeys.showOnLockScreen,
                value: settings.showsOnLockScreen,
              ),
              toggle(
                l10n.workoutSettingsSetPlan,
                l10n.workoutSettingsSetPlanSubtitle,
                WorkoutSettingsKeys.setPlanning,
                value: settings.plansSets,
              ),
            ],
          ),
          AppSection(
            header: l10n.workoutSettingsWarmUpHeader,
            children: [
              toggle(
                l10n.workoutSettingsSmartWarmUps,
                l10n.workoutSettingsSmartWarmUpsSubtitle,
                WorkoutSettingsKeys.addSmartWarmUps,
                value: settings.addSmartWarmUps,
              ),
            ],
          ),
        ];
      },
    );
  }
}
