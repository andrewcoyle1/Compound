import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

ExerciseModel _exercise() =>
    ExerciseModel.fromFirestore(modelFixture('exercise_model', 'full'));

void main() {
  test('deleteUserExercise removes the document', () async {
    final firestore = FakeFirebaseFirestore();
    final subject = FirestoreTrainingLibraryRepository(firestore: firestore);
    final exercise = _exercise();
    await subject.saveUserExercise(exercise);

    await subject.deleteUserExercise(exercise.id);

    expect(
      (await firestore.doc('exercise_templates/${exercise.id}').get()).exists,
      isFalse,
    );
  });

  test('deleteUserExercise completes offline; a refusal is reported', () async {
    FakeFirebaseFirestore();
    final firestore = OfflineFirestore();
    final refused = <(String, String)>[];
    final subject = FirestoreTrainingLibraryRepository(
      firestore: firestore,
      onWriteError: (path, error, _) =>
          refused.add((path, (error as FirebaseException).code)),
    );

    await subject.deleteUserExercise('e');
    expect(firestore.writes, ['exercise_templates/e']);

    firestore.refuse('permission-denied');
    await pumpEventQueue();
    expect(refused, [('exercise_templates/e', 'permission-denied')]);
  });

  test('in memory, deleteUserExercise removes it, telling watchers', () async {
    final exercise = _exercise();
    final subject = InMemoryTrainingLibraryRepository(exercises: [exercise]);
    final counts = subject
        .watchUserExercises(exercise.authorId)
        .map((exercises) => exercises.length);
    final expectation = expectLater(counts, emitsInOrder([1, 0]));

    await subject.deleteUserExercise(exercise.id);

    await expectation;
  });
}
