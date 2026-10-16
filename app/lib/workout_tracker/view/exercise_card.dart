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
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound/workout_tracker/view/equipment_sheet.dart';
import 'package:compound/workout_tracker/view/exercise_settings_page.dart';
import 'package:compound/workout_tracker/view/notes_sheet.dart';
import 'package:compound/workout_tracker/view/set_row_parts.dart';
import 'package:compound/workout_tracker/view/swap_exercise_picker.dart';
import 'package:compound/workout_tracker/view/tick.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound/workout_tracker/view/unit_menu.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
            _Headings(member: card.first),
            for (final member in card)
              if (member.restAnchor is r.RestTop) _RestLine(state: state),
            for (final row in rows) ...[
              _SetRow(
                member: row.member,
                set: row.set,
                badge: row.badge,
                isNext: row.set.id == nextSetId,
                keypad: state.keypad?.setId == row.set.id ? state.keypad : null,
              ),
              if (row.member.restAnchor == r.RestBelow(row.set.id))
                _RestLine(state: state),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () {
                    final cubit = context.read<ActiveWorkoutCubit>();
                    if (letter == null) {
                      cubit.addSet(card.single.exercise.id);
                    } else {
                      cubit.addRound([for (final m in card) m.exercise.id]);
                    }
                  },
                  icon: const Icon(AppSymbols.add),
                  label: Text(
                    letter == null
                        ? context.l10n.trackerAddSet
                        : context.l10n.trackerAddRound,
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
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: scheme.onSurfaceVariant,
    );
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
                    style: AppTextStyles.rowTitle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
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
              PopupMenuItem(
                value: _ExerciseAction.notes,
                child: ListTile(
                  leading: const Icon(AppSymbols.note),
                  title: Text(l10n.trackerNotes),
                ),
              ),
              if (offersDoLater)
                PopupMenuItem(
                  value: _ExerciseAction.doLater,
                  child: ListTile(
                    leading: const Icon(AppSymbols.doLater),
                    title: Text(l10n.trackerDoLater),
                  ),
                ),
              const PopupMenuDivider(),
              if (exercise.equipmentVariations.isNotEmpty)
                PopupMenuItem(
                  value: _ExerciseAction.equipment,
                  child: ListTile(
                    leading: const Icon(AppSymbols.equipment),
                    title: Text(l10n.trackerEquipment),
                  ),
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
              PopupMenuItem(
                value: _ExerciseAction.targets,
                child: ListTile(
                  leading: const Icon(AppSymbols.goal),
                  title: Text(l10n.trackerTargets),
                ),
              ),
              PopupMenuItem(
                value: _ExerciseAction.swap,
                child: ListTile(
                  leading: const Icon(AppSymbols.swap),
                  title: Text(l10n.trackerSwap),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _ExerciseAction.settings,
                child: ListTile(
                  leading: const Icon(AppSymbols.settings),
                  title: Text(l10n.trackerExerciseSettings),
                ),
              ),
              PopupMenuItem(
                value: _ExerciseAction.delete,
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
    await showEquipmentSheet(context, setup);
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
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trackerDeleteExerciseTitle),
        content: Text(member.exercise.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.trackerCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.trackerDeleteExercise),
          ),
        ],
      ),
    );
    if (delete ?? false) cubit.deleteExercise(member.exercise.id);
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
        color: AppColors.tintedSurface(scheme.primary),
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
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
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
                        style: AppTextStyles.rowTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        l10n.trackerTapToDismiss,
                        style: AppTextStyles.label.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
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

/// The column headings, which the cells' own labels speak for.
class _Headings extends StatelessWidget {
  const new({required this.member});

  final TrackerExercise member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = AppTextStyles.label.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final mode = member.exercise.trackingMode;
    Widget heading(SetField field) => Text(
      _heading(l10n, field, member),
      style: style,
      textAlign: TextAlign.center,
    );
    // The plain headings are left to the cells' own labels; the unit menus
    // are buttons in their own right.
    return _Columns(
      badge: ExcludeSemantics(child: Text(l10n.trackerColumnSet, style: style)),
      last: ExcludeSemantics(child: Text(l10n.trackerColumnLast, style: style)),
      fields: [
        for (final field in SetField.of(_plainSet, mode))
          switch (field) {
            SetField.weight => UnitMenu<ExerciseWeightUnit>(
              key: ValueKey('weight-unit-${member.exercise.id}'),
              units: ExerciseWeightUnit.values,
              selected: member.weightUnit,
              name: (unit) => weightUnitName(l10n, unit),
              semanticsLabel: l10n.trackerWeightUnitLabel(
                weightUnitName(l10n, member.weightUnit),
              ),
              onSelected: (unit) => unawaited(_weight(context, unit)),
              child: _MenuHeading(child: heading(field)),
            ),
            SetField.distance => UnitMenu<DistanceUnit>(
              key: ValueKey('distance-unit-${member.exercise.id}'),
              units: DistanceUnit.values,
              selected: member.distanceUnit,
              name: (unit) => distanceUnitName(l10n, unit),
              semanticsLabel: l10n.trackerDistanceUnitLabel(
                distanceUnitName(l10n, member.distanceUnit),
              ),
              onSelected: (unit) => unawaited(_distance(context, unit)),
              child: _MenuHeading(child: heading(field)),
            ),
            SetField.reps ||
            SetField.duration => ExcludeSemantics(child: heading(field)),
          },
      ],
      done: const SizedBox.shrink(),
    );
  }

  /// A new weight unit, asked how to apply (`promptWeightUnitChange`);
  /// the one in use asks nothing.
  Future<void> _weight(BuildContext context, ExerciseWeightUnit unit) async {
    if (unit == member.weightUnit) return;
    final cubit = context.read<ActiveWorkoutCubit>();
    final change = await askUnitChange(
      context,
      context.l10n.trackerChangeWeightUnit,
    );
    if (change == null) return;
    cubit.changeWeightUnit(
      member.exercise.id,
      unit,
      convert: change == UnitChange.convert,
    );
  }

  Future<void> _distance(BuildContext context, DistanceUnit unit) async {
    if (unit == member.distanceUnit) return;
    final cubit = context.read<ActiveWorkoutCubit>();
    final change = await askUnitChange(
      context,
      context.l10n.trackerChangeDistanceUnit,
    );
    if (change == null) return;
    cubit.changeDistanceUnit(
      member.exercise.id,
      unit,
      convert: change == UnitChange.convert,
    );
  }

  static final _plainSet = WorkoutSetModel(
    id: '',
    authorId: '',
    index: 0,
    isWarmup: false,
    dateCreated: DateTime(2000),
  );
}

String _heading(
  AppLocalizations l10n,
  SetField field,
  TrackerExercise member,
) => switch (field) {
  SetField.weight => weightUnitSymbol(member.weightUnit),
  SetField.reps => l10n.trackerColumnReps,
  SetField.distance => TrackerText.distanceSymbol(member.distanceUnit),
  SetField.duration => l10n.trackerColumnTime,
};

/// A heading that opens its unit's menu: underlined, with a row's height
/// to tap.
class _MenuHeading extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: AppControlSize.row),
    child: Center(
      child: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.underline),
        child: child,
      ),
    ),
  );
}

/// One row's columns: the badge, last time, the fields and the circle.
class _Columns extends StatelessWidget {
  const new({
    required this.badge,
    required this.last,
    required this.fields,
    required this.done,
  });

  final Widget badge;
  final Widget last;
  final List<Widget> fields;
  final Widget done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          SizedBox(
            width: MediaQuery.textScalerOf(context).scale(40),
            child: Center(child: badge),
          ),
          Expanded(flex: 3, child: last),
          for (final field in fields) Expanded(flex: 2, child: field),
          SizedBox(
            width: AppControlSize.row,
            child: Center(child: done),
          ),
        ],
      ),
    );
  }
}

/// One set: its badge, last time, its fields to type into and its circle.
/// The next set to log is tinted; a long press offers Delete Set.
class _SetRow extends StatelessWidget {
  const new({
    required this.member,
    required this.set,
    required this.badge,
    required this.isNext,
    required this.keypad,
  });

  final TrackerExercise member;
  final WorkoutSetModel set;
  final String? badge;
  final bool isNext;
  final SetKeypad? keypad;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final cubit = context.read<ActiveWorkoutCubit>();
    final exercise = member.exercise;
    final isLogged = set.completedAt != null;
    final badge = this.badge ?? TrackerText.badge(l10n, set, exercise);
    final previous = r.ActiveWorkout.lastSet(
      rulesSet(set),
      rulesExercise(exercise),
      member.previous == null ? null : rulesExercise(member.previous!),
    );
    final previousModel = previous == null
        ? null
        : member.previous!.sets.firstWhere((s) => s.id == previous.id);
    final lastText = previousModel == null
        ? AppFormat.placeholder
        : TrackerText.figures(
                l10n,
                previousModel,
                exercise.trackingMode,
                member.weightUnit,
                locale: locale,
                distanceUnit: member.distanceUnit,
              ) ??
              AppFormat.placeholder;
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final logLabel = TrackerText.logTitle(l10n, set, exercise, locale: locale);
    final fields = SetField.of(set, exercise.trackingMode);
    Widget cell(SetField field) => _Cell(
      key: ValueKey('cell-${set.id}-${field.name}'),
      label: _heading(l10n, field, member),
      text: _cellText(field, locale),
      isActive: keypad?.field == field,
      onTap: () => cubit.openKeypad(set.id, field),
    );
    final columns = _Columns(
      badge: SetBadge(
        set: set,
        badge: badge,
        semanticsLabel: set.isWarmup
            ? l10n.setWarmup
            : l10n.trackerLogSet(badge),
      ),
      // A tap copies last time's figures into an open set
      // (`SetColumnValue`'s fill).
      last: Semantics(
        label: '${l10n.trackerColumnLast}, $lastText',
        hint: previousModel == null || isLogged ? null : l10n.trackerFillsSet,
        button: previousModel != null && !isLogged,
        excludeSemantics: true,
        onTap: previousModel == null || isLogged
            ? null
            : () => cubit.fillFromPrevious(set.id),
        child: InkWell(
          key: ValueKey('last-${set.id}'),
          onTap: previousModel == null || isLogged
              ? null
              : () => cubit.fillFromPrevious(set.id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppControlSize.row - 8,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                lastText,
                style: secondary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      fields: [
        for (final field in fields)
          // A time still to do gets a stopwatch, filling towards the plan's
          // seconds for a stretch or hold, else last time's.
          if (field == SetField.duration &&
              !fields.contains(SetField.distance) &&
              !isLogged)
            SetStopwatch(
              key: ValueKey('stopwatch-cell-${set.id}'),
              setId: set.id,
              targetSeconds: rulesSet(set).isTimedPiece
                  ? set.durationSec
                  : previousModel?.durationSec,
              field: cell(field),
            )
          else
            cell(field),
      ],
      done: Semantics(
        button: true,
        toggled: isLogged,
        label: isLogged ? l10n.trackerLoggedValue : logLabel,
        excludeSemantics: true,
        child: IconButton(
          key: ValueKey('done-${set.id}'),
          onPressed: () => cubit.toggleSet(set.id),
          icon: Icon(
            isLogged ? AppSymbols.success : AppSymbols.choiceUnselected,
            color: isLogged ? colors.success : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.trackerRestTimer): () =>
            unawaited(_restTimer(context)),
        CustomSemanticsAction(label: TrackerText.deleteTitle(l10n, set)): () =>
            unawaited(deleteSet(context, set, badge)),
      },
      child: GestureDetector(
        onLongPress: () => unawaited(_menu(context, badge)),
        child: ColoredBox(
          color: isNext
              ? AppColors.tintedSurface(scheme.primary)
              : Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppControlSize.row),
            // A drop or mini-set sits under its set, one step in.
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: set.parentSetId == null ? 0 : AppSpacing.l,
              ),
              child: columns,
            ),
          ),
        ),
      ),
    );
  }

  /// The live text while the keypad types into the cell, else the stored
  /// value; empty shows the placeholder.
  String _cellText(SetField field, String locale) {
    final keypad = this.keypad;
    final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
    final raw = keypad != null && keypad.field == field
        ? keypad.text
        : SetKeypad.valueText(
            field,
            set,
            member.weightUnit,
            distanceUnit: member.distanceUnit,
          );
    // "60 + Red", "Red + Blue": the bands beside the weight.
    final bands = field == SetField.weight
        ? set.bands ?? const <String>[]
        : const <String>[];
    if (raw.isEmpty && bands.isEmpty) {
      return field == SetField.reps
          ? TrackerText.targetPlaceholder(set) ?? AppFormat.placeholder
          : AppFormat.placeholder;
    }
    return switch (field) {
      SetField.duration => SetKeypad.clockFromDigits(raw),
      SetField.weight => [
        if (raw.isNotEmpty) raw.replaceAll('.', separator),
        ...bands,
      ].join(' + '),
      SetField.distance => raw.replaceAll('.', separator),
      SetField.reps => raw,
    };
  }

  /// The long press: the rest for this set, and delete.
  Future<void> _menu(BuildContext context, String badge) async {
    final l10n = context.l10n;
    final danger = context.appColors.danger;
    final action = await showModalBottomSheet<_RowAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppSymbols.rest),
              title: Text(l10n.trackerRestTimer),
              onTap: () => Navigator.of(context).pop(_RowAction.rest),
            ),
            ListTile(
              leading: Icon(AppSymbols.delete, color: danger),
              title: Text(
                TrackerText.deleteTitle(l10n, set),
                style: TextStyle(color: danger),
              ),
              onTap: () => Navigator.of(context).pop(_RowAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case _RowAction.rest:
        await _restTimer(context);
      case _RowAction.delete:
        await deleteSet(context, set, badge);
      case null:
        break;
    }
  }

  /// The rest picker, on the rest that would run; Save keeps it for this
  /// set alone, and both wheels at zero clear it.
  Future<void> _restTimer(BuildContext context) async {
    final cubit = context.read<ActiveWorkoutCubit>();
    final initial =
        member.restPicker[set.id] ??
        cubit.state.settings?.defaultRestDurationSeconds ??
        90;
    final seconds = await showRestPicker(context, initial);
    if (seconds == null) return;
    cubit.setCustomRest(set.id, seconds > 0 ? seconds : null);
  }
}

enum _RowAction { rest, delete }

/// A field to type into: a tap opens the keypad on it.
class _Cell extends StatelessWidget {
  const new({
    required this.label,
    required this.text,
    required this.isActive,
    required this.onTap,
    super.key,
  });

  final String label;
  final String text;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      value: text,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.s)),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppControlSize.row - 8),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: ShapeDecoration(
            color: context.appColors.canvas,
            shape: RoundedSuperellipseBorder(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.s),
              ),
              side: isActive
                  ? BorderSide(color: scheme.primary, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.rowTitle.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// The rest under the set it follows: its countdown and bar, then Ready
/// until the next set (`InlineRestTimerRow`).
class _RestLine extends StatelessWidget {
  const new({required this.state});

  final ActiveWorkoutState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
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
                  color: scheme.primary,
                ),
                Text(
                  text,
                  style: AppTextStyles.label.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
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
