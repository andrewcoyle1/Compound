import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/training_library/view/exercise_picker_page.dart';
import 'package:compound/training_library/view/workout_template_detail_page.dart';
import 'package:compound/workout_editor/cubit/define_workout_cubit.dart';
import 'package:compound/workout_editor/logic/editor_text.dart';
import 'package:compound/workout_editor/view/set_target_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The workout editor (Swift `DefineWorkoutView`): the muscles planned,
/// then the exercises, each opening its targets and plan. Edit reorders and
/// deletes, and from there Superset groups exercises. Hosted by the
/// workout wizard and by a mesocycle's day, which own the [exercises]:
/// [read] gives them as they stand and [write] takes each change.
class const DefineWorkoutEditor({
  required final List<WorkoutTemplateExercise> exercises,
  required final List<WorkoutTemplateExercise> Function() read,
  required final void Function(List<WorkoutTemplateExercise>) write,

  /// A mesocycle's day: empty, it is a rest day, and the picker never opens
  /// on its own.
  final bool isMesocycleDay = false,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DefineWorkoutCubit(
        read: read,
        write: write,
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: DefineWorkoutView(
        exercises: exercises,
        isMesocycleDay: isMesocycleDay,
      ),
    );
  }
}

class DefineWorkoutView extends StatefulWidget {
  const new({required this.exercises, this.isMesocycleDay = false, super.key});

  final List<WorkoutTemplateExercise> exercises;
  final bool isMesocycleDay;

  @override
  State<DefineWorkoutView> createState() => _DefineWorkoutViewState();
}

class _DefineWorkoutViewState extends State<DefineWorkoutView> {
  @override
  void initState() {
    super.initState();
    // An empty new workout's only job is its exercises.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DefineWorkoutCubit>().appeared(
        autoOpens: !widget.isMesocycleDay,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<DefineWorkoutCubit>().state;
    final cubit = context.read<DefineWorkoutCubit>();
    final exercises = widget.exercises;
    final letters = WorkoutEditorRules.supersetLetters(exercises);
    final text = EditorText(
      l10n,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    return BlocListener<DefineWorkoutCubit, DefineWorkoutState>(
      listenWhen: (previous, current) =>
          !previous.autoOpenedPicker && current.autoOpenedPicker,
      listener: (context, _) => unawaited(_addExercises(context)),
      child: ReorderableListView.builder(
        padding: const EdgeInsets.all(AppSpacing.l),
        buildDefaultDragHandles: false,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.l,
          children: [
            if (widget.isMesocycleDay && exercises.isEmpty)
              AppSection(
                header: l10n.editorRestDay,
                children: [
                  AppListRow(
                    title: l10n.editorRestDayMessage,
                    icon: AppSymbols.restDay,
                    tint: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              )
            else
              TargetMusclesSection(exercises: exercises),
            _Header(
              state: state,
              count: exercises.length,
              onAdd: _addExercises,
            ),
          ],
        ),
        itemCount: exercises.length,
        // The rules count the destination before the move, as SwiftUI does.
        onReorderItem: (from, to) =>
            cubit.moveExercise(from, to > from ? to + 1 : to),
        itemBuilder: (context, index) {
          final exercise = exercises[index];
          final row = _ExerciseRow(
            index: index,
            exercise: exercise,
            letter: letters[exercise.supersetGroupId],
            summary: text.planSummary(exercise),
            state: state,
          );
          if (state.isEditing || state.isSelectingSuperset) {
            return KeyedSubtree(key: ValueKey(exercise.id), child: row);
          }
          return Dismissible(
            key: ValueKey(exercise.id),
            direction: DismissDirection.endToStart,
            background: ColoredBox(
              color: context.appColors.danger,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.l),
                  child: Icon(
                    AppSymbols.delete,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ),
            ),
            onDismissed: (_) => cubit.removeExercise(exercise.id),
            child: row,
          );
        },
      ),
    );
  }

  /// Opens the picker, the exercises already there ticked.
  Future<void> _addExercises(BuildContext context) async {
    final cubit = context.read<DefineWorkoutCubit>();
    final picked = await ExercisePickerPage.show(
      context,
      request: ExercisePickerRequest(
        committedIds: {for (final e in widget.exercises) e.exercise.id},
      ),
    );
    if (picked != null) cubit.picked(picked);
  }
}

/// "3 Exercises", Edit or Done (and Superset while editing), and add; or,
/// choosing a superset, what to do with its Cancel and confirm.
class const _Header({
  required final DefineWorkoutState state,
  required final int count,
  required final Future<void> Function(BuildContext) onAdd,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DefineWorkoutCubit>();
    final style = AppTextStyles.sectionTitle.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (state.isSelectingSuperset) {
      return Row(
        children: [
          Expanded(child: Text(l10n.editorSelectTwo, style: style)),
          TextButton(
            key: const Key('DefineWorkout.cancelSuperset'),
            onPressed: cubit.supersetCancelled,
            child: Text(l10n.editorCancel),
          ),
          FilledButton(
            key: const Key('DefineWorkout.confirmSuperset'),
            onPressed: state.canConfirmSuperset
                ? () {
                    unawaited(HapticFeedback.successNotification());
                    cubit.supersetConfirmed();
                  }
                : null,
            child: Text(l10n.editorSuperset),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(l10n.workoutExercisesHeader(count), style: style),
          ),
        ),
        if (state.isEditing && count >= 2)
          TextButton(
            key: const Key('DefineWorkout.superset'),
            onPressed: cubit.supersetPressed,
            child: Text(l10n.editorSuperset),
          ),
        if (count > 0)
          TextButton(
            key: const Key('DefineWorkout.edit'),
            onPressed: () => cubit.editingChanged(isEditing: !state.isEditing),
            child: Text(state.isEditing ? l10n.editorDone : l10n.editorEdit),
          ),
        IconButton.filledTonal(
          key: const Key('DefineWorkout.addExercise'),
          icon: const Icon(AppSymbols.add),
          tooltip: l10n.editorAddExercise,
          onPressed: () => unawaited(onAdd(context)),
        ),
      ],
    );
  }
}

/// An exercise: its picture, name, targets, superset letter and plan.
/// Opens its targets; choosing a superset, a tap ticks it; editing, it
/// has a handle, delete, and leave-the-superset.
class const _ExerciseRow({
  required final int index,
  required final WorkoutTemplateExercise exercise,
  required final String? letter,
  required final String? summary,
  required final DefineWorkoutState state,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<DefineWorkoutCubit>();
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final selected = state.supersetSelection.contains(exercise.id);
    final side = MediaQuery.textScalerOf(context).scale(44);
    final letter = this.letter;
    final summary = this.summary;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Row(
        spacing: AppSpacing.m,
        children: [
          if (state.isSelectingSuperset)
            Icon(
              selected
                  ? AppSymbols.choiceSelected
                  : AppSymbols.choiceUnselected,
              color: selected ? scheme.primary : scheme.outline,
            ),
          ExcludeSemantics(
            child: ClipRSuperellipse(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.s),
              ),
              child: SizedBox.square(
                dimension: side,
                child: ExerciseImage(exercise.exercise),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Text(
                  exercise.exercise.name,
                  style: AppTextStyles.rowTitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  templateTargetsText(context, exercise.setTargets),
                  style: secondary,
                ),
                if (letter != null || summary != null)
                  Wrap(
                    spacing: AppSpacing.s,
                    runSpacing: AppSpacing.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (letter != null)
                        Semantics(
                          label: l10n.supersetLabel(letter),
                          child: ExcludeSemantics(
                            child: AppChip(
                              label: letter,
                              icon: AppSymbols.superset,
                              tint: context.appColors.superset,
                            ),
                          ),
                        ),
                      if (summary != null)
                        Text(
                          summary,
                          style: secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (state.isEditing) ...[
            if (exercise.supersetGroupId != null)
              IconButton(
                icon: const Icon(AppSymbols.superset),
                tooltip: l10n.editorRemoveFromSuperset,
                onPressed: () => cubit.removedFromSuperset(exercise.id),
              ),
            IconButton(
              icon: Icon(AppSymbols.delete, color: context.appColors.danger),
              tooltip: l10n.editorDelete,
              onPressed: () => cubit.removeExercise(exercise.id),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.s),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ] else if (!state.isSelectingSuperset)
            Icon(AppSymbols.disclosure, color: scheme.outline),
        ],
      ),
    );
    return Semantics(
      button: !state.isEditing,
      selected: state.isSelectingSuperset ? selected : null,
      child: Material(
        color: scheme.surface,
        child: InkWell(
          onTap: state.isEditing
              ? null
              : state.isSelectingSuperset
              ? () {
                  unawaited(HapticFeedback.selectionClick());
                  cubit.supersetRowPressed(exercise.id);
                }
              : () => unawaited(_open(context)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: content,
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<DefineWorkoutCubit>();
    final edited = await openSetTarget(context, exercise);
    if (edited != null) cubit.exerciseEdited(edited);
  }
}
