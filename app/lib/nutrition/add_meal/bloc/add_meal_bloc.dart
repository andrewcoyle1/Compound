import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:compound_maths/compound_maths.dart' show Macros;
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

part 'add_meal_event.dart';
part 'add_meal_state.dart';

/// Logging a meal (Swift `AddMealPresenter` and
/// `NutritionLibraryPickerPresenter`): the plate, the picker that fills it,
/// and the save. Also follows everything the picker reads: the user's
/// meals (quick add's last amount, recent foods, the day's totals), diet
/// plan, food log settings and food library.
class AddMealBloc extends Bloc<AddMealEvent, AddMealState> {
  new({
    required this._nutritionRepository,
    required this._foodRepository,
    required this._analyticsRepository,
    required MealLogModel meal,
  }) : super(AddMealState(meal: meal, pickerOpen: meal.items.isEmpty)) {
    on<AddMealSubscriptionRequested>(_onSubscriptionRequested);
    on<AddMealPickerOpened>(
      (event, emit) => emit(state.copyWith(pickerOpen: true)),
    );
    on<AddMealPickerClosed>(_onPickerClosed);
    on<AddMealModeSelected>(_onModeSelected);
    on<AddMealItemAdded>(_onItemAdded);
    on<AddMealFoodQuickAdded>(_onFoodQuickAdded);
    on<AddMealItemRemoved>(
      (event, emit) => _setItems(emit, [
        for (final item in state.meal.items)
          if (item.itemId != event.itemId) item,
      ]),
    );
    on<AddMealItemChanged>(
      (event, emit) => _setItems(emit, [
        for (final item in state.meal.items)
          if (item.itemId == event.item.itemId) event.item else item,
      ]),
    );
    on<AddMealScopeChanged>(
      (event, emit) => emit(state.copyWith(scope: event.scope)),
    );
    on<AddMealTimeChanged>(
      (event, emit) =>
          emit(state.copyWith(meal: movedMeal(state.meal, event.date))),
    );
    on<AddMealSaveRequested>(_onSaveRequested);
  }

  final NutritionRepository _nutritionRepository;
  final FoodRepository _foodRepository;
  final AnalyticsRepository _analyticsRepository;

  String get _uid => state.meal.authorId;

  Future<void> _onSubscriptionRequested(
    AddMealSubscriptionRequested event,
    Emitter<AddMealState> emit,
  ) {
    _analyticsRepository.trackScreenView(
      const AnalyticsEvent('AddMealView_Appear'),
    );
    // A stream that fails leaves its last value: the plate is still usable
    // without totals, recents or the library.
    return Future.wait([
      emit.forEach(
        _nutritionRepository.watchMeals(_uid),
        onData: (meals) => state.copyWith(meals: meals),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _nutritionRepository.watchDietPlan(_uid),
        onData: (plan) => state.copyWith(dietPlan: () => plan),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _nutritionRepository.watchFoodLogSettings(_uid),
        onData: (settings) => state.copyWith(settings: settings),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _foodRepository.watchFoods(_uid),
        onData: (foods) => state.copyWith(foods: foods),
        onError: (_, _) => state,
      ),
    ]);
  }

  /// Closing the picker goes back to the plate; with nothing on it nothing
  /// is being logged, so the logger closes too.
  void _onPickerClosed(AddMealPickerClosed event, Emitter<AddMealState> emit) {
    if (state.meal.items.isEmpty && state.status != AddMealStatus.saving) {
      emit(state.copyWith(status: AddMealStatus.discarded));
    } else {
      emit(state.copyWith(pickerOpen: false));
    }
  }

  void _onModeSelected(AddMealModeSelected event, Emitter<AddMealState> emit) {
    if (event.mode == state.mode) return;
    _analyticsRepository.trackEvent(
      AnalyticsEvent(
        'NutritionLibraryPickerView_Tab_Selected',
        parameters: {'tab': event.mode.name},
      ),
    );
    emit(state.copyWith(mode: event.mode));
  }

  void _onItemAdded(AddMealItemAdded event, Emitter<AddMealState> emit) {
    _saveExternal(event.food);
    _setItems(emit, [...state.meal.items, event.item]);
  }

  /// A row's +: the food at the amount it was last logged, without the
  /// amount sheet (`NutritionLibraryPickerPresenter.quickAdd`).
  void _onFoodQuickAdded(
    AddMealFoodQuickAdded event,
    Emitter<AddMealState> emit,
  ) {
    _saveExternal(event.food);
    _setItems(emit, [
      ...state.meal.items,
      event.food.quickAddItem(state.meals ?? const []),
    ]);
  }

  /// A food from Open Food Facts goes into the user's library once it is
  /// logged, as Swift's `saveExternalFood` does. A side effect: if it fails
  /// the plate is unaffected.
  void _saveExternal(FoodModel? food) {
    if (food == null || food.authorId != null) return;
    _foodRepository
        .saveFood(
          FoodModel.fromFirestore({
            ...food.toFirestore(),
            FoodModelKeys.authorId: _uid,
          }),
        )
        .ignore();
  }

  void _setItems(Emitter<AddMealState> emit, List<MealItemModel> items) =>
      emit(state.copyWith(meal: withItems(state.meal, items)));

  /// Logs the plate (`AddMealPresenter.saveMeal`). A second request while
  /// one is saving or once it is saved, or an empty plate, does nothing.
  Future<void> _onSaveRequested(
    AddMealSaveRequested event,
    Emitter<AddMealState> emit,
  ) async {
    if (state.status == AddMealStatus.saving ||
        state.status == AddMealStatus.saved ||
        state.meal.items.isEmpty) {
      return;
    }
    emit(state.copyWith(status: AddMealStatus.saving));
    _analyticsRepository.trackEvent(
      const AnalyticsEvent('AddMealView_SaveMeal_Start'),
    );
    try {
      await _nutritionRepository.saveMeal(state.meal);
      _analyticsRepository.trackEvent(
        const AnalyticsEvent('AddMealView_SaveMeal_Success'),
      );
      emit(state.copyWith(status: AddMealStatus.saved));
    } on Object catch (error) {
      _analyticsRepository.trackEvent(
        AnalyticsEvent(
          'AddMealView_SaveMeal_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(state.copyWith(status: AddMealStatus.failure));
    }
  }

  @override
  Future<void> close() {
    _analyticsRepository.trackEvent(
      const AnalyticsEvent('AddMealView_Disappear'),
    );
    return super.close();
  }
}
