/// Estimated one-rep maxes (`ExerciseOneRMAggregator.swift`).
library;

import 'package:compound_maths/src/workout.dart';

/// No estimate is made past this many reps to failure (Reynolds 2006).
const maxRepsToFailure = 10;

/// Reps done plus reps in reserve: RIR = 10 − RPE when an RPE was logged, else
/// none.
double repsToFailure(int reps, double? rpe) {
  final reserve = rpe == null ? 0.0 : (10 - rpe).clamp(0.0, double.infinity);
  return reps + reserve;
}

/// Epley's form on reps to failure: `weight × (1 + n / 30)`, the weight itself
/// at n = 1.
///
/// `null` with no weight, no reps, or past [maxRepsToFailure].
double? estimatedOneRepMax(double weightKg, int reps, {double? rpe}) {
  if (!(weightKg > 0) || reps < 1) return null;
  final toFailure = repsToFailure(reps, rpe);
  if (toFailure > maxRepsToFailure) return null;
  if (toFailure <= 1) return weightKg;
  return weightKg * (1 + toFailure / 30);
}

/// One logged set's estimate; a set with no weight or no reps has none.
double? setEstimatedOneRepMax(WorkoutSet set) {
  final weight = set.weightKg;
  final reps = set.reps;
  if (weight == null || reps == null) return null;
  return estimatedOneRepMax(weight, reps, rpe: set.rpe);
}

/// One session's best estimate for an exercise.
typedef OneRepMaxPoint = ({String day, double value});

/// An exercise's estimates: the best of each of its seven most recent sessions,
/// newest first, and the best of those.
class const ExerciseOneRepMax({
  required final String name,
  required final List<OneRepMaxPoint> last7Workouts,
  required final double latest1RM,
});

/// The best estimated 1RM per session for each exercise template, the seven
/// most recent sessions, keyed by template id
/// (`ExerciseOneRMAggregator.aggregate`).
///
/// Warm-ups, unfinished sets and sub-sets are left out.
Map<String, ExerciseOneRepMax> exerciseOneRepMax(
  List<WorkoutSession> sessions,
) {
  // Newest first; a stable sort, so sessions at the same instant keep their
  // order.
  final indexed = sessions.indexed.toList()
    ..sort((a, b) {
      final order = b.$2.at.compareTo(a.$2.at);
      return order != 0 ? order : a.$1.compareTo(b.$1);
    });
  final points = <String, List<OneRepMaxPoint>>{};
  final names = <String, String>{};
  for (final (_, session) in indexed) {
    for (final exercise in session.exercises) {
      var best = 0.0;
      for (final set in exercise.sets) {
        if (set.isWarmup || !set.completed || set.isSubSet) continue;
        final estimate = setEstimatedOneRepMax(set);
        if (estimate != null && estimate > best) best = estimate;
      }
      if (best <= 0) continue;
      final list = points.putIfAbsent(exercise.templateId, () => []);
      names.putIfAbsent(exercise.templateId, () => exercise.name);
      if (list.length >= 7) continue;
      list.add((day: session.day, value: best));
    }
  }
  return points.map(
    (id, list) => MapEntry(
      id,
      ExerciseOneRepMax(
        name: names[id]!,
        last7Workouts: list,
        latest1RM: list.map((p) => p.value).reduce((a, b) => a > b ? a : b),
      ),
    ),
  );
}
