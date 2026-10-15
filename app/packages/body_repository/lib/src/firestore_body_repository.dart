import 'dart:developer' as developer;

import 'package:body_repository/src/body_repository.dart';
import 'package:body_repository/src/body_rules.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';

/// Called with a document's path when it cannot be decoded and is skipped.
typedef BodyDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// [BodyRepository] on Cloud Firestore.
///
/// A document that does not decode is skipped and reported to
/// `onDecodeError`, as the Swift app's sync engine skips it, so one bad
/// weigh-in never empties the chart.
///
/// Writes go through the models' `toFirestore`, with dates stored as
/// Timestamps, and whole documents are merged
/// (`docs/specs/flutter/firestore-contract.md`, Policy). A write completes
/// once Firestore has it locally, online or not ([writeLocally]).
class FirestoreBodyRepository implements BodyRepository {
  /// Creates a [FirestoreBodyRepository] reading `firestore`. Decode
  /// failures go to [onDecodeError], or to `dart:developer`'s log when it
  /// is null, and writes the server refuses go to `onWriteError`.
  new({
    required this._firestore,
    BodyDecodeErrorHandler? onDecodeError,
    this._onWriteError = logWriteError,
  }) : _onDecodeError = onDecodeError ?? _log;

  final FirebaseFirestore _firestore;
  final BodyDecodeErrorHandler _onDecodeError;
  final WriteErrorReporter _onWriteError;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Stream<List<BodyMeasurementEntry>> watchMeasurements(String uid) =>
      _user(uid)
          .collection('body_measurements')
          .where(BodyMeasurementEntryKeys.authorId, isEqualTo: uid)
          .snapshots()
          .map(
            (snapshot) => liveOldestFirst(
              _decodeAll(snapshot, BodyMeasurementEntry.fromFirestore),
              date: (entry) => entry.date,
              deletedAt: (entry) => entry.deletedAt,
            ),
          );

  @override
  Stream<List<StepsModel>> watchSteps(String uid) =>
      _user(uid)
          .collection('steps')
          .snapshots()
          .map(
            (snapshot) => liveOldestFirst(
              _decodeAll(
                snapshot,
                StepsModel.fromFirestore,
              ).where((steps) => steps.authorId == uid),
              date: (steps) => steps.date,
              deletedAt: (steps) => steps.deletedAt,
            ),
          );

  @override
  Stream<AnalyticsSettings> watchAnalyticsSettings(String uid) =>
      _user(uid)
          .collection('analytics_settings')
          .doc('analytics_settings')
          .snapshots()
          .map(
            (document) =>
                _decodeDocument(document, AnalyticsSettings.fromFirestore) ??
                AnalyticsSettings(authorId: uid),
          );

  @override
  Future<void> saveAnalyticsSettings(AnalyticsSettings settings) => _merge(
    _user(settings.authorId)
        .collection('analytics_settings')
        .doc('analytics_settings'),
    settings.toFirestore(),
  );

  @override
  Stream<WeightGoal?> watchCurrentGoal(String uid, {String? currentGoalId}) =>
      _goal(uid, currentGoalDocumentId(uid, currentGoalId)).snapshots().map(
        (document) => _decodeDocument(document, WeightGoal.fromFirestore),
      );

  @override
  Future<void> saveMeasurement(BodyMeasurementEntry entry) => _merge(
    _user(entry.authorId).collection('body_measurements').doc(entry.id),
    entry.toFirestore(),
  );

  @override
  Future<void> clearMeasurementFields(
    String uid,
    String entryId,
    Set<String> fields,
  ) {
    checkClearable(fields);
    final document = _user(uid).collection('body_measurements').doc(entryId);
    return writeLocally(
      document.path,
      () => document.update({
        for (final field in fields) field: FieldValue.delete(),
      }),
      _onWriteError,
    );
  }

  @override
  Future<void> saveSteps(StepsModel steps) => _merge(
    _user(steps.authorId).collection('steps').doc(steps.id),
    steps.toFirestore(),
  );

  @override
  Future<void> saveGoal(WeightGoal goal) =>
      _merge(_goal(goal.userId, goal.goalId), goal.toFirestore());

  /// An `update`: the server refuses a missing goal with `not-found`, which
  /// reaches `onWriteError`.
  @override
  Future<void> abandonGoal(String uid, String goalId) {
    final document = _goal(uid, goalId);
    return writeLocally(
      document.path,
      () =>
          document.update({WeightGoalKeys.status: GoalStatus.abandoned.value}),
      _onWriteError,
    );
  }

  Future<void> _merge(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, Object?> data,
  ) => writeLocally(
    document.path,
    () => document.set(_toFirestore(data), SetOptions(merge: true)),
    _onWriteError,
  );

  DocumentReference<Map<String, dynamic>> _goal(String uid, String goalId) =>
      _user(uid).collection('goals').doc(goalId);

  List<T> _decodeAll<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    T Function(Map<String, Object?>) decode,
  ) => [
    for (final document in snapshot.docs)
      ?_decode(document.reference.path, document.data(), decode),
  ];

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
        name: 'body_repository',
        error: error,
        stackTrace: stackTrace,
      );
}

// ponytail: the third copy of this converter (workout_session_repository
// and nutrition_repository have it); move it into a shared package when a
// fourth repository needs it.
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
