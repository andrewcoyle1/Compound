import 'package:compound_maths/compound_maths.dart' show estimatedOneRepMax;
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

  /// The best estimated one-rep max of its sets; 0 when none has one.
  final double bestOneRepMaxKg = 0,
}) extends Equatable {
  @override
  List<Object> get props => [
    bestOneRepMaxKg,
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
/// The Charts tab plots each performance; the Records tab reads the
/// all-time figures and the one-rep-max records.
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
    var bestOneRepMax = 0.0;
    for (final set in sets) {
      reps += set.reps ?? 0;
      volume += set.volumeKg ?? 0;
      // A best is a set of its own done for a rep or more: a drop is lighter
      // by design, and a set saved with no reps was not lifted.
      final setReps = set.reps;
      final weight = set.loadKg;
      if (set.isSubSet || setReps == null || setReps < 1) continue;
      if (weight == null || weight <= 0) continue;
      final oneRepMax = estimatedOneRepMax(weight, setReps, rpe: set.rpe) ?? 0;
      if (oneRepMax > bestOneRepMax) bestOneRepMax = oneRepMax;
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
      bestOneRepMaxKg: bestOneRepMax,
    );
  }

  bool get isEmpty => performances.isEmpty;

  /// Newest first, as the History tab reads.
  List<ExercisePerformance> get mostRecentFirst =>
      [...performances]..sort((a, b) => b.date.compareTo(a.date));

  /// Oldest first, as the charts and records read.
  List<ExercisePerformance> get chronological =>
      [...performances]..sort((a, b) => a.date.compareTo(b.date));

  /// Working sets over every performance.
  int get totalSets => performances.fold(0, (sum, p) => sum + p.workingSets);

  /// Reps over every performance.
  int get totalReps => performances.fold(0, (sum, p) => sum + p.totalReps);

  /// Weight × reps over every performance.
  double get totalVolumeKg =>
      performances.fold(0, (sum, p) => sum + p.volumeKg);

  /// The best estimated one-rep max ever; 0 with none.
  double get bestOneRepMaxKg => performances.fold(
    0,
    (best, p) => p.bestOneRepMaxKg > best ? p.bestOneRepMaxKg : best,
  );

  /// The heaviest set ever, more reps winning a tie, in the order read
  /// (Swift `heaviestSetKg`, `repsAtHeaviestSet`, `heaviestSetDate`); null
  /// when nothing was lifted.
  ExercisePerformance? get heaviest {
    ExercisePerformance? best;
    for (final p in performances) {
      if (p.heaviestWeightKg <= 0) continue;
      if (best == null ||
          p.heaviestWeightKg > best.heaviestWeightKg ||
          (p.heaviestWeightKg == best.heaviestWeightKg &&
              p.repsAtHeaviest > best.repsAtHeaviest)) {
        best = p;
      }
    }
    return best;
  }

  /// The performances whose estimated one-rep max beat every one before,
  /// newest first; equalling a best is no record
  /// (`ExerciseModelDetailPresenter.oneRMRecords`).
  List<ExercisePerformance> get oneRepMaxRecords {
    var best = 0.0;
    final records = <ExercisePerformance>[];
    for (final p in chronological) {
      if (p.bestOneRepMaxKg > best) {
        best = p.bestOneRepMaxKg;
        records.add(p);
      }
    }
    return records.reversed.toList();
  }

  @override
  List<Object> get props => [performances];
}
