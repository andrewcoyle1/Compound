import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/recipes/logic/recipe_logic.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';

/// The user's recipes as the Recipes screen lists them.
final class const RecipesState({
  /// Every recipe in the library; null until it arrives.
  final List<RecipeTemplateModel>? recipes,

  /// The filter typed.
  final String filter = '',
}) extends Equatable {
  /// The recipes shown (`RecipeListBuilderPresenter.userRecipeTemplates`
  /// and `.filteredRecipeTemplates`): those matching the filter, by name.
  List<RecipeTemplateModel> get visibleRecipes => sortedByName([
    for (final recipe in recipes ?? const <RecipeTemplateModel>[])
      if (filter.isEmpty || matchesRecipeFilter(recipe, filter)) recipe,
  ], (recipe) => recipe.name);

  RecipesState copyWith({List<RecipeTemplateModel>? recipes, String? filter}) =>
      RecipesState(
        recipes: recipes ?? this.recipes,
        filter: filter ?? this.filter,
      );

  @override
  List<Object?> get props => [
    recipes?.map((recipe) => recipe.toFirestore()).toList(),
    filter,
  ];
}

/// The Recipes screen (Swift `RecipesPresenter`, with the
/// `RecipeListBuilderPresenter` it embeds): the user's recipes, to open or
/// add to.
class RecipesCubit extends Cubit<RecipesState> {
  new({
    required String uid,
    required FoodRepository foods,
    required this._analytics,
  }) : super(const RecipesState()) {
    _analytics.appear('RecipesView');
    _subscription = foods
        .watchRecipes(uid)
        .listen(
          (recipes) => emit(state.copyWith(recipes: recipes)),
          onError: (Object _) => emit(state.copyWith(recipes: const [])),
        );
  }

  final AnalyticsRepository _analytics;
  late final StreamSubscription<List<RecipeTemplateModel>> _subscription;

  /// The filter as typed.
  void filterChanged(String filter) => emit(state.copyWith(filter: filter));

  @override
  Future<void> close() async {
    _analytics.disappear('RecipesView');
    await _subscription.cancel();
    await super.close();
  }
}
