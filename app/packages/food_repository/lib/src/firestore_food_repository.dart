import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:food_repository/src/food_repository.dart';

/// Called with a document's path when it cannot be decoded and is skipped.
typedef FoodDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// [FoodRepository] on Cloud Firestore: foods and recipes.
///
/// A document that does not decode is skipped and reported to
/// `onDecodeError`, as the Swift app's sync engine skips it. Writes go
/// through `FoodModel.toFirestore`, dates stored as Timestamps, and merge
/// (`docs/specs/flutter/firestore-contract.md`, Policy). A write completes
/// once Firestore has it locally, online or not ([writeLocally]).
class FirestoreFoodRepository implements FoodRepository {
  /// Creates a [FirestoreFoodRepository] reading `firestore`. Decode
  /// failures go to `onDecodeError`, or to `dart:developer`'s log when it
  /// is null, and writes the server refuses go to `onWriteError`.
  new({
    required this._firestore,
    FoodDecodeErrorHandler? onDecodeError,
    this._onWriteError = logWriteError,
  }) : _onDecodeError = onDecodeError ?? _log;

  final FirebaseFirestore _firestore;
  final FoodDecodeErrorHandler _onDecodeError;
  final WriteErrorReporter _onWriteError;

  CollectionReference<Map<String, dynamic>> _foods(String uid) =>
      _firestore.collection('users').doc(uid).collection('foods');

  @override
  Stream<List<FoodModel>> watchFoods(String uid) => _foods(uid).snapshots().map(
    (snapshot) => [
      for (final document in snapshot.docs)
        ?_decode(
          document.reference.path,
          document.data(),
          FoodModel.fromFirestore,
        ),
    ],
  );

  @override
  Future<void> saveFood(FoodModel food) {
    final document = _foods(requireAuthor(food)).doc(food.ingredientId);
    return writeLocally(
      document.path,
      () => document.set(
        _toFirestore(food.toFirestore()),
        SetOptions(merge: true),
      ),
      _onWriteError,
    );
  }

  @override
  Future<void> deleteFood(String uid, String ingredientId) {
    final document = _foods(uid).doc(ingredientId);
    return writeLocally(document.path, document.delete, _onWriteError);
  }

  CollectionReference<Map<String, dynamic>> _recipes(String uid) =>
      _firestore.collection('users').doc(uid).collection('recipe_templates');

  @override
  Stream<List<RecipeTemplateModel>> watchRecipes(String uid) =>
      _recipes(uid).snapshots().map(
        (snapshot) => [
          for (final document in snapshot.docs)
            ?_decode(
              document.reference.path,
              document.data(),
              RecipeTemplateModel.fromFirestore,
            ),
        ],
      );

  @override
  Future<void> saveRecipe(RecipeTemplateModel recipe) {
    final document = _recipes(requireRecipeAuthor(recipe)).doc(recipe.recipeId);
    return writeLocally(
      document.path,
      () => document.set(
        _toFirestore(recipe.toFirestore()),
        SetOptions(merge: true),
      ),
      _onWriteError,
    );
  }

  @override
  Future<void> deleteRecipe(String uid, String recipeId) {
    final document = _recipes(uid).doc(recipeId);
    return writeLocally(document.path, document.delete, _onWriteError);
  }

  T? _decode<T>(
    String path,
    Map<String, Object?> data,
    T Function(Map<String, Object?>) fromFirestore,
  ) {
    try {
      return fromFirestore(_fromFirestore(data));
    } on Object catch (error, stackTrace) {
      _onDecodeError(path, error, stackTrace);
      return null;
    }
  }

  static void _log(String path, Object error, StackTrace stackTrace) =>
      developer.log(
        'Skipped $path: it does not decode',
        name: 'food_repository',
        error: error,
        stackTrace: stackTrace,
      );
}

// ponytail: the same converter as nutrition_repository's; share it once the
// copies start to differ.
/// Firestore's values to the models' at any depth: a [Timestamp] becomes a
/// UTC [DateTime].
Map<String, Object?> _fromFirestore(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _value(value)));

Object? _value(Object? value) => switch (value) {
  final Timestamp timestamp => timestamp.toDate().toUtc(),
  final Map<String, Object?> map => _fromFirestore(map),
  final List<Object?> list => list.map(_value).toList(),
  _ => value,
};

/// The models' values to Firestore's at any depth: a [DateTime] becomes a
/// [Timestamp], as Swift's encoder stores a `Date`.
Map<String, Object?> _toFirestore(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _stored(value)));

Object? _stored(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => _toFirestore(map),
  final List<Object?> list => list.map(_stored).toList(),
  _ => value,
};
