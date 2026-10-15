import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:nutrition_repository/src/meal_days.dart';
import 'package:nutrition_repository/src/nutrition_repository.dart';

/// Called with a document's path when it cannot be decoded and is skipped.
typedef NutritionDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// [NutritionRepository] on Cloud Firestore.
///
/// A document that does not decode is skipped and reported to
/// `onDecodeError`, as the Swift app's sync engine skips it, so one bad
/// meal never empties the day.
///
/// Writes go through the models' `toFirestore`, with dates stored as
/// Timestamps, and whole documents are merged
/// (`docs/specs/flutter/firestore-contract.md`, Policy). A write completes
/// once Firestore has it locally, online or not ([writeLocally]).
class FirestoreNutritionRepository implements NutritionRepository {
  /// Creates a [FirestoreNutritionRepository] reading `firestore`. Decode
  /// failures go to [onDecodeError], or to `dart:developer`'s log when it
  /// is null, and writes the server refuses go to `onWriteError`.
  new({
    required this._firestore,
    NutritionDecodeErrorHandler? onDecodeError,
    this._onWriteError = logWriteError,
  }) : _onDecodeError = onDecodeError ?? _log;

  final FirebaseFirestore _firestore;
  final NutritionDecodeErrorHandler _onDecodeError;
  final WriteErrorReporter _onWriteError;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Stream<List<MealLogModel>> watchMeals(
    String uid, {
    bool includeHiddenHealthImports = false,
  }) =>
      _user(uid)
          .collection('meal_logs')
          .where(MealLogModelKeys.authorId, isEqualTo: uid)
          .snapshots()
          .map((snapshot) {
            final meals = [
              for (final document in snapshot.docs)
                ?_decode(
                  document.reference.path,
                  document.data(),
                  MealLogModel.fromFirestore,
                ),
            ];
            return includeHiddenHealthImports
                ? meals
                : withoutDuplicateHealthImports(meals);
          });

  @override
  Stream<DietPlan?> watchDietPlan(String uid) => _firestore
      .collection('diet_plans')
      .doc(uid)
      .snapshots()
      .map((document) => _decodeDocument(document, DietPlan.fromFirestore));

  @override
  Stream<FoodLogSettings> watchFoodLogSettings(String uid) =>
      _user(uid)
          .collection('food_log_settings')
          .doc('food_log_settings')
          .snapshots()
          .map(
            (document) =>
                _decodeDocument(document, FoodLogSettings.fromFirestore) ??
                FoodLogSettings(authorId: uid),
          );

  @override
  Future<void> saveMeal(MealLogModel meal) => _merge(
    _user(meal.authorId).collection('meal_logs').doc(meal.mealId),
    meal.toFirestore(),
  );

  @override
  Future<void> deleteMeal(String uid, String mealId) {
    final document = _user(uid).collection('meal_logs').doc(mealId);
    return writeLocally(document.path, document.delete, _onWriteError);
  }

  @override
  Future<void> saveDietPlan(DietPlan plan) => _merge(
    _firestore.collection('diet_plans').doc(plan.planId),
    plan.toFirestore(),
  );

  Future<void> _merge(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, Object?> data,
  ) => writeLocally(
    document.path,
    () => document.set(_toFirestore(data), SetOptions(merge: true)),
    _onWriteError,
  );

  T? _decodeDocument<T>(
    DocumentSnapshot<Map<String, dynamic>> document,
    T Function(Map<String, Object?>) decode,
  ) {
    final data = document.data();
    return data == null ? null : _decode(document.reference.path, data, decode);
  }

  T? _decode<T>(
    String path,
    Map<String, Object?> data,
    T Function(Map<String, Object?>) decode,
  ) {
    try {
      return decode(_fromFirestore(data));
    } on Object catch (error, stackTrace) {
      _onDecodeError(path, error, stackTrace);
      return null;
    }
  }

  static void _log(String path, Object error, StackTrace stackTrace) =>
      developer.log(
        'Skipped $path: it does not decode',
        name: 'nutrition_repository',
        error: error,
        stackTrace: stackTrace,
      );
}

// ponytail: same converter as workout_session_repository's; share it once a
// third repository needs it.
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
