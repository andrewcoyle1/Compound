import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart'
    show TrackerExercise;
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound/workout_tracker/view/exercise_settings_page.dart'
    show distanceUnitName, weightUnitName, weightUnitSymbol;
import 'package:compound/workout_tracker/view/set_row_parts.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound/workout_tracker/view/unit_menu.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// What one exercise's set table (its headings, rows and keypad) asks of
/// the screen holding it: the live tracker (`ActiveWorkoutCubit`) or a
/// finished workout's editor (`SessionEditCubit`), as Swift's
/// `ExerciseCardView` and `ExerciseEditorView` share `SetTrackerRow`.
abstract interface class SetTableActions {
  /// Opens the keypad on [field] of [setId].
  void openKeypad(String setId, SetField field);

  /// The circle: logs an open set, or un-logs a logged one.
  void toggleSet(String setId);

  /// Deletes [setId] with its pair and sub-rows.
  void deleteSet(String setId);

  /// The set type menu.
  void setSetType(String setId, r.SetTypeChoice choice);

  /// Add Another Drop or Mini-Set.
  void addSubSet(String setId, r.SubSetKind kind);

  /// The stopwatch stopped on [seconds] held.
  void stopwatchStopped(String setId, int seconds);

  /// The weight heading's menu.
  void changeWeightUnit(
    String exerciseId,
    ExerciseWeightUnit unit, {
    required bool convert,
  });

  /// The distance heading's menu.
  void changeDistanceUnit(
    String exerciseId,
    DistanceUnit unit, {
    required bool convert,
  });

  /// A digit or the decimal point.
  void keypadKey(String key);

  void keypadBackspace();

  /// − or +: the next weight the equipment makes.
  void keypadStep({required bool up});

  /// ± on an assisted weight.
  void keypadSign();

  /// A weight from the loading bar, in the display unit.
  void keypadWeight(double value);

  /// A band chip, on or off.
  void keypadBand(String name);

  /// The plates key: the loading bar shown or put away.
  void togglePlates();

  /// A reps chip.
  void keypadReps(int reps);

  /// Reps in reserve; the chip chosen clears it.
  void keypadRir(int rir);

  /// Next →: the row's next field.
  void keypadNext();

  /// ✓ on the row's last field: logs the set and closes.
  void keypadDone();

  /// Hides the keypad.
  void closeKeypad();

  /// The loading bar opened the plate calculator.
  void plateCalculatorOpened();

  /// Done in the plate calculator: the bar and plates saved to the gym.
  Future<void> saveGymLoading(GymProfileModel edited);
}

/// The column headings, which the cells' own labels speak for.
class SetTableHeadings extends StatelessWidget {
  const new({required this.member, required this.actions, super.key});

  final TrackerExercise member;
  final SetTableActions actions;

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
    return SetTableColumns(
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
    final change = await askUnitChange(
      context,
      context.l10n.trackerChangeWeightUnit,
    );
    if (change == null) return;
    actions.changeWeightUnit(
      member.exercise.id,
      unit,
      convert: change == UnitChange.convert,
    );
  }

  Future<void> _distance(BuildContext context, DistanceUnit unit) async {
    if (unit == member.distanceUnit) return;
    final change = await askUnitChange(
      context,
      context.l10n.trackerChangeDistanceUnit,
    );
    if (change == null) return;
    actions.changeDistanceUnit(
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
class SetTableColumns extends StatelessWidget {
  const new({
    required this.badge,
    required this.last,
    required this.fields,
    required this.done,
    super.key,
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
/// The next set to log is tinted; a long press offers Delete Set, and
/// Rest Timer… where rests run.
class SetTableRow extends StatelessWidget {
  const new({
    required this.member,
    required this.set,
    required this.actions,
    this.badge,
    this.isNext = false,
    this.keypad,
    this.onFillFromPrevious,
    this.restInitialSeconds,
    this.onCustomRest,
    super.key,
  });

  final TrackerExercise member;
  final WorkoutSetModel set;
  final SetTableActions actions;

  /// What the set's circle shows in place of its number ("B1·1").
  final String? badge;

  /// The set the log button logs next, tinted.
  final bool isNext;

  /// The keypad, when it is open on this set.
  final SetKeypad? keypad;

  /// Copies last time's figures into the open set; `null` offers no fill.
  final ValueChanged<String>? onFillFromPrevious;

  /// What the rest picker opens on.
  final int? restInitialSeconds;

  /// Keeps a rest set by hand (`null` clears it); `null` offers no Rest
  /// Timer…, as a finished workout's editor runs no rests.
  final void Function(String setId, int? seconds)? onCustomRest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final cubit = actions;
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
    final fill = onFillFromPrevious;
    final canFill = previousModel != null && !isLogged && fill != null;
    final columns = SetTableColumns(
      badge: SetBadge(
        exercise: exercise,
        actions: actions,
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
        hint: canFill ? l10n.trackerFillsSet : null,
        button: canFill,
        excludeSemantics: true,
        onTap: canFill ? () => fill(set.id) : null,
        child: InkWell(
          key: ValueKey('last-${set.id}'),
          onTap: canFill ? () => fill(set.id) : null,
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
              onStopped: (seconds) => cubit.stopwatchStopped(set.id, seconds),
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
        if (onCustomRest != null)
          CustomSemanticsAction(label: l10n.trackerRestTimer): () =>
              unawaited(_restTimer(context)),
        CustomSemanticsAction(label: TrackerText.deleteTitle(l10n, set)): () =>
            unawaited(deleteSet(context, actions, exercise, set, badge)),
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
            if (onCustomRest != null)
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
        await deleteSet(context, actions, member.exercise, set, badge);
      case null:
        break;
    }
  }

  /// The rest picker, on the rest that would run; Save keeps it for this
  /// set alone, and both wheels at zero clear it.
  Future<void> _restTimer(BuildContext context) async {
    final keep = onCustomRest;
    if (keep == null) return;
    final seconds = await showRestPicker(context, restInitialSeconds ?? 90);
    if (seconds == null) return;
    keep(set.id, seconds > 0 ? seconds : null);
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
