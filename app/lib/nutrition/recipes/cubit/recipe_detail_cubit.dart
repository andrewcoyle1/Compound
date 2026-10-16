import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show roundedAmount;
import 'package:compound/nutrition/recipes/logic/recipe_logic.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart' show FoodLogSettingsKeys;
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Where deleting the recipe is.
enum RecipeDetailDeleteStatus {
  /// Not deleting.
  idle,

  /// Deleting.
  deleting,

  /// Deleted; the screen closes.
  deleted,
}

/// One recipe from the library.
final class const RecipeDetailState({
  /// The recipe; null until the library arrives, or once it has gone.
  final RecipeTemplateModel? recipe,

  /// Whether the library has arrived.
  final bool loaded = false,

  /// The food log settings, which hold the favourites; null until read.
  final FoodLogSettings? settings,

  /// Whether the recipe is a favourite, as last chosen here or read.
  final bool isFavourited = false,

  /// The servings the stepper is set to, or null while it is still on the
  /// recipe as written.
  final double? servingsOverride,

  final RecipeDetailDeleteStatus deleteStatus = RecipeDetailDeleteStatus.idle,

  /// How many favourite changes have failed, so each says so.
  final int favouriteFailures = 0,

  /// How many deletes have failed, so each says so.
  final int deleteFailures = 0,
}) extends Equatable {
  /// The servings shown (`RecipeDetailPresenter.servings`).
  double get servings => servingsOverride ?? recipe?.servingDivisor ?? 1;

  /// The whole of what the stepper makes, every serving
  /// (`RecipeDetailPresenter.scaledNutrients`).
  NutrientMap get scaledNutrients =>
      recipe?.nutrientsFor(servings) ?? const NutrientMap();

  /// [ingredient]'s amount for the servings chosen, to one decimal place
  /// (`RecipeDetailPresenter.scaledAmount`).
  double scaledAmount(RecipeIngredientModel ingredient) {
    final factor = recipe?.factorFor(servings) ?? 0;
    return roundedAmount(ingredient.amount * factor);
  }

  RecipeDetailState copyWith({
    RecipeTemplateModel? Function()? recipe,
    bool? loaded,
    FoodLogSettings? settings,
    bool? isFavourited,
    double? servingsOverride,
    RecipeDetailDeleteStatus? deleteStatus,
    int? favouriteFailures,
    int? deleteFailures,
  }) => RecipeDetailState(
    recipe: recipe == null ? this.recipe : recipe(),
    loaded: loaded ?? this.loaded,
    settings: settings ?? this.settings,
    isFavourited: isFavourited ?? this.isFavourited,
    servingsOverride: servingsOverride ?? this.servingsOverride,
    deleteStatus: deleteStatus ?? this.deleteStatus,
    favouriteFailures: favouriteFailures ?? this.favouriteFailures,
    deleteFailures: deleteFailures ?? this.deleteFailures,
  );

  @override
  List<Object?> get props => [
    recipe?.toFirestore(),
    loaded,
    settings,
    isFavourited,
    servingsOverride,
    deleteStatus,
    favouriteFailures,
    deleteFailures,
  ];
}

/// A recipe's detail (Swift `RecipeDetailPresenter`): its servings, scaled
/// by a stepper, its ingredients, a favourite toggle stored on the food log
/// settings, Start, and Delete for its author.
class RecipeDetailCubit extends Cubit<RecipeDetailState> {
  new({
    required this._uid,
    required this._recipeId,
    required this._foods,
    required this._nutrition,
    required this._analytics,
  }) : super(const RecipeDetailState()) {
    _analytics.appear('RecipeDetailView');
    _subscriptions = [
      _foods
          .watchRecipes(_uid)
          .listen(
            (recipes) => emit(
              state.copyWith(
                recipe: () => recipes
                    .where((recipe) => recipe.recipeId == _recipeId)
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
                isFavourited: settings.favouriteRecipeIds.contains(_recipeId),
              ),
            ),
            onError: (Object _) {},
          ),
    ];
  }

  final String _uid;
  final String _recipeId;
  final FoodRepository _foods;
  final NutritionRepository _nutrition;
  final AnalyticsRepository _analytics;
  late final List<StreamSubscription<Object?>> _subscriptions;

  /// Only the recipe's author may delete it
  /// (`RecipeDetailPresenter.canDelete`).
  bool get canDelete {
    final author = state.recipe?.authorId;
    return author != null && author == _uid;
  }

  /// The stepper (`RecipeDetailPresenter.onServingsChanged`): kept between
  /// half a serving and a hundred.
  void servingsChanged(double servings) =>
      emit(state.copyWith(servingsOverride: clampedServings(servings)));

  /// The heart (`RecipeDetailPresenter.onFavouritePressed`): shown at once,
  /// saved to the latest settings, and put back if the save fails.
  Future<void> favouriteToggled() async {
    final settings = state.settings;
    if (settings == null) return;
    final favourite = !state.isFavourited;
    emit(state.copyWith(isFavourited: favourite));
    _analytics.analytic('RecipeDetailView_Favourite_Start');
    final ids = [
      for (final id in settings.favouriteRecipeIds)
        if (id != _recipeId) id,
      if (favourite) _recipeId,
    ];
    try {
      await _nutrition.saveFoodLogSettings(
        FoodLogSettings.fromFirestore({
          ...settings.toFirestore(),
          FoodLogSettingsKeys.favouriteRecipeIds: ids,
        }),
      );
      _analytics.analytic('RecipeDetailView_Favourite_Success');
    } on Object catch (error) {
      _analytics.severe('RecipeDetailView_Favourite_Fail', error);
      emit(
        state.copyWith(
          isFavourited: !favourite,
          favouriteFailures: state.favouriteFailures + 1,
        ),
      );
    }
  }

  /// Deletes the recipe, once confirmed (`RecipeDetailPresenter
  /// .deleteRecipe`).
  Future<void> deleteConfirmed() async {
    if (!canDelete || state.deleteStatus != RecipeDetailDeleteStatus.idle) {
      return;
    }
    emit(state.copyWith(deleteStatus: RecipeDetailDeleteStatus.deleting));
    _analytics.analytic('RecipeDetailView_Delete_Start');
    try {
      await _foods.deleteRecipe(_uid, _recipeId);
      _analytics.analytic('RecipeDetailView_Delete_Success');
      emit(state.copyWith(deleteStatus: RecipeDetailDeleteStatus.deleted));
    } on Object catch (error) {
      _analytics.severe('RecipeDetailView_Delete_Fail', error);
      emit(
        state.copyWith(
          deleteStatus: RecipeDetailDeleteStatus.idle,
          deleteFailures: state.deleteFailures + 1,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _analytics.disappear('RecipeDetailView');
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}
