import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:training_library_repository/src/training_library_repository.dart';

/// Called with a document's path when it cannot be decoded and is skipped.
typedef LibraryDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// [TrainingLibraryRepository] on Cloud Firestore.
///
/// A document that does not decode is skipped and reported to
/// `onDecodeError`, as the Swift app's sync engine skips it. Writes go
/// through the models' `toFirestore`, with dates stored as Timestamps, and
/// whole documents are merged (`docs/specs/flutter/firestore-contract.md`,
/// Policy). A write completes once Firestore has it locally, online or not
/// ([writeLocally]).
class FirestoreTrainingLibraryRepository implements TrainingLibraryRepository {
  /// Creates a [FirestoreTrainingLibraryRepository] reading `firestore`.
  /// Decode failures go to [onDecodeError], or to `dart:developer`'s log
  /// when it is null, and writes the server refuses go to `onWriteError`.
  new({
    required this._firestore,
    LibraryDecodeErrorHandler? onDecodeError,
    this._onWriteError = logWriteError,
  }) : _onDecodeError = onDecodeError ?? _log;

  final FirebaseFirestore _firestore;
  final LibraryDecodeErrorHandler _onDecodeError;
  final WriteErrorReporter _onWriteError;

  CollectionReference<Map<String, dynamic>> _user(String uid, String name) =>
      _firestore.collection('users').doc(uid).collection(name);

  @override
  Stream<List<ExerciseModel>> watchUserExercises(String uid) => _firestore
      .collection('exercise_templates')
      .where(ExerciseModelKeys.authorId, isEqualTo: uid)
      .snapshots()
      .map(
        (snapshot) =>
            _decodeAll(snapshot, ExerciseModel.fromFirestore)
              ..sort((a, b) => a.name.compareTo(b.name)),
      );

  @override
  Stream<List<WorkoutTemplateModel>> watchUserWorkoutTemplates(String uid) =>
      _user(uid, 'workout_templates').snapshots().map(
        (snapshot) => _decodeAll(snapshot, WorkoutTemplateModel.fromFirestore),
      );

  @override
  Stream<List<GymProfileModel>> watchGymProfiles(String uid) =>
      _user(uid, 'gym_profiles').snapshots().map(
        (snapshot) => _decodeAll(snapshot, GymProfileModel.fromFirestore),
      );

  @override
  Future<void> saveGymProfile(GymProfileModel profile) => _merge(
    _user(profile.authorId, 'gym_profiles').doc(profile.id),
    profile.toFirestore(),
  );

  @override
  Stream<List<ExerciseSettingsModel>> watchExerciseSettings(String uid) =>
      _user(uid, 'exercise_settings').snapshots().map(
        (snapshot) => _decodeAll(snapshot, ExerciseSettingsModel.fromFirestore),
      );

  @override
  Stream<WorkoutSettings> watchWorkoutSettings(String uid) =>
      _user(uid, 'workout_settings').doc('workout_settings').snapshots().map((
        document,
      ) {
        final data = document.data();
        return (data == null
                ? null
                : _decode(
                    document.reference.path,
                    data,
                    WorkoutSettings.fromFirestore,
                  )) ??
            WorkoutSettings(authorId: uid);
      });

  @override
  Future<void> saveExerciseSettings(
    String uid,
    ExerciseSettingsModel settings,
  ) => _merge(
    _user(uid, 'exercise_settings').doc(settings.id),
    settings.toFirestore(),
  );

  Future<void> _merge(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, Object?> data,
  ) => writeLocally(
    document.path,
    () => document.set(_toFirestore(data), SetOptions(merge: true)),
    _onWriteError,
  );

  List<T> _decodeAll<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    T Function(Map<String, Object?>) decode,
  ) => [
    for (final document in snapshot.docs)
      ?_decode(document.reference.path, document.data(), decode),
  ];

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
        name: 'training_library_repository',
        error: error,
        stackTrace: stackTrace,
      );
}

// ponytail: the fourth copy of this converter (workout_session, nutrition
// and body repositories have it). Not moved into a shared package here
// because those packages are being changed by parallel slices; do it in a
// quiet slice.
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
