/// The warm-up ramp before the working sets: lighter sets whose reps taper as
/// the load rises (`WorkoutSessionModel+WarmupSets.swift`). Sources and
/// Compound's own choices: `MethodInfo.warmupSets`.
library;

import 'package:training_rules/src/models.dart';

/// Warm-up rules (`WorkoutSessionModel.generateWarmupSets` and helpers).
abstract final class WarmUps {
  /// The warm-up sets for one exercise. Without a plan [count], how many
  /// follows from the working reps and type, and a warm-up the rounding puts
  /// at or above the working weight, or onto the one before, is dropped. Work
  /// at body weight or with assistance gets none unless the plan asks.
  ///
  /// [round] is the exercise's weight rule (`WeightRoundingRule.round`);
  /// `null`, as without a library exercise, leaves weights unrounded.
  static List<WorkoutSet> generate({
    required TrackingMode trackingMode,
    required double? workingWeightKg,
    required int? workingReps,
    required List<SetTarget> setTargets,
    required String Function() newId,
    String authorId = '',
    ExerciseType? exerciseType,
    double Function(double)? round,
    int? count,
  }) {
    if (trackingMode != TrackingMode.weightReps &&
        trackingMode != TrackingMode.repsOnly) {
      return [];
    }
    final isUnloaded =
        trackingMode == TrackingMode.repsOnly ||
        (workingWeightKg != null && workingWeightKg <= 0);
    if (count == null && isUnloaded) return [];

    final targetReps =
        workingReps ??
        setTargets.firstOrNull?.minReps ??
        setTargets.firstOrNull?.maxReps;
    final fractions = percentages(
      count ?? warmupCount(targetReps, exerciseType),
    );
    final sets = [
      for (final (index, fraction) in fractions.indexed)
        WorkoutSet(
          id: newId(),
          authorId: authorId,
          index: index + 1,
          // Bodyweight work has no load to taper against.
          reps: trackingMode == TrackingMode.weightReps
              ? reps(fraction)
              : targetReps,
          weightKg: _weight(workingWeightKg, fraction, round),
          isWarmup: true,
        ),
    ];

    if (count != null || workingWeightKg == null || workingWeightKg <= 0) {
      return sets;
    }
    final kept = <WorkoutSet>[];
    for (final set in sets) {
      final weight = set.weightKg!;
      if (weight <= 0 ||
          weight >= workingWeightKg ||
          weight <= (kept.lastOrNull?.weightKg ?? 0)) {
        continue;
      }
      kept.add(set.copyWith(index: kept.length + 1));
    }
    return kept;
  }

  static double? _weight(
    double? working,
    double fraction,
    double Function(double)? round,
  ) {
    if (working == null) return null;
    // Assistance (stored negative) warms up with more of it.
    final weight = working >= 0 ? working * fraction : working * (2 - fraction);
    return round == null ? weight : round(weight);
  }

  /// The share of the working weight for each warm-up.
  static List<double> percentages(int count) => switch (count) {
    <= 0 => [],
    1 => [0.60],
    2 => [0.50, 0.75],
    3 => [0.45, 0.65, 0.82],
    _ => [0.45, 0.60, 0.75, 0.85, for (var i = 4; i < count; i++) 0.90],
  };

  /// Reps at [percentage] of the working weight: 8, 5, 3, then 2.
  static int reps(double percentage) => switch (percentage) {
    <= 0.5 => 8,
    <= 0.7 => 5,
    <= 0.85 => 3,
    _ => 2,
  };

  /// How many warm-ups without a plan: one for isolation and core; otherwise
  /// three for six reps or fewer, two up to twelve (or unknown), one past.
  static int warmupCount(int? workingReps, ExerciseType? type) {
    switch (type) {
      case ExerciseType.isolationUpper ||
          ExerciseType.isolationLower ||
          ExerciseType.core:
        return 1;
      case ExerciseType.compoundUpper || ExerciseType.compoundLower || null:
        if (workingReps == null || workingReps <= 0) return 2;
        if (workingReps <= 6) return 3;
        if (workingReps <= 12) return 2;
        return 1;
    }
  }
}
