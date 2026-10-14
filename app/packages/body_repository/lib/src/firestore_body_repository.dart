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
class FirestoreBodyRepository implements BodyRepository {
  /// Creates a [FirestoreBodyRepository] reading `firestore`. Decode
  /// failures go to [onDecodeError], or to `dart:developer`'s log when it
  /// is null.
  new({required this._firestore, BodyDecodeErrorHandler? onDecodeError})
    : _onDecodeError = onDecodeError ?? _log;

  final FirebaseFirestore _firestore;
  final BodyDecodeErrorHandler _onDecodeError;

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
  Stream<WeightGoal?> watchCurrentGoal(String uid, {String? currentGoalId}) =>
      _user(uid)
          .collection('goals')
          .doc(currentGoalDocumentId(uid, currentGoalId))
          .snapshots()
          .map(
            (document) => _decodeDocument(document, WeightGoal.fromFirestore),
          );

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
