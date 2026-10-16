import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

Map<String, Object?> _tagged(String model, String name) => jsonDecode(
  File('../../../contracts/firestore/$model/$name.json').readAsStringSync(),
) as Map<String, Object?>;

/// A contract fixture as Firestore holds it: each tagged timestamp a
/// [Timestamp].
Map<String, Object?> _fixture(String model, String name) =>
    _toFirestore(taggedJsonToFirestore(_tagged(model, name)));

Map<String, Object?> _toFirestore(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _value(value)));

Object? _value(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => _toFirestore(map),
  final List<Object?> list => list.map(_value).toList(),
  _ => value,
};

void main() {
  group(FirestoreTrainingLibraryRepository, () {
    const uid = 'user_contract_full';
    late FakeFirebaseFirestore firestore;
    late List<(String, Object)> decodeErrors;
    late FirestoreTrainingLibraryRepository subject;

    CollectionReference<Map<String, dynamic>> user(String name) =>
        firestore.collection('users/$uid/$name');

    setUp(() {
      firestore = FakeFirebaseFirestore();
      decodeErrors = [];
      subject = FirestoreTrainingLibraryRepository(
        firestore: firestore,
        onDecodeError: (path, error, _) => decodeErrors.add((path, error)),
      );
    });

    test("reads $uid's exercises from exercise_templates, by name", () async {
      final exercises = firestore.collection('exercise_templates');
      await exercises
          .doc('b')
          .set(_fixture('exercise_model', 'full')..['name'] = 'Zercher');
      await exercises.doc('a').set(_fixture('exercise_model', 'full'));
      await exercises
          .doc('other')
          .set(_fixture('exercise_model', 'full')..['author_id'] = 'someone');
      await exercises.doc('bad').set({'author_id': uid, 'id': 'bad'});

      final read = await subject.watchUserExercises(uid).first;

      expect([for (final e in read) e.name], ['Paused Bench Press', 'Zercher']);
      expect(
        firestoreToTaggedJson(read.first.toFirestore()),
        _tagged('exercise_model', 'full'),
      );
      expect(decodeErrors.single.$1, 'exercise_templates/bad');
    });

    test('reads workout templates back exactly', () async {
      await user('workout_templates')
          .doc('full')
          .set(_fixture('workout_template', 'full'));
      final read = await subject.watchUserWorkoutTemplates(uid).first;
      expect(
        firestoreToTaggedJson(read.single.toFirestore()),
        _tagged('workout_template', 'full'),
      );
    });

    test('reads gym profiles back exactly', () async {
      await user('gym_profiles')
          .doc('full')
          .set(_fixture('gym_profile', 'full'));
      final read = await subject.watchGymProfiles(uid).first;
      expect(
        firestoreToTaggedJson(read.single.toFirestore()),
        _tagged('gym_profile', 'full'),
      );
      expect(read.single.deletedAt, DateTime.utc(2026, 10, 4, 8));
    });

    test(
      'reads exercise settings, skipping one that does not decode',
      () async {
        await user('exercise_settings')
            .doc('full')
            .set(_fixture('exercise_settings', 'full'));
        await user('exercise_settings').doc('bad').set({'id': 'bad'});
        final read = await subject.watchExerciseSettings(uid).first;
        expect(read.single.restDurationOverride, 150);
        expect(decodeErrors.single.$1, 'users/$uid/exercise_settings/bad');
      },
    );

    group('watchWorkoutSettings', () {
      test('reads the settings document back exactly', () async {
        await user('workout_settings')
            .doc('workout_settings')
            .set(_fixture('workout_settings', 'full'));
        final read = await subject.watchWorkoutSettings(uid).first;
        expect(
          firestoreToTaggedJson(read.toFirestore()),
          _tagged('workout_settings', 'full'),
        );
      });

      test("falls back to Swift's defaults with no document", () async {
        final read = await subject.watchWorkoutSettings(uid).first;
        expect(read.authorId, uid);
        expect(read.defaultRestDurationSeconds, 90);
        expect(decodeErrors, isEmpty);
      });

      test("falls back to Swift's defaults when it does not decode", () async {
        await user('workout_settings')
            .doc('workout_settings')
            .set({'id': 'workout_settings'});
        final read = await subject.watchWorkoutSettings(uid).first;
        expect(read.authorId, uid);
        expect(decodeErrors, hasLength(1));
      });
    });

    test('logs a skipped document without a handler', () async {
      final logged = FirestoreTrainingLibraryRepository(firestore: firestore);
      await user('gym_profiles').doc('bad').set({'id': 'bad'});
      expect(await logged.watchGymProfiles(uid).first, isEmpty);
    });
  });
}
