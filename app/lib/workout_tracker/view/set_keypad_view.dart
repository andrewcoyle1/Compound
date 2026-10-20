import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart'
    show TrackerExercise;
import 'package:compound/workout_tracker/cubit/plate_calculator_cubit.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound/workout_tracker/view/plate_calculator_sheet.dart';
import 'package:compound/workout_tracker/view/plate_loading_view.dart';
import 'package:compound/workout_tracker/view/set_table.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// The weight, reps, distance and time keypad, docked at the foot of the
/// tracker like the system keyboard it replaces (`SetKeyboardView`). Every
/// key edits the set as it is pressed.
///
/// Digits on the left, sized as a number pad. The right-hand column, top to
/// bottom: hide; the plates key on a bar or plate-loaded machine, or ± on an
/// assisted weight; − and + on a weight; and Next → to the row's next field,
/// or ✓ on its last, which logs the set. Over a weight: the bar and plates
/// being loaded, the gym's bands and how to make a stack's weight.
///
/// It works for whichever screen holds the set table: the live tracker or
/// a finished workout's editor, through [actions].
class SetKeypadView extends StatelessWidget {
  const new({
    required this.keypad,
    required this.exercise,
    required this.member,
    required this.actions,
    this.rirTracking = false,
    this.showsPlates = true,
    this.plateCalculator,
    super.key,
  });

  final SetKeypad keypad;

  /// The exercise holding the keypad's set.
  final WorkoutExerciseModel? exercise;

  /// The exercise's units and steps.
  final TrackerExercise? member;
  final SetTableActions actions;

  /// The effort chips show for every set, not only those with a target.
  final bool rirTracking;

  /// The loading bar is shown over a bar's weight.
  final bool showsPlates;

  /// What the loading bar's plate calculator opens on.
  final PlateCalculatorSetup? plateCalculator;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = actions;
    final exercise = this.exercise;
    final set = exercise?.sets.where((s) => s.id == keypad.setId).firstOrNull;
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
    final showsEffort = rirTracking || target?.rirTarget != null;
    final selectedRir = set.rpe == null
        ? null
        : r.EffortScale.rirChoice(set.rpe!);

    // The exercise's equipment, for the loading bar, the bands and ±.
    final member = this.member;
    final unit = member?.weightUnit ?? ExerciseWeightUnit.kilograms;
    final step = member?.weightStep ?? r.WeightStep.fallback(unit.rules);
    final isWeight = keypad.field == SetField.weight;
    // On a bar or plate-loaded machine, whatever the weight, so the bar and
    // plates being loaded are always in view; with every plate off it still
    // opens the plate calculator, where they go back on.
    final showsLoadingBar = isWeight && step.baseWeight != null;
    final shown = keypad.shownWeight(set, unit);
    final loading = r.PlateLoading.of(step, shown);
    final stackSummary = isWeight
        ? TrackerText.stackSummary(l10n, step, shown, unit, locale: locale)
        : null;

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
      [
        digit('4'),
        digit('5'),
        digit('6'),
        if (showsLoadingBar)
          Semantics(
            selected: showsPlates,
            child: _Key(
              key: const ValueKey('keypad-plates'),
              label: l10n.keypadShowPlates,
              onPressed: cubit.togglePlates,
              child: const Icon(AppSymbols.plateCalculator),
            ),
          )
        else if (keypad.showsSignKey)
          Semantics(
            hint: l10n.keypadChangeSignHint,
            child: _Key(
              key: const ValueKey('keypad-sign'),
              label: l10n.keypadChangeSign,
              onPressed: cubit.keypadSign,
              child: const Text('±'),
            ),
          )
        else
          const SizedBox.shrink(),
      ],
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
              // A weight the bar cannot carry keeps the bar up, as it holds
              // the nearest that can.
              if (showsLoadingBar && (showsPlates || loading == null))
                _LoadingBar(
                  actions: actions,
                  plateCalculator: plateCalculator,
                  loading: loading,
                  step: step,
                  shown: shown,
                  unit: unit,
                  machineBase: r.convertWeight(
                    set.machineBaseKg ?? 0,
                    unit.rules,
                  ),
                ),
              if (isWeight && step.bands.isNotEmpty)
                _ChipStrip(
                  children: [
                    _Heading(l10n.keypadBands),
                    for (final band in step.bands)
                      _KeyChip(
                        key: ValueKey('keypad-band-$band'),
                        title: band,
                        selected: set.bands?.contains(band) ?? false,
                        onPressed: () => cubit.keypadBand(band),
                      ),
                  ],
                ),
              if (stackSummary != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Center(
                    child: Text(
                      stackSummary,
                      style: AppTextStyles.rowDetail.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
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
                      child: _Heading(l10n.trackerRirShort),
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
                // The number face, which has one weight for every key.
                child: DefaultTextStyle.merge(
                  style: AppTextStyles.metric.copyWith(color: foreground),
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
    super.key,
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
                  style:
                      (selected
                              ? AppTextStyles.rowDetail.semibold
                              : AppTextStyles.rowDetail)
                          .copyWith(
                            color: selected
                                ? scheme.onPrimary
                                : scheme.onSurface,
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

/// A chip row's name, before its chips.
class _Heading extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: AppTextStyles.label.semibold.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// The bar and plates for the weight being typed (`SetKeyboardView`'s
/// loading bar), with their sum on a line under them. Tapped, it opens the
/// plate calculator. A weight the plates cannot make offers the nearest
/// that they can.
class _LoadingBar extends StatelessWidget {
  const new({
    required this.actions,
    required this.plateCalculator,
    required this.loading,
    required this.step,
    required this.shown,
    required this.unit,
    required this.machineBase,
  });

  final SetTableActions actions;
  final PlateCalculatorSetup? plateCalculator;
  final r.PlateLoading? loading;
  final r.WeightStep step;
  final double? shown;
  final ExerciseWeightUnit unit;

  /// A machine's base kept out of the field, in [unit].
  final double machineBase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final cubit = actions;
    final loading = this.loading;
    final shown = this.shown;
    final scheme = Theme.of(context).colorScheme;
    final danger = context.appColors.danger;
    if (loading != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xxs,
          children: [
            Semantics(
              button: true,
              hint: l10n.keypadPlatesHint,
              child: InkWell(
                key: const ValueKey('keypad-loading'),
                onTap: () => unawaited(_openPlateCalculator(context)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: PlateLoadingView(
                    loading: loading,
                    plates: step.plates,
                    unit: unit,
                    showsEquation: false,
                  ),
                ),
              ),
            ),
            Text(
              TrackerText.plateEquation(l10n, loading, unit, locale: locale),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.rowDetail.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }
    final base = step.baseWeight;
    final result = base == null || shown == null
        ? null
        : r.PlateCalculator.load(
            total: shown,
            bar: base,
            plates: step.plates,
            sleeves: step.sleeves,
          );
    final symbol = TrackerText.unit(unit);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          spacing: AppSpacing.s,
          children: [
            Icon(AppSymbols.warning, color: danger),
            Text(
              l10n.keypadNotLoadable,
              style: AppTextStyles.rowDetail.copyWith(color: danger),
            ),
            if (result case r.NotLoadable(:final below, :final above))
              for (final value in [?below, ?above])
                Semantics(
                  button: true,
                  label: l10n.keypadUseWeight(
                    TrackerText.amount(value - machineBase, locale: locale),
                    symbol,
                  ),
                  excludeSemantics: true,
                  child: AppCtaButton(
                    key: ValueKey('keypad-use-$value'),
                    label: _weight(value - machineBase, symbol, locale),
                    variant: AppCtaVariant.secondary,
                    size: AppCtaSize.compact,
                    onPressed: () => cubit.keypadWeight(value),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// The plate calculator for the set; Done saves the bar and plates to
  /// the gym, and the keypad steps on them from then on.
  Future<void> _openPlateCalculator(BuildContext context) async {
    final setup = plateCalculator;
    if (setup == null) return;
    actions.plateCalculatorOpened();
    final edited = await showPlateCalculator(context, setup);
    if (edited != null) await actions.saveGymLoading(edited);
  }

  static String _weight(double value, String symbol, String locale) =>
      '${TrackerText.amount(value, locale: locale)} $symbol';
}
