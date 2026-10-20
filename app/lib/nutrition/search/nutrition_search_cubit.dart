import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/recipes/logic/recipe_logic.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';

/// The Nutrition tab's search over the user's foods and recipes.
final class const NutritionSearchState({
  final String query = '',
  final List<FoodModel> foods = const [],
  final List<RecipeTemplateModel> recipes = const [],
}) extends Equatable {
  /// Whether the query says anything, so results replace the day.
  bool get isSearching => FuzzyMatch.isSearching(query);

  /// Foods matching on name, brand or description, best first and then by
  /// name (`NutritionPresenter.filteredFoods`). None for a blank query.
  List<FoodModel> get matchingFoods =>
      isSearching ? searchFoods(foods, query) : const [];

  /// Recipes matching on name, an ingredient's name or description, best
  /// first and then by name (`NutritionPresenter.filteredRecipes`). None
  /// for a blank query.
  List<RecipeTemplateModel> get matchingRecipes =>
      isSearching ? searchRecipes(recipes, query) : const [];

  NutritionSearchState copyWith({
    String? query,
    List<FoodModel>? foods,
    List<RecipeTemplateModel>? recipes,
  }) => NutritionSearchState(
    query: query ?? this.query,
    foods: foods ?? this.foods,
    recipes: recipes ?? this.recipes,
  );

  @override
  List<Object?> get props => [
    query,
    [for (final food in foods) food.toFirestore()],
    [for (final recipe in recipes) recipe.toFirestore()],
  ];
}

/// The search field above the Nutrition tab's day (Swift
/// `NutritionPresenter.searchString`): its query and the library it
/// searches.
class NutritionSearchCubit extends Cubit<NutritionSearchState> {
  new({required String uid, required FoodRepository foods})
    : super(const NutritionSearchState()) {
    // A library that fails to load searches as empty.
    _subscriptions = [
      foods
          .watchFoods(uid)
          .listen(
            (foods) => emit(state.copyWith(foods: foods)),
            onError: (Object _) {},
          ),
      foods
          .watchRecipes(uid)
          .listen(
            (recipes) => emit(state.copyWith(recipes: recipes)),
            onError: (Object _) {},
          ),
    ];
  }

  late final List<StreamSubscription<Object?>> _subscriptions;

  void queryChanged(String query) => emit(state.copyWith(query: query));

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}
