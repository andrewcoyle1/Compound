import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// A muscle's planned work in a template (Swift `TargetMuscleSummary`).
final class const TargetMuscleSummary(
  final Muscles muscle,

  /// Planned sets, a muscle the exercise only assists counting half.
  final double weightedTargetSets,

  /// How many of the template's exercises work it.
  final int exerciseCount,
) extends Equatable {
  @override
  List<Object> get props => [muscle, weightedTargetSets, exerciseCount];
}

/// The read-only views of a template's plan (`MuscleVolume.targetSummaries`,
/// `WorkoutTemplateExercise+PlanSummary.swift`, `WorkoutTemplateRow`).
abstract final class TemplateSummary {
  /// Planned sets per muscle: the whole set for a primary muscle, half for
  /// a secondary one. Exercises with no sets planned add nothing. Sorted by
  /// [name], the muscle's display name.
  static List<TargetMuscleSummary> targetMuscles(
    List<WorkoutTemplateExercise> exercises,
    String Function(Muscles) name,
  ) {
    final sets = <Muscles, double>{};
    final counts = <Muscles, int>{};
    for (final exercise in exercises) {
      final setCount = exercise.setTargets.length;
      if (setCount == 0) continue;
      for (final MapEntry(key: muscle, value: target)
          in exercise.exercise.muscleGroups.entries) {
        final factor = target == MuscleTargetType.secondary ? 0.5 : 1.0;
        sets[muscle] = (sets[muscle] ?? 0) + setCount * factor;
        counts[muscle] = (counts[muscle] ?? 0) + 1;
      }
    }
    return [
      for (final MapEntry(key: muscle, value: weighted) in sets.entries)
        TargetMuscleSummary(muscle, weighted, counts[muscle]!),
    ]..sort((a, b) => name(a.muscle).compareTo(name(b.muscle)));
  }

  /// Every muscle the template works, primary if any exercise works it
  /// directly, sorted as [sortedMuscles].
  static List<(Muscles, MuscleTargetType)> muscleTags(
    WorkoutTemplateModel template,
    String Function(Muscles) name,
  ) {
    final merged = <Muscles, MuscleTargetType>{};
    for (final exercise in template.exercises) {
      for (final MapEntry(key: muscle, value: target)
          in exercise.exercise.muscleGroups.entries) {
        if (merged[muscle] == null || target == MuscleTargetType.primary) {
          merged[muscle] = target;
        }
      }
    }
    return sortedMuscles(merged, name);
  }

  /// [muscles] primary first, then secondary, each by [name].
  static List<(Muscles, MuscleTargetType)> sortedMuscles(
    Map<Muscles, MuscleTargetType> muscles,
    String Function(Muscles) name,
  ) {
    int rank(MuscleTargetType target) =>
        target == MuscleTargetType.primary ? 0 : 1;
    return [
      for (final MapEntry(key: muscle, value: target) in muscles.entries)
        (muscle, target),
    ]..sort(
      (a, b) => rank(a.$2) != rank(b.$2)
          ? rank(a.$2) - rank(b.$2)
          : name(a.$1).compareTo(name(b.$1)),
    );
  }

  /// The working sets, the lowest and highest reps and the RIR range the
  /// targets set ("3 sets · 8–10 · RIR 1"). A rep range with only a
  /// ceiling starts at 1; with only a floor, `repsHigh` is null.
  static ({int sets, int? repsLow, int? repsHigh, int? rirLow, int? rirHigh})
  targets(List<SetTarget> targets) {
    int? least(Iterable<int?> values) => values.nonNulls.fold<int?>(
      null,
      (low, value) => low == null || value < low ? value : low,
    );
    int? most(Iterable<int?> values) => values.nonNulls.fold<int?>(
      null,
      (high, value) => high == null || value > high ? value : high,
    );
    final low = least(targets.map((target) => target.minReps));
    final high = most(targets.map((target) => target.maxReps));
    final rirs = targets.map((target) => target.rirTarget);
    return (
      sets: targets.length,
      repsLow: low ?? (high == null ? null : 1),
      repsHigh: high,
      rirLow: least(rirs),
      rirHigh: most(rirs),
    );
  }

  /// Each superset's letter by group id, in the order the groups first
  /// appear. A group of one is not a superset; past "Z" there is no letter.
  static Map<String, String> supersetLetters(
    List<WorkoutTemplateExercise> exercises,
  ) {
    final groups = exercises.map((exercise) => exercise.supersetGroupId);
    final letters = <String, String>{};
    for (final group in groups.nonNulls) {
      if (letters.containsKey(group) || letters.length >= 26) continue;
      if (groups.where((other) => other == group).length < 2) continue;
      letters[group] = String.fromCharCode(65 + letters.length);
    }
    return letters;
  }

  /// The names of the plan's alternatives, in its order; ids not in
  /// [library] are skipped.
  static List<String> alternativeNames(
    WorkoutTemplateExercise exercise,
    List<ExerciseModel> library,
  ) => [
    for (final id in exercise.substituteExerciseIds)
      ?library.where((candidate) => candidate.id == id).firstOrNull?.name,
  ];
}
