import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/workout_editor/cubit/set_target_cubit.dart'
    show SessionScope;
import 'package:compound/workout_editor/view/set_target_page.dart';
import 'package:compound/workout_session_detail/cubit/session_edit_cubit.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart'
    show TrackerExercise;
import 'package:compound/workout_tracker/view/equipment_sheet.dart';
import 'package:compound/workout_tracker/view/exercise_settings_page.dart';
import 'package:compound/workout_tracker/view/notes_sheet.dart';
import 'package:compound/workout_tracker/view/set_row_parts.dart'
    show confirmDestructive;
import 'package:compound/workout_tracker/view/set_table.dart';
import 'package:compound/workout_tracker/view/swap_exercise_picker.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_session/training_session.dart';

/// One exercise of a finished workout while it is edited
/// (`ExerciseEditorView`): a row that opens onto its sets, open to begin
/// with and folded away on a tap. Under it, the actions as chips, then the
/// tracker's own set table (headings with the unit menus, rows, the
/// keypad), done warm-ups folded into one line, and Add Set.
class SessionExerciseEditor extends StatelessWidget {
  const new({required this.member, super.key});

  final TrackerExercise member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    final open = cubit.state.keypad;
    final exercise = member.exercise;
    Widget row(WorkoutSetModel set) => SetTableRow(
      member: member,
      set: set,
      actions: cubit,
      keypad: open?.setId == set.id ? open : null,
    );
    final warmups = [
      for (final set in exercise.sets)
        if (set.isWarmup && set.completedAt != null) set,
    ];
    return AppCard(
      child: Theme(
        // The tile draws no dividers of its own over the card.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('exercise-${exercise.id}'),
          initiallyExpanded: true,
          maintainState: true,
          tilePadding: const EdgeInsetsDirectional.only(
            start: AppSpacing.l,
            end: AppSpacing.s,
          ),
          childrenPadding: const EdgeInsets.only(bottom: AppSpacing.s),
          title: _Header(member: member),
          children: [
            _ActionChips(member: member),
            SetTableHeadings(member: member, actions: cubit),
            if (warmups.isNotEmpty)
              ExpansionTile(
                key: ValueKey('warmups-${exercise.id}'),
                leading: Icon(
                  AppSymbols.success,
                  color: context.appColors.success,
                ),
                title: Text(
                  l10n.warmupCount(warmups.length),
                  style: AppTextStyles.rowDetail,
                ),
                children: [for (final set in warmups) row(set)],
              ),
            for (final set in exercise.sets)
              if (!set.isWarmup || set.completedAt == null) row(set),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: ValueKey('add-set-${exercise.id}'),
                  onPressed: () => cubit.addSet(exercise.id),
                  icon: const Icon(AppSymbols.add),
                  label: Text(l10n.trackerAddSet),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picture, name and progress, the exercise note and this workout's,
/// and a button for the notes (`EditorExerciseHeader`).
class _Header extends StatelessWidget {
  const new({required this.member});

  final TrackerExercise member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final exercise = member.exercise;
    final rules = rulesExercise(exercise);
    final logged = rules.loggedSetCount;
    final total = rules.workingSetCount;
    final isDone = logged == total;
    final side = MediaQuery.textScalerOf(context).scale(AppControlSize.row);
    final sessionNote = switch (exercise.notes?.trim()) {
      final note? when note.isNotEmpty => note,
      _ => null,
    };
    final progressColor = isDone
        ? context.appColors.success
        : scheme.onSurfaceVariant;
    return Row(
      spacing: AppSpacing.m,
      children: [
        ExcludeSemantics(
          child: ClipRSuperellipse(
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.s)),
            child: SizedBox.square(
              dimension: side,
              child: ExerciseImage.named(
                name: exercise.name,
                image: exercise.imageName,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xxs,
            children: [
              Text(exercise.name, style: AppTextStyles.sectionTitle),
              // Counted in sets, not rows: three a side reads "Set 2/3".
              Semantics(
                value: isDone ? l10n.sessionAllSetsDone : null,
                child: Row(
                  spacing: AppSpacing.xs,
                  children: [
                    if (isDone)
                      Icon(
                        AppSymbols.success,
                        size: AppIconSize.small.of(context),
                        color: progressColor,
                      ),
                    Text(
                      l10n.sessionSetProgress(
                        logged + 1 < total ? logged + 1 : total,
                        total,
                      ),
                      style: AppTextStyles.label.copyWith(color: progressColor),
                    ),
                  ],
                ),
              ),
              if (member.exerciseNote case final note?)
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (sessionNote != null)
                Row(
                  spacing: AppSpacing.xs,
                  children: [
                    Icon(AppSymbols.note, size: AppIconSize.small.of(context)),
                    Expanded(
                      child: Text(
                        sessionNote,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        IconButton(
          key: ValueKey('exercise-note-${exercise.id}'),
          tooltip: sessionNote == null
              ? l10n.sessionAddNote
              : l10n.sessionEditNote,
          icon: Icon(
            sessionNote == null ? AppSymbols.addNote : AppSymbols.note,
          ),
          onPressed: () => unawaited(_editNotes(context)),
        ),
      ],
    );
  }

  /// The notes sheet: this workout's note on the exercise, kept with the
  /// edit, and the exercise note, saved at once.
  Future<void> _editNotes(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    final exercise = member.exercise;
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
        NoteField(
          label: l10n.trackerExerciseNote,
          footer: l10n.trackerExerciseNoteFooter,
          initial: member.exerciseNote ?? '',
        ),
      ],
    );
    if (notes == null) return;
    await cubit.saveExerciseNotes(
      exercise.id,
      sessionNote: notes[0],
      exerciseNote: notes[1],
    );
  }
}

enum _MoreAction { settings, delete }

/// Equipment, Split L/R, Targets, Swap, Superset… and More, as chips over
/// the table (`ExerciseEditorView.actionBar`).
class _ActionChips extends StatelessWidget {
  const new({required this.member});

  final TrackerExercise member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    final exercise = member.exercise;
    final rules = rulesExercise(exercise);
    final group = exercise.supersetGroupId;
    final groupSize = group == null
        ? 0
        : cubit.state.session.exercises
              .where((e) => e.supersetGroupId == group)
              .length;
    final tint = Theme.of(context).colorScheme.onSurfaceVariant;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Row(
        children: [
          if (exercise.equipmentVariations.isNotEmpty)
            AppChip(
              key: ValueKey('chip-equipment-${exercise.id}'),
              label: l10n.trackerEquipment,
              icon: AppSymbols.equipment,
              tint: tint,
              onPressed: () => unawaited(_equipment(context)),
            ),
          if (rules.isPerSide)
            Semantics(
              hint: l10n.trackerSplitSidesHint,
              child: AppChip(
                key: ValueKey('chip-split-${exercise.id}'),
                label: l10n.trackerSplitSides,
                icon: AppSymbols.splitSides,
                tint: tint,
                selected: rules.isSplit,
                onPressed: () => cubit.toggleSides(exercise.id),
              ),
            ),
          AppChip(
            key: ValueKey('chip-targets-${exercise.id}'),
            label: l10n.trackerTargets,
            icon: AppSymbols.goal,
            tint: tint,
            onPressed: () => unawaited(_targets(context)),
          ),
          AppChip(
            key: ValueKey('chip-swap-${exercise.id}'),
            label: l10n.trackerSwap,
            icon: AppSymbols.swap,
            tint: tint,
            onPressed: () => unawaited(_swap(context)),
          ),
          AppChip(
            key: ValueKey('chip-superset-${exercise.id}'),
            label: switch (groupSize) {
              0 => l10n.sessionSuperset,
              > 2 => l10n.sessionRemoveCircuit,
              _ => l10n.sessionRemoveSuperset,
            },
            icon: AppSymbols.superset,
            tint: tint,
            onPressed: () => group == null
                ? unawaited(_pair(context))
                : cubit.leaveSuperset(exercise.id),
          ),
          PopupMenuButton<_MoreAction>(
            key: ValueKey('exercise-menu-${exercise.id}'),
            tooltip: l10n.programMore,
            onSelected: (action) => switch (action) {
              _MoreAction.settings => unawaited(_settings(context)),
              _MoreAction.delete => unawaited(_delete(context)),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _MoreAction.settings,
                child: ListTile(
                  leading: const Icon(AppSymbols.settings),
                  title: Text(l10n.trackerExerciseSettings),
                ),
              ),
              PopupMenuItem(
                value: _MoreAction.delete,
                child: ListTile(
                  leading: Icon(
                    AppSymbols.delete,
                    color: context.appColors.danger,
                  ),
                  title: Text(
                    l10n.trackerDeleteExercise,
                    style: TextStyle(color: context.appColors.danger),
                  ),
                ),
              ),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppControlSize.row),
              child: Center(
                child: AppChip(
                  label: l10n.programMore,
                  icon: AppSymbols.more,
                  tint: tint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _equipment(BuildContext context) async {
    final cubit = context.read<SessionEditCubit>();
    final setup = cubit.state.equipmentSetup(member.exercise.id);
    if (setup == null) return;
    cubit.equipmentOpened();
    await showEquipmentSheet(
      context,
      setup,
      onChosen: cubit.chooseVariation,
      onGymEdited: cubit.gymEdited,
    );
  }

  /// This workout's targets for the exercise.
  Future<void> _targets(BuildContext context) async {
    final cubit = context.read<SessionEditCubit>();
    final exercise = member.exercise;
    final model = cubit.state.libraryModel(exercise.id);
    if (model == null) return;
    cubit.targetsOpened();
    final saved = await openSetTarget(
      context,
      WorkoutTemplateExercise(
        id: exercise.id,
        exercise: model,
        setTargets: exercise.setTargets,
        setRestTimers: false,
      ),
      scope: const SessionScope(),
      settings: cubit.state.settings,
      library: cubit.state.library,
    );
    if (saved != null) cubit.setTargets(exercise.id, saved.setTargets);
  }

  /// Swap, in place: logged sets move to an exercise measured the same
  /// way; to one measured differently they cannot, so it asks first.
  Future<void> _swap(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>()..swapOpened();
    final exercise = member.exercise;
    final replacement = await SwapExercisePicker.show(
      context,
      library: cubit.state.library,
      alternativeIds: exercise.substituteExerciseIds,
    );
    if (replacement == null || !context.mounted) return;
    if (cubit.state.asksBeforeSwapping(exercise.id, replacement)) {
      final discard = await confirmDestructive(
        context,
        title: l10n.sessionDiscardLoggedSetsTitle,
        message: l10n.sessionMeasuredDifferently(
          replacement.name,
          exercise.name,
        ),
        action: l10n.sessionSwapAndDiscard,
      );
      if (!discard) return;
      return cubit.swapExercise(
        exercise.id,
        replacement,
        keepLoggedSets: false,
      );
    }
    cubit.swapExercise(exercise.id, replacement, keepLoggedSets: true);
  }

  /// Superset…: the workout's other exercises to pair with, or why there
  /// are none.
  Future<void> _pair(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    final exercise = member.exercise;
    final others = [
      for (final e in cubit.state.session.exercises)
        if (e.id != exercise.id) e,
    ];
    if (others.isEmpty) {
      return await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.sessionNoExercisesAvailable),
          content: Text(l10n.sessionNoExercisesAvailableMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      );
    }
    final partner = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.sessionAddToGroup),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(l10n.sessionPairWith(exercise.name)),
          ),
          for (final other in others)
            SimpleDialogOption(
              key: ValueKey('pair-${other.id}'),
              onPressed: () => Navigator.of(context).pop(other.id),
              child: Text(other.name),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.trackerCancel),
          ),
        ],
      ),
    );
    if (partner != null) cubit.pairSuperset(exercise.id, partner);
  }

  Future<void> _settings(BuildContext context) async {
    final cubit = context.read<SessionEditCubit>();
    final model = cubit.state.libraryModel(member.exercise.id);
    if (model == null) return;
    cubit.exerciseSettingsOpened();
    await ExerciseSettingsPage.push(context, model);
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<SessionEditCubit>();
    final delete = await confirmDestructive(
      context,
      title: context.l10n.trackerDeleteExerciseTitle,
      message: member.exercise.name,
      action: context.l10n.trackerDeleteExercise,
    );
    if (delete) cubit.deleteExercise(member.exercise.id);
  }
}
