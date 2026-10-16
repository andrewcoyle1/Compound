import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show withItems;
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/widgets/calendar/calendar_day_marker.dart';
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
    AnalyticsRepository analyticsRepository = const AnalyticsRepository(),
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : _analytics = analyticsRepository,
       super(_initialState(startOfDay(_now()))) {
    on<NutritionDaySubscriptionRequested>(_onSubscriptionRequested);
    on<NutritionDayDateSelected>(_onDateSelected);
    on<NutritionDayItemDeleted>(_onItemDeleted);
    on<NutritionDayItemEdited>(_onItemEdited);
    on<NutritionDayMealLoggedAgain>(_onMealLoggedAgain);
  }

  static NutritionDayState _initialState(DateTime today) =>
      NutritionDayState(selectedDay: today, today: today);

  final NutritionRepository _nutritionRepository;
  final String _uid;
  final AnalyticsRepository _analytics;
  final DateTime Function() _now;
  final String Function() _newId;

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

  /// Writes the corrected food into its meal
  /// (`NutritionPresenter.saveEditedItem`). A food no longer in the meal is
  /// left alone.
  Future<void> _onItemEdited(
    NutritionDayItemEdited event,
    Emitter<NutritionDayState> emit,
  ) async {
    final meal = event.meal;
    if (!meal.items.any((item) => item.itemId == event.item.itemId)) return;
    final saved = await _saveMeal(
      withItems(meal, [
        for (final item in meal.items)
          if (item.itemId == event.item.itemId) event.item else item,
      ]),
    );
    if (!saved) emit(state.copyWith(editFailures: state.editFailures + 1));
  }

  /// Logs the meal's foods again as a new meal now, from whichever day it
  /// is on (`NutritionPresenter.onLogAgainPressed`). From another day the
  /// copy lands out of sight, so the screen is told.
  Future<void> _onMealLoggedAgain(
    NutritionDayMealLoggedAgain event,
    Emitter<NutritionDayState> emit,
  ) async {
    final now = _now();
    final saved = await _saveMeal(
      MealLogModel(
        mealId: _newId(),
        authorId: _uid,
        dayKey: dayKeyOf(now),
        date: now,
        items: event.meal.items,
        notes: event.meal.notes,
      ),
    );
    if (!saved) {
      emit(state.copyWith(logAgainFailures: state.logAgainFailures + 1));
    } else if (state.selectedDay != startOfDay(now)) {
      emit(state.copyWith(loggedAgainToday: state.loggedAgainToday + 1));
    }
  }

  /// Saves [meal] between `NutritionView_SaveMeal_Start` and `_Success` or
  /// a severe `_Fail`; whether it saved.
  Future<bool> _saveMeal(MealLogModel meal) async {
    _analytics.analytic('NutritionView_SaveMeal_Start');
    try {
      await _nutritionRepository.saveMeal(meal);
      _analytics.analytic('NutritionView_SaveMeal_Success');
      return true;
    } on Object catch (error) {
      _analytics.severe('NutritionView_SaveMeal_Fail', error);
      return false;
    }
  }
}
