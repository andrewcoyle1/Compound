/// The Today tab's rules, ported from the Swift `TodayChecklist`,
/// `TodayStarter` and `TodayPresenter(+Checklist)`: the day's checklist,
/// the getting-started card and the evening protein gap. Pure, so the bloc
/// and the widgets only read it. The words live in the ARB strings; these
/// return the decisions and the numbers.
library;

import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// Whether [a] and [b] fall on the same local calendar day.
bool isSameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

// MARK: - Training

/// [uid]'s sessions that count toward the weekly goal and the streak:
/// finished, not a rest day, not deleted, and started no later than [now]
/// (`WeeklyStreak.make`'s filter).
List<WorkoutSessionModel> countedSessions(
  Iterable<WorkoutSessionModel> sessions, {
  required String uid,
  required DateTime now,
}) => [
  for (final session in sessions)
    if (session.authorId == uid &&
        session.endedAt != null &&
        !session.isRestDay &&
        session.deletedAt == null &&
        !session.dateCreated.isAfter(now))
      session,
];

/// [uid]'s own workout finished today, the newest if there are several
/// (`TodayPresenter.sessionFinishedToday`).
WorkoutSessionModel? sessionFinishedToday(
  Iterable<WorkoutSessionModel> sessions, {
  required String uid,
  required DateTime now,
}) {
  WorkoutSessionModel? newest;
  for (final session in sessions) {
    final ended = session.endedAt;
    if (ended == null ||
        session.authorId != uid ||
        session.isRestDay ||
        session.deletedAt != null ||
        !isSameDay(ended, now)) {
      continue;
    }
    if (newest == null || ended.isAfter(newest.endedAt!)) newest = session;
  }
  return newest;
}

// MARK: - Weigh-in

/// The latest weigh-in and its change from the last one at least a week
/// earlier (`TodayChecklist.weightTrend`): calendar days, not a Kalman
/// trend. A null change with no weigh-in that far back.
({BodyMeasurementEntry? latest, double? weekChangeKg}) weighInChange(
  Iterable<BodyMeasurementEntry> measurements,
) {
  final weighIns = [
    for (final entry in measurements)
      if (entry.deletedAt == null && entry.weightKg != null) entry,
  ]..sort((a, b) => a.date.compareTo(b.date));
  if (weighIns.isEmpty) return (latest: null, weekChangeKg: null);
  final latest = weighIns.last;
  final at = latest.date.toLocal();
  final weekBefore = DateTime(
    at.year,
    at.month,
    at.day - 7,
    at.hour,
    at.minute,
    at.second,
    at.millisecond,
  );
  final baseline = weighIns.lastWhere(
    (entry) => !entry.date.isAfter(weekBefore),
    orElse: () => latest,
  );
  return (
    latest: latest,
    weekChangeKg: identical(baseline, latest)
        ? null
        : latest.weightKg! - baseline.weightKg!,
  );
}

/// The active goal's weekly change, negative when losing; null when
/// maintaining, inactive or without a goal (`goalWeeklyChangeKg`).
double? goalWeeklyChangeKg(WeightGoal? goal) {
  if (goal == null || goal.status != GoalStatus.active) return null;
  return switch (goal.objective) {
    OverarchingObjective.loseWeight => -goal.weeklyChangeKg.abs(),
    OverarchingObjective.gainWeight => goal.weeklyChangeKg.abs(),
    OverarchingObjective.maintain => null,
  };
}

// MARK: - Steps

/// The step goal for anyone who has not chosen one.
const defaultStepGoal = 8000;

/// The default step goal from [olderAdultAge].
const olderAdultStepGoal = 7000;

/// The age the lower default starts at.
const olderAdultAge = 60;

/// The default goal for someone born on [dateOfBirth]: 8,000 a day, or
/// 7,000 from 60 (Paluch 2022; Ding 2025). Only a default: a goal the user
/// chose is never replaced (`TodayChecklist.ageAdjustedStepGoal`).
int ageAdjustedStepGoal(DateTime? dateOfBirth, {required DateTime now}) {
  if (dateOfBirth == null) return defaultStepGoal;
  final born = dateOfBirth.toLocal();
  final today = now.toLocal();
  final hadBirthday =
      today.month > born.month ||
      (today.month == born.month && today.day >= born.day);
  final age = today.year - born.year - (hadBirthday ? 0 : 1);
  return age >= olderAdultAge ? olderAdultStepGoal : defaultStepGoal;
}

/// Steps counted on [now]'s day (`TodayPresenter.stepsToday`).
int stepsOn(Iterable<StepsModel> steps, DateTime now) => steps
    .where((s) => s.deletedAt == null && isSameDay(s.date, now))
    .fold(0, (sum, s) => sum + s.number);

// MARK: - The checklist

/// One thing to get done today.
sealed class ChecklistItem extends Equatable {
  const new();

  /// Whether it is done.
  bool get isDone;
}

/// A workout finished today. Without one the item is left out: the planned
/// and rest-day states need the mesocycle schedule (programs, M5).
final class const TrainingItem(
  /// The finished workout.
  final WorkoutSessionModel session,
) extends ChecklistItem {
  @override
  bool get isDone => true;

  @override
  List<Object?> get props => [session.id];
}

/// Eating to target: calories inside the band and protein reached; without
/// a diet plan, logging any food.
final class const NutritionItem({
  required final double calories,
  required final double proteinGrams,
  required final int mealsLogged,

  /// Null or 0 without a diet plan.
  final double? calorieTarget,
  final double? proteinTarget,
}) extends ChecklistItem {
  /// Calories count as on target within this fraction either side, as the
  /// weekly review does.
  static const calorieTolerance = 0.1;

  /// Whether there is a calorie target to hit.
  bool get hasTarget => (calorieTarget ?? 0) > 0;

  /// Whether there is a protein target to reach.
  bool get hasProteinTarget => (proteinTarget ?? 0) > 0;

  @override
  bool get isDone {
    if (!hasTarget) return mealsLogged > 0;
    final target = calorieTarget!;
    final caloriesOnTarget =
        (calories - target).abs() <= target * calorieTolerance;
    return caloriesOnTarget &&
        (!hasProteinTarget || proteinGrams >= proteinTarget!);
  }

  @override
  List<Object?> get props => [
    calories,
    proteinGrams,
    mealsLogged,
    calorieTarget,
    proteinTarget,
  ];
}

/// Weighing in today, with the week's change and the goal's pace.
final class const WeighInItem({
  required final bool isToday,
  final double? latestKg,

  /// Change from the last weigh-in at least a week before the latest.
  final double? weekChangeKg,

  /// The goal's planned weekly change, signed: negative when losing.
  final double? goalWeeklyChangeKg,
}) extends ChecklistItem {
  @override
  bool get isDone => isToday;

  @override
  List<Object?> get props => [
    isToday,
    latestKg,
    weekChangeKg,
    goalWeeklyChangeKg,
  ];
}

/// Reaching the step goal. Only shown once steps have ever arrived.
final class const StepsItem({required final int today, required final int goal})
    extends ChecklistItem {
  @override
  bool get isDone => today >= goal;

  @override
  List<Object?> get props => [today, goal];
}

/// The day as a list of things to get done (`TodayChecklist`). The day is
/// complete when every item that applies is.
class const TodayChecklist(final List<ChecklistItem> items) extends Equatable {
  /// Builds the checklist from its inputs (`TodayChecklist.build`): training
  /// only with a workout finished today, steps only with step data.
  factory build({
    required WorkoutSessionModel? finishedToday,
    required NutritionItem nutrition,
    required WeighInItem weighIn,
    required StepsItem? steps,
  }) => TodayChecklist([
    if (finishedToday != null) TrainingItem(finishedToday),
    nutrition,
    weighIn,
    ?steps,
  ]);

  /// How many items are done.
  int get doneCount => items.where((item) => item.isDone).length;

  /// Whether every item is done.
  bool get isComplete => items.isNotEmpty && items.every((item) => item.isDone);

  @override
  List<Object?> get props => [items];
}

// MARK: - Getting started

/// A new account's first steps (`TodayStarter`).
enum StarterStep {
  /// Finish a workout.
  firstWorkout,

  /// Log a meal.
  firstMeal,

  /// Log a weigh-in.
  firstWeighIn,

  /// Connect Apple Health or Health Connect: done once steps have come in.
  appleHealth,

  /// Connect Strava. Left out of a build without Strava.
  strava,
}

/// The starter steps not yet done, in order: the card shows while any are
/// left.
List<StarterStep> remainingStarterSteps({
  required bool hasWorkout,
  required bool hasMeal,
  required bool hasWeighIn,
  required bool hasStepData,
  required bool stravaConnected,
}) => [
  if (!hasWorkout) StarterStep.firstWorkout,
  if (!hasMeal) StarterStep.firstMeal,
  if (!hasWeighIn) StarterStep.firstWeighIn,
  if (!hasStepData) StarterStep.appleHealth,
  if (!stravaConnected) StarterStep.strava,
];

// MARK: - Evening protein

/// The hour the protein reminder starts.
const proteinGapHour = 17;

/// The smallest gap worth a reminder, in grams.
const proteinGapMinimum = 20.0;

/// From 5pm, protein still short of the target by at least 20 g: the gap
/// in grams, else null (`TodayPresenter.proteinGapText`).
double? proteinGap({
  required DateTime now,
  required double? targetGrams,
  required double eatenGrams,
}) {
  if (now.toLocal().hour < proteinGapHour) return null;
  final target = targetGrams ?? 0;
  if (target <= 0) return null;
  final gap = target - eatenGrams;
  return gap >= proteinGapMinimum ? gap : null;
}
