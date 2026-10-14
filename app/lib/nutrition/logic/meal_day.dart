/// The meal log day's arithmetic, ported from the Swift
/// `NutritionPresenter`, `MealHourHeaderPresenter` and `CalendarDayMarker`:
/// the day's meals, totals and target, the hour timeline and the calendar's
/// calorie markers. Pure, so the bloc and the widgets only read it.
library;

import 'package:compound_maths/compound_maths.dart';
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// The four figures the header and the hour rows show, in the Swift
/// `Macro.allCases` order.
enum Macro {
  /// Calories, in kcal.
  calories,

  /// Fat, in grams.
  fat,

  /// Protein, in grams.
  protein,

  /// Carbohydrate, in grams.
  carbs;

  /// This macro's figure in [macros].
  double of(Macros macros) => switch (this) {
    calories => macros.calories,
    fat => macros.fatGrams,
    protein => macros.proteinGrams,
    carbs => macros.carbGrams,
  };
}

/// An item's calories and macros from its nutrient snapshot; a nutrient it
/// does not record counts as zero (Swift `MealItemModel.calories ?? 0`).
extension MealItemMacros on MealItemModel {
  /// The item's calories and macros.
  Macros get macros => (
    calories: nutrients.values[NutrientKey.calories] ?? 0,
    proteinGrams: nutrients.values[NutrientKey.protein] ?? 0,
    carbGrams: nutrients.values[NutrientKey.carbs] ?? 0,
    fatGrams: nutrients.values[NutrientKey.fatTotal] ?? 0,
  );
}

/// A meal's totals (Swift `MealLogModel.totalCalories` and the rest).
extension MealLogMacros on MealLogModel {
  /// The sum of the meal's items.
  Macros get macros => sumMacros(items.map((item) => item.macros));
}

/// What [meals] add up to: a day's totals, or an hour's
/// (`MealLogManager.getDailyTotals`, `MealHourHeaderPresenter.total`).
Macros totalsOf(Iterable<MealLogModel> meals) =>
    sumMacros(meals.map((meal) => meal.macros));

/// [date]'s calendar day, at midnight local time.
DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// [day]'s `yyyy-MM-dd` key, as `MealLogModel.dayKey` stores it.
String dayKeyOf(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// [plan]'s target for the day [dayKey]; null without a plan, or when the
/// plan is short of that weekday (Swift `NutritionPresenter.dailyTarget`).
Macros? dailyTarget(DietPlan? plan, String dayKey) => plan == null
    ? null
    : planDayTarget([
        for (final day in plan.days)
          (
            calories: day.calories,
            proteinGrams: day.proteinGrams,
            carbGrams: day.carbGrams,
            fatGrams: day.fatGrams,
          ),
      ], dayKey);

/// The meals on [dayKey], in the order they were eaten
/// (`MealLogManager.getMeals(for:)`).
List<MealLogModel> mealsOnDay(Iterable<MealLogModel> meals, String dayKey) => [
  for (final meal in meals)
    if (meal.dayKey == dayKey) meal,
]..sort((a, b) => a.date.compareTo(b.date));

/// One hour of the timeline: its start, and the meals eaten inside it.
typedef TimelineHour = ({DateTime hour, List<MealLogModel> meals});

/// [day]'s timeline (Swift `NutritionPresenter.timelineHours`): every hour
/// from `startHour` to `endHour` unless `hideEmptyHours`, plus every hour
/// holding a meal, inside the window or not, so nothing logged is
/// unreachable. A window that ends before it starts adds no hours.
List<TimelineHour> timelineHours({
  required DateTime day,
  required List<MealLogModel> meals,
  required FoodLogSettings settings,
}) {
  final mealsByHour = <DateTime, List<MealLogModel>>{};
  for (final meal in meals) {
    final at = meal.date.toLocal();
    (mealsByHour[DateTime(at.year, at.month, at.day, at.hour)] ??= []).add(
      meal,
    );
  }
  final hours = {...mealsByHour.keys};
  if (!settings.hideEmptyHours) {
    for (var hour = settings.startHour; hour <= settings.endHour; hour++) {
      hours.add(DateTime(day.year, day.month, day.day, hour));
    }
  }
  return [
    for (final hour in hours.toList()..sort())
      (hour: hour, meals: mealsByHour[hour] ?? const []),
  ];
}

/// The time printed beside [item]: only a meal's first item carries one,
/// so items logged together read as one block. Compares ids, since two
/// helpings of one food are equal by value.
DateTime? itemTimestamp(MealItemModel item, MealLogModel meal) =>
    meal.items.isNotEmpty && meal.items.first.itemId == item.itemId
    ? meal.date
    : null;

/// A day's mark on the calendar strip (Swift `CalendarDayMarker`): the
/// calories logged, against the plan's goal for that day when it has one.
/// Without a goal the day is simply marked as logged.
class const CalorieMarker({
  /// The calories logged that day.
  required final double calories,

  /// The plan's calorie goal for the day, or null when there is none.
  final double? goal,
}) extends Equatable {
  /// How far past the goal still counts as on target: going over by a
  /// little is not worth flagging (`NutritionPresenter.calorieGrace`).
  static const grace = 100.0;

  /// How much of the ring is drawn, 0–1. A day without a goal draws it all.
  double get fraction {
    final goal = this.goal;
    return goal == null ? 1 : (calories / goal).clamp(0, 1).toDouble();
  }

  /// Whether the goal has been reached.
  bool get isGoalMet {
    final goal = this.goal;
    return goal != null && calories >= goal;
  }

  /// Whether the goal and its [grace] have both been passed. The ring is
  /// then dashed as well as recoloured, so the state is not hue alone.
  bool get isOverGoal {
    final goal = this.goal;
    return goal != null && calories > goal + grace;
  }

  /// Whether a day with a goal has nothing toward it, so no ring is drawn.
  bool get isEmpty => goal != null && calories <= 0;

  @override
  List<Object?> get props => [calories, goal];
}

/// Every logged day's [CalorieMarker], by day key, in one pass (Swift
/// `NutritionPresenter.calorieMarkersByDay`). A day whose plan target has
/// no calories gets a plain logged mark, since a ring with nothing to fill
/// toward would read as a missed day.
Map<String, CalorieMarker> calorieMarkersByDay(
  Iterable<MealLogModel> meals,
  DietPlan? plan,
) {
  final caloriesByDay = <String, double>{};
  for (final meal in meals) {
    caloriesByDay.update(
      meal.dayKey,
      (calories) => calories + meal.macros.calories,
      ifAbsent: () => meal.macros.calories,
    );
  }
  return caloriesByDay.map((dayKey, calories) {
    final goal = dailyTarget(plan, dayKey)?.calories;
    return MapEntry(
      dayKey,
      CalorieMarker(
        calories: calories,
        goal: goal != null && goal > 0 ? goal : null,
      ),
    );
  });
}
