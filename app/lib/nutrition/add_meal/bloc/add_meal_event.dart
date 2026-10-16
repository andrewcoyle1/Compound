part of 'add_meal_bloc.dart';

sealed class AddMealEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Start following the meals, plan, settings, foods and recipes.
final class AddMealSubscriptionRequested extends AddMealEvent {
  const new();
}

/// Add Food: open the picker over the plate.
final class AddMealPickerOpened extends AddMealEvent {
  const new();
}

/// The picker's close.
final class AddMealPickerClosed extends AddMealEvent {
  const new();
}

/// A picker tab was chosen.
final class const AddMealModeSelected(final FoodPickerMode mode)
    extends AddMealEvent {
  @override
  List<Object?> get props => [mode];
}

/// [item] goes on the plate, made from [food] when it came from one.
final class const AddMealItemAdded(
  final MealItemModel item, {
  final FoodModel? food,
}) extends AddMealEvent {
  @override
  List<Object?> get props => [item, food];
}

/// A row's +: [food] at the amount it was last logged.
final class const AddMealFoodQuickAdded(final FoodModel food)
    extends AddMealEvent {
  @override
  List<Object?> get props => [food];
}

/// A recipe row's +: [recipe] at the servings it was last logged.
final class const AddMealRecipeQuickAdded(final RecipeTemplateModel recipe)
    extends AddMealEvent {
  @override
  List<Object?> get props => [recipe.recipeId];
}

/// The plate item [itemId] was removed.
final class const AddMealItemRemoved(final String itemId) extends AddMealEvent {
  @override
  List<Object?> get props => [itemId];
}

/// A plate item's amount was corrected; [item] keeps its id.
final class const AddMealItemChanged(final MealItemModel item)
    extends AddMealEvent {
  @override
  List<Object?> get props => [item];
}

/// The totals now show [scope].
final class const AddMealScopeChanged(final NutritionScope scope)
    extends AddMealEvent {
  @override
  List<Object?> get props => [scope];
}

/// The meal was eaten at [date].
final class const AddMealTimeChanged(final DateTime date) extends AddMealEvent {
  @override
  List<Object?> get props => [date];
}

/// Log: save the plate.
final class AddMealSaveRequested extends AddMealEvent {
  const new();
}
