part of 'progress_bloc.dart';

/// Where the overview's data has got to.
enum ProgressStatus {
  /// Waiting for the sessions, meals or weigh-ins.
  loading,

  /// All three have arrived.
  loaded,

  /// One of them could not be read.
  failure,
}

/// One reading on a card's chart: when, and its value in the unit shown.
typedef ProgressPoint = ({DateTime date, double value});

/// Everything the Progress overview is built from, as the repositories last
/// gave it, and the cards' figures derived from it through
/// `progress_overview.dart`.
final class const ProgressState({
  /// The signed-in user's id.
  required final String uid,

  /// When the screen opened: "today" for every card.
  required final DateTime now,

  /// The first day of the user's week, as an ISO weekday (1 = Monday).
  required final int firstWeekday,

  /// The user's sessions; null until they arrive.
  final List<WorkoutSessionModel>? sessions,

  /// The user's meals; null until they arrive.
  final List<MealLogModel>? meals,

  /// The user's weigh-ins and measurements; null until they arrive.
  final List<BodyMeasurementEntry>? measurements,

  /// The diet plan, or null without one.
  final DietPlan? dietPlan,

  /// Every step count, oldest first.
  final List<StepsModel> steps = const [],

  /// Which sections are hidden, or null until read.
  final AnalyticsSettings? analyticsSettings,

  /// The profile, or null until read.
  final UserModel? user,

  /// The current weight goal, or null without one.
  final WeightGoal? goal,

  /// Whether reading the sessions, meals or weigh-ins failed.
  final bool failed = false,

  /// What the expenditure engine reads besides the logs; the settings are
  /// null until read.
  final NutritionStrategySettings? strategySettings,
  final List<NutritionDayAnnotation> annotations = const [],
  final LoggingBreak? loggingBreak,
}) extends Equatable {
  /// Where the data has got to.
  ProgressStatus get status => failed
      ? ProgressStatus.failure
      : sessions == null || meals == null || measurements == null
      ? ProgressStatus.loading
      : ProgressStatus.loaded;

  /// The unit every body weight is shown in: pounds if the profile says so.
  AppWeightUnit get unit =>
      user?.submittedWeightUnitPreference == WeightUnitPreference.pounds
      ? AppWeightUnit.pounds
      : AppWeightUnit.kilograms;

  double _inUnit(double kilograms) => unit == AppWeightUnit.pounds
      ? kilograms * AppFormat.poundsPerKilogram
      : kilograms;

  /// Whether [section] is shown.
  bool isVisible(ProgressSection section) =>
      section.isVisible(analyticsSettings);

  List<BodyMeasurementEntry> get _measurements => measurements ?? const [];

  // MARK: Workouts

  /// Finished workouts, rest days and future-dated ones aside.
  List<WorkoutSessionModel> get _finished =>
      countedSessions(sessions ?? const [], uid: uid, now: now);

  /// The seven most recent workouts, oldest first.
  List<WorkoutSessionModel> get recentWorkouts => lastWorkouts(_finished);

  /// Working sets in each of [recentWorkouts].
  List<ProgressPoint> get workoutSets => [
    for (final session in recentWorkouts)
      (date: session.endedAt!, value: session.loggedSetCount.toDouble()),
  ];

  // MARK: Habits

  List<DateTime> get _workoutDates => [
    for (final session in _finished) session.endedAt!,
  ];

  /// The last 30 days with a workout, oldest first.
  List<bool> get workoutGrid => habitGrid(_workoutDates, now);

  /// Workouts finished this week.
  int get workoutsThisWeek =>
      countThisWeek(_workoutDates, now, firstWeekday: firstWeekday);

  /// The last 30 days with a weigh-in, oldest first.
  List<bool> get weighInGrid => habitGrid(weighInDates(_measurements), now);

  /// Weigh-ins this week.
  int get weighInsThisWeek => countThisWeek(
    weighInDates(_measurements),
    now,
    firstWeekday: firstWeekday,
  );

  // MARK: Nutrition

  /// What was eaten on each of the last seven days, oldest first.
  List<Macros> get macrosWeek => macrosLastWeek(meals ?? const [], now);

  /// The plan's protein target for today, or null without a plan.
  double? get proteinTarget =>
      dailyTarget(dietPlan, dayKeyOf(now.toLocal()))?.proteinGrams;

  // MARK: Body

  /// The last seven weigh-ins, in [unit].
  List<ProgressPoint> get scaleWeights => [
    for (final entry in lastReadings(weighInsOf(_measurements)))
      (date: entry.date, value: _inUnit(entry.weightKg!)),
  ];

  /// The trend at the last seven weigh-ins, run over every one, in [unit].
  List<ProgressPoint> get trendWeights => [
    for (final point in lastReadings(trendOf(weighInsOf(_measurements))))
      (date: point.date, value: _inUnit(point.value)),
  ];

  /// The last seven body-fat readings, in percent.
  List<ProgressPoint> get bodyFat => [
    for (final entry in lastBodyFatReadings(_measurements))
      (date: entry.date, value: entry.bodyFatPercentage!),
  ];

  /// Each of the last seven days' steps.
  List<ProgressPoint> get stepsWeek => [
    for (final reading in stepsLastWeek(steps, now))
      (date: reading.date, value: reading.number.toDouble()),
  ];

  /// Progress toward the weight goal.
  GoalProgress get goalProgress => progressTowardGoal(goal, _measurements);

  // MARK: Expenditure

  /// The engine's figure on each of the last seven days and today's
  /// (`expenditureSparklineData`, `energyBalanceExpenditure`): the day's
  /// estimate, the last after a break, the formula before the history.
  /// Null until the strategy settings arrive.
  ({List<ProgressPoint> week, double today})? get expenditure {
    final settings = strategySettings;
    if (settings == null) return null;
    final inputs = ExpenditureInputs(
      now: now,
      settings: settings,
      user: user,
      meals: meals ?? const [],
      measurements: _measurements,
      steps: steps,
      annotations: annotations,
      loggingBreak: loggingBreak,
    );
    final history = inputs.history;
    final on = expenditureOn(history, inputs.priorKcal);
    return (
      week: [
        for (final day in lastWeekDays(now))
          (date: localMidnight(day), value: on(day)),
      ],
      today: history.lastOrNull?.kcal ?? inputs.priorKcal,
    );
  }

  ProgressState copyWith({
    List<WorkoutSessionModel>? sessions,
    List<MealLogModel>? meals,
    List<BodyMeasurementEntry>? measurements,
    DietPlan? Function()? dietPlan,
    List<StepsModel>? steps,
    AnalyticsSettings? Function()? analyticsSettings,
    UserModel? Function()? user,
    WeightGoal? Function()? goal,
    bool? failed,
    NutritionStrategySettings? strategySettings,
    List<NutritionDayAnnotation>? annotations,
    LoggingBreak? Function()? loggingBreak,
  }) => ProgressState(
    uid: uid,
    now: now,
    firstWeekday: firstWeekday,
    sessions: sessions ?? this.sessions,
    meals: meals ?? this.meals,
    measurements: measurements ?? this.measurements,
    dietPlan: dietPlan == null ? this.dietPlan : dietPlan(),
    steps: steps ?? this.steps,
    analyticsSettings: analyticsSettings == null
        ? this.analyticsSettings
        : analyticsSettings(),
    user: user == null ? this.user : user(),
    goal: goal == null ? this.goal : goal(),
    failed: failed ?? this.failed,
    strategySettings: strategySettings ?? this.strategySettings,
    annotations: annotations ?? this.annotations,
    loggingBreak: loggingBreak == null ? this.loggingBreak : loggingBreak(),
  );

  @override
  List<Object?> get props => [
    uid,
    now,
    firstWeekday,
    sessions,
    meals,
    measurements,
    dietPlan,
    steps,
    analyticsSettings,
    user,
    goal,
    failed,
    strategySettings,
    annotations,
    loggingBreak,
  ];
}
