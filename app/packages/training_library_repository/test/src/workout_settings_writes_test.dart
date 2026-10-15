// saveWorkoutSettings, checked against the Firestore contract: what is
// stored is exactly the model's canonical encoding.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart' show WorkoutSettingsKeys;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../helpers/contract.dart';

void main() {
  group('FirestoreTrainingLibraryRepository.saveWorkoutSettings', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreTrainingLibraryRepository subject;

    DocumentReference<Map<String, dynamic>> document(String uid) =>
        firestore.doc('users/$uid/workout_settings/workout_settings');
    Future<Map<String, Object?>> stored(String uid) async =>
        storedAsTagged((await document(uid).get()).data()!);

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = FirestoreTrainingLibraryRepository(firestore: firestore);
    });

    for (final name in [
      'full',
      'minimal',
      'legacy-null-optionals.expected',
      'legacy-retired-keys.expected',
      'legacy-whole-number-doubles.expected',
      'legacy-amrap-never-adds-weight.expected',
    ]) {
      test('stores the $name fixture as the model encodes it', () async {
        final model = WorkoutSettings.fromFirestore(
          modelFixture('workout_settings', name),
        );

        await subject.saveWorkoutSettings(model);

        final written = await stored(model.authorId);
        expect(written, strictlyEquals(model.toFirestore()));
        expect(
          written,
          strictlyEquals(taggedFixture('workout_settings', name)),
        );
      });
    }

    test('reads back through watchWorkoutSettings', () async {
      final model = WorkoutSettings.fromFirestore(
        modelFixture('workout_settings', 'full'),
      );

      await subject.saveWorkoutSettings(model);
      final read = await subject.watchWorkoutSettings(model.authorId).first;

      expect(
        read.toFirestore(),
        strictlyEquals(taggedFixture('workout_settings', 'full')),
      );
    });

    test(
      'writes every known field as given: an unknown field survives, a '
      'null optional is deleted and the rest-by-kind map is replaced',
      () async {
        final full = WorkoutSettings.fromFirestore(
          modelFixture('workout_settings', 'full'),
        );
        await document(full.authorId).set({
          ...storedFixture('workout_settings', 'full'),
          'field_from_a_newer_build': 1,
        });

        // Swift's "Off" for the superset rest and "Reset Default Timers".
        final change = WorkoutSettings(
          authorId: full.authorId,
          restDurationsByExerciseType: const {'core': 45},
        );
        await subject.saveWorkoutSettings(change);

        final written = await stored(full.authorId);
        expect(
          written,
          strictlyEquals({
            ...change.toFirestore(),
            'field_from_a_newer_build': 1,
          }),
        );
        expect(
          written.containsKey(
            WorkoutSettingsKeys.supersetTransitionRestSeconds,
          ),
          isFalse,
        );
      },
    );

    test('creates the document when there is none', () async {
      const settings = WorkoutSettings(authorId: 'new');
      await subject.saveWorkoutSettings(settings);
      expect(await stored('new'), strictlyEquals(settings.toFirestore()));
    });
  });

  group('InMemoryTrainingLibraryRepository.saveWorkoutSettings', () {
    const uid = 'me';

    test('saves new settings, and watchers see them', () async {
      final subject = InMemoryTrainingLibraryRepository();
      final rir = subject
          .watchWorkoutSettings(uid)
          .map((settings) => settings.rirTracking);
      final expectation = expectLater(rir, emitsInOrder([false, true]));

      await subject.saveWorkoutSettings(
        const WorkoutSettings(authorId: uid, rirTracking: true),
      );

      await expectation;
    });

    test('replaces the stored settings, leaving other users alone', () async {
      final subject = InMemoryTrainingLibraryRepository(
        workoutSettings: const [
          WorkoutSettings(
            authorId: uid,
            setPlanning: true,
            restDurationsByExerciseType: {'compoundUpper': 180},
          ),
          WorkoutSettings(authorId: 'you', rirTracking: true),
        ],
      );

      await subject.saveWorkoutSettings(
        const WorkoutSettings(authorId: uid, keepAlive: false),
      );

      final mine = await subject.watchWorkoutSettings(uid).first;
      expect(mine.keepAlive, isFalse);
      expect(mine.setPlanning, isNull);
      expect(mine.restDurationsByExerciseType, isEmpty);
      expect(
        (await subject.watchWorkoutSettings('you').first).rirTracking,
        isTrue,
      );
    });
  });
}
