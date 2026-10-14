import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// A contract fixture as Firestore holds it: each tagged timestamp a
/// [Timestamp].
Map<String, Object?> _fixture(String name) => _toFirestore(
  taggedJsonToFirestore(
    jsonDecode(
      File('../../../contracts/firestore/workout_session/$name.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  ),
);

Map<String, Object?> _toFirestore(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _value(value)));

Object? _value(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => _toFirestore(map),
  final List<Object?> list => list.map(_value).toList(),
  _ => value,
};

void main() {
  group(FirestoreWorkoutSessionRepository, () {
    const uid = 'user_contract_full';
    late FakeFirebaseFirestore firestore;
    late List<(String, Object)> decodeErrors;
    late FirestoreWorkoutSessionRepository subject;

    CollectionReference<Map<String, dynamic>> sessions(String owner) =>
        firestore.collection('users/$owner/workout_sessions');

    setUp(() {
      firestore = FakeFirebaseFirestore();
      decodeErrors = [];
      subject = FirestoreWorkoutSessionRepository(
        firestore: firestore,
        onDecodeError: (path, error, _) => decodeErrors.add((path, error)),
      );
    });

    group('watchSessions', () {
      test(
        'reads the full fixture back exactly, timestamps included',
        () async {
          final full = _fixture('full');
          await sessions(uid).doc('session_contract_full').set(full);

          final read = await subject.watchSessions(uid).first;

          expect(read, hasLength(1));
          expect(
            firestoreToTaggedJson(read.single.toFirestore()),
            equals(
              jsonDecode(
                File('../../../contracts/firestore/workout_session/full.json')
                    .readAsStringSync(),
              ),
            ),
          );
          expect(read.single.dateCreated.isUtc, isTrue);
          expect(
            read.single.exercises.first.sets.single.completedAt,
            DateTime.utc(2026, 10, 12, 17, 41, 2, 750),
          );
          expect(decodeErrors, isEmpty);
        },
      );

      test(
        'returns only sessions $uid authored in their own collection',
        () async {
          await sessions(uid)
              .doc('mine')
              .set(_fixture('minimal')..['author_id'] = uid);
          await sessions(uid).doc('forged').set(_fixture('minimal'));
          await sessions('someone_else')
              .doc('theirs')
              .set(_fixture('minimal')..['author_id'] = uid);

          final read = await subject.watchSessions(uid).first;

          expect(read.map((session) => session.authorId), [uid]);
        },
      );

      test('skips and reports a session that does not decode', () async {
        await sessions(uid).doc('good').set(_fixture('full'));
        await sessions(uid)
            .doc('bad')
            .set(_fixture('full')..remove('is_rest_day'));

        final read = await subject.watchSessions(uid).first;

        expect(read.map((session) => session.id), ['session_contract_full']);
        expect(decodeErrors.single.$1, 'users/$uid/workout_sessions/bad');
      });

      test('emits again when a session changes', () async {
        final emissions = subject.watchSessions(uid);
        final first = expectLater(
          emissions.map((list) => list.length),
          emitsInOrder([0, 1]),
        );
        await Future<void>.delayed(Duration.zero);
        await sessions(uid).doc('new').set(_fixture('full'));
        await first;
      });
    });

    group('session', () {
      test('returns the session with that id', () async {
        await sessions(uid).doc('session_contract_full').set(_fixture('full'));

        final read = await subject.session(uid, 'session_contract_full');

        expect(read?.name, 'Push A');
      });

      test('returns null when there is no such session', () async {
        expect(await subject.session(uid, 'missing'), isNull);
      });

      test('returns null and reports a session that does not decode', () async {
        await sessions(uid).doc('bad').set({'id': 'bad'});

        expect(await subject.session(uid, 'bad'), isNull);
        expect(decodeErrors.single.$1, 'users/$uid/workout_sessions/bad');
      });

      test('logs a failure when no handler is given', () async {
        await sessions(uid).doc('bad').set({'id': 'bad'});
        final logging = FirestoreWorkoutSessionRepository(firestore: firestore);

        expect(await logging.session(uid, 'bad'), isNull);
      });
    });
  });
}
