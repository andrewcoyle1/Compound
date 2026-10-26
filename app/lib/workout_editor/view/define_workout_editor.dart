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
            count: exercises.length,
            exercise: exercise,
            letter: letters[exercise.supersetGroupId],
            summary: text.planSummary(exercise),
            state: state,
          );
          if (state.isEditing || state.isSelectingSuperset) {
            return KeyedSubtree(key: ValueKey(exercise.id), child: row);
          }
          return AppSwipeActions(
            key: ValueKey(exercise.id),
            trailing: [
              AppSwipeAction(
                label: l10n.editorDelete,
                icon: AppSymbols.delete,
                isDestructive: true,
                onPressed: () => cubit.removeExercise(exercise.id),
              ),
              if (exercise.supersetGroupId != null)
                AppSwipeAction(
                  label: l10n.editorRemoveFromSuperset,
                  icon: AppSymbols.superset,
                  onPressed: () => cubit.removedFromSuperset(exercise.id),
                ),
            ],
            trailingFullSwipe: false,
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
    final style = AppTextStyles.sectionTitle.secondary(context);
    if (state.isSelectingSuperset) {
      return Row(
        children: [
          Expanded(child: Text(l10n.editorSelectTwo, style: style)),
          AppTextButton(
            key: const Key('DefineWorkout.cancelSuperset'),
            label: l10n.editorCancel,
            onPressed: cubit.supersetCancelled,
          ),
          AppCtaButton(
            key: const Key('DefineWorkout.confirmSuperset'),
            label: l10n.editorSuperset,
            size: AppCtaSize.compact,
            onPressed: state.canConfirmSuperset
                ? () {
                    unawaited(AppHaptics.success());
                    cubit.supersetConfirmed();
                  }
                : null,
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
          AppTextButton(
            key: const Key('DefineWorkout.superset'),
            label: l10n.editorSuperset,
            onPressed: cubit.supersetPressed,
          ),
        if (count > 0)
          AppTextButton(
            key: const Key('DefineWorkout.edit'),
            label: state.isEditing ? l10n.editorDone : l10n.editorEdit,
            onPressed: () => cubit.editingChanged(isEditing: !state.isEditing),
          ),
        AppIconButton(
          key: const Key('DefineWorkout.addExercise'),
          icon: AppSymbols.add,
          semanticLabel: l10n.editorAddExercise,
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
  required final int count,
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
    final secondary = AppTextStyles.rowDetail.secondary(context);
    final selected = state.supersetSelection.contains(exercise.id);
    final side = MediaQuery.textScalerOf(context).scale(AppControlSize.row);
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
              color: selected ? context.appColors.accentInk : scheme.outline,
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
                Text(exercise.exercise.name, style: AppTextStyles.sectionTitle),
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
              AppIconButton(
                icon: AppSymbols.superset,
                semanticLabel: l10n.editorRemoveFromSuperset,
                onPressed: () => cubit.removedFromSuperset(exercise.id),
              ),
            AppIconButton(
              icon: AppSymbols.delete,
              semanticLabel: l10n.editorDelete,
              isDestructive: true,
              onPressed: () => cubit.removeExercise(exercise.id),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s),
                child: Icon(AppSymbols.reorder, color: scheme.outline),
              ),
            ),
          ] else if (!state.isSelectingSuperset)
            Icon(
              AppSymbols.disclosure,
              size: AppIconSize.small.of(context),
              color: scheme.outline,
            ),
        ],
      ),
    );
    return Semantics(
      button: !state.isEditing,
      selected: state.isSelectingSuperset ? selected : null,
      // The rows read as one grouped card: round at its ends, hairlines
      // between, as an AppSection draws them.
      child: Material(
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: index == 0 ? const Radius.circular(AppRadius.l) : Radius.zero,
            bottom: index == count - 1
                ? const Radius.circular(AppRadius.l)
                : Radius.zero,
          ),
        ),
        child: AppPressable(
          onTap: state.isEditing
              ? null
              : state.isSelectingSuperset
              ? () {
                  unawaited(AppHaptics.selection());
                  cubit.supersetRowPressed(exercise.id);
                }
              : () => unawaited(_open(context)),
          child: Column(
            children: [
              if (index > 0)
                Divider(indent: AppSpacing.l + side + AppSpacing.m),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: content,
              ),
            ],
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
