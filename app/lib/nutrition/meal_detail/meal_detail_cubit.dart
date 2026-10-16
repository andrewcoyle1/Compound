import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Where deleting the meal is.
enum MealDetailStatus {
  /// Showing the meal.
  idle,

  /// Deleting it.
  deleting,

  /// Deleted; the screen closes.
  deleted,
}

/// A logged meal.
final class const MealDetailState({
  /// The meal; null until it is read, or once it has gone.
  final MealLogModel? meal,

  /// Whether the meals have been read.
  final bool loaded = false,
  final MealDetailStatus status = MealDetailStatus.idle,

  /// How many deletes have failed, so each says so.
  final int deleteFailures = 0,
}) extends Equatable {
  MealDetailState copyWith({
    MealLogModel? Function()? meal,
    bool? loaded,
    MealDetailStatus? status,
    int? deleteFailures,
  }) => MealDetailState(
    meal: meal == null ? this.meal : meal(),
    loaded: loaded ?? this.loaded,
    status: status ?? this.status,
    deleteFailures: deleteFailures ?? this.deleteFailures,
  );

  @override
  List<Object?> get props => [meal, loaded, status, deleteFailures];
}

/// A logged meal's summary (Swift `MealDetailPresenter`): its totals and
/// foods, kept current, and Delete. Opens on `meal` when the caller has it.
class MealDetailCubit extends Cubit<MealDetailState> {
  new({
    required this._uid,
    required this._mealId,
    required NutritionRepository nutrition,
    required this._analytics,
    MealLogModel? meal,
  }) : _nutrition = nutrition,
       super(MealDetailState(meal: meal, loaded: meal != null)) {
    if (meal != null) _appeared(meal);
    _subscription = nutrition.watchMeals(_uid).listen((meals) {
      final meal = meals.where((meal) => meal.mealId == _mealId).firstOrNull;
      if (!state.loaded && meal != null) _appeared(meal);
      emit(state.copyWith(meal: () => meal, loaded: true));
    }, onError: (Object _) => emit(state.copyWith(loaded: true)));
  }

  final String _uid;
  final String _mealId;
  final NutritionRepository _nutrition;
  final AnalyticsRepository _analytics;
  late final StreamSubscription<List<MealLogModel>> _subscription;

  void _appeared(MealLogModel meal) =>
      _analytics.appear('MealDetailView', {'item_count': meal.items.length});

  /// Deletes the meal, once confirmed (`MealDetailPresenter.delete`).
  Future<void> deleteConfirmed() async {
    if (state.status != MealDetailStatus.idle) return;
    emit(state.copyWith(status: MealDetailStatus.deleting));
    _analytics.analytic('MealDetailView_Delete_Start');
    try {
      await _nutrition.deleteMeal(_uid, _mealId);
      _analytics.analytic('MealDetailView_Delete_Success');
      emit(state.copyWith(status: MealDetailStatus.deleted));
    } on Object catch (error) {
      _analytics.severe('MealDetailView_Delete_Fail', error);
      emit(
        state.copyWith(
          status: MealDetailStatus.idle,
          deleteFailures: state.deleteFailures + 1,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _analytics.disappear('MealDetailView');
    await _subscription.cancel();
    await super.close();
  }
}
