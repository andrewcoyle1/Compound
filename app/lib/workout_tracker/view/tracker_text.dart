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
}
