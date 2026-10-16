import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Where deleting the food is.
enum FoodDetailDeleteStatus {
  /// Not deleting.
  idle,

  /// Deleting.
  deleting,

  /// Deleted; the screen closes.
  deleted,
}

/// One food from the library.
final class const FoodDetailState({
  /// The food; null until the library arrives, or once it has gone.
  final FoodModel? food,

  /// Whether the library has arrived.
  final bool loaded = false,

  /// The food log settings, which hold the favourites; null until read.
  final FoodLogSettings? settings,

  /// Whether the food is a favourite, as last chosen here or read.
  final bool isFavourited = false,

  final FoodDetailDeleteStatus deleteStatus = FoodDetailDeleteStatus.idle,

  /// How many favourite changes have failed, so each says so.
  final int favouriteFailures = 0,

  /// How many deletes have failed, so each says so.
  final int deleteFailures = 0,
}) extends Equatable {
  FoodDetailState copyWith({
    FoodModel? Function()? food,
    bool? loaded,
    FoodLogSettings? settings,
    bool? isFavourited,
    FoodDetailDeleteStatus? deleteStatus,
    int? favouriteFailures,
    int? deleteFailures,
  }) => FoodDetailState(
    food: food == null ? this.food : food(),
    loaded: loaded ?? this.loaded,
    settings: settings ?? this.settings,
    isFavourited: isFavourited ?? this.isFavourited,
    deleteStatus: deleteStatus ?? this.deleteStatus,
    favouriteFailures: favouriteFailures ?? this.favouriteFailures,
    deleteFailures: deleteFailures ?? this.deleteFailures,
  );

  @override
  List<Object?> get props => [
    food?.toFirestore(),
    loaded,
    settings,
    isFavourited,
    deleteStatus,
    favouriteFailures,
    deleteFailures,
  ];
}

/// A food's detail (Swift `FoodDetailPresenter`): its nutrients, a
/// favourite toggle stored on the food log settings, and Delete for its
/// author.
class FoodDetailCubit extends Cubit<FoodDetailState> {
  new({
    required this._uid,
    required this._foodId,
    required this._foods,
    required this._nutrition,
    required this._analytics,
  }) : super(const FoodDetailState()) {
    _analytics.appear('FoodDetailView');
    _subscriptions = [
      _foods
          .watchFoods(_uid)
          .listen(
            (foods) => emit(
              state.copyWith(
                food: () => foods
                    .where((food) => food.ingredientId == _foodId)
                    .firstOrNull,
                loaded: true,
              ),
            ),
            onError: (Object _) => emit(state.copyWith(loaded: true)),
          ),
      _nutrition
          .watchFoodLogSettings(_uid)
          .listen(
            (settings) => emit(
              state.copyWith(
                settings: settings,
                isFavourited: settings.favouriteFoodIds.contains(_foodId),
              ),
            ),
            onError: (Object _) {},
          ),
    ];
  }

  final String _uid;
  final String _foodId;
  final FoodRepository _foods;
  final NutritionRepository _nutrition;
  final AnalyticsRepository _analytics;
  late final List<StreamSubscription<Object?>> _subscriptions;

  /// Only the food's author may delete it
  /// (`FoodDetailPresenter.canDelete`).
  bool get canDelete {
    final author = state.food?.authorId;
    return author != null && author == _uid;
  }

  /// The heart (`FoodDetailPresenter.onFavouritePressed`): shown at once,
  /// saved to the latest settings, and put back if the save fails.
  Future<void> favouriteToggled() async {
    final settings = state.settings;
    if (settings == null) return;
    final favourite = !state.isFavourited;
    emit(state.copyWith(isFavourited: favourite));
    _analytics.analytic('FoodDetailView_Favourite_Start');
    final ids = [
      for (final id in settings.favouriteFoodIds)
        if (id != _foodId) id,
      if (favourite) _foodId,
    ];
    try {
      await _nutrition.saveFoodLogSettings(
        FoodLogSettings.fromFirestore({
          ...settings.toFirestore(),
          FoodLogSettingsKeys.favouriteFoodIds: ids,
        }),
      );
      _analytics.analytic('FoodDetailView_Favourite_Success');
    } on Object catch (error) {
      _analytics.severe('FoodDetailView_Favourite_Fail', error);
      emit(
        state.copyWith(
          isFavourited: !favourite,
          favouriteFailures: state.favouriteFailures + 1,
        ),
      );
    }
  }

  /// Deletes the food, once confirmed (`FoodDetailPresenter.deleteFood`).
  Future<void> deleteConfirmed() async {
    if (!canDelete || state.deleteStatus != FoodDetailDeleteStatus.idle) {
      return;
    }
    emit(state.copyWith(deleteStatus: FoodDetailDeleteStatus.deleting));
    _analytics.analytic('FoodDetailView_Delete_Start');
    try {
      await _foods.deleteFood(_uid, _foodId);
      _analytics.analytic('FoodDetailView_Delete_Success');
      emit(state.copyWith(deleteStatus: FoodDetailDeleteStatus.deleted));
    } on Object catch (error) {
      _analytics.severe('FoodDetailView_Delete_Fail', error);
      emit(
        state.copyWith(
          deleteStatus: FoodDetailDeleteStatus.idle,
          deleteFailures: state.deleteFailures + 1,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _analytics.disappear('FoodDetailView');
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}
