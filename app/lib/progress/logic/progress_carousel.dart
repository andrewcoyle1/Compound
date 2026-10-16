/// The sums behind the Progress tab's header carousel (Swift
/// `ProgressCarouselMetrics` and `ProgressCarouselPresenter`): this week's
/// training tally and each exercise's most recent record. The energy
/// averages are `compound_maths`' `comparedAverages`. Pure, so the bloc and
/// the widgets only read it.
library;

import 'package:compound/training_analytics/logic/training_analytics.dart'
    show mathsSession;
import 'package:compound_maths/compound_maths.dart' show setEstimatedOneRepMax;
import 'package:compound_models/compound_models.dart';

/// What a week of training covered: the muscles and exercises with at
/// least one finished working set, and those sets.
typedef WorkoutTally = ({int muscles, int sets, int exercises});

/// What [sessions] trained, a left/right pair counting once, the muscles
/// read from [exercises] by template id
/// (`ProgressCarouselMetrics.tally`).
WorkoutTally workoutTally(
  Iterable<WorkoutSessionModel> sessions,
  Map<String, ExerciseModel> exercises,
) {
  final muscles = <Muscles>{};
  final templates = <String>{};
  var sets = 0;
  for (final exercise in sessions.expand((session) => session.exercises)) {
    final done = exercise.loggedSetCount;
    if (done == 0) continue;
    sets += done;
    templates.add(exercise.templateId);
    muscles.addAll(exercises[exercise.templateId]?.muscleGroups.keys ?? []);
  }
  return (muscles: muscles.length, sets: sets, exercises: templates.length);
}

// ponytail: a microcycle stands in for the calendar week the card is titled
// with, as in Swift; a block whose microcycle is not seven days long reads
// slightly off. Scale by its length if that matters.
/// One pass through [mesocycle]'s days: what a full microcycle of it plans,
/// counting only exercises with set targets
/// (`ProgressCarouselMetrics.target(of:)`).
WorkoutTally mesocycleTarget(Mesocycle mesocycle) {
  final planned = [
    for (final template in mesocycle.workoutTemplates)
      for (final exercise in template.exercises)
        if (exercise.setTargets.isNotEmpty) exercise,
  ];
  return (
    muscles: {
      for (final exercise in planned) ...exercise.exercise.muscleGroups.keys,
    }.length,
    sets: planned.fold(0, (sum, exercise) => sum + exercise.setTargets.length),
    exercises: {for (final exercise in planned) exercise.exercise.id}.length,
  );
}

/// What a record measures.
enum RecordKind {
  /// One session's working volume for the exercise.
  volume,

  /// The most reps in one working set.
  reps,

  /// The best estimated one-rep max.
  oneRepMax,
}

/// An exercise's best, and when it was first reached.
typedef ExerciseRecord = ({
  String templateId,
  String name,

  /// Kilograms for volume and the 1RM, a count for reps.
  double value,
  DateTime date,
});

/// How many records the card lists.
const recordLimit = 7;

/// Each exercise's best [kind] across [finished] (finished, undeleted,
/// non-rest sessions), the most recently set first; a first-ever lift
/// counts. A record matched later keeps the date it was first set
/// (`ProgressCarouselMetrics.recentRecords`).
List<ExerciseRecord> recentRecords(
  RecordKind kind,
  Iterable<WorkoutSessionModel> finished,
) {
  DateTime at(WorkoutSessionModel s) => s.endedAt ?? s.dateCreated;
  final sessions = [...finished]..sort((a, b) => at(a).compareTo(at(b)));
  final best = <String, ExerciseRecord>{};
  for (final session in sessions) {
    final maths = mathsSession(session);
    for (final (index, exercise) in session.exercises.indexed) {
      final sets = exercise.loggedWorkingSets;
      final value = switch (kind) {
        RecordKind.volume => _positive(
          sets.fold<double>(0, (sum, set) => sum + (set.volumeKg ?? 0)),
        ),
        RecordKind.reps => _max([
          for (final set in sets)
            if (set.reps case final reps?) reps.toDouble(),
        ]),
        RecordKind.oneRepMax => _max([
          for (final set in maths.exercises[index].sets)
            if (set.completed && !set.isWarmup) ?setEstimatedOneRepMax(set),
        ]),
      };
      if (value == null || value <= (best[exercise.templateId]?.value ?? 0)) {
        continue;
      }
      best[exercise.templateId] = (
        templateId: exercise.templateId,
        name: exercise.name,
        value: value,
        date: at(session),
      );
    }
  }
  final records = best.values.toList()
    ..sort(
      (a, b) => a.date != b.date
          ? b.date.compareTo(a.date)
          : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  return records.take(recordLimit).toList();
}

double? _positive(double value) => value > 0 ? value : null;

double? _max(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
