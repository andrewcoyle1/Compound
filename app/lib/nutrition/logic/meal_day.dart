/// The meal log day's arithmetic, ported from the Swift
/// `NutritionPresenter`, `MealHourHeaderPresenter` and `CalendarDayMarker`:
/// the day's meals, totals and target, the hour timeline and the calendar's
/// calorie markers. Pure, so the bloc and the widgets only read it.
library;

import 'package:compound/widgets/calendar/calendar_day_marker.dart';
import 'package:compound_maths/compound_maths.dart';
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

/// How far past the calorie goal still counts as on target: going over by
/// a little is not worth flagging (`NutritionPresenter.calorieGrace`).
const calorieGrace = 100.0;

/// Every logged day's calendar marker, by day key, in one pass (Swift
/// `NutritionPresenter.calorieMarkersByDay`): the calories against the
/// day's goal, or, when the plan gives no calorie goal, a plain logged mark,
/// since a ring with nothing to fill toward would read as a missed day.
Map<String, CalendarDayMarker> calorieMarkersByDay(
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
      goal != null && goal > 0
          ? GoalProgressMarker(value: calories, goal: goal, grace: calorieGrace)
          : const CountMarker(1),
    );
  });
}
