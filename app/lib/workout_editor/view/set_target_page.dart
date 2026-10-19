import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/view/program_widgets.dart'
    show confirmDestructive;
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/training_library/view/exercise_picker_page.dart';
import 'package:compound/workout_editor/cubit/set_target_cubit.dart';
import 'package:compound/workout_editor/logic/editor_text.dart';
import 'package:compound/workout_editor/view/editor_widgets.dart';
import 'package:compound/workout_editor/view/set_plan_detail_sheet.dart';
import 'package:compound/workout_editor/view/weekly_targets_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Opens the targets editor on [exercise], over everything, and returns the
/// exercise as saved, or null when closed. The workout settings and the
/// library are read here unless given.
Future<WorkoutTemplateExercise?> openSetTarget(
  BuildContext context,
  WorkoutTemplateExercise exercise, {
  SetTargetScope scope = const TemplateScope(),
  WorkoutSettings? settings,
  List<ExerciseModel>? library,
}) async {
  final repository = context.read<TrainingLibraryRepository>();
  final app = context.read<AppBloc>().state;
  final uid = app is AppAuthenticated ? app.user.uid : '';
  final resolvedSettings =
      settings ?? await repository.watchWorkoutSettings(uid).first;
  final resolvedLibrary =
      library ??
      [
        ...await repository.watchUserExercises(uid).first,
        ...PrebuiltCatalogue.instance.exercises,
      ];
  if (!context.mounted) return null;
  return await Navigator.of(context).push<WorkoutTemplateExercise>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SetTargetPage(
        exercise: exercise,
        scope: scope,
        settings: resolvedSettings,
        library: resolvedLibrary,
      ),
    ),
  );
}

/// The targets of one exercise (Swift `SetTargetView`): each set's reps
/// and reps in reserve, and with the set plan on its kind and plan; for a
/// template exercise also its plan (`ExercisePlanSection`); and whether it
/// sets rest timers. Pops with the exercise as saved.
class const SetTargetPage({
  required final WorkoutTemplateExercise exercise,
  required final SetTargetScope scope,
  required final WorkoutSettings settings,
  final List<ExerciseModel> library = const [],
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SetTargetCubit(
        exercise: exercise,
        scope: scope,
        settings: settings,
        library: library,
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const SetTargetView(),
    );
  }
}

class SetTargetView extends StatelessWidget {
  const new({super.key});

  Future<void> _close(BuildContext context) async {
    final cubit = context.read<SetTargetCubit>();
    if (!cubit.state.hasUnsavedChanges) return Navigator.of(context).pop();
    await _confirmDiscard(context);
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final l10n = context.l10n;
    final discard = await confirmDestructive(
      context,
      title: l10n.discardChangesTitle,
      confirmLabel: l10n.discardChangesButton,
    );
    // Past the PopScope: the choice to leave has been made.
    if (discard && context.mounted) Navigator.of(context).pop();
  }

  void _save(BuildContext context) {
    final cubit = context.read<SetTargetCubit>()..save();
    final saved = cubit.state.saved;
    if (saved == null) {
      unawaited(HapticFeedback.errorNotification());
      return;
    }
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SetTargetCubit>();
    final state = context.watch<SetTargetCubit>().state;
    return PopScope<WorkoutTemplateExercise>(
      canPop: !state.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard(context));
      },
      child: AppScaffold(
        appBar: AppBar(
          leading: AppToolbarButton.close(
            key: const Key('SetTarget.close'),
            semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => unawaited(_close(context)),
          ),
          title: EditorTitle(
            title: switch (state.scope) {
              WeekScope(:final week) => l10n.editorFromWeek(week),
              TemplateScope() || SessionScope() => l10n.editorTargets,
            },
            subtitle: state.exercise.exercise.name,
          ),
          actions: [
            AppToolbarButton.confirm(
              key: const Key('SetTarget.save'),
              semanticLabel: l10n.editorSave,
              onPressed: () => _save(context),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const _Targets(),
              if (state.showsPlan) ...[
                const SizedBox(height: AppSpacing.l),
                const _ExercisePlan(),
              ],
              if (state.showsRestTimers) ...[
                const SizedBox(height: AppSpacing.l),
                AppSection(
                  children: [
                    AppListRowToggle(
                      title: l10n.editorSetRestTimers,
                      subtitle: l10n.editorSetRestTimersSubtitle,
                      icon: AppSymbols.rest,
                      value: state.exercise.setRestTimers,
                      onChanged: (on) => cubit.restTimersChanged(on: on),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The sets: a row each with its reps range and RIR, the plan under it
/// when the set plan is on, then Add Set.
class _Targets extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SetTargetCubit>();
    final targets = context.select<SetTargetCubit, List<SetTarget>>(
      (cubit) => cubit.state.exercise.setTargets,
    );
    final label = AppTextStyles.label.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return AppSection(
      children: [
        // Each field names its own column and set.
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.m,
              AppSpacing.l,
              0,
            ),
            child: Row(
              spacing: AppSpacing.s,
              children: [
                SizedBox(
                  width: _numberWidth,
                  child: Text(
                    l10n.trackerColumnSet,
                    style: label,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.editorRepsMin,
                    style: label,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.editorRepsMax,
                    style: label,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: _numberWidth,
                  child: Text(
                    l10n.editorRir,
                    style: label,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final target in targets)
          AppSwipeActions(
            key: ValueKey(target.id),
            trailing: [
              AppSwipeAction(
                label: l10n.editorDelete,
                icon: AppSymbols.delete,
                isDestructive: true,
                onPressed: () => cubit.deleteSet(target.id),
              ),
            ],
            child: _TargetRow(target: target, plansSets: cubit.state.plansSets),
          ),
        Semantics(
          label: l10n.editorAddSetLabel,
          button: true,
          excludeSemantics: true,
          child: AppListRowButton(
            key: const Key('SetTarget.addSet'),
            title: l10n.editorAddSet,
            icon: AppSymbols.add,
            accessory: null,
            onPressed: cubit.addSet,
          ),
        ),
      ],
    );
  }
}

const double _numberWidth = 48;

class const _TargetRow({
  required final SetTarget target,
  required final bool plansSets,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SetTargetCubit>();
    final text = EditorText(
      l10n,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: AppSpacing.s,
            children: [
              SizedBox(
                width: _numberWidth,
                child: Semantics(
                  label: l10n.editorSetNumber(target.setNumber),
                  excludeSemantics: true,
                  child: NumberBadge('${target.setNumber}'),
                ),
              ),
              Expanded(
                child: RepsField(
                  key: Key('SetTarget.min.${target.id}'),
                  value: target.minReps,
                  hint: l10n.editorOptional,
                  label: l10n.editorMinRepsLabel(target.setNumber),
                  onChanged: (reps) =>
                      cubit.setChanged(target.copyWith(minReps: () => reps)),
                ),
              ),
              Expanded(
                child: RepsField(
                  key: Key('SetTarget.max.${target.id}'),
                  value: target.maxReps,
                  hint: l10n.editorOptional,
                  label: l10n.editorMaxRepsLabel(target.setNumber),
                  onChanged: (reps) =>
                      cubit.setChanged(target.copyWith(maxReps: () => reps)),
                ),
              ),
              SizedBox(
                width: _numberWidth,
                child: ChoiceMenu<int?>(
                  key: Key('SetTarget.rir.${target.id}'),
                  tooltip: l10n.editorRirLabel(target.setNumber),
                  value: target.rirTarget,
                  choices: const [null, ...WorkoutEditorRules.rirChoices],
                  title: (rir) =>
                      rir == null ? l10n.editorNone : EditorText.rirText(rir),
                  onSelected: (rir) =>
                      cubit.setChanged(target.copyWith(rirTarget: () => rir)),
                  child: NumberBadge(EditorText.rirText(target.rirTarget)),
                ),
              ),
            ],
          ),
          if (plansSets) _PlanButton(target: target, text: text),
        ],
      ),
    );
  }
}

/// The set's kind and its plan under its reps, opening that set's plan.
class const _PlanButton({
  required final SetTarget target,
  required final EditorText text,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SetTargetCubit>();
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final chip = text.chip(target);
    final summary = text.summary(target, cubit.state.settings);
    return Semantics(
      button: true,
      label: l10n.editorSetKindLabel(
        target.setNumber,
        text.kindTitle(target.setType),
      ),
      value: summary ?? '',
      excludeSemantics: true,
      child: InkWell(
        key: Key('SetTarget.plan.${target.id}'),
        onTap: () => unawaited(
          showSetPlanDetail(
            context,
            target: target,
            settings: cubit.state.settings,
            onChange: cubit.setChanged,
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: _numberWidth + AppSpacing.s,
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (chip != null)
                      AppChip(label: chip)
                    else
                      Text(text.kindTitle(target.setType), style: secondary),
                    if (summary != null) Text(summary, style: secondary),
                  ],
                ),
              ),
              Icon(
                AppSymbols.disclosure,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A template exercise's plan: warm-ups, rest, notes, link, weekly
/// targets, and its substitutions (Swift `ExercisePlanSection`).
class _ExercisePlan extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SetTargetCubit>();
    final state = context.watch<SetTargetCubit>().state;
    final exercise = state.exercise;
    final text = EditorText(
      l10n,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.l,
      children: [
        AppSection(
          header: l10n.editorPlan,
          children: [
            ChoiceMenu<int?>(
              key: const Key('SetTarget.warmupSets'),
              tooltip: l10n.editorWarmupSets,
              value: exercise.warmupSetCount,
              choices: WorkoutEditorRules.choices(
                WorkoutEditorRules.warmupSetChoices,
                exercise.warmupSetCount,
              ),
              title: text.warmupTitle,
              onSelected: cubit.warmupsChanged,
              child: AppListRow(
                title: l10n.editorWarmupSets,
                accessory: AppListRowMenu(
                  text.warmupTitle(exercise.warmupSetCount),
                ),
              ),
            ),
            ChoiceMenu<int?>(
              key: const Key('SetTarget.rest'),
              tooltip: l10n.editorRest,
              value: exercise.restSeconds,
              choices: WorkoutEditorRules.choices(
                WorkoutEditorRules.restSecondsChoices,
                exercise.restSeconds,
              ),
              title: text.restTitle,
              onSelected: cubit.restChanged,
              child: AppListRow(
                title: l10n.editorRest,
                accessory: AppListRowMenu(text.restTitle(exercise.restSeconds)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: TextFormField(
                key: const Key('SetTarget.notes'),
                initialValue: exercise.notes ?? '',
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: l10n.editorNotes,
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: cubit.notesChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Focus(
                    onFocusChange: (focused) {
                      if (!focused) cubit.linkSubmitted();
                    },
                    child: TextFormField(
                      key: const Key('SetTarget.link'),
                      initialValue: state.linkText,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: l10n.editorLink,
                        border: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: cubit.linkChanged,
                      onFieldSubmitted: (_) => cubit.linkSubmitted(),
                    ),
                  ),
                  if (state.showsLinkError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s),
                      child: AppInlineMessage(
                        kind: AppInlineMessageKind.error,
                        text: l10n.editorLinkError,
                        kindLabel: l10n.editorLinkError,
                      ),
                    ),
                ],
              ),
            ),
            AppListRowButton(
              key: const Key('SetTarget.variesByWeek'),
              title: l10n.editorWeeklyTargets,
              subtitle: text.variationSummary(
                exercise.setTargets,
                exercise.setTargetsByMicrocycle,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WeeklyTargetsPage(
                    exercise: exercise,
                    settings: cubit.state.settings,
                    library: cubit.state.library,
                    onChange: cubit.variationsChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
        AppSection(
          header: l10n.editorSubstitutions,
          children: [
            for (final substitute in cubit.state.substitutes)
              AppSwipeActions(
                key: ValueKey(substitute.id),
                trailing: [
                  AppSwipeAction(
                    label: l10n.editorRemove,
                    icon: AppSymbols.delete,
                    isDestructive: true,
                    onPressed: () => cubit.substitutionRemoved(substitute.id),
                  ),
                ],
                child: AppListRow(
                  title: substitute.name,
                  thumbnail: ExerciseImage(substitute),
                  accessory: AppListRowCustom(
                    AppIconButton(
                      icon: AppSymbols.delete,
                      semanticLabel: l10n.editorRemove,
                      isDestructive: true,
                      onPressed: () => cubit.substitutionRemoved(substitute.id),
                    ),
                  ),
                ),
              ),
            AppListRowButton(
              key: const Key('SetTarget.addSubstitution'),
              title: l10n.editorAddSubstitution,
              icon: AppSymbols.add,
              accessory: null,
              onPressed: () => unawaited(_addSubstitutions(context)),
            ),
          ],
        ),
      ],
    );
  }

  /// The picker with the substitutions already chosen ticked, never the
  /// exercise itself.
  Future<void> _addSubstitutions(BuildContext context) async {
    final cubit = context.read<SetTargetCubit>();
    final picked = await ExercisePickerPage.show(
      context,
      request: ExercisePickerRequest(
        committedIds: {...cubit.state.exercise.substituteExerciseIds},
        excludedIds: {cubit.state.exercise.exercise.id},
      ),
    );
    if (picked != null) cubit.substitutionsPicked(picked);
  }
}
