import 'package:compound_models/compound_models.dart';

/// The signed-in user's food library (Swift `FoodManager`).
abstract interface class FoodRepository {
  /// Every food at `users/{uid}/foods`, as the Swift app's listener reads
  /// them. Re-emitted on every change.
  Stream<List<FoodModel>> watchFoods(String uid);

  /// Saves [food] to `users/{food.authorId}/foods/{food.ingredientId}`,
  /// merged over anything there, as `FoodManager.saveFood` does
  /// (`saveDocument` is `setData(merge: true)`).
  ///
  /// Throws an [ArgumentError], writing nothing, when [food] has no author
  /// (the rules refuse it) or no id.
  Future<void> saveFood(FoodModel food);

  /// Deletes `users/{uid}/foods/{ingredientId}`, as `FoodManager.deleteFood`
  /// does (`deleteDocument` is a plain `delete()`). Deleting a food that is
  /// not there is not an error, as in Firestore.
  Future<void> deleteFood(String uid, String ingredientId);

  /// Every recipe at `users/{uid}/recipe_templates`, as Swift's
  /// `RecipeTemplateManager` listens to them. Re-emitted on every change.
  Stream<List<RecipeTemplateModel>> watchRecipes(String uid);

  /// Saves [recipe] to `users/{recipe.authorId}/recipe_templates/
  /// {recipe.recipeId}`, merged over anything there, as
  /// `RecipeTemplateManager.saveRecipeTemplate` does.
  ///
  /// Throws an [ArgumentError], writing nothing, when [recipe] has no author
  /// (the rules refuse it) or no id.
  Future<void> saveRecipe(RecipeTemplateModel recipe);

  /// Deletes `users/{uid}/recipe_templates/{recipeId}`, as
  /// `RecipeTemplateManager.deleteRecipeTemplate` does. Deleting a recipe
  /// that is not there is not an error.
  Future<void> deleteRecipe(String uid, String recipeId);
}

/// The user id [food] is saved under: its author, which must be set.
String requireAuthor(FoodModel food) {
  final authorId = food.authorId;
  if (authorId == null || authorId.isEmpty) {
    throw ArgumentError.value(food.authorId, 'food.authorId', 'is required');
  }
  if (food.ingredientId.isEmpty) {
    throw ArgumentError.value(
      food.ingredientId,
      'food.ingredientId',
      'is empty',
    );
  }
  return authorId;
}

/// The user id [recipe] is saved under: its author, which must be set.
String requireRecipeAuthor(RecipeTemplateModel recipe) {
  final authorId = recipe.authorId;
  if (authorId == null || authorId.isEmpty) {
    throw ArgumentError.value(
      recipe.authorId,
      'recipe.authorId',
      'is required',
    );
  }
  if (recipe.recipeId.isEmpty) {
    throw ArgumentError.value(recipe.recipeId, 'recipe.recipeId', 'is empty');
  }
  return authorId;
}

/// [food] owned by [uid], as Swift's `withAuthorId`.
FoodModel withAuthor(FoodModel food, String uid) => FoodModel.fromFirestore({
  ...food.toFirestore(),
  FoodModelKeys.authorId: uid,
});
