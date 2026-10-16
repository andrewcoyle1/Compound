import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/contract.dart';
import '../helpers/user_fields.dart';

void main() {
  group(InMemoryUserRepository, () {
    final now = DateTime(2026, 10, 14, 12);
    final user = sampleUser(now: now);
    final settings = sampleUserSettings(now: now);
    final subject = InMemoryUserRepository(
      users: {sampleUserId: user},
      settings: {sampleUserId: settings},
    );

    test('serves the seeded profile and settings', () async {
      expect(await subject.watchUser(sampleUserId).first, same(user));
      expect(
        await subject.watchPrivateSettings(sampleUserId).first,
        same(settings),
      );
    });

    test('serves null for anyone else', () async {
      expect(await subject.watchUser('someone').first, isNull);
      expect(await subject.watchPrivateSettings('someone').first, isNull);
    });

    test('userExists is true only for a stored profile', () async {
      expect(await subject.userExists(sampleUserId), isTrue);
      expect(await subject.userExists('someone'), isFalse);
    });

    test('is empty by default', () async {
      expect(
        await InMemoryUserRepository().watchUser(sampleUserId).first,
        isNull,
      );
    });

    group('writes', () {
      final full = UserModel.fromFirestore(modelFixture('user_model', 'full'));
      final fullSettings = PrivateUserSettings.fromFirestore(
        modelFixture('private_user_settings', 'full'),
      );
      late InMemoryUserRepository repository;

      setUp(() => repository = InMemoryUserRepository());

      test('createUser stores the user, and watchers see it', () async {
        final expectation = expectLater(
          repository.watchUser(full.userId).map((user) => user?.username),
          emitsInOrder([null, 'ada']),
        );

        await repository.createUser(full);

        await expectation;
        expect(
          (await repository.watchUser(full.userId).first)!.toFirestore(),
          full.toFirestore(),
        );
      });

      test('createUser merges over the stored profile, as Firestore', () async {
        await repository.createUser(full);
        await repository.createUser(UserModel(userId: full.userId));

        final user = await repository.watchUser(full.userId).first;
        expect(user!.username, 'ada');
        expect(user.didCompleteOnboarding, isFalse);
      });

      test('updateUserFields sets exactly the fields given', () async {
        await repository.createUser(full);

        await repository.updateUserFields(full.userId, everyFieldUpdate);

        final user = await repository.watchUser(full.userId).first;
        expect(
          firestoreToTaggedJson(user!.toFirestore()),
          strictlyEquals({
            ...taggedFixture('user_model', 'full'),
            ...taggedUpdates,
          }),
        );
      });

      test('updateUserFields removes a cleared field', () async {
        await repository.createUser(full);

        await repository.updateUserFields(full.userId, [
          UserField.submittedProfileImage.cleared,
        ]);

        final user = await repository.watchUser(full.userId).first;
        expect(user!.submittedProfileImage, isNull);
        expect(user.submittedFirstName, full.submittedFirstName);
      });

      test('updateUserFields fails with not-found without a profile', () {
        expect(
          repository.updateUserFields('nobody', [UserField.isPrivate(true)]),
          throwsA(
            isA<FirebaseException>().having((e) => e.code, 'code', 'not-found'),
          ),
        );
      });

      test('deleteUser removes the profile, and watchers see it', () async {
        await repository.createUser(full);
        final expectation = expectLater(
          repository.watchUser(full.userId).map((user) => user?.userId),
          emitsInOrder([full.userId, null]),
        );

        await repository.deleteUser(full.userId);

        await expectation;
        expect(await repository.userExists(full.userId), isFalse);
      });

      test('mergePrivateSettings merges, and watchers see it', () async {
        final expectation = expectLater(
          repository
              .watchPrivateSettings('me')
              .map((settings) => settings?.coachConsent),
          emitsInOrder([null, true, false]),
        );

        await repository.mergePrivateSettings('me', fullSettings);
        await repository.mergePrivateSettings(
          'me',
          const PrivateUserSettings(coachConsent: false),
        );

        await expectation;
        expect(
          (await repository.watchPrivateSettings('me').first)!.toFirestore(),
          {...fullSettings.toFirestore(), 'coach_consent': false},
        );
      });

      test('mergePrivateSettings deletes the fields it clears', () async {
        await repository.mergePrivateSettings('me', fullSettings);
        await repository.mergePrivateSettings(
          'me',
          const PrivateUserSettings(weekStreak: 0),
          clearing: {PrivateUserSettingsKeys.lastTrainedAt},
        );
        final stored = (await repository.watchPrivateSettings('me').first)!;
        expect(stored.lastTrainedAt, isNull);
        expect(stored.weekStreak, 0);
        expect(stored.coachConsent, fullSettings.coachConsent);
      });
    });
  });

  group('sampleUser', () {
    final now = DateTime(2026, 10, 14, 12);

    test('is the staging auth user, onboarded, with metric units', () {
      final user = sampleUser(now: now);
      expect(user.userId, 'mock_user_123');
      expect(user.displayName, 'Alice Cooper');
      expect(user.email, 'alice@example.com');
      expect(user.didCompleteOnboarding, isTrue);
      expect(
        user.submittedWeightUnitPreference,
        WeightUnitPreference.kilograms,
      );
      expect(
        user.submittedLengthUnitPreference,
        LengthUnitPreference.centimeters,
      );
      expect(user.weeklySessionGoal, 3);
      expect(user.creationDate, now.subtract(const Duration(days: 30)));
    });

    test('has settings that agree with the weekly goal', () {
      final settings = sampleUserSettings(now: now);
      expect(settings.weekGoal, sampleUser(now: now).weeklySessionGoal);
      expect(settings.weekSessions, lessThanOrEqualTo(settings.weekGoal!));
    });

    test('round-trips through the Firestore encoding', () {
      final user = sampleUser(now: now);
      expect(
        UserModel.fromFirestore(user.toFirestore()).toFirestore(),
        user.toFirestore(),
      );
      final settings = sampleUserSettings(now: now);
      expect(
        PrivateUserSettings.fromFirestore(settings.toFirestore()).toFirestore(),
        settings.toFirestore(),
      );
    });
  });

  testWidgets("a watcher's first value arrives under a fake clock", (
    tester,
  ) async {
    // A bloc awaits `.first`; it must not wait on anything outside the
    // widget test's zone.
    var arrived = false;
    unawaited(
      InMemoryUserRepository().watchUser('x').first.then((_) => arrived = true),
    );
    await tester.pump();
    expect(arrived, isTrue);
  });
}
