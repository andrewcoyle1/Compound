import 'package:compound_models/src/training_enums.dart';
import 'package:compound_models/src/workout_exercise_model.dart';
import 'package:compound_models/src/workout_session_model.dart';
import 'package:compound_models/src/workout_set_model.dart';

/// What a logged set amounts to, as the Swift app's `WorkoutSetModel`
/// computes it (`WorkoutSetModel.swift`, `SetKind.swift`).
extension WorkoutSetStats on WorkoutSetModel {
  /// A drop, mini-set or cluster belonging to the set named by
  /// [WorkoutSetModel.parentSetId], rather than a set of its own.
  bool get isSubSet => parentSetId != null;

  /// The weight as entered and shown: the total less a machine base kept out
  /// of it.
  double? get loadKg => switch (weightKg) {
    final weight? => weight - (machineBaseKg ?? 0),
    null => null,
  };

  /// Weight × reps, null without both or for assistance (a negative load). A
  /// `both` row counts twice, as does a dumbbell in each hand (`loadCount`).
  double? get volumeKg {
    final load = loadKg;
    final reps = this.reps;
    if (load == null || load < 0 || reps == null) return null;
    final sides = side == SetSide.both ? 2 : 1;
    final loads = (loadCount ?? 1) < 1 ? 1 : loadCount ?? 1;
    return load * reps * sides * loads;
  }
}

/// Set counting with a left/right pair as one set (`WorkoutSetPairing.swift`).
extension WorkoutSetListStats on Iterable<WorkoutSetModel> {
  /// How many sets these rows amount to: a right row straight after a left
  /// row is the same set, and a sub-set adds nothing.
  int get pairedSetCount {
    var count = 0;
    SetSide? previousSide;
    for (final set in this) {
      if (set.isSubSet) continue;
      if (!(set.side == SetSide.right && previousSide == SetSide.left)) {
        count += 1;
      }
      previousSide = set.side;
    }
    return count;
  }
}

/// An exercise's logged work (`WorkoutSetPairing.swift:147-207`).
extension WorkoutExerciseStats on WorkoutExerciseModel {
  /// The sets that count as work, warm-ups excluded.
  List<WorkoutSetModel> get workingSets => [
    for (final set in sets)
      if (!set.isWarmup) set,
  ];

  /// The working sets that were done: what every summary counts.
  List<WorkoutSetModel> get loggedWorkingSets => [
    for (final set in sets)
      if (!set.isWarmup && set.completedAt != null) set,
  ];

  /// How many working sets were logged, a left/right pair counted once.
  int get loggedSetCount => loggedWorkingSets.pairedSetCount;

  /// The number [set] is shown as: a pair shares its number, and a sub-set
  /// takes its parent's.
  int workingSetNumber(WorkoutSetModel set) {
    final upToAndIncluding = <WorkoutSetModel>[];
    for (final candidate in workingSets) {
      upToAndIncluding.add(candidate);
      if (candidate.id == set.id) break;
    }
    return upToAndIncluding.pairedSetCount;
  }

  /// The unit this exercise's weights are shown in: the exercise's own, else
  /// the first set's that has one, else kilograms.
  ExerciseWeightUnit get displayWeightUnit =>
      weightUnit ??
      sets.map((set) => set.weightUnit).nonNulls.firstOrNull ??
      ExerciseWeightUnit.kilograms;
}

/// A session's totals (`WorkoutSessionModel.swift:359-410`).
extension WorkoutSessionStats on WorkoutSessionModel {
  /// The logged working sets' weight × reps.
  double get loggedVolumeKg => exercises
      .expand((exercise) => exercise.loggedWorkingSets)
      .map((set) => set.volumeKg ?? 0)
      .fold(0, (sum, volume) => sum + volume);

  /// The logged working sets, a left/right pair counted once.
  int get loggedSetCount =>
      exercises.fold(0, (sum, exercise) => sum + exercise.loggedSetCount);

  /// The exercises with a logged set.
  List<WorkoutExerciseModel> get doneExercises => [
    for (final exercise in exercises)
      if (exercise.sets.any((set) => set.completedAt != null)) exercise,
  ];

  /// How long the workout was under way, paused time left out; null while it
  /// is running.
  Duration? get activeDuration {
    final end = endedAt;
    if (end == null) return null;
    final paused = Duration(
      microseconds: ((pausedSeconds ?? 0) * Duration.microsecondsPerSecond)
          .round(),
    );
    final active = end.difference(dateCreated) - paused;
    return active.isNegative ? Duration.zero : active;
  }

  /// The unit most of the logged sets were entered in, else kilograms.
  ExerciseWeightUnit get authorWeightUnit {
    final units = exercises
        .expand((exercise) => exercise.loggedWorkingSets)
        .map((set) => set.weightUnit)
        .nonNulls
        .toList();
    final pounds = units.where((unit) => unit == ExerciseWeightUnit.pounds);
    return pounds.length * 2 > units.length
        ? ExerciseWeightUnit.pounds
        : ExerciseWeightUnit.kilograms;
  }
}
