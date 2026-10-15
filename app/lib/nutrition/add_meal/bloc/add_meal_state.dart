part of 'add_meal_bloc.dart';

/// The picker's tabs, in Swift's order less the AI scanner, Describe (M5)
/// and, on Mac, the barcode scanner.
enum FoodPickerMode {
  /// The camera, or a barcode typed in.
  barcode,

  /// The user's foods and Open Food Facts.
  search,

  /// Energy and macros typed straight in.
  quickAdd,

  /// The user's saved and favourite foods.
  library,
}

/// Where the save has got to.
enum AddMealStatus {
  /// Building the plate.
  editing,

  /// Saving the meal.
  saving,

  /// Logged: the logger closes.
  saved,

  /// The save failed; the plate is still there.
  failure,

  /// Closed with nothing on the plate.
  discarded,
}

final class const AddMealState({
  /// The meal being built.
  required final MealLogModel meal,

  /// Whether the picker is showing over the plate.
  final bool pickerOpen = false,

  /// The picker's tab.
  final FoodPickerMode mode = FoodPickerMode.search,

  /// What the totals show.
  final NutritionScope scope = NutritionScope.plate,

  /// Where the save has got to.
  final AddMealStatus status = AddMealStatus.editing,

  /// Every meal the user has logged; null until they arrive.
  final List<MealLogModel>? meals,

  /// The diet plan, or null.
  final DietPlan? dietPlan,

  /// The food log settings; null until they arrive.
  final FoodLogSettings? settings,

  /// The user's food library.
  final List<FoodModel> foods = const [],
}) extends Equatable {
  /// The settings, or Swift's defaults until they arrive.
  FoodLogSettings get effectiveSettings =>
      settings ?? FoodLogSettings(authorId: meal.authorId);

  /// The totals shown at [scope].
  Macros get totals => scopedTotals(meal, meals ?? const [], scope);

  /// The targets they are shown against.
  Macros get target => plateTarget(meal, dietPlan);

  AddMealState copyWith({
    MealLogModel? meal,
    bool? pickerOpen,
    FoodPickerMode? mode,
    NutritionScope? scope,
    AddMealStatus? status,
    List<MealLogModel>? meals,
    DietPlan? Function()? dietPlan,
    FoodLogSettings? settings,
    List<FoodModel>? foods,
  }) => AddMealState(
    meal: meal ?? this.meal,
    pickerOpen: pickerOpen ?? this.pickerOpen,
    mode: mode ?? this.mode,
    scope: scope ?? this.scope,
    // A change to the plate after a failed save starts over.
    status:
        status ??
        (this.status == AddMealStatus.failure
            ? AddMealStatus.editing
            : this.status),
    meals: meals ?? this.meals,
    dietPlan: dietPlan == null ? this.dietPlan : dietPlan(),
    settings: settings ?? this.settings,
    foods: foods ?? this.foods,
  );

  @override
  List<Object?> get props => [
    meal,
    pickerOpen,
    mode,
    scope,
    status,
    meals,
    dietPlan,
    settings,
    foods,
  ];
}
