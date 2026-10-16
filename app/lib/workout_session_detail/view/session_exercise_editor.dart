import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_session_detail/cubit/session_edit_cubit.dart';
import 'package:compound/workout_session_detail/view/set_detail_row.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart' show SetField;
import 'package:compound/workout_tracker/view/notes_sheet.dart';
import 'package:compound/workout_tracker/view/set_row_parts.dart'
    show confirmDestructive;
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// One exercise of a finished workout while it is edited
/// (`ExerciseEditorView`): its sets, each ticked or not, with the set type
/// menu, Add Another Drop or Mini-Set and Delete on the row's menu, and a
/// tap opening the set's figures; Add Set under them; Notes, Split L/R and
/// Delete Exercise on the exercise's menu.
class SessionExerciseEditor extends StatelessWidget {
  const new({required this.exercise, required this.distanceUnit, super.key});

  final WorkoutExerciseModel exercise;
  final AppDistanceUnit distanceUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    return AppSection(
      children: [
        AppListRow(
          title: exercise.name,
          subtitle: exercise.notes,
          icon: AppSymbols.exercise,
          accessory: AppListRowCustom(_ExerciseMenu(exercise: exercise)),
        ),
        for (final set in exercise.sets)
          _EditableSetRow(
            exercise: exercise,
            set: set,
            distanceUnit: distanceUnit,
          ),
        AppListRowButton(
          title: l10n.trackerAddSet,
          icon: AppSymbols.add,
          accessory: null,
          onPressed: () => cubit.addSet(exercise.id),
        ),
      ],
    );
  }
}

enum _ExerciseAction { notes, split, delete }

class _ExerciseMenu extends StatelessWidget {
  const new({required this.exercise});

  final WorkoutExerciseModel exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rules = rulesExercise(exercise);
    return PopupMenuButton<_ExerciseAction>(
      key: ValueKey('exercise-menu-${exercise.id}'),
      icon: Icon(AppSymbols.more),
      tooltip: l10n.programMore,
      onSelected: (action) => switch (action) {
        _ExerciseAction.notes => unawaited(_editNotes(context)),
        _ExerciseAction.split => context.read<SessionEditCubit>().toggleSides(
          exercise.id,
        ),
        _ExerciseAction.delete => unawaited(_delete(context)),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _ExerciseAction.notes,
          child: ListTile(
            leading: const Icon(AppSymbols.note),
            title: Text(l10n.trackerNotes),
          ),
        ),
        if (rules.isPerSide)
          CheckedPopupMenuItem(
            value: _ExerciseAction.split,
            checked: rules.isSplit,
            child: Text(l10n.trackerSplitSides),
          ),
        PopupMenuItem(
          value: _ExerciseAction.delete,
          child: ListTile(
            leading: Icon(AppSymbols.delete, color: context.appColors.danger),
            title: Text(
              l10n.trackerDeleteExercise,
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editNotes(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    final notes = await showNotesSheet(
      context,
      title: exercise.name,
      saveLabel: l10n.trackerSave,
      fields: [
        NoteField(
          label: l10n.trackerSessionNote,
          footer: l10n.trackerSessionNoteFooter,
          initial: exercise.notes ?? '',
        ),
      ],
    );
    if (notes != null) cubit.setExerciseNotes(exercise.id, notes.single);
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<SessionEditCubit>();
    final delete = await confirmDestructive(
      context,
      title: context.l10n.trackerDeleteExerciseTitle,
      message: exercise.name,
      action: context.l10n.trackerDeleteExercise,
    );
    if (delete) cubit.deleteExercise(exercise.id);
  }
}

class _EditableSetRow extends StatelessWidget {
  const new({
    required this.exercise,
    required this.set,
    required this.distanceUnit,
  });

  final WorkoutExerciseModel exercise;
  final WorkoutSetModel set;
  final AppDistanceUnit distanceUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    final name = TrackerText.setName(
      l10n,
      set,
      TrackerText.badge(l10n, set, exercise),
    );
    final logged = set.completedAt != null;
    return Row(
      children: [
        IconButton(
          key: ValueKey('set-tick-${set.id}'),
          icon: Icon(
            logged ? AppSymbols.success : AppSymbols.choiceUnselected,
            color: logged ? Theme.of(context).colorScheme.primary : null,
          ),
          tooltip: logged ? l10n.trackerLoggedValue : l10n.keypadLogSet,
          onPressed: () => cubit.toggleSet(set.id),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: name,
            child: InkWell(
              key: ValueKey('set-row-${set.id}'),
              onTap: () => unawaited(_editFigures(context)),
              child: SetDetailRow(
                set: set,
                number: exercise.workingSetNumber(set),
                trackingMode: exercise.trackingMode,
                weightUnit: exercise.displayWeightUnit,
                distanceUnit: distanceUnit,
              ),
            ),
          ),
        ),
        _SetMenu(exercise: exercise, set: set, name: name),
      ],
    );
  }

  Future<void> _editFigures(BuildContext context) async {
    final cubit = context.read<SessionEditCubit>();
    final edited = await showModalBottomSheet<WorkoutSetModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FiguresSheet(
        set: set,
        trackingMode: exercise.trackingMode,
        weightUnit: exercise.displayWeightUnit,
        distanceUnit: distanceUnit,
        title: TrackerText.setName(
          context.l10n,
          set,
          TrackerText.badge(context.l10n, set, exercise),
        ),
      ),
    );
    if (edited != null) cubit.updateSet(exercise.id, edited);
  }
}

class _SetMenu extends StatelessWidget {
  const new({required this.exercise, required this.set, required this.name});

  final WorkoutExerciseModel exercise;
  final WorkoutSetModel set;
  final String name;

  static const _delete = 'delete';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rules = rulesSet(set);
    final offersTypes = r.ActiveWorkout.offersSetTypes(rules);
    final current = r.typeChoiceOf(rules);
    return PopupMenuButton<Object>(
      key: ValueKey('set-menu-${set.id}'),
      icon: Icon(AppSymbols.more),
      tooltip: l10n.sessionSetActions,
      onSelected: (value) => switch (value) {
        final r.SetTypeChoice choice => unawaited(_changeType(context, choice)),
        final r.SubSetKind kind => context.read<SessionEditCubit>().addSubSet(
          set.id,
          kind,
        ),
        _ => unawaited(_deleteSet(context)),
      },
      itemBuilder: (_) => [
        if (offersTypes)
          for (final choice in r.ActiveWorkout.setTypeOptions(rules))
            CheckedPopupMenuItem<Object>(
              value: choice,
              checked: choice == current,
              child: Text(TrackerText.setType(l10n, choice)),
            ),
        if (offersTypes && r.ActiveWorkout.offersDrop(rules))
          PopupMenuItem<Object>(
            value: r.SubSetKind.drop,
            child: ListTile(
              leading: const Icon(AppSymbols.add),
              title: Text(l10n.trackerAddDrop),
            ),
          ),
        if (offersTypes && r.ActiveWorkout.offersMiniSet(rules))
          PopupMenuItem<Object>(
            value: r.SubSetKind.mini,
            child: ListTile(
              leading: const Icon(AppSymbols.add),
              title: Text(l10n.trackerAddMiniSet),
            ),
          ),
        PopupMenuItem<Object>(
          value: _delete,
          child: ListTile(
            leading: Icon(AppSymbols.delete, color: context.appColors.danger),
            title: Text(
              TrackerText.deleteTitle(l10n, set),
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ),
      ],
    );
  }

  /// Sub-rows the new type has no use for go, asking first when any of them
  /// is logged.
  Future<void> _changeType(BuildContext context, r.SetTypeChoice choice) async {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    final lost = cubit.state.loggedRowsLostBy(set.id, choice);
    if (lost > 0) {
      final change = await confirmDestructive(
        context,
        title: l10n.trackerChangeTypeTitle(
          name,
          TrackerText.setType(l10n, choice),
        ),
        message: l10n.trackerChangeTypeMessage(lost),
        action: l10n.trackerChange,
      );
      if (!change) return;
    }
    cubit.setSetType(set.id, choice);
  }

  /// Asks first when its drops or mini-sets would go with it.
  Future<void> _deleteSet(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    final message = TrackerText.subSetsDeleted(
      l10n,
      cubit.state.subSetsRemovedBy(set.id),
    );
    if (message != null) {
      final delete = await confirmDestructive(
        context,
        title: l10n.trackerDeleteSetTitle(name),
        message: message,
        action: l10n.trackerDeleteSet,
      );
      if (!delete) return;
    }
    cubit.deleteSet(set.id);
  }
}

/// A set's figures, in the exercise's units, for its tracking mode (the
/// fields the tracker's keypad walks). Save returns the set with them;
/// Close returns `null`.
class _FiguresSheet extends StatefulWidget {
  const new({
    required this.set,
    required this.trackingMode,
    required this.weightUnit,
    required this.distanceUnit,
    required this.title,
  });

  final WorkoutSetModel set;
  final TrackingMode trackingMode;
  final ExerciseWeightUnit weightUnit;
  final AppDistanceUnit distanceUnit;
  final String title;

  @override
  State<_FiguresSheet> createState() => _FiguresSheetState();
}

class _FiguresSheetState extends State<_FiguresSheet> {
  late WorkoutSetModel _set = widget.set;

  bool get _pounds => widget.weightUnit == ExerciseWeightUnit.pounds;
  bool get _miles => widget.distanceUnit == AppDistanceUnit.miles;

  double? _shown(SetField field) => switch (field) {
    SetField.weight => switch (_set.weightKg) {
      final kg? => _pounds ? kg * AppFormat.poundsPerKilogram : kg,
      null => null,
    },
    SetField.reps => _set.reps?.toDouble(),
    SetField.duration => _set.durationSec?.toDouble(),
    SetField.distance => switch (_set.distanceMeters) {
      final meters? =>
        _miles ? meters * AppFormat.milesPerMeter : meters / 1000,
      null => null,
    },
  };

  void _typed(SetField field, double? value) => setState(
    () => _set = switch (field) {
      SetField.weight => _set.copyWith(
        weightKg: value == null
            ? null
            : _pounds
            ? value / AppFormat.poundsPerKilogram
            : value,
      ),
      SetField.reps => _set.copyWith(reps: value?.round()),
      SetField.duration => _set.copyWith(durationSec: value?.round()),
      SetField.distance => _set.copyWith(
        distanceMeters: value == null
            ? null
            : _miles
            ? value / AppFormat.milesPerMeter
            : value * 1000,
      ),
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fields = SetField.of(widget.set, widget.trackingMode);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.l,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(AppSymbols.close),
                tooltip: l10n.socialClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              IconButton(
                icon: const Icon(AppSymbols.selected),
                tooltip: l10n.trackerSave,
                onPressed: () => Navigator.of(context).pop(_set),
              ),
            ],
          ),
          AppSection(
            children: [
              for (final field in fields)
                AppNumberField(
                  key: ValueKey('figure-${field.name}'),
                  label: switch (field) {
                    SetField.weight => l10n.sessionWeight,
                    SetField.reps => l10n.trackerColumnReps,
                    SetField.duration => l10n.trackerColumnTime,
                    SetField.distance => l10n.sessionDistance,
                  },
                  unit: switch (field) {
                    SetField.weight => _pounds ? 'lb' : 'kg',
                    SetField.reps => null,
                    SetField.duration => 's',
                    SetField.distance => widget.distanceUnit.symbol,
                  },
                  value: _shown(field),
                  onChanged: (value) => _typed(field, value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
