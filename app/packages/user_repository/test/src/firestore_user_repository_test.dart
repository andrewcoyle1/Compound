import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

Map<String, Object?> _json(String model, String name) => jsonDecode(
  File('../../../contracts/firestore/$model/$name.json').readAsStringSync(),
) as Map<String, Object?>;

/// A contract fixture as Firestore holds it: each tagged timestamp a
/// [Timestamp].
Map<String, Object?> _fixture(String model, String name) =>
    _toFirestore(taggedJsonToFirestore(_json(model, name)));

Map<String, Object?> _toFirestore(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _value(value)));

Object? _value(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => _toFirestore(map),
  final List<Object?> list => list.map(_value).toList(),
  _ => value,
};

void main() {
  group(FirestoreUserRepository, () {
    const uid = 'user_contract_full';
    late FakeFirebaseFirestore firestore;
    late List<(String, Object)> decodeErrors;
    late FirestoreUserRepository subject;

    DocumentReference<Map<String, dynamic>> user() =>
        firestore.doc('users/$uid');
    DocumentReference<Map<String, dynamic>> settings() =>
        firestore.doc('users/$uid/private/settings');

    setUp(() {
      firestore = FakeFirebaseFirestore();
      decodeErrors = [];
      subject = FirestoreUserRepository(
        firestore: firestore,
        onDecodeError: (path, error, _) => decodeErrors.add((path, error)),
      );
    });

    group('watchUser', () {
      test(
        'reads the full fixture back exactly, timestamps included',
        () async {
          await user().set(_fixture('user_model', 'full'));

          final read = await subject.watchUser(uid).first;

          expect(
            firestoreToTaggedJson(read!.toFirestore()),
            equals(_json('user_model', 'full')),
          );
          expect(read.creationDate, DateTime.utc(2025, 3, 4, 5, 6, 7, 123));
          expect(read.creationDate!.isUtc, isTrue);
          expect(decodeErrors, isEmpty);
        },
      );

      test('is null when there is no document', () async {
        expect(await subject.watchUser(uid).first, isNull);
      });

      test('is null, and reports, when the document does not decode', () async {
        await user().set(
          _fixture('user_model', 'full')..remove('did_complete_onboarding'),
        );

        expect(await subject.watchUser(uid).first, isNull);
        expect(decodeErrors.single.$1, 'users/$uid');
      });

      test('emits again when the document changes', () async {
        final names = subject.watchUser(uid).map((user) => user?.displayName);
        final expectation = expectLater(
          names,
          emitsInOrder([null, 'Ada Lovelace']),
        );
        await Future<void>.delayed(Duration.zero);
        await user().set(_fixture('user_model', 'full'));
        await expectation;
      });

      test('logs a decode error when no handler is given', () async {
        await user().set(<String, Object?>{'user_id': uid});
        final logging = FirestoreUserRepository(firestore: firestore);

        expect(await logging.watchUser(uid).first, isNull);
      });
    });

    group('watchPrivateSettings', () {
      test('reads the full fixture back exactly', () async {
        await settings().set(_fixture('private_user_settings', 'full'));

        final read = await subject.watchPrivateSettings(uid).first;

        expect(
          firestoreToTaggedJson(read!.toFirestore()),
          equals(_json('private_user_settings', 'full')),
        );
        expect(read.weekEndsAt!.isUtc, isTrue);
      });

      test('is null when there is no document', () async {
        expect(await subject.watchPrivateSettings(uid).first, isNull);
      });

      test('is null, and reports, when the document does not decode', () async {
        await settings().set(<String, Object?>{'week_streak': 'two'});

        expect(await subject.watchPrivateSettings(uid).first, isNull);
        expect(decodeErrors.single.$1, 'users/$uid/private/settings');
      });
    });
  });
}
