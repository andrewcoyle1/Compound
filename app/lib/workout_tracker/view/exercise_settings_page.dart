import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/create_exercise/create_exercise.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/training/view/rest_timer_settings_page.dart';
import 'package:compound/training_library/view/exercise_detail_page.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound/workout_tracker/cubit/exercise_settings_cubit.dart';
import 'package:compound/workout_tracker/view/notes_sheet.dart';
import 'package:compound/workout_tracker/view/set_row_parts.dart';
import 'package:compound/workout_tracker/view/unit_menu.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart';

/// Exercise Settings (Swift `ExerciseSettingsView`), from the tracker's
/// exercise menu: Info, the weight and distance units, the exercise's own
/// rest, the left/right rest it follows, its note, and Edit Duplicate.
class ExerciseSettingsPage extends StatelessWidget {
  const new({required this.exercise, super.key});

  /// Pushes the page for [exercise].
  static Future<void> push(BuildContext context, ExerciseModel exercise) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExerciseSettingsPage(exercise: exercise),
        ),
      );

  final ExerciseModel exercise;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => ExerciseSettingsCubit(
        exercise: exercise,
        uid: app.user.uid,
        user: app.profile,
        library: context.read<TrainingLibraryRepository>(),
        units: context.read<UnitPreferenceStore>(),
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const ExerciseSettingsView(),
    );
  }
}

class ExerciseSettingsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ExerciseSettingsCubit>();
    final state = context.watch<ExerciseSettingsCubit>().state;
    final exercise = state.exercise;
    final override = state.restOverride;
    final percent = state.sideSetRestPercent;
    String duration(int seconds) =>
        AppFormat.duration(Duration(seconds: seconds));
    return ScreenAnalytics(
      appeared: cubit.appeared,
      disappeared: cubit.disappeared,
      child: AppScaffold(
        appBar: AppBar(title: Text(l10n.trackerExerciseSettings)),
        body: SafeArea(
          bottom: false,
          child: LibrarySections(
            children: [
              AppSection(
                header: exercise.name,
                children: [
                  AppListRowButton(
                    title: l10n.exerciseSettingsInfo,
                    subtitle:
                        exercise.description ??
                        l10n.exerciseSettingsInfoSubtitle,
                    icon: AppSymbols.info,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ExerciseDetailPage(exerciseId: exercise.id),
                      ),
                    ),
                  ),
                  UnitMenu<ExerciseWeightUnit>(
                    key: const Key('ExerciseSettings.weightUnit'),
                    units: ExerciseWeightUnit.values,
                    selected: state.units.weightUnit,
                    name: (unit) => weightUnitName(l10n, unit),
                    onSelected: cubit.weightUnitChanged,
                    child: AppListRow(
                      title: l10n.exerciseSettingsWeightUnit,
                      icon: AppSymbols.weight,
                      accessory: AppListRowValue(
                        weightUnitName(l10n, state.units.weightUnit),
                      ),
                    ),
                  ),
                  UnitMenu<DistanceUnit>(
                    key: const Key('ExerciseSettings.distanceUnit'),
                    units: DistanceUnit.values,
                    selected: state.units.distanceUnit,
                    name: (unit) => distanceUnitName(l10n, unit),
                    onSelected: cubit.distanceUnitChanged,
                    child: AppListRow(
                      title: l10n.exerciseSettingsDistanceUnit,
                      icon: AppSymbols.cardio,
                      accessory: AppListRowValue(
                        distanceUnitName(l10n, state.units.distanceUnit),
                      ),
                    ),
                  ),
                  AppListRowButton(
                    key: const Key('ExerciseSettings.rest'),
                    title: l10n.workoutSettingsRestTimer,
                    subtitle: override == null
                        ? l10n.exerciseSettingsRestDefault(
                            duration(state.defaultRest),
                          )
                        : l10n.exerciseSettingsRestCustom(duration(override)),
                    icon: AppSymbols.rest,
                    onPressed: () => unawaited(_rest(context)),
                  ),
                  // Only for an exercise worked one limb at a time.
                  if (state.isPerSide)
                    AppListRowButton(
                      key: const Key('ExerciseSettings.sideRest'),
                      title: l10n.restTimerBetweenSides,
                      subtitle: percent == null
                          ? l10n.workoutSettingsOff
                          : l10n.exerciseSettingsSideRest('$percent'),
                      icon: AppSymbols.splitSides,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RestTimerSettingsPage(),
                        ),
                      ),
                    ),
                  AppListRowButton(
                    key: const Key('ExerciseSettings.note'),
                    title: l10n.trackerExerciseNote,
                    subtitle: state.noteSummary ?? l10n.none,
                    icon: AppSymbols.note,
                    onPressed: () => unawaited(_note(context)),
                  ),
                  AppListRowButton(
                    key: const Key('ExerciseSettings.duplicate'),
                    title: l10n.exerciseSettingsEditDuplicate,
                    icon: AppSymbols.duplicate,
                    onPressed: () => unawaited(
                      CreateExercisePage.open(
                        context,
                        prefill: ExerciseDraft.duplicating(
                          exercise,
                          name: l10n.exerciseCopyName(exercise.name),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The rest picker on the exercise's own rest, else 0:00; Save keeps
  /// it, and both wheels at zero clear it.
  static Future<void> _rest(BuildContext context) async {
    final cubit = context.read<ExerciseSettingsCubit>();
    final seconds = await showRestPicker(
      context,
      cubit.state.restOverride ?? 0,
    );
    if (seconds != null) await cubit.restChanged(seconds);
  }

  static Future<void> _note(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ExerciseSettingsCubit>();
    final notes = await showNotesSheet(
      context,
      title: cubit.state.exercise.name,
      saveLabel: l10n.trackerSave,
      fields: [
        NoteField(
          label: l10n.trackerExerciseNote,
          footer: l10n.trackerExerciseNoteFooter,
          initial: cubit.state.note,
        ),
      ],
    );
    if (notes != null) await cubit.noteChanged(notes.single);
  }
}

/// "Kilograms", "Pounds".
String weightUnitName(AppLocalizations l10n, ExerciseWeightUnit unit) =>
    switch (unit) {
      ExerciseWeightUnit.kilograms => l10n.unitKilograms,
      ExerciseWeightUnit.pounds => l10n.unitPounds,
    };

/// "Meters", "Miles".
String distanceUnitName(AppLocalizations l10n, DistanceUnit unit) =>
    switch (unit) {
      DistanceUnit.meters => l10n.unitMeters,
      DistanceUnit.miles => l10n.unitMiles,
    };

/// "kg", "lb": a weight unit's symbol, for a column heading.
String weightUnitSymbol(ExerciseWeightUnit unit) =>
    WorkoutText.weightUnit(unit).symbol;
