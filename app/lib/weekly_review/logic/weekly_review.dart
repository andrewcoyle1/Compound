/// One week of the user's own training, body weight and nutrition, as a
/// pure function of their data and a week (Swift `WeeklyReview.swift`), so
/// every number on the Weekly Review is tested without a bloc. The words
/// live in the ARB strings.
library;

import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/training_analytics/logic/training_analytics.dart';
import 'package:compound/weight_metric/models/weight_metric.dart';
import 'package:compound/workout_history/models/workout_session_highlights.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// The one line at the top of the review, first match wins.
sealed class WeeklyTakeaway extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// "No sessions logged this week."
final class NoSessionsTakeaway extends WeeklyTakeaway {
  const new();
}

/// "Goal hit and 2 PRs set. Great week."
final class const GoalAndRecordsTakeaway(final int records)
    extends WeeklyTakeaway {
  @override
  List<Object?> get props => [records];
}

/// "Goal hit: 3 of 3 sessions."
final class const GoalHitTakeaway(final int sessions, final int goal)
    extends WeeklyTakeaway {
  @override
  List<Object?> get props => [sessions, goal];
}

/// "Volume up 12% on last week."
final class const VolumeUpTakeaway(final double change) extends WeeklyTakeaway {
  @override
  List<Object?> get props => [change];
}

/// "2 more sessions would have hit your goal."
final class const SessionsToGoTakeaway(final int sessions)
    extends WeeklyTakeaway {
  @override
  List<Object?> get props => [sessions];
}

/// Days whose meals landed within [WeeklyReview.calorieTolerance] of that
/// day's target, of the days with meals logged.
typedef NutritionAdherence = ({int daysOnTarget, int daysLogged});

/// One week's review (Swift `WeeklyReview`).
final class const WeeklyReview({
  /// Midnight on the week's first day.
  required final DateTime weekStart,
  required final int sessionCount,
  required final int goal,
  required final double volumeKg,
  required final double previousVolumeKg,

  /// The unit the week's sets were lifted in, for its volume.
  required final ExerciseWeightUnit volumeUnit,

  /// Hard sets per muscle, most first.
  required final List<({Muscles muscle, double sets})> setsPerMuscle,

  /// Every record set that week, one per exercise.
  required final List<PersonalRecord> personalRecords,
  required final double? averageRpe,

  /// The trend weight at the week's last weigh-in.
  required final double? latestWeightKg,

  /// Its change from the trend before the week (or at its first).
  required final double? weightChangeKg,
  required final NutritionAdherence? nutrition,
}) extends Equatable {
  /// The review of the week starting at [weekStart] (local midnight) for
  /// [uid]. [library] names the muscles each exercise trains and
  /// [muscleName] orders muscles with equal sets; without [dietPlan] there
  /// is no adherence to report.
  factory build({
    required List<WorkoutSessionModel> sessions,
    required List<BodyMeasurementEntry> measurements,
    required List<MealLogModel> meals,
    required DateTime weekStart,
    required String uid,
    required int goal,
    required List<ExerciseModel> library,
    required String Function(Muscles) muscleName,
    DietPlan? dietPlan,
  }) {
    final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    final lastWeek = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day - 7,
    );
    final week = sessionsInWeek(sessions, uid: uid, start: weekStart, end: end);
    final previous = sessionsInWeek(
      sessions,
      uid: uid,
      start: lastWeek,
      end: weekStart,
    );
    final weights = _weights(measurements, weekStart, end);
    return WeeklyReview(
      weekStart: weekStart,
      sessionCount: week.length,
      goal: goal,
      volumeKg: _volume(week),
      previousVolumeKg: _volume(previous),
      volumeUnit: _unit(week),
      setsPerMuscle: _setsPerMuscle(week, library, muscleName),
      personalRecords: _records(week, sessions),
      averageRpe: _averageRpe(week),
      latestWeightKg: weights.latest,
      weightChangeKg: weights.change,
      nutrition: _adherence(meals, weekStart, end, dietPlan),
    );
  }

  /// How far a day may land from its calorie target and still count.
  static const calorieTolerance = 0.1;

  /// The day after the week's last.
  DateTime get weekEnd =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + 7);

  /// The fraction of last week's volume gained, e.g. 0.12; null when last
  /// week had none.
  double? get volumeChange => previousVolumeKg > 0
      ? (volumeKg - previousVolumeKg) / previousVolumeKg
      : null;

  /// The line at the top.
  WeeklyTakeaway get takeaway {
    if (sessionCount == 0) return const NoSessionsTakeaway();
    if (sessionCount >= goal && personalRecords.isNotEmpty) {
      return GoalAndRecordsTakeaway(personalRecords.length);
    }
    if (sessionCount >= goal) return GoalHitTakeaway(sessionCount, goal);
    final change = volumeChange;
    if (change != null && change >= 0.1) return VolumeUpTakeaway(change);
    return SessionsToGoTakeaway(goal - sessionCount);
  }

  @override
  List<Object?> get props => [
    weekStart,
    sessionCount,
    goal,
    volumeKg,
    previousVolumeKg,
    volumeUnit,
    setsPerMuscle,
    personalRecords,
    averageRpe,
    latestWeightKg,
    weightChangeKg,
    nutrition,
  ];

  /// [uid]'s finished, non-rest sessions started from [start] up to [end]
  /// (`WorkoutSessionHighlights.sessions(of:inWeekOf:)`).
  static List<WorkoutSessionModel> sessionsInWeek(
    List<WorkoutSessionModel> sessions, {
    required String uid,
    required DateTime start,
    required DateTime end,
  }) => [
    for (final session in sessions)
      if (session.authorId == uid &&
          session.endedAt != null &&
          !session.isRestDay &&
          session.deletedAt == null &&
          !session.dateCreated.isBefore(start) &&
          session.dateCreated.isBefore(end))
        session,
  ];

  static double _volume(List<WorkoutSessionModel> sessions) =>
      sessions.fold(0, (sum, session) => sum + session.loggedVolumeKg);

  /// Pounds when most of the logged sets with a unit were entered in them.
  static ExerciseWeightUnit _unit(List<WorkoutSessionModel> sessions) {
    final units = [
      for (final session in sessions)
        for (final exercise in session.exercises)
          for (final set in exercise.loggedWorkingSets) ?set.weightUnit,
    ];
    final pounds = units.where((u) => u == ExerciseWeightUnit.pounds).length;
    return pounds * 2 > units.length
        ? ExerciseWeightUnit.pounds
        : ExerciseWeightUnit.kilograms;
  }

  static List<({Muscles muscle, double sets})> _setsPerMuscle(
    List<WorkoutSessionModel> sessions,
    List<ExerciseModel> library,
    String Function(Muscles) muscleName,
  ) {
    final daily = maths.dailyMuscleSets(
      sessions.map(mathsSession).toList(),
      muscleTargets(library),
    );
    return [
      for (final muscle in Muscles.values)
        if (daily[mathsMuscle(muscle)] case final days?)
          (muscle: muscle, sets: days.values.fold<double>(0, (a, b) => a + b)),
    ]..sort(
      (a, b) => a.sets != b.sets
          ? b.sets.compareTo(a.sets)
          : muscleName(a.muscle).compareTo(muscleName(b.muscle)),
    );
  }

  /// One record per exercise: a lift beaten twice keeps its later mark.
  static List<PersonalRecord> _records(
    List<WorkoutSessionModel> week,
    List<WorkoutSessionModel> history,
  ) {
    final all = [
      for (final session in [
        ...week,
      ]..sort((a, b) => a.dateCreated.compareTo(b.dateCreated)))
        ...WorkoutSessionHighlights.personalRecords(
          session,
          priorSessions: history,
          limit: 1 << 30,
        ),
    ];
    final seen = <String>{};
    return [
      for (final record in all.reversed)
        if (seen.add(record.exerciseName)) record,
    ].reversed.toList();
  }

  /// The mean RPE of finished working sets that recorded one.
  static double? _averageRpe(List<WorkoutSessionModel> sessions) {
    final values = [
      for (final session in sessions)
        for (final exercise in session.exercises)
          for (final set in exercise.loggedWorkingSets) ?set.rpe,
    ];
    return values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
  }

  /// The trend at the week's last weigh-in, and its change from the trend
  /// at the last weigh-in before the week (or, with none, at the week's
  /// first). Only weigh-ins up to the week's end feed it, so a past week
  /// does not change with later readings.
  static ({double? latest, double? change}) _weights(
    List<BodyMeasurementEntry> measurements,
    DateTime start,
    DateTime end,
  ) {
    final weighIns = [
      for (final entry in weighInsOf(measurements))
        if (entry.date.isBefore(end)) entry,
    ];
    final last = weighIns.lastIndexWhere((e) => !e.date.isBefore(start));
    if (last < 0) return (latest: null, change: null);
    final trend = trendOf(weighIns);
    final first = weighIns.indexWhere((e) => !e.date.isBefore(start));
    final baseline = first > 0 ? first - 1 : (last > first ? first : null);
    final latest = trend[last].value;
    return (
      latest: latest,
      change: baseline == null ? null : latest - trend[baseline].value,
    );
  }

  static NutritionAdherence? _adherence(
    List<MealLogModel> meals,
    DateTime start,
    DateTime end,
    DietPlan? plan,
  ) {
    if (plan == null || plan.days.isEmpty) return null;
    final days = <String, List<MealLogModel>>{};
    for (final meal in meals) {
      if (meal.date.isBefore(start) || !meal.date.isBefore(end)) continue;
      days.putIfAbsent(dayKeyOf(meal.date.toLocal()), () => []).add(meal);
    }
    var onTarget = 0;
    days.forEach((day, meals) {
      final target = dailyTarget(plan, day)?.calories ?? 0;
      if (target <= 0) return;
      final eaten = totalsOf(meals).calories;
      if ((eaten - target).abs() <= target * calorieTolerance) onTarget++;
    });
    return (daysOnTarget: onTarget, daysLogged: days.length);
  }
}
