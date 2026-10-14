import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
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
class FirestoreUserRepository implements UserRepository {
  /// Creates a [FirestoreUserRepository] reading `firestore`. Decode
  /// failures go to [onDecodeError], or to `dart:developer`'s log when it is
  /// null.
  new({required this._firestore, UserDecodeErrorHandler? onDecodeError})
    : _onDecodeError = onDecodeError ?? _log;

  final FirebaseFirestore _firestore;
  final UserDecodeErrorHandler _onDecodeError;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Stream<UserModel?> watchUser(String uid) =>
      _watch(_user(uid), UserModel.fromFirestore);

  @override
  Stream<PrivateUserSettings?> watchPrivateSettings(String uid) => _watch(
    _user(uid).collection('private').doc('settings'),
    PrivateUserSettings.fromFirestore,
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
