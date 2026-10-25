import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/training_library/logic/template_summary.dart';
import 'package:compound/workout_editor/cubit/set_target_cubit.dart'
    show SessionScope;
import 'package:compound/workout_editor/view/set_target_page.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart';
import 'package:compound/workout_tracker/view/equipment_sheet.dart';
import 'package:compound/workout_tracker/view/exercise_settings_page.dart';
import 'package:compound/workout_tracker/view/notes_sheet.dart';
import 'package:compound/workout_tracker/view/set_table.dart';
import 'package:compound/workout_tracker/view/swap_exercise_picker.dart';
import 'package:compound/workout_tracker/view/tick.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// The card: the exercise on it, or its superset as one card with the
/// members' rows in rounds (`ExerciseCardView`, `SupersetBlockView`).
class ExerciseCard extends StatelessWidget {
  const new({required this.state, super.key});

  final ActiveWorkoutState state;

  @override
  Widget build(BuildContext context) {
    final card = state.card;
    final letter = state.supersetLetter;
    if (card.isEmpty) return const SizedBox.shrink();
    final byId = {for (final member in card) member.exercise.id: member};
    final List<_Row> rows;
    if (letter == null) {
      final member = card.single;
      rows = [
        for (final set in member.exercise.sets)
          _Row(member: member, set: set, badge: null),
      ];
    } else {
      rows = [
        for (final row in state.blockRows)
          if (row.setId case final setId?)
            if (byId[row.exerciseId] case final member?)
              _Row(
                member: member,
                set: member.exercise.sets.firstWhere((s) => s.id == setId),
                badge: row.badge,
              ),
      ];
    }
    final cubit = context.read<ActiveWorkoutCubit>();
    final nextSetId = switch (state.primaryAction) {
      r.LogSetAction(:final setId) => setId,
      _ => null,
    };
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (letter != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppChip(
                    label: context.l10n.supersetLabel(letter),
                    icon: AppSymbols.superset,
                    tint: context.appColors.superset,
                  ),
                ),
              ),
            for (final (index, member) in card.indexed)
              _Header(
                member: member,
                memberLabel: letter == null
                    ? null
                    : r.ActiveWorkout.memberLabel(letter, index),
                // A superset is put off as one, from its first member.
                offersDoLater: index == 0 && member.canDoLater,
              ),
            for (final member in card)
              if (_ProgressionNote.textOf(context, state, member)
                  case final text?)
                _ProgressionNote(text: text),
            const SizedBox(height: AppSpacing.s),
            SetTableHeadings(member: card.first, actions: cubit),
            for (final member in card)
              if (member.restAnchor is r.RestTop) _RestLine(state: state),
            for (final row in rows) ...[
              SetTableRow(
                member: row.member,
                set: row.set,
                actions: cubit,
                badge: row.badge,
                isNext: row.set.id == nextSetId,
                keypad: state.keypad?.setId == row.set.id ? state.keypad : null,
                onFillFromPrevious: cubit.fillFromPrevious,
                restInitialSeconds:
                    row.member.restPicker[row.set.id] ??
                    state.settings?.defaultRestDurationSeconds ??
                    90,
                onCustomRest: cubit.setCustomRest,
              ),
              if (row.member.restAnchor == r.RestBelow(row.set.id))
                _RestLine(state: state),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppTextButton(
                  onPressed: () {
                    if (letter == null) {
                      cubit.addSet(card.single.exercise.id);
                    } else {
                      cubit.addRound([for (final m in card) m.exercise.id]);
                    }
                  },
                  label: letter == null
                      ? context.l10n.trackerAddSet
                      : context.l10n.trackerAddRound,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _Row({
  required final TrackerExercise member,
  required final WorkoutSetModel set,
  required final String? badge,
});

/// The exercise's name, targets and notes, with its menu.
class _Header extends StatelessWidget {
  const new({
    required this.member,
    required this.memberLabel,
    this.offersDoLater = false,
  });

  final TrackerExercise member;
  final String? memberLabel;
  final bool offersDoLater;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final exercise = member.exercise;
    final secondary = AppTextStyles.rowDetail.secondary(context);
    final notes = [
      if (member.exerciseNote case final note?) (AppSymbols.pinnedNote, note),
      if (exercise.planNotes?.trim() case final note? when note.isNotEmpty)
        (AppSymbols.note, note),
      if (exercise.notes?.trim() case final note? when note.isNotEmpty)
        (AppSymbols.note, note),
    ];
    final targets = _targets(context, exercise.setTargets);
    final label = memberLabel;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.l,
        top: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    label == null ? exercise.name : '$label  ${exercise.name}',
                    style: AppTextStyles.sectionTitle,
                  ),
                ),
                if (targets.isNotEmpty) Text(targets, style: secondary),
                for (final (icon, note) in notes)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xs,
                    children: [
                      Icon(
                        icon,
                        size: AppIconSize.small.of(context),
                        color: scheme.onSurfaceVariant,
                      ),
                      Expanded(child: Text(note, style: secondary)),
                    ],
                  ),
              ],
            ),
          ),
          PopupMenuButton<_ExerciseAction>(
            tooltip: l10n.trackerExerciseOptions,
            icon: Icon(AppSymbols.more),
            onSelected: (action) => switch (action) {
              _ExerciseAction.equipment => unawaited(_equipment(context)),
              _ExerciseAction.sides =>
                context.read<ActiveWorkoutCubit>().toggleSides(exercise.id),
              _ExerciseAction.notes => unawaited(_editNotes(context)),
              _ExerciseAction.doLater =>
                context.read<ActiveWorkoutCubit>().doLater(exercise.id),
              _ExerciseAction.targets => unawaited(_editTargets(context)),
              _ExerciseAction.swap => unawaited(_swap(context)),
              _ExerciseAction.settings => unawaited(_settings(context)),
              _ExerciseAction.delete => unawaited(_delete(context)),
            },
            itemBuilder: (_) => [
              AppMenuItem(
                value: _ExerciseAction.notes,
                icon: AppSymbols.note,
                label: l10n.trackerNotes,
              ),
              if (offersDoLater)
                AppMenuItem(
                  value: _ExerciseAction.doLater,
                  icon: AppSymbols.doLater,
                  label: l10n.trackerDoLater,
                ),
              const PopupMenuDivider(),
              if (exercise.equipmentVariations.isNotEmpty)
                AppMenuItem(
                  value: _ExerciseAction.equipment,
                  icon: AppSymbols.equipment,
                  label: l10n.trackerEquipment,
                ),
              // A check beside it while the sides are logged apart.
              if (rulesExercise(exercise).isPerSide)
                CheckedPopupMenuItem(
                  value: _ExerciseAction.sides,
                  checked: rulesExercise(exercise).isSplit,
                  child: Semantics(
                    hint: l10n.trackerSplitSidesHint,
                    child: Text(l10n.trackerSplitSides),
                  ),
                ),
              AppMenuItem(
                value: _ExerciseAction.targets,
                icon: AppSymbols.goal,
                label: l10n.trackerTargets,
              ),
              AppMenuItem(
                value: _ExerciseAction.swap,
                icon: AppSymbols.swap,
                label: l10n.trackerSwap,
              ),
              const PopupMenuDivider(),
              AppMenuItem(
                value: _ExerciseAction.settings,
                icon: AppSymbols.settings,
                label: l10n.trackerExerciseSettings,
              ),
              AppMenuItem(
                value: _ExerciseAction.delete,
                icon: AppSymbols.delete,
                label: l10n.trackerDeleteExercise,
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "3 sets · 8–12 · RIR 1", what the plan sets.
  static String _targets(BuildContext context, List<SetTarget> setTargets) {
    if (setTargets.isEmpty) return '';
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final targets = TemplateSummary.targets(setTargets);
    String range(int low, int high) => low == high
        ? AppFormat.number(low, locale: locale)
        : AppFormat.repRange(low, high, locale: locale);
    return [
      l10n.setCount(targets.sets),
      switch ((targets.repsLow, targets.repsHigh)) {
        (final low?, final high?) => range(low, high),
        (final low?, null) => '${AppFormat.number(low, locale: locale)}+',
        _ => null,
      },
      if ((targets.rirLow, targets.rirHigh) case (final low?, final high?))
        l10n.rirRange(range(low, high)),
    ].nonNulls.join(' · ');
  }

  /// The exercise's equipment variations, to choose or edit.
  Future<void> _equipment(BuildContext context) async {
    final cubit = context.read<ActiveWorkoutCubit>();
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

  /// The exercise as the library has it; null for one it no longer holds,
  /// which offers no Targets or Exercise Settings, as in Swift.
  ExerciseModel? _libraryModel(BuildContext context) => context
      .read<ActiveWorkoutCubit>()
      .state
      .library
      .where((e) => e.id == member.exercise.templateId)
      .firstOrNull;

  /// This workout's targets for the exercise (`SetTargetScope.session`).
  Future<void> _editTargets(BuildContext context) async {
    final cubit = context.read<ActiveWorkoutCubit>();
    final model = _libraryModel(context);
    if (model == null) return;
    cubit.targetsOpened();
    final saved = await openSetTarget(
      context,
      WorkoutTemplateExercise(
        id: member.exercise.id,
        exercise: model,
        setTargets: member.exercise.setTargets,
        setRestTimers: false,
      ),
      scope: const SessionScope(),
      settings: cubit.state.settings,
      library: cubit.state.library,
    );
    if (saved != null) cubit.setTargets(member.exercise.id, saved.setTargets);
  }

  /// Swap Exercise, the plan's alternatives first; the logged sets stay.
  Future<void> _swap(BuildContext context) async {
    final cubit = context.read<ActiveWorkoutCubit>()..swapOpened();
    final replacement = await SwapExercisePicker.show(
      context,
      library: cubit.state.library,
      alternativeIds: member.exercise.substituteExerciseIds,
    );
    if (replacement != null) {
      cubit.swapExercise(member.exercise.id, replacement);
    }
  }

  Future<void> _settings(BuildContext context) async {
    final model = _libraryModel(context);
    if (model == null) return;
    context.read<ActiveWorkoutCubit>().exerciseSettingsOpened();
    await ExerciseSettingsPage.push(context, model);
  }

  Future<void> _editNotes(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ActiveWorkoutCubit>();
    final notes = await showNotesSheet(
      context,
      title: member.exercise.name,
      saveLabel: l10n.trackerSave,
      fields: [
        NoteField(
          label: l10n.trackerSessionNote,
          footer: l10n.trackerSessionNoteFooter,
          initial: member.exercise.notes ?? '',
          // The note left last time, the session the Last column reads.
          hint: switch (member.previous?.notes?.trim()) {
            final note? when note.isNotEmpty => note,
            _ => null,
          },
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
      member.exercise.id,
      sessionNote: notes[0],
      exerciseNote: notes[1],
    );
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ActiveWorkoutCubit>();
    final delete = await AppDialog.confirmDestructive(
      context,
      title: l10n.trackerDeleteExerciseTitle,
      message: member.exercise.name,
      confirmLabel: l10n.trackerDeleteExercise,
      cancelLabel: l10n.trackerCancel,
    );
    if (delete) cubit.deleteExercise(member.exercise.id);
  }
}

/// Why smart progression changed today's numbers, above the sets until it
/// is tapped (`ProgressionNote`): the reason, then the plan the exercise
/// opens with when the set plan is on.
class _ProgressionNote extends StatelessWidget {
  const new({required this.text});

  final String text;

  /// The note for [member], or null when none shows.
  static String? textOf(
    BuildContext context,
    ActiveWorkoutState state,
    TrackerExercise member,
  ) {
    if (!member.showsProgressionNote) return null;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final reason = member.progressionReason;
    final note = [
      if (reason != null)
        TrackerText.progressionReason(
          l10n,
          reason,
          member.weightUnit,
          locale: locale,
        ),
      if (state.settings?.setPlanning ?? false)
        ?TrackerText.planSummary(
          l10n,
          member.exercise,
          member.weightUnit,
          locale: locale,
        ),
    ];
    return note.isEmpty ? null : note.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final acknowledge = context
        .read<ActiveWorkoutCubit>()
        .acknowledgeProgressionNote;
    const shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.m)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        0,
      ),
      child: Material(
        color: AppColors.tintedSurface(Theme.of(context).colorScheme.primary),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // The method sits beside the label, outside the dismissing
            // tap, so asking how the numbers were reached keeps them.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: AppSpacing.xs,
                children: [
                  Icon(
                    AppSymbols.smartProgression,
                    size: AppIconSize.small.of(context),
                    color: scheme.onSurfaceVariant,
                  ),
                  Text(
                    l10n.workoutSettingsSmartProgression,
                    style: AppTextStyles.label.semibold.secondary(context),
                  ),
                  MethodInfoButton(MethodInfo.smartProgression(l10n)),
                ],
              ),
            ),
            Semantics(
              key: const Key('ExerciseCard.progressionNote'),
              button: true,
              label: l10n.trackerProgressionNoteLabel(text),
              hint: l10n.trackerDismissesNote,
              excludeSemantics: true,
              onTap: acknowledge,
              child: InkWell(
                onTap: acknowledge,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.m,
                    0,
                    AppSpacing.m,
                    AppSpacing.m,
                  ),
                  child: Column(
                    spacing: AppSpacing.xs,
                    children: [
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.rowTitle,
                      ),
                      Text(
                        l10n.trackerTapToDismiss,
                        style: AppTextStyles.label.secondary(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ExerciseAction {
  equipment,
  sides,
  notes,
  doLater,
  targets,
  swap,
  settings,
  delete,
}

/// The rest under the set it follows: its countdown and bar, then Ready
/// until the next set (`InlineRestTimerRow`).
class _RestLine extends StatelessWidget {
  const new({required this.state});

  final ActiveWorkoutState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Tick(
      builder: (context, now) {
        final end = state.restEnd;
        final length = state.restLength;
        final left = end?.difference(now);
        final running = left != null && !left.isNegative;
        final text = running
            ? l10n.trackerRestRunning(
                AppFormat.duration(left + const Duration(milliseconds: 999)),
              )
            : l10n.trackerRestReady;
        final fraction = running && length != null && length.inSeconds > 0
            ? 1 - left.inMilliseconds / length.inMilliseconds
            : 1.0;
        return Semantics(
          liveRegion: !running,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              spacing: AppSpacing.s,
              children: [
                Icon(
                  AppSymbols.rest,
                  size: AppIconSize.small.of(context),
                  color: context.appColors.accentInk,
                ),
                Text(
                  text,
                  style: AppTextStyles.label.semibold.tabular.accent(context),
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0, 1).toDouble(),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadius.s),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
