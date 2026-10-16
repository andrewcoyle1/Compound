import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:user_repository/src/user_field.dart';
import 'package:user_repository/src/user_repository.dart';

/// Called with a document's path when it cannot be decoded.
typedef UserDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// [UserRepository] on Cloud Firestore.
///
/// A document that does not decode reads as null and is reported to
/// `onDecodeError`, as the Swift app drops a document it cannot decode,
/// rather than failing the stream.
///
/// Writes go through the models' `toFirestore`, with dates stored as
/// Timestamps, and whole documents are merged
/// (`docs/specs/flutter/firestore-contract.md`, Policy). A write completes
/// once Firestore has it locally, online or not ([writeLocally]).
class FirestoreUserRepository implements UserRepository {
  /// Creates a [FirestoreUserRepository] reading `firestore`. Decode
  /// failures go to [onDecodeError], or to `dart:developer`'s log when it is
  /// null, and writes the server refuses go to `onWriteError`.
  new({
    required this._firestore,
    UserDecodeErrorHandler? onDecodeError,
    this._onWriteError = logWriteError,
  }) : _onDecodeError = onDecodeError ?? _log;

  final FirebaseFirestore _firestore;
  final UserDecodeErrorHandler _onDecodeError;
  final WriteErrorReporter _onWriteError;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _settings(String uid) =>
      _user(uid).collection('private').doc('settings');

  @override
  Stream<UserModel?> watchUser(String uid) =>
      _watch(_user(uid), UserModel.fromFirestore);

  @override
  Stream<PrivateUserSettings?> watchPrivateSettings(String uid) =>
      _watch(_settings(uid), PrivateUserSettings.fromFirestore);

  @override
  Future<bool> userExists(String uid) async =>
      (await _user(uid).get(const GetOptions(source: Source.server))).exists;

  @override
  Future<void> createUser(UserModel user) =>
      _merge(_user(user.userId), user.toFirestore());

  /// An `update`, which the server refuses with `not-found` when there is no
  /// profile; that reaches `onWriteError`, as Swift reports it.
  @override
  Future<void> updateUserFields(String uid, List<UserFieldValue> fields) {
    final document = _user(uid);
    return writeLocally(
      document.path,
      () => document.update(
        _toFirestore({
          for (final field in fields)
            field.key: field.value ?? FieldValue.delete(),
        }),
      ),
      _onWriteError,
    );
  }

  /// Awaits the server on purpose; see [UserRepository.deleteUser].
  @override
  Future<void> deleteUser(String uid) => _user(uid).delete();

  @override
  Future<void> mergePrivateSettings(
    String uid,
    PrivateUserSettings settings, {
    Set<String> clearing = const {},
  }) => _merge(_settings(uid), {
    ...settings.toFirestore(),
    for (final key in clearing) key: FieldValue.delete(),
  });

  Future<void> _merge(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, Object?> data,
  ) => writeLocally(
    document.path,
    () => document.set(_toFirestore(data), SetOptions(merge: true)),
    _onWriteError,
  );

  Stream<T?> _watch<T>(
    DocumentReference<Map<String, dynamic>> document,
    T Function(Map<String, Object?> data) decode,
  ) => document.snapshots().map((snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    try {
      return decode(_fromFirestore(data));
    } on Object catch (error, stackTrace) {
      _onDecodeError(snapshot.reference.path, error, stackTrace);
      return null;
    }
  });

  static void _log(String path, Object error, StackTrace stackTrace) =>
      developer.log(
        'Could not read $path: it does not decode',
        name: 'user_repository',
        error: error,
        stackTrace: stackTrace,
      );
}

// Mirrors workout_session_repository's converter: Firestore's values to the
// models' at any depth, a [Timestamp] becoming a UTC [DateTime].
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
