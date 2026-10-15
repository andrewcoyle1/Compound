import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/logic/template_summary.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound/workout_tracker/view/notes_sheet.dart';
import 'package:compound/workout_tracker/view/tick.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
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
              ),
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
  const new({required this.member, required this.memberLabel});

  final TrackerExercise member;
  final String? memberLabel;

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
              _ExerciseAction.notes => unawaited(_editNotes(context)),
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

enum _ExerciseAction { notes, delete }

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
    return ExcludeSemantics(
      child: _Columns(
        badge: Text(l10n.trackerColumnSet, style: style),
        last: Text(l10n.trackerColumnLast, style: style),
        fields: [
          for (final field in SetField.of(_plainSet, mode))
            Text(
              _heading(l10n, field, member.weightUnit),
              style: style,
              textAlign: TextAlign.center,
            ),
        ],
        done: const SizedBox.shrink(),
      ),
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
  ExerciseWeightUnit unit,
) => switch (field) {
  SetField.weight => WorkoutText.weightUnit(unit).symbol,
  SetField.reps => l10n.trackerColumnReps,
  SetField.distance => 'm',
  SetField.duration => l10n.trackerColumnTime,
};

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
              ) ??
              AppFormat.placeholder;
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final logLabel = TrackerText.logTitle(l10n, set, exercise, locale: locale);
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.trackerDeleteSet): () =>
            cubit.deleteSet(set.id),
      },
      child: GestureDetector(
        onLongPress: () => unawaited(_menu(context)),
        child: ColoredBox(
          color: isNext
              ? AppColors.tintedSurface(scheme.primary)
              : Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppControlSize.row),
            child: _Columns(
              badge: Text(
                badge,
                style: AppTextStyles.rowDetail.copyWith(
                  fontWeight: FontWeight.w600,
                  color: set.isWarmup ? colors.warmup : scheme.onSurface,
                ),
                semanticsLabel: set.isWarmup
                    ? l10n.setWarmup
                    : l10n.trackerLogSet(badge),
              ),
              last: Semantics(
                label: '${l10n.trackerColumnLast}, $lastText',
                excludeSemantics: true,
                child: Text(
                  lastText,
                  style: secondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              fields: [
                for (final field in SetField.of(set, exercise.trackingMode))
                  _Cell(
                    key: ValueKey('cell-${set.id}-${field.name}'),
                    label: _heading(l10n, field, member.weightUnit),
                    text: _cellText(field, locale),
                    isActive: keypad?.field == field,
                    onTap: () => cubit.openKeypad(set.id, field),
                  ),
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
        : SetKeypad.valueText(field, set, member.weightUnit);
    if (raw.isEmpty) return AppFormat.placeholder;
    return switch (field) {
      SetField.duration => SetKeypad.clockFromDigits(raw),
      SetField.weight || SetField.distance => raw.replaceAll('.', separator),
      SetField.reps => raw,
    };
  }

  Future<void> _menu(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ActiveWorkoutCubit>();
    final delete = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: Icon(AppSymbols.delete, color: context.appColors.danger),
          title: Text(
            l10n.trackerDeleteSet,
            style: TextStyle(color: context.appColors.danger),
          ),
          onTap: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (delete ?? false) cubit.deleteSet(set.id);
  }
}

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
