import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/recipes/logic/recipe_logic.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/undo/pending_deletes.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// The user's recipes as the Recipes screen lists them.
final class const RecipesState({
  /// Every recipe in the library; null until it arrives.
  final List<RecipeTemplateModel>? recipes,

  /// The filter typed.
  final String filter = '',

  /// Whether rows show the recipe's picture (`RecipeListBuilderView`'s
  /// `showFoodImageInLogger`).
  final bool showImage = true,
}) extends Equatable {
  /// The recipes shown (`RecipeListBuilderPresenter.userRecipeTemplates`
  /// and `.filteredRecipeTemplates`): those matching the filter, best first
  /// and then by name.
  List<RecipeTemplateModel> get visibleRecipes =>
      searchRecipes(recipes ?? const [], filter);

  RecipesState copyWith({
    List<RecipeTemplateModel>? recipes,
    String? filter,
    bool? showImage,
  }) => RecipesState(
    recipes: recipes ?? this.recipes,
    filter: filter ?? this.filter,
    showImage: showImage ?? this.showImage,
  );

  @override
  List<Object?> get props => [
    recipes?.map((recipe) => recipe.toFirestore()).toList(),
    filter,
    showImage,
  ];
}

/// The Recipes screen (Swift `RecipesPresenter`, with the
/// `RecipeListBuilderPresenter` it embeds): the user's recipes, to open or
/// add to. A recipe waiting on an Undo in `pendingDeletes` is left out.
class RecipesCubit extends Cubit<RecipesState> {
  new({
    required String uid,
    required FoodRepository foods,
    required NutritionRepository nutrition,
    required this._analytics,
    PendingDeletes? pendingDeletes,
  }) : super(const RecipesState()) {
    _analytics.appear('RecipesView');
    _subscriptions = [
      foods.watchRecipes(uid).listen((recipes) {
        _stored = recipes;
        _show();
      }, onError: (Object _) => emit(state.copyWith(recipes: const []))),
      if (pendingDeletes != null)
        pendingDeletes.watch().listen((keys) {
          _hidden = keys;
          _show();
        }),
      nutrition
          .watchFoodLogSettings(uid)
          .listen(
            (settings) =>
                emit(state.copyWith(showImage: settings.showFoodImageInLogger)),
            onError: (Object _) {},
          ),
    ];
  }

  final AnalyticsRepository _analytics;
  late final List<StreamSubscription<Object?>> _subscriptions;

  /// The recipes as stored, null until they arrive, and the ones waiting on
  /// an Undo, left out.
  List<RecipeTemplateModel>? _stored;
  Set<String> _hidden = const {};

  void _show() {
    final stored = _stored;
    if (stored == null) return;
    emit(
      state.copyWith(
        recipes: stored.hide(_hidden, (r) => PendingKeys.recipe(r.recipeId)),
      ),
    );
  }

  /// The filter as typed.
  void filterChanged(String filter) => emit(state.copyWith(filter: filter));

  @override
  Future<void> close() async {
    _analytics.disappear('RecipesView');
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}
