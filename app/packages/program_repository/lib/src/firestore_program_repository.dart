import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:program_repository/src/program_repository.dart';

/// Called with a document's path when it cannot be decoded and is skipped.
typedef ProgramDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// [ProgramRepository] on Cloud Firestore.
///
/// A document that does not decode is skipped and reported to
/// `onDecodeError`, as the Swift app's sync engine skips it. Writes go
/// through the models' `toFirestore`, with dates stored as Timestamps, and
/// whole documents are merged (`docs/specs/flutter/firestore-contract.md`,
/// Policy). A write completes once Firestore has it locally, online or not
/// ([writeLocally]).
class FirestoreProgramRepository implements ProgramRepository {
  /// Creates a [FirestoreProgramRepository] on `firestore`. Decode failures
  /// go to [onDecodeError], or to `dart:developer`'s log when it is null,
  /// and writes the server refuses go to `onWriteError`.
  new({
    required this._firestore,
    ProgramDecodeErrorHandler? onDecodeError,
    this._onWriteError = logWriteError,
  }) : _onDecodeError = onDecodeError ?? _log;

  final FirebaseFirestore _firestore;
  final ProgramDecodeErrorHandler _onDecodeError;
  final WriteErrorReporter _onWriteError;

  CollectionReference<Map<String, dynamic>> _user(String uid, String name) =>
      _firestore.collection('users').doc(uid).collection(name);

  @override
  Stream<List<Mesocycle>> watchMesocycles(String uid) =>
      _watch(_user(uid, 'mesocycles'), Mesocycle.fromFirestore);

  @override
  Stream<List<Macrocycle>> watchMacrocycles(String uid) =>
      _watch(_user(uid, 'macrocycles'), Macrocycle.fromFirestore);

  @override
  Future<void> saveMesocycle(Mesocycle mesocycle) => _save(
    _user(mesocycle.authorId, 'mesocycles').doc(mesocycle.id),
    mesocycle.toFirestore(),
  );

  @override
  Future<void> saveMacrocycle(Macrocycle macrocycle) => _save(
    _user(macrocycle.authorId, 'macrocycles').doc(macrocycle.id),
    macrocycle.toFirestore(),
    deleting: [
      if (macrocycle.startMicrocycleIndex == null)
        MacrocycleKeys.startMicrocycleIndex,
    ],
  );

  @override
  Future<void> deleteMesocycle(String uid, String id) =>
      _delete(_user(uid, 'mesocycles').doc(id));

  @override
  Future<void> deleteMacrocycle(String uid, String id) =>
      _delete(_user(uid, 'macrocycles').doc(id));

  Future<void> _delete(DocumentReference<Map<String, dynamic>> document) =>
      writeLocally(document.path, document.delete, _onWriteError);

  Future<void> _save(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, Object?> data, {
    List<String> deleting = const [],
  }) => writeLocally(
    document.path,
    () => document.set({
      ..._toFirestore(data),
      for (final key in deleting) key: FieldValue.delete(),
    }, SetOptions(merge: true)),
    _onWriteError,
  );

  Stream<List<T>> _watch<T>(
    CollectionReference<Map<String, dynamic>> collection,
    T Function(Map<String, Object?>) decode,
  ) => collection.snapshots().map(
    (snapshot) => [
      for (final document in snapshot.docs)
        ?_decode(document.reference.path, document.data(), decode),
    ],
  );

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
        name: 'program_repository',
        error: error,
        stackTrace: stackTrace,
      );
}

// ponytail: another copy of the repositories' Timestamp converter; extract
// it into a shared package in a quiet slice (decisions.md, M1 shell).
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
