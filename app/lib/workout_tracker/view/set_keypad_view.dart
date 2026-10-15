import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// The weight, reps, distance and time keypad, docked at the foot of the
/// tracker like the system keyboard it replaces (`SetKeyboardView`). Every
/// key edits the set as it is pressed.
///
/// Digits on the left, sized as a number pad. The right-hand column, top to
/// bottom: hide; nothing; − and + on a weight; and Next → to the row's next
/// field, or ✓ on its last, which logs the set.
class SetKeypadView extends StatelessWidget {
  const new({required this.state, required this.keypad, super.key});

  final ActiveWorkoutState state;
  final SetKeypad keypad;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ActiveWorkoutCubit>();
    final exercise = state.exercise(keypad.exerciseId);
    final set = state.set(keypad.setId);
    if (exercise == null || set == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
    final next = keypad.nextField;
    final isLogged = set.completedAt != null;

    // The set's target, by its number among the working sets.
    final targets = exercise.setTargets;
    final number = r.ActiveWorkout.round(
      rulesSet(set),
      rulesExercise(exercise),
    );
    final target = targets.isEmpty || set.isWarmup
        ? null
        : targets[(number - 1).clamp(0, targets.length - 1)];
    final lastSetReps = exercise.sets
        .where((s) => s.completedAt != null && !s.isWarmup && s.id != set.id)
        .lastOrNull
        ?.reps;
    final showsEffort =
        (state.settings?.rirTracking ?? false) || target?.rirTarget != null;
    final selectedRir = set.rpe == null
        ? null
        : r.EffortScale.rirChoice(set.rpe!);

    Widget digit(String key) => _Key(
      key: ValueKey('keypad-$key'),
      label: key,
      onPressed: () => cubit.keypadKey(key),
      child: Text(key),
    );

    final rows = <List<Widget>>[
      [
        digit('1'),
        digit('2'),
        digit('3'),
        _Key(
          key: const ValueKey('keypad-hide'),
          label: l10n.keypadHide,
          onPressed: cubit.closeKeypad,
          child: const Icon(AppSymbols.hideKeyboard),
        ),
      ],
      [digit('4'), digit('5'), digit('6'), const SizedBox.shrink()],
      [
        digit('7'),
        digit('8'),
        digit('9'),
        if (keypad.field == SetField.weight)
          Row(
            spacing: _spacing,
            children: [
              Expanded(
                child: _Key(
                  key: const ValueKey('keypad-down'),
                  label: l10n.keypadDecrease,
                  onPressed: () => cubit.keypadStep(up: false),
                  child: const Icon(AppSymbols.decrease),
                ),
              ),
              Expanded(
                child: _Key(
                  key: const ValueKey('keypad-up'),
                  label: l10n.keypadIncrease,
                  onPressed: () => cubit.keypadStep(up: true),
                  child: const Icon(AppSymbols.add),
                ),
              ),
            ],
          )
        else
          const SizedBox.shrink(),
      ],
      [
        if (keypad.field.takesDecimals)
          _Key(
            key: const ValueKey('keypad-.'),
            label: l10n.keypadDecimal,
            plain: true,
            onPressed: () => cubit.keypadKey('.'),
            child: Text(separator),
          )
        else
          const SizedBox.shrink(),
        digit('0'),
        _Key(
          key: const ValueKey('keypad-delete'),
          label: l10n.keypadDelete,
          plain: true,
          onPressed: cubit.keypadBackspace,
          child: const Icon(AppSymbols.deleteBackward),
        ),
        if (next != null)
          _Key(
            key: const ValueKey('keypad-next'),
            label: l10n.keypadNext(_fieldName(l10n, next)),
            prominent: true,
            onPressed: cubit.keypadNext,
            child: const Icon(AppSymbols.nextField),
          )
        else
          _Key(
            key: const ValueKey('keypad-done'),
            label: isLogged ? l10n.keypadDone : l10n.keypadLogSet,
            prominent: true,
            onPressed: cubit.keypadDone,
            child: const Icon(AppSymbols.selected),
          ),
      ],
    ];

    final repsChips = [
      if (lastSetReps != null)
        (l10n.keypadLastSetChip(AppFormat.number(lastSetReps)), lastSetReps),
      if (target?.minReps case final reps?)
        (l10n.keypadMinChip(AppFormat.number(reps)), reps),
      if (target?.maxReps case final reps?)
        (l10n.keypadMaxChip(AppFormat.number(reps)), reps),
    ];

    // The keys grow with the text up to a cap, as the system keyboard's do.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Material(
        color: context.appColors.canvas,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.s,
            AppSpacing.xs,
            AppSpacing.s,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: _spacing,
            children: [
              if (keypad.field == SetField.reps && repsChips.isNotEmpty)
                _ChipStrip(
                  children: [
                    for (final (title, reps) in repsChips)
                      _KeyChip(
                        title: title,
                        onPressed: () => cubit.keypadReps(reps),
                      ),
                  ],
                ),
              if (keypad.field == SetField.reps && showsEffort)
                _ChipStrip(
                  children: [
                    Semantics(
                      label: l10n.trackerRirTitle,
                      excludeSemantics: true,
                      child: Text(
                        l10n.trackerRirShort,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final rir in r.EffortScale.rirChoices)
                      _KeyChip(
                        title: r.EffortScale.rirText(rir),
                        label: l10n.trackerRirChip(r.EffortScale.rirText(rir)),
                        selected: selectedRir == rir,
                        onPressed: () => cubit.keypadRir(rir),
                      ),
                  ],
                ),
              for (final row in rows)
                Row(
                  spacing: _spacing,
                  children: [
                    for (final (index, key) in row.indexed)
                      Expanded(flex: index == 3 ? 4 : 3, child: key),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _spacing = 6;

  static String _fieldName(AppLocalizations l10n, SetField field) =>
      switch (field) {
        SetField.weight => l10n.keypadFieldWeight,
        SetField.reps => l10n.keypadFieldReps,
        SetField.distance => l10n.keypadFieldDistance,
        SetField.duration => l10n.keypadFieldTime,
      };
}

/// A key: a digit or a symbol, with a click as the system keys make.
class _Key extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    required this.child,
    this.prominent = false,
    this.plain = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;
  final bool prominent;

  /// No key drawn behind it, as the number pad's point and delete.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = prominent ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: prominent
            ? scheme.primary
            : plain
            ? Colors.transparent
            : context.appColors.surface,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.m)),
        ),
        child: InkWell(
          customBorder: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.m)),
          ),
          onTap: () {
            unawaited(SystemSound.play(SystemSoundType.click));
            onPressed();
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.textScalerOf(context).scale(48),
            ),
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: foreground,
                    fontWeight: prominent ? FontWeight.w600 : FontWeight.w400,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of chips over the keypad that scrolls sideways when it outgrows
/// the width.
class _ChipStrip extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: SetKeypadView._spacing, children: children),
    );
  }
}

/// A chip over the keypad, drawn as a key: the accent when chosen.
class _KeyChip extends StatelessWidget {
  const new({
    required this.title,
    required this.onPressed,
    this.label,
    this.selected = false,
  });

  final String title;
  final String? label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label ?? title,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : context.appColors.surface,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.m)),
        ),
        child: InkWell(
          customBorder: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.m)),
          ),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppControlSize.row),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Center(
                widthFactor: 1,
                child: Text(
                  title,
                  style: AppTextStyles.rowDetail.copyWith(
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
