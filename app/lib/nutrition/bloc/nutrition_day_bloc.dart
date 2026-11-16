import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show withItems;
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/review/review_moment.dart';
import 'package:compound/undo/pending_deletes.dart';
import 'package:compound/widgets/calendar/calendar_day_marker.dart';
import 'package:compound_maths/compound_maths.dart';
import 'package:compound_models/compound_models.dart';
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
    this._reviews,
    this._pendingDeletes,
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

  /// Asks for a rating after a save, as Swift's `addMeal` does; none in
  /// tests that leave it out.
  final ReviewPrompter? _reviews;

  /// Meals and foods waiting on an Undo, left out of the day and of their
  /// meals (and a meal left with no foods, out of the day), so the totals
  /// drop at once.
  final PendingDeletes? _pendingDeletes;

  /// The meals as stored, and the meals and foods hidden from them.
  List<MealLogModel>? _stored;
  Set<String> _hidden = const {};

  List<MealLogModel> _visible() {
    final visible = <MealLogModel>[];
    for (final meal in _stored ?? const <MealLogModel>[]) {
      if (_hidden.contains(PendingKeys.meal(meal.mealId))) continue;
      final items = meal.items.hide(
        _hidden,
        (item) => PendingKeys.mealItem(meal.mealId, item.itemId),
      );
      if (items.isEmpty) continue;
      visible.add(
        items.length == meal.items.length ? meal : withItems(meal, items),
      );
    }
    return visible;
  }

  Future<void> _onSubscriptionRequested(
    NutritionDaySubscriptionRequested event,
    Emitter<NutritionDayState> emit,
  ) => Future.wait([
    emit.forEach(
      _nutritionRepository.watchMeals(_uid),
      onData: (meals) {
        _stored = meals;
        return state.copyWith(meals: _visible());
      },
      onError: (_, _) => state.copyWith(failed: true),
    ),
    if (_pendingDeletes case final pending?)
      emit.forEach(
        pending.watch(),
        onData: (keys) {
          _hidden = keys;
          return _stored == null ? state : state.copyWith(meals: _visible());
        },
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
    try {
      await _deleteItem(event.meal, event.itemId);
    } on Object catch (_) {
      emit(state.copyWith(deleteFailures: state.deleteFailures + 1));
    }
  }

  /// Deletes food [itemId] from meal [mealId] for good, once its Undo has
  /// gone. It works from the meal as last stored, not as it was when the
  /// food was swiped, so edits made meanwhile are kept. A failure is
  /// rethrown for the snack bar to report.
  Future<void> deleteItem(String mealId, String itemId) async {
    final meal = _stored?.where((m) => m.mealId == mealId).firstOrNull;
    if (meal == null) return;
    await _deleteItem(meal, itemId);
  }

  Future<void> _deleteItem(MealLogModel meal, String itemId) async {
    final items = [
      for (final item in meal.items)
        if (item.itemId != itemId) item,
    ];
    if (items.isEmpty) {
      await _nutritionRepository.deleteMeal(_uid, meal.mealId);
    } else {
      final updated = withItems(meal, items);
      await _nutritionRepository.saveMeal(updated);
      _askForReview(updated);
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
      _askForReview(meal);
      return true;
    } on Object catch (error) {
      _analytics.severe('NutritionView_SaveMeal_Fail', error);
      return false;
    }
  }

  /// The seventh day of food logging in a row asks for a rating. Swift asks
  /// only on these three saves (`addMeal`), not when AddMeal logs food.
  void _askForReview(MealLogModel saved) {
    final reviews = _reviews;
    if (reviews == null) return;
    final days = ReviewMoment.daysInARow(
      today: _now(),
      loggedDays: [
        for (final meal in state.meals ?? const <MealLogModel>[]) meal.date,
        saved.date,
      ],
    );
    unawaited(reviews.requestIfEarned(ReviewFoodLogged(days)));
  }
}
