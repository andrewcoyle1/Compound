import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// A lift in a session that beat everything its author had done before:
/// [value] is the heaviest load in kilograms (with its [reps]), or the most
/// reps, seconds or metres, by [trackingMode].
final class const PersonalRecord({
  required final String exerciseName,
  required final TrackingMode trackingMode,
  required final double value,
  required final int reps,
  required final ExerciseWeightUnit weightUnit,
}) extends Equatable {
  @override
  List<Object> get props => [
    exerciseName,
    trackingMode,
    value,
    reps,
    weightUnit,
  ];
}

/// What made a finished session stand out, read off its author's own
/// history: a port of the Swift app's `WorkoutSessionHighlights`.
abstract final class WorkoutSessionHighlights {
  /// The exercises in [session] whose best working set beat the author's
  /// best across every finished session dated before it, at most [limit].
  ///
  /// A first-ever lift is not a record: there is nothing earlier to beat.
  static List<PersonalRecord> personalRecords(
    WorkoutSessionModel session, {
    required List<WorkoutSessionModel> priorSessions,
    int limit = 3,
  }) {
    final earlier = [
      for (final prior in priorSessions)
        if (_counts(prior, session.authorId) &&
            prior.id != session.id &&
            prior.dateCreated.isBefore(session.dateCreated))
          prior,
    ];
    final seen = <String>{};
    final records = <PersonalRecord>[];
    for (final exercise in session.exercises) {
      if (!seen.add(exercise.templateId) || records.length >= limit) continue;
      final mode = exercise.trackingMode;
      final now = _best(exercise.templateId, mode, [session]);
      final before = _best(exercise.templateId, mode, earlier);
      if (now == null || before == null || !now.beats(before)) continue;
      records.add(
        PersonalRecord(
          exerciseName: exercise.name,
          trackingMode: mode,
          value: now.value,
          reps: now.reps,
          weightUnit:
              exercise.loggedWorkingSets
                  .map((set) => set.weightUnit)
                  .nonNulls
                  .firstOrNull ??
              exercise.weightUnit ??
              session.authorWeightUnit,
        ),
      );
    }
    return records;
  }

  /// Where [session] falls among its author's finished, non-rest sessions
  /// in its calendar week: 1 for the first, 3 for the third. The week starts
  /// on [firstDayOfWeek], 0 for Sunday as `MaterialLocalizations` counts.
  static int weeklyWorkoutNumber(
    WorkoutSessionModel session, {
    required List<WorkoutSessionModel> history,
    required int firstDayOfWeek,
  }) {
    final week = weekStart(session.dateCreated, firstDayOfWeek);
    return history
            .where(
              (other) =>
                  _counts(other, session.authorId) &&
                  other.id != session.id &&
                  !other.dateCreated.isAfter(session.dateCreated) &&
                  weekStart(other.dateCreated, firstDayOfWeek) == week,
            )
            .length +
        1;
  }

  /// Midnight, local time, on the first day of [date]'s week.
  static DateTime weekStart(DateTime date, int firstDayOfWeek) {
    final local = date.toLocal();
    // DateTime.weekday is 1 (Monday) to 7 (Sunday); % 7 makes Sunday 0.
    final offset = (local.weekday % 7 - firstDayOfWeek + 7) % 7;
    return DateTime(local.year, local.month, local.day - offset);
  }

  static bool _counts(WorkoutSessionModel session, String author) =>
      session.authorId == author &&
      session.endedAt != null &&
      !session.isRestDay &&
      session.deletedAt == null;

  /// The best logged working set of one exercise across [sessions]. Weighted
  /// lifts take the heaviest set of its own done for a rep or more, then the
  /// most reps at that weight (`ExerciseModelDetailStats`); other modes take
  /// the most reps, time or distance.
  static _Mark? _best(
    String templateId,
    TrackingMode mode,
    List<WorkoutSessionModel> sessions,
  ) {
    final sets = [
      for (final session in sessions)
        if (session.endedAt != null)
          for (final exercise in session.exercises)
            if (exercise.templateId == templateId)
              ...exercise.loggedWorkingSets,
    ];
    if (mode == TrackingMode.weightReps) {
      _Mark? best;
      for (final set in sets) {
        final reps = set.reps;
        final load = set.loadKg;
        if (set.isSubSet || reps == null || reps < 1) continue;
        if (load == null || load <= 0) continue;
        final mark = _Mark(load, reps);
        if (best == null || mark.beats(best)) best = mark;
      }
      return best;
    }
    final values = sets.map(
      (set) => switch (mode) {
        TrackingMode.repsOnly => set.reps?.toDouble(),
        TrackingMode.timeOnly => set.durationSec?.toDouble(),
        _ => set.distanceMeters,
      },
    );
    final top = values.nonNulls.fold<double>(0, (a, b) => a > b ? a : b);
    return top > 0 ? _Mark(top, 0) : null;
  }
}

/// A best set, compared on [value] and then [reps].
final class const _Mark(final double value, final int reps) {
  bool beats(_Mark other) =>
      value > other.value || (value == other.value && reps > other.reps);
}
