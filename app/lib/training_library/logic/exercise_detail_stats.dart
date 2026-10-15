import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// One finished session's work on an exercise
/// (`ExerciseModelDetailStats.Performance`).
final class const ExercisePerformance({
  required final String sessionId,

  /// When the session ended.
  required final DateTime date,
  required final String workoutName,

  /// Working sets, a left/right pair counted once and drops not at all.
  required final int workingSets,
  required final int totalReps,

  /// Weight × reps over the working sets, as everywhere else.
  required final double volumeKg,

  /// The heaviest set of its own done for a rep or more, as its load.
  required final double heaviestWeightKg,

  /// The reps done at [heaviestWeightKg].
  required final int repsAtHeaviest,
}) extends Equatable {
  @override
  List<Object> get props => [
    sessionId,
    date,
    workoutName,
    workingSets,
    totalReps,
    volumeKg,
    heaviestWeightKg,
    repsAtHeaviest,
  ];
}

/// What the exercise detail's History tab shows, from the finished sessions
/// that included the exercise (Swift `ExerciseModelDetailStats`). Warm-ups
/// and sets never marked done are left out.
///
/// The estimated one-rep max and the records built on it wait for the
/// Records tab (`MethodInfo.estimatedOneRepMax`).
final class const ExerciseDetailStats({
  /// In the order the sessions were read.
  final List<ExercisePerformance> performances = const [],
}) extends Equatable {
  /// The performances of the exercise with [templateId] in [sessions].
  factory make(List<WorkoutSessionModel> sessions, String templateId) =>
      ExerciseDetailStats(
        performances: [
          for (final session in sessions)
            if (session.endedAt case final ended?)
              for (final exercise in session.exercises)
                if (exercise.templateId == templateId &&
                    exercise.loggedWorkingSets.isNotEmpty)
                  _performance(session, ended, exercise.loggedWorkingSets),
        ],
      );

  static ExercisePerformance _performance(
    WorkoutSessionModel session,
    DateTime date,
    List<WorkoutSetModel> sets,
  ) {
    var reps = 0;
    var volume = 0.0;
    var heaviest = 0.0;
    var repsAtHeaviest = 0;
    for (final set in sets) {
      reps += set.reps ?? 0;
      volume += set.volumeKg ?? 0;
      // A best is a set of its own done for a rep or more: a drop is lighter
      // by design, and a set saved with no reps was not lifted.
      final setReps = set.reps;
      final weight = set.loadKg;
      if (set.isSubSet || setReps == null || setReps < 1) continue;
      if (weight == null || weight <= 0) continue;
      if (weight > heaviest ||
          (weight == heaviest && setReps > repsAtHeaviest)) {
        heaviest = weight;
        repsAtHeaviest = setReps;
      }
    }
    return ExercisePerformance(
      sessionId: session.id,
      date: date,
      workoutName: session.name,
      workingSets: sets.where((set) => !set.isSubSet).pairedSetCount,
      totalReps: reps,
      volumeKg: volume,
      heaviestWeightKg: heaviest,
      repsAtHeaviest: repsAtHeaviest,
    );
  }

  bool get isEmpty => performances.isEmpty;

  /// Newest first, as the History tab reads.
  List<ExercisePerformance> get mostRecentFirst =>
      [...performances]..sort((a, b) => b.date.compareTo(a.date));

  @override
  List<Object> get props => [performances];
}
