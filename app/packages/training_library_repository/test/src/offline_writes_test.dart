import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The repository's writes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy).
void main() {
  group('FirestoreTrainingLibraryRepository offline', () {
    late OfflineFirestore firestore;
    late List<(String, String)> refused;
    late FirestoreTrainingLibraryRepository subject;

    // FieldValue sentinels bind to whichever FieldValue factory is

    // installed when first used; fake_cloud_firestore installs its own

    // only when a fake is built. Build one first, or when this file runs

    // before the Firestore tests in one isolate (very_good test's

    // optimisation) they get the method-channel factory.

    setUpAll(FakeFirebaseFirestore.new);

    setUp(() {
      firestore = OfflineFirestore();
      refused = [];
      subject = FirestoreTrainingLibraryRepository(
        firestore: firestore,
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
      );
    });

    test('the writes complete offline; a refusal is reported', () async {
      final gym = GymProfileModel.fromFirestore(
        modelFixture('gym_profile', 'full'),
      );
      final settings = ExerciseSettingsModel.fromFirestore(
        modelFixture('exercise_settings', 'full'),
      );
      await subject.saveGymProfile(gym);
      await subject.saveExerciseSettings('u', settings);
      expect(firestore.writes, [
        'users/${gym.authorId}/gym_profiles/${gym.id}',
        'users/u/exercise_settings/${settings.id}',
      ]);
      expect(refused, isEmpty);

      firestore.refuse('permission-denied');
      await pumpEventQueue();

      expect(refused, [
        for (final path in [
          'users/${gym.authorId}/gym_profiles/${gym.id}',
          'users/u/exercise_settings/${settings.id}',
        ])
          (path, 'permission-denied'),
      ]);
    });
  });
}
