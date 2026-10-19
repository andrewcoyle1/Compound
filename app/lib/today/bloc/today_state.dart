part of 'today_bloc.dart';

/// Where the day's data has got to.
enum TodayStatus {
  /// Waiting for the sessions, meals or weigh-ins.
  loading,

  /// All three have arrived.
  loaded,

  /// One of them could not be read.
  failure,
}

/// Everything Today is built from, as the repositories last gave it, and
/// what the screen derives from it through `today_checklist.dart` and
/// `compound_maths`' streak.
final class const TodayState({
  /// The signed-in user's id.
  required final String uid,

  /// When the screen opened: "today" and the evening reminder's clock.
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

  /// The step goal setting, or null until read.
  final AnalyticsSettings? analyticsSettings,

  /// The profile, or null until read.
  final UserModel? user,

  /// The current weight goal, or null without one.
  final WeightGoal? goal,

  /// Whether reading the sessions, meals or weigh-ins failed.
  final bool failed = false,

  /// Whether the weekly review card was opened since the screen started.
  final bool weeklyReviewOpened = false,

  /// Whether the getting-started section was hidden, on this device.
  final bool starterDismissed = false,

  /// The check-in's day and the weeks done, or null until read.
  final NutritionStrategySettings? strategySettings,
  final CheckInRecord? checkInRecord,
  final LoggingBreak? loggingBreak,

  /// This week's check-in was skipped here; the card stays away while the
  /// write lands.
  final bool checkInSkipped = false,

  /// Moves each time skipping the check-in fails.
  final int skipFailures = 0,

  /// Moves each time a step goal is saved, and each time saving one fails.
  final int stepGoalSaves = 0,
  final int stepGoalFailures = 0,

  /// Moves the first time each day the checklist is complete.
  final int dayCompletions = 0,

  /// Whether the checklist's inputs (the sessions, meals, weigh-ins, diet
  /// plan, steps, step goal and profile) have each arrived: until then an
  /// item can look done or undone only because something is still on its
  /// way.
  final bool checklistRead = false,

  /// The items ([ChecklistItem.kind]) celebrated while the screen has been
  /// open: each turned done in view, for the first time today.
  final Set<String> celebrated = const {},
}) extends Equatable {
  /// Where the data has got to.
  TodayStatus get status => failed
      ? TodayStatus.failure
      : sessions == null || meals == null || measurements == null
      ? TodayStatus.loading
      : TodayStatus.loaded;

  /// Today's key.
  String get todayKey => dayKeyOf(now.toLocal());

  /// Today's meals.
  List<MealLogModel> get todayMeals => mealsOnDay(meals ?? const [], todayKey);

  /// What today's meals add up to.
  Macros get nutritionTotals => totalsOf(todayMeals);

  /// The plan's target for today, or null without a plan.
  Macros? get nutritionTarget => dailyTarget(dietPlan, todayKey);

  /// The weight unit to show: pounds if the profile says so.
  bool get usesPounds =>
      user?.submittedWeightUnitPreference == WeightUnitPreference.pounds;

  /// The user's own goal, else the age-adjusted default.
  int get stepGoal =>
      analyticsSettings?.dailyStepGoal ??
      ageAdjustedStepGoal(user?.submittedDateOfBirth, now: now);

  /// Today's own finished workout, the newest of several.
  WorkoutSessionModel? get finishedToday =>
      sessionFinishedToday(sessions ?? const [], uid: uid, now: now);

  /// The day's checklist without a mesocycle's plan.
  TodayChecklist get checklist => checklistWith();

  /// The day's checklist (`TodayPresenter.checklist`), with [planned], today's
  /// day plan in the active mesocycle, for the training item.
  TodayChecklist checklistWith({WorkoutTemplateModel? planned}) {
    final totals = nutritionTotals;
    final target = nutritionTarget;
    final trend = weighInChange(measurements ?? const []);
    final latest = trend.latest;
    return TodayChecklist.build(
      finishedToday: finishedToday,
      planned: planned,
      nutrition: NutritionItem(
        calories: totals.calories,
        proteinGrams: totals.proteinGrams,
        mealsLogged: todayMeals.length,
        calorieTarget: target?.calories,
        proteinTarget: target?.proteinGrams,
      ),
      weighIn: WeighInItem(
        isToday: latest != null && isSameDay(latest.date, now),
        latestKg: latest?.weightKg,
        weekChangeKg: trend.weekChangeKg,
        goalWeeklyChangeKg: goalWeeklyChangeKg(goal),
      ),
      steps: steps.isEmpty
          ? null
          : StepsItem(today: stepsOn(steps, now), goal: stepGoal),
    );
  }

  /// The sessions that count toward the streak.
  List<WorkoutSessionModel> get _counted =>
      countedSessions(sessions ?? const [], uid: uid, now: now);

  /// The weekly streak (`CoreInteractor.weeklyStreak`).
  WeeklyStreak get streak => WeeklyStreak.make(
    sessionDays: [
      for (final session in _counted) dayKeyOf(session.dateCreated.toLocal()),
    ],
    today: todayKey,
    goal: weeklySessionGoal(user?.weeklySessionGoal),
    firstWeekday: firstWeekday,
  );

  /// This week's seven days, from its first, at local midnight.
  List<DateTime> get weekDays {
    final start = weekStartOf(todayKey, firstWeekday: firstWeekday);
    final first = DateTime.parse(start);
    return [
      for (var i = 0; i < 7; i++)
        DateTime(first.year, first.month, first.day + i),
    ];
  }

  /// The keys of this week's days with a counted session; rest days do not
  /// count (`WorkoutStreakPresenter.workoutDaysThisWeek`).
  Set<String> get workoutDaysThisWeek {
    final week = weekStartOf(todayKey, firstWeekday: firstWeekday);
    return {
      for (final session in _counted)
        if (weekStartOf(
              dayKeyOf(session.dateCreated.toLocal()),
              firstWeekday: firstWeekday,
            ) ==
            week)
          dayKeyOf(session.dateCreated.toLocal()),
    };
  }

  /// Every finished workout, rest days aside.
  int get totalWorkouts => _counted.length;

  /// The getting-started steps still to do; the card shows while any are.
  /// Strava's is the view's to add, from the app-wide Strava state, so it
  /// counts as done here.
  List<StarterStep> get starterSteps => remainingStarterSteps(
    hasWorkout: _counted.isNotEmpty,
    hasMeal: meals?.isNotEmpty ?? false,
    hasWeighIn: weighInChange(measurements ?? const []).latest != null,
    hasStepData: steps.isNotEmpty,
    stravaConnected: true,
  );

  /// From 5pm, the protein still to eat when at least 20 g short.
  double? get proteinGapGrams => proteinGap(
    now: now,
    targetGrams: nutritionTarget?.proteinGrams,
    eatenGrams: nutritionTotals.proteinGrams,
  );

  /// Whether to offer last week's review: from the start of a week until
  /// it is opened, when last week has a workout or a meal to review
  /// (`TodayPresenter.showsWeeklyReviewCard`).
  bool get showsWeeklyReviewCard {
    if (weeklyReviewOpened) return false;
    final thisWeek = weekStartOf(todayKey, firstWeekday: firstWeekday);
    final lastWeek = addDays(thisWeek, -7);
    bool inLastWeek(DateTime date) {
      final day = dayKeyOf(date.toLocal());
      return day.compareTo(lastWeek) >= 0 && day.compareTo(thisWeek) < 0;
    }

    final trained = (sessions ?? const []).any(
      (s) =>
          s.authorId == uid && s.endedAt != null && inLastWeek(s.dateCreated),
    );
    return trained || (meals ?? const []).any((m) => inLastWeek(m.date));
  }

  /// The week the check-in card offers, or null when none is waiting
  /// (`TodayPresenter.dueCheckInWeekStart`).
  DateTime? get dueCheckInWeekStart {
    final settings = strategySettings;
    if (settings == null || checkInSkipped) return null;
    final inputs = ExpenditureInputs(
      now: now,
      settings: settings,
      loggingBreak: loggingBreak,
      checkInRecord: checkInRecord,
    );
    return inputs.checkInState == CheckInState.due
        ? inputs.checkInWeekStart
        : null;
  }

  TodayState copyWith({
    List<WorkoutSessionModel>? sessions,
    List<MealLogModel>? meals,
    List<BodyMeasurementEntry>? measurements,
    DietPlan? Function()? dietPlan,
    List<StepsModel>? steps,
    AnalyticsSettings? Function()? analyticsSettings,
    UserModel? Function()? user,
    WeightGoal? Function()? goal,
    bool? failed,
    bool? weeklyReviewOpened,
    bool? starterDismissed,
    NutritionStrategySettings? strategySettings,
    CheckInRecord? Function()? checkInRecord,
    LoggingBreak? Function()? loggingBreak,
    bool? checkInSkipped,
    int? skipFailures,
    int? stepGoalSaves,
    int? stepGoalFailures,
    int? dayCompletions,
    bool? checklistRead,
    Set<String>? celebrated,
  }) => TodayState(
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
    weeklyReviewOpened: weeklyReviewOpened ?? this.weeklyReviewOpened,
    starterDismissed: starterDismissed ?? this.starterDismissed,
    strategySettings: strategySettings ?? this.strategySettings,
    checkInRecord: checkInRecord == null ? this.checkInRecord : checkInRecord(),
    loggingBreak: loggingBreak == null ? this.loggingBreak : loggingBreak(),
    checkInSkipped: checkInSkipped ?? this.checkInSkipped,
    skipFailures: skipFailures ?? this.skipFailures,
    stepGoalSaves: stepGoalSaves ?? this.stepGoalSaves,
    stepGoalFailures: stepGoalFailures ?? this.stepGoalFailures,
    dayCompletions: dayCompletions ?? this.dayCompletions,
    checklistRead: checklistRead ?? this.checklistRead,
    celebrated: celebrated ?? this.celebrated,
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
    weeklyReviewOpened,
    starterDismissed,
    strategySettings,
    checkInRecord,
    loggingBreak,
    checkInSkipped,
    skipFailures,
    stepGoalSaves,
    stepGoalFailures,
    dayCompletions,
    checklistRead,
    celebrated,
  ];
}
