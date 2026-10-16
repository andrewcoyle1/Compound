import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/nutrition/recipes/logic/recipe_logic.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';

/// Where the create flow's save is.
enum CreateRecipeStatus {
  /// Being filled in.
  editing,

  /// Saving.
  saving,

  /// Saved; the flow closes.
  created,

  /// The save failed; the form stays open.
  failed,
}

/// The recipe being created, across its two steps.
final class const CreateRecipeState({
  final String name = '',
  final double? servings,
  final double? totalWeight,
  final List<RecipeIngredientModel> ingredients = const [],

  /// The method, a row per step, starting with one empty row.
  final List<String> steps = const [''],
  final double? prepTime,
  final double? cookTime,
  final String sourceUrl = '',
  final CreateRecipeStatus status = CreateRecipeStatus.editing,
}) extends Equatable {
  /// Both required fields are filled in, so Next is on
  /// (`CreateRecipePresenter.canSave`).
  bool get canContinue => name.trim().isNotEmpty && (servings ?? 0) > 0;

  /// Anything entered that closing would throw away
  /// (`CreateRecipePresenter.hasUnsavedChanges`).
  bool get hasUnsavedChanges =>
      name.trim().isNotEmpty ||
      servings != null ||
      totalWeight != null ||
      ingredients.isNotEmpty;

  /// Grams of the weighed ingredients, or null with none.
  double? get ingredientsWeight => weighedTotal(ingredients);

  /// Whether a save is under way, so a second tap cannot save twice.
  bool get isSaving => status == CreateRecipeStatus.saving;

  CreateRecipeState copyWith({
    String? name,
    double? Function()? servings,
    double? Function()? totalWeight,
    List<RecipeIngredientModel>? ingredients,
    List<String>? steps,
    double? Function()? prepTime,
    double? Function()? cookTime,
    String? sourceUrl,
    CreateRecipeStatus? status,
  }) => CreateRecipeState(
    name: name ?? this.name,
    servings: servings == null ? this.servings : servings(),
    totalWeight: totalWeight == null ? this.totalWeight : totalWeight(),
    ingredients: ingredients ?? this.ingredients,
    steps: steps ?? this.steps,
    prepTime: prepTime == null ? this.prepTime : prepTime(),
    cookTime: cookTime == null ? this.cookTime : cookTime(),
    sourceUrl: sourceUrl ?? this.sourceUrl,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [
    name,
    servings,
    totalWeight,
    [for (final ingredient in ingredients) ingredient.toFirestore()],
    steps,
    prepTime,
    cookTime,
    sourceUrl,
    status,
  ];
}

/// Creating a recipe (Swift `CreateRecipePresenter` and
/// `RecipePreparationPresenter`): its name, servings, weight and
/// ingredients, then its timing, link and method, saved to the user's
/// library.
class CreateRecipeCubit extends Cubit<CreateRecipeState> {
  /// `uid` is the signed-in user, who authors the recipe; without one
  /// nothing is saved.
  new({
    required this._uid,
    required this._foods,
    required this._analytics,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(const CreateRecipeState());

  final String? _uid;
  final FoodRepository _foods;
  final AnalyticsRepository _analytics;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Records one of the flow's screens appearing: `CreateRecipeView`,
  /// `RecipeIngredientAmountView` or `RecipePreparationView`.
  void appeared(String screen) => _analytics.appear(screen);

  /// Records one of the flow's screens going.
  void disappeared(String screen) => _analytics.disappear(screen);

  void nameChanged(String name) => emit(state.copyWith(name: name));

  void servingsChanged(double? servings) =>
      emit(state.copyWith(servings: () => servings));

  void totalWeightChanged(double? weight) =>
      emit(state.copyWith(totalWeight: () => weight));

  /// An ingredient confirmed in the picker: it joins the list, or replaces
  /// the one made from the same food.
  void ingredientConfirmed(RecipeIngredientModel ingredient) => emit(
    state.copyWith(ingredients: withIngredient(state.ingredients, ingredient)),
  );

  /// The list's swipe to delete (`CreateRecipePresenter
  /// .onDeleteIngredients`).
  void ingredientRemoved(int index) => emit(
    state.copyWith(ingredients: [...state.ingredients]..removeAt(index)),
  );

  /// The amount typed in the list's row; blank reads as 0, as Swift's field
  /// leaves the amount it cannot parse.
  void ingredientAmountChanged(int index, double? amount) =>
      _replace(index, amount: amount ?? 0);

  /// The unit picked in the list's row.
  void ingredientUnitChanged(int index, IngredientAmountUnit unit) =>
      _replace(index, unit: unit);

  void _replace(int index, {double? amount, IngredientAmountUnit? unit}) {
    final old = state.ingredients[index];
    emit(
      state.copyWith(
        ingredients: [...state.ingredients]
          ..[index] = RecipeIngredientModel(
            ingredient: old.ingredient,
            amount: amount ?? old.amount,
            unit: unit ?? old.unit,
          ),
      ),
    );
  }

  void stepAdded() => emit(state.copyWith(steps: [...state.steps, '']));

  void stepChanged(int index, String text) =>
      emit(state.copyWith(steps: [...state.steps]..[index] = text));

  void stepRemoved(int index) =>
      emit(state.copyWith(steps: [...state.steps]..removeAt(index)));

  /// A step dragged from [from] to land at [to]
  /// (`RecipePreparationPresenter.onMoveStep`).
  void stepMoved(int from, int to) {
    final steps = [...state.steps];
    steps.insert(to, steps.removeAt(from));
    emit(state.copyWith(steps: steps));
  }

  void prepTimeChanged(double? minutes) =>
      emit(state.copyWith(prepTime: () => minutes));

  void cookTimeChanged(double? minutes) =>
      emit(state.copyWith(cookTime: () => minutes));

  void sourceUrlChanged(String url) => emit(state.copyWith(sourceUrl: url));

  /// The recipe Create saves (`RecipePreparationPresenter.buildRecipe`):
  /// the name capitalised, blank steps and an empty link left out, and a
  /// total weight of 0 stored as absent. Null signed out or before the
  /// first step is complete.
  RecipeTemplateModel? buildRecipe() {
    final uid = _uid;
    final servings = state.servings;
    if (uid == null || servings == null || !state.canContinue) return null;
    final now = _now();
    final weight = state.totalWeight ?? 0;
    return RecipeTemplateModel(
      recipeId: _newId(),
      authorId: uid,
      name: capitalizedName(state.name),
      dateCreated: now,
      dateModified: now,
      ingredients: state.ingredients,
      clickCount: 0,
      bookmarkCount: 0,
      favouriteCount: 0,
      servingQuantity: servings,
      totalWeight: weight > 0 ? weight : null,
      preparationSteps: [
        for (final step in state.steps)
          if (step.trim().isNotEmpty) step,
      ],
      prepTimeMins: state.prepTime,
      cookTimeMins: state.cookTime,
      sourceUrl: state.sourceUrl.isEmpty ? null : state.sourceUrl,
    );
  }

  /// Create (`RecipePreparationPresenter.onCreatePressed`): saves the
  /// recipe between `RecipePreparationView_CreateRecipe_Start` and
  /// `_Success` or a severe `_Fail`. Does nothing while saving or without
  /// a recipe to save.
  Future<void> create() async {
    final recipe = buildRecipe();
    if (state.isSaving || recipe == null) return;
    emit(state.copyWith(status: CreateRecipeStatus.saving));
    _analytics.analytic('RecipePreparationView_CreateRecipe_Start');
    try {
      await _foods.saveRecipe(recipe);
      _analytics.analytic('RecipePreparationView_CreateRecipe_Success');
      emit(state.copyWith(status: CreateRecipeStatus.created));
    } on Object catch (error) {
      _analytics.severe('RecipePreparationView_CreateRecipe_Fail', error);
      emit(state.copyWith(status: CreateRecipeStatus.failed));
    }
  }
}
