/// The Progress tab's arithmetic, ported from the Swift `AnalyticsPresenter`
/// (+DataLoading): which sections show, the habit grids, the last week of
/// macros, protein and steps, the last seven weigh-ins, body-fat readings and
/// workouts, and goal progress. Pure, so the bloc and the widgets only read
/// it. The words live in the ARB strings.
library;

import 'dart:math' as math;

import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/weight_metric/models/weight_metric.dart';
import 'package:compound_maths/compound_maths.dart';
import 'package:compound_models/compound_models.dart';

// MARK: - Sections

/// A section of the Progress tab, in the tab's order (Swift
/// `AnalyticsSection`). [id] is the raw value `hidden_section_ids` stores.
enum ProgressSection {
  /// Workouts, expenditure, weight trend, goal progress, energy balance.
  insightsAndAnalytics('insights_and_analytics'),

  /// The weigh-in and workout grids.
  habits('habits'),

  /// Macros and protein.
  nutrition('nutrition'),

  /// Scale weight and visual body fat.
  bodyMetrics('body_metrics'),

  /// Weekly sets per muscle.
  muscleGroups('muscle_groups'),

  /// Estimated one-rep maxes.
  exercises('exercises');

  new(this.id);

  /// The stored raw value.
  final String id;

  /// Whether [settings] leave this section showing; all show until the
  /// settings arrive (`AnalyticsSettings.isVisible`).
  bool isVisible(AnalyticsSettings? settings) =>
      !(settings?.hiddenSectionIds.contains(id) ?? false);
}

// MARK: - Habits

/// How many days a habit grid covers: ten columns of three.
const habitGridDays = 30;

/// One cell per day for the [habitGridDays] days ending on [now]'s, oldest
/// first: whether any of [dates] fell on it. Twice in a day is one cell
/// (`AnalyticsPresenter.workoutContributionData`, `weighInSummary`).
List<bool> habitGrid(Iterable<DateTime> dates, DateTime now) {
  final days = {for (final date in dates) dayKeyOf(date.toLocal())};
  final today = dayKeyOf(now.toLocal());
  return [
    for (var i = habitGridDays - 1; i >= 0; i--)
      days.contains(addDays(today, -i)),
  ];
}

/// How many of [dates] fall in the week of [now], up to today, the week
/// starting on [firstWeekday] (`AnalyticsPresenter.workoutCountThisWeek`).
int countThisWeek(
  Iterable<DateTime> dates,
  DateTime now, {
  required int firstWeekday,
}) {
  final today = dayKeyOf(now.toLocal());
  final start = weekStartOf(today, firstWeekday: firstWeekday);
  return dates.where((date) {
    final day = dayKeyOf(date.toLocal());
    return day.compareTo(start) >= 0 && day.compareTo(today) <= 0;
  }).length;
}

/// When each of [measurements]' weigh-ins was taken.
List<DateTime> weighInDates(Iterable<BodyMeasurementEntry> measurements) => [
  for (final entry in weighInsOf(measurements)) entry.date,
];

// MARK: - Last seven

/// How many readings a card's chart shows.
const cardReadings = 7;

/// The last [cardReadings] of [items].
List<T> lastReadings<T>(List<T> items) => items.length <= cardReadings
    ? items
    : items.sublist(items.length - cardReadings);

/// The seven most recently finished of [finished], oldest first
/// (`AnalyticsPresenter.workoutLast7Sessions`). [finished] must all have
/// ended.
List<WorkoutSessionModel> lastWorkouts(
  Iterable<WorkoutSessionModel> finished,
) => lastReadings(
  [...finished]..sort((a, b) => a.endedAt!.compareTo(b.endedAt!)),
);

/// [measurements] with a body-fat reading, oldest first, the last seven.
List<BodyMeasurementEntry> lastBodyFatReadings(
  Iterable<BodyMeasurementEntry> measurements,
) => lastReadings(
  [
    for (final entry in measurements)
      if (entry.deletedAt == null && entry.bodyFatPercentage != null) entry,
  ]..sort((a, b) => a.date.compareTo(b.date)),
);

/// The days from six days before [now]'s through it, as keys, oldest first.
List<String> lastWeekDays(DateTime now) {
  final today = dayKeyOf(now.toLocal());
  return [for (var i = 6; i >= 0; i--) addDays(today, -i)];
}

/// Each of the last seven days' steps, oldest first, a day with two
/// readings keeping the higher, so a partial count never stands beside a
/// complete one (`AnalyticsPresenter.stepsLast7`, `consolidateStepsByDay`).
List<StepsModel> stepsLastWeek(Iterable<StepsModel> steps, DateTime now) {
  final days = lastWeekDays(now).toSet();
  final best = <String, StepsModel>{};
  for (final reading in steps) {
    if (reading.deletedAt != null) continue;
    final day = dayKeyOf(reading.date.toLocal());
    if (!days.contains(day)) continue;
    final kept = best[day];
    if (kept == null || reading.number > kept.number) best[day] = reading;
  }
  return best.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

// MARK: - Nutrition

/// What was eaten on each of the last seven days, oldest first; an
/// unlogged day is zero (`AnalyticsPresenter.loadMacrosData`).
List<Macros> macrosLastWeek(Iterable<MealLogModel> meals, DateTime now) => [
  for (final day in lastWeekDays(now)) totalsOf(mealsOnDay(meals, day)),
];

/// The protein bar's ceiling without a target, in grams.
const defaultProteinCeiling = 150.0;

/// The protein bar's full width: 20% past the target (or 150 g), or what
/// was eaten if more, so the bar never overflows
/// (`AnalyticsPresenter.proteinMax`).
double proteinCeiling({required double eaten, required double? target}) =>
    math.max(eaten, (target ?? defaultProteinCeiling) * 1.2);

// MARK: - Goal progress

/// How far the goal is along, before any weigh-in is read.
enum GoalProgressState {
  /// There is no goal.
  noGoal,

  /// Nothing has been weighed since the goal was set.
  noEntries,

  /// Progress can be measured.
  measured,
}

/// The goal card: its state and, when measured, the percentage of the way
/// from the starting weight to the target, clamped to 0–100.
typedef GoalProgress = ({GoalProgressState state, double percent});

/// The share of the way from [WeightGoal.startingWeightKg] to
/// [WeightGoal.targetWeightKg] that [currentKg] has covered, 0–1; 0 when
/// moving the wrong way (`WeightGoal.calculateProgress`).
double goalFraction(WeightGoal goal, double currentKg) {
  final start = goal.startingWeightKg;
  final target = goal.targetWeightKg;
  if (target == start) return 0;
  final losing = target < start;
  final rightWay = losing ? currentKg < start : currentKg > start;
  if (!rightWay) return 0;
  return ((start - currentKg).abs() / (target - start).abs()).clamp(0, 1);
}

/// Progress toward [goal], measured from the trend weight over every
/// weigh-in, once one has been logged since the goal was set
/// (`AnalyticsPresenter.goalProgressPercent`).
GoalProgress progressTowardGoal(
  WeightGoal? goal,
  Iterable<BodyMeasurementEntry> measurements,
) {
  if (goal == null) return (state: GoalProgressState.noGoal, percent: 0);
  final since = weighInsOf(measurements)
      .where((entry) => !entry.date.isBefore(goal.createdAt));
  final trend = latestTrendWeightKg(measurements);
  if (since.isEmpty || trend == null) {
    return (state: GoalProgressState.noEntries, percent: 0);
  }
  return (
    state: GoalProgressState.measured,
    percent: goalFraction(goal, trend) * 100,
  );
}
