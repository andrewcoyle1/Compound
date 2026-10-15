/// The logged training a calculation reads, cut down to the fields the maths
/// uses.
///
/// Mirrors `WorkoutSessionModel`, `WorkoutExerciseModel` and `WorkoutSetModel`
/// in the Swift app, and `pairedSetCount` from `WorkoutSetPairing.swift`.
library;

/// Which side a unilateral set was done on (`SetSide.swift`).
enum SetSide { left, right, both }

/// The kind of set (`SetKind.swift`). Only drops, myo-reps and rest-pause add
/// credit to a set.
enum SetKind {
  standard,
  drop,
  amrap,
  myo,
  restPause,
  cluster,
  partials,
  stretch,
  hold,
}

/// One logged set row.
///
/// A sub-set (a drop, mini-set or cluster piece) carries its parent's [id] as
/// [parentSetId].
class const WorkoutSet({
  final String? id,
  final int? reps,
  final double? weightKg,
  final double? rpe,
  final SetSide? side,
  final SetKind kind = SetKind.standard,
  final String? parentSetId,
  final bool isWarmup = false,
  final bool completed = false,
}) {
  /// Part of another set rather than a set of its own.
  bool get isSubSet => parentSetId != null;
}

/// One exercise in a session: its template and its set rows, in logged order.
class const WorkoutExercise({
  required final String templateId,
  required final String name,
  required final List<WorkoutSet> sets,

  /// How many sets the plan asked for (`setTargets.count`); 0 without a
  /// plan.
  final int plannedSets = 0,
});

/// One finished session.
///
/// [day] is the day key of the session's end (else its start); [at] orders
/// sessions within a day, as the Swift orders them by `endedAt ?? dateCreated`.
class const WorkoutSession({
  required final String day,
  required final DateTime at,
  required final List<WorkoutExercise> exercises,

  /// Whether the session was a deload week's, which asks for about half the
  /// sets its targets list.
  final bool isDeload = false,
});

/// How many sets these rows amount to, a left/right pair counting once.
///
/// A right row straight after a left one folds into it; every other row counts
/// for itself. A sub-set is part of its parent and adds nothing.
/// `WorkoutSetPairing.pairedSetCount`.
int pairedSetCount(Iterable<WorkoutSet> sets) {
  var count = 0;
  SetSide? previousSide;
  for (final set in sets) {
    if (set.isSubSet) continue;
    if (!(set.side == SetSide.right && previousSide == SetSide.left)) count++;
    previousSide = set.side;
  }
  return count;
}

/// Finished working sets, a pair counting once, however easy
/// (`MuscleVolume.completedWorkingSets`).
int completedWorkingSets(WorkoutExercise exercise) => pairedSetCount(
  exercise.sets.where((set) => !set.isWarmup && set.completed),
);
