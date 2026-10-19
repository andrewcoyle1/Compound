import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/recipes/logic/recipe_logic.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// The user's foods as the Foods screen lists them.
final class const FoodsState({
  /// Every food in the library; null until it arrives.
  final List<FoodModel>? foods,

  /// Whether branded foods are listed (the Show Branded Foods setting).
  final bool showBrandedFoods = true,

  /// The filter typed.
  final String filter = '',

  /// Whether rows show the food's picture (the Show Food Image setting of
  /// the logger's food tiles).
  final bool showFoodImage = true,
}) extends Equatable {
  /// The foods shown (`IngredientListBuilderPresenter.userFoods` and
  /// `.filteredFoods`): branded ones only when the setting allows, matching
  /// the filter, best first and then by name.
  List<FoodModel> get visibleFoods => searchFoods([
    for (final food in foods ?? const <FoodModel>[])
      if (showBrandedFoods || food.brandName == null) food,
  ], filter);

  FoodsState copyWith({
    List<FoodModel>? foods,
    bool? showBrandedFoods,
    String? filter,
    bool? showFoodImage,
  }) => FoodsState(
    foods: foods ?? this.foods,
    showBrandedFoods: showBrandedFoods ?? this.showBrandedFoods,
    filter: filter ?? this.filter,
    showFoodImage: showFoodImage ?? this.showFoodImage,
  );

  @override
  List<Object?> get props => [foods, showBrandedFoods, filter, showFoodImage];
}

/// The Foods screen (Swift `FoodsPresenter`, with the
/// `IngredientListBuilderPresenter` it embeds): the user's food library, to
/// open or add to.
class FoodsCubit extends Cubit<FoodsState> {
  new({
    required String uid,
    required FoodRepository foods,
    required NutritionRepository nutrition,
    required this._analytics,
    this._screen = 'FoodsView',
  }) : super(const FoodsState()) {
    _analytics.appear(_screen);
    _subscriptions = [
      foods
          .watchFoods(uid)
          .listen(
            (foods) => emit(state.copyWith(foods: foods)),
            onError: (Object _) => emit(state.copyWith(foods: const [])),
          ),
      nutrition
          .watchFoodLogSettings(uid)
          .listen(
            (settings) => emit(
              state.copyWith(
                showBrandedFoods: settings.showBrandedFoods,
                showFoodImage: settings.showFoodImageInLogger,
              ),
            ),
            onError: (Object _) {},
          ),
    ];
  }

  final AnalyticsRepository _analytics;

  /// The screen logged on appear and disappear: `FoodsView`, or
  /// `IngredientsView` for the list on its own, picking a recipe's
  /// ingredients.
  final String _screen;
  late final List<StreamSubscription<Object?>> _subscriptions;

  /// The filter as typed.
  void filterChanged(String filter) => emit(state.copyWith(filter: filter));

  /// A food was picked (`IngredientListBuilderPresenter
  /// .navToIngredientAmountView`, which Foods routes to the detail), or
  /// added by its + when [method] is `quickAdd`.
  void foodSelected(FoodModel food, {String method = 'amount'}) =>
      _analytics.analytic('IngredientsView_Ingredient_Selected', {
        'ingredient_id': food.ingredientId,
        'ingredient_name': food.name,
        'method': method,
      });

  /// + or Create a Food.
  void addPressed() =>
      _analytics.analytic('IngredientsView_AddIngredientPressed');

  @override
  Future<void> close() async {
    _analytics.disappear(_screen);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}
