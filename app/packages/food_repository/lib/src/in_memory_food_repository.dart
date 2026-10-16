import 'dart:async';

import 'package:compound_models/compound_models.dart';
import 'package:food_repository/src/food_repository.dart';

/// [FoodRepository] in memory, for the staging flavor and tests. Seed it
/// with `sampleFoods`.
///
/// Saves behave as Firestore's do: they merge over the stored food field
/// by field, nested maps such as `nutrients` included, refuse a food with
/// no author, and every watcher sees the change.
class InMemoryFoodRepository implements FoodRepository {
  /// Creates an [InMemoryFoodRepository] holding `foods`, each stored under
  /// its author.
  new({List<FoodModel> foods = const []}) {
    for (final food in foods) {
      _foods[(requireAuthor(food), food.ingredientId)] = food;
    }
  }

  final _foods = <(String, String), FoodModel>{};
  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<List<FoodModel>> watchFoods(String uid) => Stream.multi((listener) {
    List<FoodModel> read() => [
      for (final MapEntry(:key, :value) in _foods.entries)
        if (key.$1 == uid) value,
    ];
    listener.add(read());
    final subscription = _changes.stream.listen((_) => listener.add(read()));
    // Not `subscription.cancel` itself: `first` would wait on the Future
    // that returns, which never completes under a widget test's fake clock.
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
