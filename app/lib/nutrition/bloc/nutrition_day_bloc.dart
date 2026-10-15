import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show withItems;
import 'package:compound_maths/compound_maths.dart';
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

part 'nutrition_day_event.dart';
part 'nutrition_day_state.dart';

/// The Nutrition tab's day: the user's meals, plan and food log settings
/// from [NutritionRepository], and the day picked on the calendar strip.
/// Opens on today, read from `now`.
class NutritionDayBloc extends Bloc<NutritionDayEvent, NutritionDayState> {
  new({
    required this._nutritionRepository,
    required this._uid,
    DateTime Function() now = DateTime.now,
  }) : super(_initialState(startOfDay(now()))) {
    on<NutritionDaySubscriptionRequested>(_onSubscriptionRequested);
    on<NutritionDayDateSelected>(_onDateSelected);
    on<NutritionDayItemDeleted>(_onItemDeleted);
  }

  static NutritionDayState _initialState(DateTime today) =>
      NutritionDayState(selectedDay: today, today: today);

  final NutritionRepository _nutritionRepository;
  final String _uid;

  Future<void> _onSubscriptionRequested(
    NutritionDaySubscriptionRequested event,
    Emitter<NutritionDayState> emit,
  ) => Future.wait([
    emit.forEach(
      _nutritionRepository.watchMeals(_uid),
      onData: (meals) => state.copyWith(meals: meals),
      onError: (_, _) => state.copyWith(failed: true),
    ),
    // The repository already falls back to no plan and to Swift's default
    // settings; these cover a stream that fails outright.
    emit.forEach(
      _nutritionRepository.watchDietPlan(_uid),
      onData: (plan) => state.copyWith(dietPlan: () => plan),
      onError: (_, _) => state.copyWith(dietPlan: () => null),
    ),
    emit.forEach(
      _nutritionRepository.watchFoodLogSettings(_uid),
      onData: (settings) => state.copyWith(settings: settings),
      onError: (_, _) =>
          state.copyWith(settings: FoodLogSettings(authorId: _uid)),
    ),
  ]);

  void _onDateSelected(
    NutritionDayDateSelected event,
    Emitter<NutritionDayState> emit,
  ) => emit(state.copyWith(selectedDay: startOfDay(event.day)));

  /// Deletes one logged food (`NutritionPresenter.deleteMealItem`): the
  /// meal is saved without it, or deleted when it was the last.
  Future<void> _onItemDeleted(
    NutritionDayItemDeleted event,
    Emitter<NutritionDayState> emit,
  ) async {
    final meal = event.meal;
    final items = [
      for (final item in meal.items)
        if (item.itemId != event.itemId) item,
    ];
    try {
      if (items.isEmpty) {
        await _nutritionRepository.deleteMeal(_uid, meal.mealId);
      } else {
        await _nutritionRepository.saveMeal(withItems(meal, items));
      }
    } on Object catch (_) {
      emit(state.copyWith(deleteFailures: state.deleteFailures + 1));
    }
  }
}
