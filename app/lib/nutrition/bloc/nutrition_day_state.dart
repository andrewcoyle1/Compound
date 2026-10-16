part of 'nutrition_day_bloc.dart';

/// Where the day's data has got to.
enum NutritionDayStatus {
  /// Waiting for the meals or the food log settings.
  loading,

  /// Both have arrived.
  loaded,

  /// The meals could not be read.
  failure,
}

/// The meal log for [selectedDay], and everything the screen derives from
/// it through `meal_day.dart`.
final class const NutritionDayState({
  /// The day shown, at local midnight.
  required final DateTime selectedDay,

  /// Today, at local midnight, when the screen opened.
  required final DateTime today,

  /// Every meal the user has logged, as the repository reads them; null
  /// until they arrive.
  final List<MealLogModel>? meals,

  /// The diet plan, or null when there is none.
  final DietPlan? dietPlan,

  /// The food log settings; null until they arrive.
  final FoodLogSettings? settings,

  /// Whether reading the meals failed.
  final bool failed = false,

  /// How many deletes have failed, so the screen says so each time.
  final int deleteFailures = 0,

  /// How many corrected amounts have failed to save.
  final int editFailures = 0,

  /// How many Log Agains have failed.
  final int logAgainFailures = 0,

  /// How many meals were logged again from another day, out of sight on
  /// today, so the screen says where each went.
  final int loggedAgainToday = 0,
}) extends Equatable {
  /// Where the data has got to.
  NutritionDayStatus get status => failed
      ? NutritionDayStatus.failure
      : meals == null || settings == null
      ? NutritionDayStatus.loading
      : NutritionDayStatus.loaded;

  /// [selectedDay]'s key.
  String get dayKey => dayKeyOf(selectedDay);

  /// The selected day's meals, in the order they were eaten.
  List<MealLogModel> get dayMeals => mealsOnDay(meals ?? const [], dayKey);

  /// The selected day's timeline. Empty until the settings arrive.
  List<TimelineHour> get timeline => switch (settings) {
    final settings? => timelineHours(
      day: selectedDay,
      meals: dayMeals,
      settings: settings,
    ),
    null => const [],
  };

  /// What the selected day's meals add up to.
  Macros get totals => totalsOf(dayMeals);

  /// The plan's target for the selected day, or null without one.
  Macros? get target => dailyTarget(dietPlan, dayKey);

  /// Every logged day's calendar mark, by day key.
  Map<String, CalendarDayMarker> get markers =>
      calorieMarkersByDay(meals ?? const [], dietPlan);

  NutritionDayState copyWith({
    DateTime? selectedDay,
    List<MealLogModel>? meals,
    DietPlan? Function()? dietPlan,
    FoodLogSettings? settings,
    bool? failed,
    int? deleteFailures,
    int? editFailures,
    int? logAgainFailures,
    int? loggedAgainToday,
  }) => NutritionDayState(
    selectedDay: selectedDay ?? this.selectedDay,
    today: today,
    meals: meals ?? this.meals,
    dietPlan: dietPlan == null ? this.dietPlan : dietPlan(),
    settings: settings ?? this.settings,
    failed: failed ?? this.failed,
    deleteFailures: deleteFailures ?? this.deleteFailures,
    editFailures: editFailures ?? this.editFailures,
    logAgainFailures: logAgainFailures ?? this.logAgainFailures,
    loggedAgainToday: loggedAgainToday ?? this.loggedAgainToday,
  );

  @override
  List<Object?> get props => [
    selectedDay,
    today,
    meals,
    dietPlan,
    settings,
    failed,
    deleteFailures,
    editFailures,
    logAgainFailures,
    loggedAgainToday,
  ];
}
