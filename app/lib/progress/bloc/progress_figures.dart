import 'package:app_ui/app_ui.dart' show AppFormat, AppWeightUnit;
import 'package:checkin_repository/checkin_repository.dart' show localMidnight;
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition_overview/logic/nutrition_overview.dart';
import 'package:compound/progress/bloc/progress_bloc.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:compound/progress/logic/nutrition_analytics.dart';
import 'package:compound/progress/logic/progress_carousel.dart';
import 'package:compound/progress/logic/progress_overview.dart';
import 'package:compound/social/logic/circle_week.dart';
import 'package:compound/training_analytics/logic/training_analytics.dart'
    show exerciseLibrary;
import 'package:compound/weight_metric/models/weight_metric.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show PrebuiltCatalogue;

/// A logged reading that can be deleted: its entry, when, and its value in
/// the unit shown.
typedef BodyReading = ({String id, DateTime date, double value});

/// One weigh-in since the goal was set, with the progress its trend weight
/// stood at (Swift `GoalProgressEntry`).
typedef GoalEntry = ({
  String id,
  DateTime date,
  double weightKg,
  double progressPercent,
});

/// One of the last 30 days on the carousel's Energy Balance page.
typedef EnergyDay = ({
  DateTime date,
  double intake,
  double expenditure,
  double? target,
});

/// The figures of the screens behind the Progress tab (Body Metrics,
/// Nutrition, Habits, Insights, Goal Progress, Steps and the carousel),
/// derived from the same data as the overview through the pure functions
/// in `progress/logic`.
extension ProgressFigures on ProgressState {
  List<BodyMeasurementEntry> get _measurements => measurements ?? const [];

  /// The length unit circumferences are shown in.
  LengthUnitPreference get lengthUnit =>
      user?.submittedLengthUnitPreference ?? LengthUnitPreference.centimeters;

  /// The length unit's symbol.
  String get lengthSymbol =>
      lengthUnit == LengthUnitPreference.inches ? 'in' : 'cm';

  /// [kilograms] in the profile's weight unit.
  double inWeightUnit(double kilograms) => unit == AppWeightUnit.pounds
      ? kilograms * AppFormat.poundsPerKilogram
      : kilograms;

  // MARK: Body metrics

  /// Every reading of [kind], in [lengthUnit], oldest first.
  List<BodyReading> measurementReadings(BodyMeasurementKind kind) => [
    for (final e in entriesOf(_measurements, kind.valueOf))
      (id: e.id, date: e.date, value: inLength(e.value, lengthUnit)),
  ];

  /// Every visual body fat reading, in percent, oldest first.
  List<BodyReading> get bodyFatReadings =>
      entriesOf(_measurements, (e) => e.bodyFatPercentage);

  /// Every weigh-in, in [unit], oldest first.
  List<BodyReading> get weightReadings => [
    for (final e in entriesOf(_measurements, (e) => e.weightKg))
      (id: e.id, date: e.date, value: inWeightUnit(e.value)),
  ];

  /// Each entry's [kind] ratio, oldest first.
  List<BodyReading> ratioReadings(maths.BodyRatioKind kind) => entriesOf(
    _measurements,
    ratioOf(kind, heightCm: user?.submittedHeightCentimeters),
  );

  /// The profile's sex, for the waist-to-hip cut-off.
  maths.Gender? get sex => maths.Gender.tryParse(user?.submittedGender?.value);

  // MARK: Nutrition

  /// Every logged day of the last year, oldest first.
  List<NutritionDay> get nutritionHistory =>
      nutritionDays(meals ?? const [], now);

  /// Today's totals, or null with nothing logged today.
  maths.Macros? get todayTotals {
    final today = mealsOnDay(meals ?? const [], dayKeyOf(now));
    return today.isEmpty ? null : totalsOf(today);
  }

  /// Today's nutrient breakdown.
  Map<NutrientLine, double> get todayBreakdown =>
      nutrientBreakdown(mealsOnDay(meals ?? const [], dayKeyOf(now)));

  /// The plan's targets for today, or null without a plan.
  maths.Macros? get todayTarget => dailyTarget(dietPlan, dayKeyOf(now));

  // MARK: Habits

  /// The last 30 days with food logged, oldest first.
  List<bool> get foodLoggingGrid =>
      habitGrid(foodLoggedDates(nutritionHistory), now);

  /// Days this week with food logged.
  int get foodLoggedThisWeek => countThisWeek(
    foodLoggedDates(nutritionHistory),
    now,
    firstWeekday: firstWeekday,
  );

  // MARK: Steps

  /// The last 90 days' steps, a day keeping its largest reading, oldest
  /// first: today included, tomorrow and other users' readings not
  /// (`StepsPresenter.last90Days`).
  List<MetricPoint> get stepsHistory {
    final start = DateTime(now.year, now.month, now.day - 89);
    final end = DateTime(now.year, now.month, now.day + 1);
    final best = <DateTime, StepsModel>{};
    for (final reading in steps) {
      final date = reading.date.toLocal();
      if (reading.deletedAt != null ||
          reading.authorId != uid ||
          date.isBefore(start) ||
          !date.isBefore(end)) {
        continue;
      }
      final day = startOfDay(date);
      if (reading.number > (best[day]?.number ?? -1)) best[day] = reading;
    }
    return [
      for (final reading in best.values)
        (date: reading.date, value: reading.number.toDouble()),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  // MARK: Goal progress

  /// Each weigh-in since the goal was set, with the progress its trend
  /// weight (smoothed over every weigh-in) stood at, oldest first.
  List<GoalEntry> get goalEntries {
    final goal = this.goal;
    if (goal == null) return const [];
    final weighIns = weighInsOf(_measurements);
    return [
      for (final (i, point) in trendOf(weighIns).indexed)
        if (!point.date.isBefore(goal.createdAt))
          (
            id: weighIns[i].id,
            date: point.date,
            weightKg: weighIns[i].weightKg!,
            progressPercent: goalFraction(goal, point.value) * 100,
          ),
    ];
  }

  /// The trend weight now, once a weigh-in has been logged since the goal
  /// was set.
  double? get goalTrendKg =>
      goalEntries.isEmpty ? null : latestTrendWeightKg(_measurements);

  // MARK: Carousel

  /// This week's days, as keys, from the week's first day
  /// (`NutritionTargetChartPresenter.startOfCurrentWeek`).
  List<String> get weekDayKeys {
    final today = dayKeyOf(now);
    final start = maths.weekStartOf(today, firstWeekday: firstWeekday);
    return [for (var i = 0; i < 7; i++) maths.addDays(start, i)];
  }

  /// What was eaten on each of [weekDayKeys]; an unlogged day is zero.
  List<maths.Macros> get loggedWeek => [
    for (final day in weekDayKeys) totalsOf(mealsOnDay(meals ?? const [], day)),
  ];

  /// The plan's target on each of [weekDayKeys], by weekday, or null
  /// without a plan of seven days.
  List<maths.Macros>? get targetWeek {
    if (dietPlan?.days.length != 7) return null;
    return [for (final day in weekDayKeys) dailyTarget(dietPlan, day)!];
  }

  /// The last 30 days' intake against the engine's expenditure and the
  /// plan's calories, oldest first.
  List<EnergyDay> get energyDays {
    final lookup = expenditureLookup;
    final today = dayKeyOf(now);
    return [
      for (var offset = energyDayCount - 1; offset >= 0; offset--)
        if (maths.addDays(today, -offset) case final day)
          (
            date: localMidnight(day),
            intake: totalsOf(mealsOnDay(meals ?? const [], day)).calories,
            expenditure: lookup?.on(day) ?? 0,
            target: dailyTarget(dietPlan, day)?.calories,
          ),
    ];
  }

  /// This week's finished sessions' tally
  /// (`WorkoutSessionHighlights.sessions(of:inWeekOf:)`).
  WorkoutTally get weekTally => workoutTally(
    CircleWeek.sessionsInWeek(uid, now, sessions ?? const [], firstWeekday % 7),
    {
      for (final exercise in exerciseLibrary(
        userExercises,
        PrebuiltCatalogue.instance.exercises,
      ))
        exercise.id: exercise,
    },
  );

  /// The most recently set records of [kind].
  List<ExerciseRecord> records(RecordKind kind) => recentRecords(kind, [
    for (final session in sessions ?? const <WorkoutSessionModel>[])
      if (session.authorId == uid &&
          session.endedAt != null &&
          session.deletedAt == null &&
          !session.isRestDay)
        session,
  ]);
}

/// How many days the carousel's Energy Balance page covers.
const energyDayCount = 30;
