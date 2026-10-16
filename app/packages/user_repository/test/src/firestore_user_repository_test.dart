import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/contract.dart';
import '../helpers/user_fields.dart';

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
    Future<Map<String, Object?>> stored(
      DocumentReference<Map<String, dynamic>> document,
    ) async => storedAsTagged((await document.get()).data()!);

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
          await user().set(storedFixture('user_model', 'full'));

          final read = await subject.watchUser(uid).first;

          expect(
            firestoreToTaggedJson(read!.toFirestore()),
            equals(taggedFixture('user_model', 'full')),
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
          storedFixture('user_model', 'full')
            ..remove('did_complete_onboarding'),
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
        await user().set(storedFixture('user_model', 'full'));
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
        await settings().set(storedFixture('private_user_settings', 'full'));

        final read = await subject.watchPrivateSettings(uid).first;

        expect(
          firestoreToTaggedJson(read!.toFirestore()),
          equals(taggedFixture('private_user_settings', 'full')),
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

    group('userExists', () {
      test('is false with no profile', () async {
        expect(await subject.userExists(uid), isFalse);
      });

      test('is true with a profile, even one that does not decode', () async {
        await user().set({'not': 'a user'});
        expect(await subject.userExists(uid), isTrue);
      });
    });

    group('createUser', () {
      for (final name in ['full', 'minimal']) {
        test('stores the $name fixture as the model encodes it', () async {
          final model = UserModel.fromFirestore(
            modelFixture('user_model', name),
          );

          await subject.createUser(model);

          final written = await stored(firestore.doc('users/${model.userId}'));
          expect(
            written,
            strictlyEquals(firestoreToTaggedJson(model.toFirestore())),
          );
          expect(written, strictlyEquals(taggedFixture('user_model', name)));
        });
      }

      test('merges, keeping a field this app does not know', () async {
        await user().set({'field_from_a_newer_build': 1});

        await subject.createUser(
          UserModel.fromFirestore(modelFixture('user_model', 'full')),
        );

        expect(
          await stored(user()),
          strictlyEquals({
            ...taggedFixture('user_model', 'full'),
            'field_from_a_newer_build': 1,
          }),
        );
      });
    });

    group('updateUserFields', () {
      test(
        'sets every allowed field, typed as Swift stores it, and nothing else',
        () async {
          await user().set(storedFixture('user_model', 'full'));

          await subject.updateUserFields(uid, everyFieldUpdate);

          final expected = {
            ...taggedFixture('user_model', 'full'),
            ...taggedUpdates,
          };
          expect(await stored(user()), strictlyEquals(expected));
          final read = await subject.watchUser(uid).first;
          expect(
            firestoreToTaggedJson(read!.toFirestore()),
            strictlyEquals(expected),
          );
        },
      );

      test('a cleared field is deleted, not written as null', () async {
        await user().set(storedFixture('user_model', 'full'));

        await subject.updateUserFields(uid, [
          UserField.submittedProfileImage.cleared,
        ]);

        final data = (await user().get()).data()!;
        expect(data.containsKey(UserModelKeys.submittedProfileImage), isFalse);
        expect(data[UserModelKeys.submittedFirstName], isNotNull);
      });

      test('fails when there is no profile, as Firestore does', () async {
        await expectLater(
          subject.updateUserFields(uid, [UserField.weeklySessionGoal(3)]),
          throwsA(isA<FirebaseException>()),
        );
        expect((await user().get()).exists, isFalse);
      });
    });

    group('deleteUser', () {
      test('deletes the profile, leaving its subcollections to the '
          'function', () async {
        await user().set(storedFixture('user_model', 'full'));
        await settings().set(storedFixture('private_user_settings', 'full'));

        await subject.deleteUser(uid);

        expect((await user().get()).exists, isFalse);
        expect((await settings().get()).exists, isTrue);
      });
    });

    group('mergePrivateSettings', () {
      test('stores the full fixture as the model encodes it', () async {
        final model = PrivateUserSettings.fromFirestore(
          modelFixture('private_user_settings', 'full'),
        );

        await subject.mergePrivateSettings(uid, model);

        final written = await stored(settings());
        expect(
          written,
          strictlyEquals(firestoreToTaggedJson(model.toFirestore())),
        );
        expect(
          written,
          strictlyEquals(taggedFixture('private_user_settings', 'full')),
        );
      });

      test('withdraws coach consent by writing false over it', () async {
        await settings().set(storedFixture('private_user_settings', 'full'));

        await subject.mergePrivateSettings(
          uid,
          const PrivateUserSettings(coachConsent: false),
        );

        expect(
          await stored(settings()),
          strictlyEquals({
            ...taggedFixture('private_user_settings', 'full'),
            'coach_consent': false,
          }),
        );
      });

      test('leaves the fields it omits as they were', () async {
        await settings().set({
          ...storedFixture('private_user_settings', 'full'),
          'field_from_a_newer_build': 'kept',
        });

        await subject.mergePrivateSettings(uid, const PrivateUserSettings());

        expect(
          await stored(settings()),
          strictlyEquals({
            ...taggedFixture('private_user_settings', 'full'),
            'field_from_a_newer_build': 'kept',
          }),
        );
      });
    });
  });

  test('UserField names only model fields updated by name', () {
    expect([
      for (final field in UserField.values) field.key,
    ], unorderedEquals(taggedUpdates.keys));
    expect(UserModelKeys.all, containsAll(taggedUpdates.keys));
    expect([
      for (final value in everyFieldUpdate) value.key,
    ], unorderedEquals(taggedUpdates.keys));
  });
}
