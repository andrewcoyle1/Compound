import 'dart:async';

import 'package:compound_models/compound_models.dart';
import 'package:food_repository/src/food_repository.dart';

/// [FoodRepository] in memory, for the staging flavor and tests. Seed it
/// with `sampleFoods` and `sampleRecipes`.
///
/// Saves behave as Firestore's do: they merge over the stored food field
/// by field, nested maps such as `nutrients` included, refuse a food with
/// no author, and every watcher sees the change.
class InMemoryFoodRepository implements FoodRepository {
  /// Creates an [InMemoryFoodRepository] holding `foods`, each stored under
  /// its author.
  new({
    List<FoodModel> foods = const [],
    List<RecipeTemplateModel> recipes = const [],
  }) {
    for (final food in foods) {
      _foods[(requireAuthor(food), food.ingredientId)] = food;
    }
    for (final recipe in recipes) {
      _recipes[(requireRecipeAuthor(recipe), recipe.recipeId)] = recipe;
    }
  }

  final _foods = <(String, String), FoodModel>{};
  final _recipes = <(String, String), RecipeTemplateModel>{};
  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<List<FoodModel>> watchFoods(String uid) => _watch(_foods, uid);

  @override
  Stream<List<RecipeTemplateModel>> watchRecipes(String uid) =>
      _watch(_recipes, uid);

  Stream<List<T>> _watch<T>(Map<(String, String), T> store, String uid) =>
      Stream.multi((listener) {
        List<T> read() => [
          for (final MapEntry(:key, :value) in store.entries)
            if (key.$1 == uid) value,
        ];
        listener.add(read());
        final subscription = _changes.stream.listen(
          (_) => listener.add(read()),
        );
        // Not `subscription.cancel` itself: `first` would wait on the
        // Future that returns, which never completes under a widget test's
        // fake clock.
        listener.onCancel = () => unawaited(subscription.cancel());
      });

  @override
  Future<void> saveFood(FoodModel food) async {
    final key = (requireAuthor(food), food.ingredientId);
    _foods[key] = FoodModel.fromFirestore(
      _merged(_foods[key]?.toFirestore() ?? const {}, food.toFirestore()),
    );
    _changes.add(null);
  }

  @override
  Future<void> deleteFood(String uid, String ingredientId) async {
    if (_foods.remove((uid, ingredientId)) != null) _changes.add(null);
  }

  @override
  Future<void> saveRecipe(RecipeTemplateModel recipe) async {
    final key = (requireRecipeAuthor(recipe), recipe.recipeId);
    _recipes[key] = RecipeTemplateModel.fromFirestore(
      _merged(_recipes[key]?.toFirestore() ?? const {}, recipe.toFirestore()),
    );
    _changes.add(null);
  }

  @override
  Future<void> deleteRecipe(String uid, String recipeId) async {
    if (_recipes.remove((uid, recipeId)) != null) _changes.add(null);
  }
}

/// [update] merged over [stored] as Firestore's `set(merge: true)` merges:
/// a map merges key by key, anything else replaces.
Map<String, Object?> _merged(
  Map<String, Object?> stored,
  Map<String, Object?> update,
) => {
  ...stored,
  for (final MapEntry(:key, :value) in update.entries)
    key: switch ((stored[key], value)) {
      (final Map<String, Object?> old, final Map<String, Object?> new_) =>
        _merged(old, new_),
      _ => value,
    },
};
