// saveExerciseSettings, checked against the Firestore contract: what is
// stored is exactly the model's canonical encoding.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart'
    show ExerciseSettingsModelKeys;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../helpers/contract.dart';

void main() {
  group('FirestoreTrainingLibraryRepository.saveExerciseSettings', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreTrainingLibraryRepository subject;

    DocumentReference<Map<String, dynamic>> document(String uid, String id) =>
        firestore.doc('users/$uid/exercise_settings/$id');
    Future<Map<String, Object?>> stored(String uid, String id) async =>
        storedAsTagged((await document(uid, id).get()).data()!);

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = FirestoreTrainingLibraryRepository(firestore: firestore);
    });

    for (final name in ['full', 'minimal', 'legacy-null-optionals.expected']) {
      test('stores the $name fixture as the model encodes it', () async {
        final model = ExerciseSettingsModel.fromFirestore(
          modelFixture('exercise_settings', name),
        );

        await subject.saveExerciseSettings(model.authorId, model);

        final written = await stored(model.authorId, model.id);
        expect(written, strictlyEquals(model.toFirestore()));
        expect(
          written,
          strictlyEquals(taggedFixture('exercise_settings', name)),
        );
      });
    }

    test('reads back through watchExerciseSettings', () async {
      final model = ExerciseSettingsModel.fromFirestore(
        modelFixture('exercise_settings', 'full'),
      );

      await subject.saveExerciseSettings(model.authorId, model);
      final read = await subject.watchExerciseSettings(model.authorId).first;

      expect(
        read.single.toFirestore(),
        strictlyEquals(taggedFixture('exercise_settings', 'full')),
      );
    });

    test('merges: a field this app does not know survives, and a field '
        'left empty keeps what was stored, as in Swift', () async {
      final full = ExerciseSettingsModel.fromFirestore(
        modelFixture('exercise_settings', 'full'),
      );
      await document(full.authorId, full.id).set({
        ...storedFixture('exercise_settings', 'full'),
        'field_from_a_newer_build': 1,
      });

      await subject.saveExerciseSettings(
        full.authorId,
        ExerciseSettingsModel(id: full.id, authorId: full.authorId, note: 'X'),
      );

      expect(
        await stored(full.authorId, full.id),
        strictlyEquals({
          ...taggedFixture('exercise_settings', 'full'),
          ExerciseSettingsModelKeys.note: 'X',
          'field_from_a_newer_build': 1,
        }),
      );
    });
  });

  group('InMemoryTrainingLibraryRepository.saveExerciseSettings', () {
    const uid = 'me';
    late InMemoryTrainingLibraryRepository subject;

    setUp(
      () => subject = InMemoryTrainingLibraryRepository(
        exerciseSettings: const [
          ExerciseSettingsModel(id: 'theirs', authorId: 'you', note: 'Hi'),
        ],
      ),
    );

    test('adds new settings, and watchers see them', () async {
      final notes = subject
          .watchExerciseSettings(uid)
          .map((all) => [for (final s in all) s.note]);
      final expectation = expectLater(
        notes,
        emitsInOrder([
          <String?>[],
          ['Wide grip'],
        ]),
      );

      await subject.saveExerciseSettings(
        uid,
        const ExerciseSettingsModel(
          id: 'bench',
          authorId: uid,
          note: 'Wide grip',
        ),
      );

      await expectation;
    });

    test('merges over stored settings field by field', () async {
      await subject.saveExerciseSettings(
        uid,
        const ExerciseSettingsModel(
          id: 'bench',
          authorId: uid,
          note: 'Wide grip',
          restDurationOverride: 120,
        ),
      );

      await subject.saveExerciseSettings(
        uid,
        const ExerciseSettingsModel(
          id: 'bench',
          authorId: uid,
          restDurationOverride: 90,
        ),
      );

      final read = (await subject.watchExerciseSettings(uid).first).single;
      expect(read.note, 'Wide grip');
      expect(read.restDurationOverride, 90);
    });
  });
}
