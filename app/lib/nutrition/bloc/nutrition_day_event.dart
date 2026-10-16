part of 'nutrition_day_bloc.dart';

sealed class NutritionDayEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Start following the user's meals, diet plan and food log settings.
final class NutritionDaySubscriptionRequested extends NutritionDayEvent {
  const new();
}

/// The user picked [day] on the calendar strip.
final class const NutritionDayDateSelected(final DateTime day)
    extends NutritionDayEvent {
  @override
  List<Object> get props => [day];
}

/// The logged food [itemId] was deleted from [meal]; the meal goes with its
/// last food.
final class const NutritionDayItemDeleted(
  final MealLogModel meal,
  final String itemId,
) extends NutritionDayEvent {
  @override
  List<Object> get props => [meal.mealId, itemId];
}

/// The logged food [item] was corrected in [meal]; [item] keeps its id
/// (`NutritionPresenter.onEditMealItem`).
final class const NutritionDayItemEdited(
  final MealLogModel meal,
  final MealItemModel item,
) extends NutritionDayEvent {
  @override
  List<Object> get props => [meal.mealId, item];
}

/// Log Again: [meal]'s foods logged again as a new meal now
/// (`NutritionPresenter.onLogAgainPressed`).
final class const NutritionDayMealLoggedAgain(final MealLogModel meal)
    extends NutritionDayEvent {
  @override
  List<Object> get props => [meal.mealId];
}
