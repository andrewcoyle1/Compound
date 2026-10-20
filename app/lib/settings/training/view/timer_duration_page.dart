import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/settings/training/cubit/exercise_rest_timers_cubit.dart';
import 'package:compound/settings/training/logic/workout_settings_rules.dart';
import 'package:compound/settings/training/view/workout_settings_screen.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/widgets/number_wheel.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Timer Duration (Swift `TimerDurationView`): the rest for each exercise
/// type, a reset back to the defaults, and rests set on single exercises.
class TimerDurationPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'durations';
  static const name = 'settingsTimerDuration';

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    final l10n = context.l10n;
    return BlocProvider(
      create: (context) => ExerciseRestTimersCubit(
        repository: context.read<TrainingLibraryRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
        systemExercises: PrebuiltCatalogue.instance.exercises,
      )..subscribe(),
      child: BlocListener<ExerciseRestTimersCubit, ExerciseRestTimersState>(
        listenWhen: (previous, current) =>
            current.saveFailed && !previous.saveFailed,
        listener: (context, _) => showAppSnackBar(
          context,
          l10n.workoutSettingsSaveFailed,
          style: AppSnackBarStyle.error,
        ),
        child: WorkoutSettingsScreen(
          screen: 'TimerDurationView',
          title: l10n.restTimerDuration,
          sections: (context, settings, change) => [
            MethodInfoHeader(
              title: l10n.timerDurationDefaultsHeader,
              info: MethodInfo.restIntervals(l10n),
            ),
            AppSection(
              footer: l10n.timerDurationDefaultsFooter,
              children: [
                for (final type in ExerciseType.values)
                  AppListRowButton(
                    title: l10n.exerciseTypeName(type),
                    subtitle: AppFormat.duration(
                      Duration(seconds: settings.restDuration(type)),
                    ),
                    onPressed: () async {
                      final seconds = await showRestDurationPicker(
                        context,
                        title: l10n.exerciseTypeName(type),
                        seconds: settings.restDuration(type),
                      );
                      if (seconds == null) return;
                      change({
                        WorkoutSettingsKeys.restDurationsByExerciseType: {
                          ...settings.restDurationsByExerciseType,
                          type.value: seconds,
                        },
                      });
                    },
                  ),
              ],
            ),
            AppSection(
              children: [
                AppListRowButton(
                  title: l10n.timerDurationReset,
                  accessory: null,
                  tint: Theme.of(context).colorScheme.error,
                  onPressed: () async {
                    if (await _confirmReset(context)) {
                      change({
                        WorkoutSettingsKeys.restDurationsByExerciseType:
                            const <String, int>{},
                      });
                    }
                  },
                ),
              ],
            ),
            _ExerciseTimersSection(
              defaultSeconds: settings.defaultRestDurationSeconds,
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> _confirmReset(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog.confirmDestructive(
      context,
      title: l10n.timerDurationResetTitle,
      message: l10n.timerDurationResetMessage,
      cancelLabel: l10n.timerDurationCancel,
      confirmLabel: l10n.timerDurationResetConfirm,
    );
  }
}

class _ExerciseTimersSection extends StatelessWidget {
  const new({required this.defaultSeconds});

  /// Where a new exercise's picker starts (Swift's global default rest).
  final int defaultSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ExerciseRestTimersCubit>();
    final state = context.watch<ExerciseRestTimersCubit>().state;
    Future<void> edit(String id, String name, int seconds) async {
      final picked = await showRestDurationPicker(
        context,
        title: name,
        seconds: seconds,
      );
      if (picked != null) await cubit.setOverride(id, picked);
    }

    return AppSection(
      header: l10n.timerDurationExerciseHeader,
      footer: l10n.timerDurationExerciseFooter,
      children: [
        for (final override in state.overrides)
          // Swift's swipe to remove, beside the row's own button.
          AppSwipeActions(
            trailing: [
              AppSwipeAction(
                label: l10n.timerDurationRemove,
                icon: AppSymbols.delete,
                isDestructive: true,
                onPressed: () => cubit.remove(override.id),
              ),
            ],
            child: AppListRowButton(
              title: override.name,
              subtitle: AppFormat.duration(Duration(seconds: override.seconds)),
              accessory: AppListRowCustom(
                AppIconButton(
                  icon: AppSymbols.delete,
                  semanticLabel: l10n.timerDurationRemove,
                  onPressed: () => cubit.remove(override.id),
                ),
              ),
              onPressed: () =>
                  edit(override.id, override.name, override.seconds),
            ),
          ),
        AppListRowButton(
          title: l10n.timerDurationAddExercise,
          subtitle: l10n.timerDurationAddExerciseSubtitle,
          icon: AppSymbols.add,
          onPressed: () async {
            final exercise = await _chooseExercise(
              context,
              state.withoutOverride,
            );
            if (exercise == null || !context.mounted) return;
            await edit(
              exercise.id,
              exercise.name,
              cubit.overrideFor(exercise.id) ?? defaultSeconds,
            );
          },
        ),
      ],
    );
  }

  static Future<ExerciseModel?> _chooseExercise(
    BuildContext context,
    List<ExerciseModel> exercises,
  ) => showAppSheet<ExerciseModel>(
    context: context,
    size: AppSheetSize.full,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Semantics(
            header: true,
            child: Text(
              context.l10n.timerDurationChooseExercise,
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          // The sheet's primary scroll controller, so the list drags it.
          child: ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) => AppListRowButton(
              title: exercises[index].name,
              accessory: null,
              onPressed: () => Navigator.of(context).pop(exercises[index]),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Asks for a rest of 0–9 minutes and 0, 15, 30 or 45 seconds, starting at
/// [seconds] (Swift's duration wheels). Null when closed without saving.
Future<int?> showRestDurationPicker(
  BuildContext context, {
  required String title,
  required int seconds,
}) {
  var minutes = (seconds ~/ 60).clamp(0, 9);
  // Onto the wheel's quarter minutes, so Save never stores a value the
  // wheel isn't showing.
  var remainder = seconds % 60 ~/ 15 * 15;
  return showAppSheet<int>(
    context: context,
    size: AppSheetSize.compact,
    builder: (context) {
      final l10n = context.l10n;
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                AppToolbarButton.close(
                  semanticLabel: MaterialLocalizations.of(context)
                      .closeButtonLabel,
                ),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.sectionTitle,
                    textAlign: TextAlign.center,
                  ),
                ),
                AppToolbarButton.confirm(
                  semanticLabel: l10n.timerDurationSave,
                  onPressed: () =>
                      Navigator.of(context).pop(minutes * 60 + remainder),
                ),
              ],
            ),
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(180),
              child: Row(
                children: [
                  Expanded(
                    child: NumberWheel(
                      label: l10n.timerDurationMinutes,
                      values: [for (var m = 0; m < 10; m++) m],
                      selected: minutes,
                      itemLabel: l10n.timerDurationMinutesValue,
                      onChanged: (value) => minutes = value,
                    ),
                  ),
                  Expanded(
                    child: NumberWheel(
                      label: l10n.timerDurationSeconds,
                      values: const [0, 15, 30, 45],
                      selected: remainder,
                      itemLabel: l10n.timerDurationSecondsValue,
                      onChanged: (value) => remainder = value,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
