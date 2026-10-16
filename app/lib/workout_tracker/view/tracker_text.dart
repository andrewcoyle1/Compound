import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// The tracker's words, worded from the decisions `training_rules` makes
/// (`ActiveWorkout.logTitle`, `figures`, `SetValidation`).
abstract final class TrackerText {
  /// A set's place in its table: "W", "2", "1L", or "↳" for a drop or
  /// mini-set.
  static String badge(
    AppLocalizations l10n,
    WorkoutSetModel set,
    WorkoutExerciseModel exercise,
  ) {
    if (set.isWarmup) return l10n.trackerWarmupBadge;
    if (set.parentSetId != null) return '↳';
    return r.ActiveWorkout.setNumberLabel(
      rulesSet(set),
      rulesExercise(exercise),
    );
  }

  /// "100 kg × 8", "12 reps", "1:30", "400 m · 1:30"; null until the set
  /// holds its figures.
  static String? figures(
    AppLocalizations l10n,
    WorkoutSetModel set,
    TrackingMode mode,
    ExerciseWeightUnit unit, {
    String? locale,
  }) {
    final duration = set.durationSec == null
        ? null
        : AppFormat.duration(Duration(seconds: set.durationSec!));
    switch (mode) {
      case TrackingMode.weightReps:
        final reps = set.reps;
        if (reps == null) return null;
        final load = set.loadKg;
        if (load == null || load == 0) return l10n.repCount(reps);
        final weight = AppFormat.weight(
          load,
          WorkoutText.weightUnit(unit),
          maxFractionDigits: 2,
          locale: locale,
        );
        return '$weight × ${AppFormat.number(reps, locale: locale)}';
      case TrackingMode.repsOnly:
        return set.reps == null ? null : l10n.repCount(set.reps!);
      case TrackingMode.timeOnly:
        return duration;
      case TrackingMode.distanceTime:
        final meters = set.distanceMeters;
        if (meters == null || duration == null) return null;
        return '${metersText(meters, locale)} · $duration';
    }
  }

  /// "400 m".
  static String metersText(double meters, String? locale) =>
      '${AppFormat.number(meters, maxFractionDigits: 2, locale: locale)} m';

  /// The log button's words for [set]: "Log set 2 · 100 kg × 8".
  static String logTitle(
    AppLocalizations l10n,
    WorkoutSetModel set,
    WorkoutExerciseModel exercise, {
    String? locale,
  }) {
    final name = switch (set) {
      WorkoutSetModel(isWarmup: true) => l10n.trackerLogWarmup,
      WorkoutSetModel(parentSetId: final _?, kind: SetKind.drop) =>
        l10n.trackerLogDrop,
      WorkoutSetModel(parentSetId: null, kind: SetKind.amrap) =>
        l10n.trackerLogFailure,
      _ => l10n.trackerLogSet(badge(l10n, set, exercise)),
    };
    final figures = TrackerText.figures(
      l10n,
      set,
      exercise.trackingMode,
      exercise.weightUnit ?? ExerciseWeightUnit.kilograms,
      locale: locale,
    );
    return [name, ?figures].join(' · ');
  }

  /// Why a set could not be logged.
  static String problem(AppLocalizations l10n, r.SetProblem problem) =>
      switch (problem) {
        r.SetProblem.noReps => l10n.trackerProblemNoReps,
        r.SetProblem.noTime => l10n.trackerProblemNoTime,
        r.SetProblem.negativeWeight => l10n.trackerProblemNegativeWeight,
        r.SetProblem.noDistance => l10n.trackerProblemNoDistance,
      };

  /// What VoiceOver and TalkBack hear when a set is logged:
  /// "Set 2 logged, 100 kg × 8".
  static String logged(
    AppLocalizations l10n,
    WorkoutSetModel set,
    WorkoutExerciseModel exercise, {
    String? locale,
  }) {
    final figures = TrackerText.figures(
      l10n,
      set,
      exercise.trackingMode,
      exercise.weightUnit ?? ExerciseWeightUnit.kilograms,
      locale: locale,
    );
    return l10n.trackerSetLogged(badge(l10n, set, exercise), figures ?? '');
  }

  // MARK: - Loading

  /// A weight already in the display unit, as the loading reads it:
  /// "47.5", up to two decimals.
  static String amount(double value, {String? locale}) =>
      AppFormat.number(value, maxFractionDigits: 2, locale: locale);

  /// "kg" or "lb".
  static String unit(ExerciseWeightUnit unit) =>
      WorkoutText.weightUnit(unit).symbol;

  /// "1 × 25 · 2 × 10", heaviest first.
  static String plateCounts(r.PlateLoading loading, {String? locale}) => [
    for (final (weight, count) in loading.counts)
      '$count × ${amount(weight, locale: locale)}',
  ].join(' · ');

  /// "25 kg on each side + 20 kg bar = 70 kg", "25 kg of plates + 18 kg
  /// base = 43 kg" on a single-sleeve machine, or "Empty bar = 20 kg".
  static String plateEquation(
    AppLocalizations l10n,
    r.PlateLoading loading,
    ExerciseWeightUnit weightUnit, {
    String? locale,
  }) {
    String weight(double value) =>
        '${amount(value, locale: locale)} ${unit(weightUnit)}';
    final total = weight(loading.total);
    if (loading.perSide.isEmpty) return l10n.plateEquationEmpty(total);
    return loading.sleeves == 1
        ? l10n.plateEquationSingle(
            weight(loading.plates),
            weight(loading.base),
            total,
          )
        : l10n.plateEquationBar(
            weight(loading.plates),
            weight(loading.base),
            total,
          );
  }

  /// "Not loadable: 67.5 or 72.5 kg", the nearest totals either side.
  static String notLoadable(
    AppLocalizations l10n,
    r.NotLoadable result,
    ExerciseWeightUnit weightUnit, {
    String? locale,
  }) {
    final options = [
      for (final value in [result.below, result.above])
        if (value != null) amount(value, locale: locale),
    ];
    if (options.isEmpty) return l10n.plateNotLoadablePlates;
    return l10n.plateNotLoadableOptions(
      options.length == 1
          ? options.single
          : l10n.plateOr(options[0], options[1]),
      unit(weightUnit),
    );
  }

  /// "Pin 14 + 2 kg" for [total] on a stack with add-ons, "Pin 14 kg" when
  /// no add-on is needed; `null` for anything else.
  static String? stackSummary(
    AppLocalizations l10n,
    r.WeightStep step,
    double? total,
    ExerciseWeightUnit weightUnit, {
    String? locale,
  }) {
    final breakdown = total == null ? null : step.stack?.breakdown(total);
    if (breakdown == null) return null;
    final pin = amount(breakdown.pin, locale: locale);
    if (breakdown.addOns.isEmpty) return l10n.stackPin(pin, unit(weightUnit));
    return l10n.stackPinAddOns(
      pin,
      [for (final a in breakdown.addOns) amount(a, locale: locale)].join(' + '),
      unit(weightUnit),
    );
  }
}
