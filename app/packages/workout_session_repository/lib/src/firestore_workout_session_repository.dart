import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:workout_session_repository/src/workout_session_repository.dart';

/// Called with a document's path when it cannot be decoded and is skipped.
typedef SessionDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// [WorkoutSessionRepository] on Cloud Firestore.
///
/// A document that does not decode is skipped and reported to
/// `onDecodeError`, as the Swift app's sync engine skips it, so one bad
/// session never empties the list.
///
/// A write completes once Firestore has it locally, online or not
/// ([writeLocally]).
class FirestoreWorkoutSessionRepository implements WorkoutSessionRepository {
  /// Creates a [FirestoreWorkoutSessionRepository] reading `firestore`.
  /// Decode failures go to [onDecodeError], or to `dart:developer`'s log
  /// when it is null, and writes the server refuses go to `onWriteError`.
  new({
    required this._firestore,
    SessionDecodeErrorHandler? onDecodeError,
    this._onWriteError = logWriteError,
  }) : _onDecodeError = onDecodeError ?? _log;

  final FirebaseFirestore _firestore;
  final SessionDecodeErrorHandler _onDecodeError;
  final WriteErrorReporter _onWriteError;

  CollectionReference<Map<String, dynamic>> _sessions(String uid) =>
      _firestore.collection('users').doc(uid).collection('workout_sessions');

  @override
  Stream<List<WorkoutSessionModel>> watchSessions(String uid) =>
      _sessions(uid)
          .where(WorkoutSessionModelKeys.authorId, isEqualTo: uid)
          .snapshots()
          .map(
            (snapshot) => [
              for (final document in snapshot.docs)
                ?_decode(document.reference.path, document.data()),
            ],
          );

  @override
  Future<WorkoutSessionModel?> session(String uid, String id) async {
    final document = await _sessions(uid).doc(id).get();
    final data = document.data();
    return data == null ? null : _decode(document.reference.path, data);
  }

  @override
  Future<void> saveSession(String uid, WorkoutSessionModel session) {
    final document = _sessions(uid).doc(session.id);
    return writeLocally(
      document.path,
      () => document.set(
        _toFirestore(session.toFirestore()),
        SetOptions(merge: true),
      ),
      _onWriteError,
    );
  }

  /// An `update`: the server refuses a missing session with `not-found`,
  /// which reaches `onWriteError`. After [saveSession] the session is in the
  /// local cache, and Firestore sends writes in order, so it never is.
  @override
  Future<void> updateWeekStreakCount(String uid, String sessionId, int weeks) {
    final document = _sessions(uid).doc(sessionId);
    return writeLocally(
      document.path,
      () => document.update({WorkoutSessionModelKeys.weekStreakCount: weeks}),
      _onWriteError,
    );
  }

  /// An `update`, as [updateWeekStreakCount] is.
  @override
  Future<void> updateStravaActivityId(
    String uid,
    String sessionId,
    int activityId,
  ) {
    final document = _sessions(uid).doc(sessionId);
    return writeLocally(
      document.path,
      () => document.update({
        WorkoutSessionModelKeys.stravaActivityId: activityId,
      }),
      _onWriteError,
    );
  }

  WorkoutSessionModel? _decode(String path, Map<String, Object?> data) {
    try {
      return WorkoutSessionModel.fromFirestore(_fromFirestore(data));
    } on Object catch (error, stackTrace) {
      _onDecodeError(path, error, stackTrace);
      return null;
    }
  }

  static void _log(String path, Object error, StackTrace stackTrace) =>
      developer.log(
        'Skipped $path: it does not decode',
        name: 'workout_session_repository',
        error: error,
        stackTrace: stackTrace,
      );
}

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

Map<String, Object?> _toFirestore(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _stored(value)));

Object? _stored(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => _toFirestore(map),
  final List<Object?> list => list.map(_stored).toList(),
  _ => value,
};
