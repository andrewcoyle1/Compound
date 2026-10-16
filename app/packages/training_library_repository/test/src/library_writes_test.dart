import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../helpers/contract.dart';

ExerciseModel _exercise(String name) =>
    ExerciseModel.fromFirestore(modelFixture('exercise_model', name));

WorkoutTemplateModel _template(String name) =>
    WorkoutTemplateModel.fromFirestore(modelFixture('workout_template', name));

void main() {
  group('$FirestoreTrainingLibraryRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreTrainingLibraryRepository subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = FirestoreTrainingLibraryRepository(firestore: firestore);
    });

    for (final name in ['full', 'minimal']) {
      test('saveUserExercise stores the $name fixture exactly', () async {
        final exercise = _exercise(name);

        await subject.saveUserExercise(exercise);

        final document = firestore.doc('exercise_templates/${exercise.id}');
        expect(
          storedAsTagged((await document.get()).data()!),
          strictlyEquals(taggedFixture('exercise_model', name)),
        );
      });

      test('saveWorkoutTemplate stores the $name fixture exactly', () async {
        final template = _template(name);

        await subject.saveWorkoutTemplate(template);

        final document = firestore.doc(
          'users/${template.authorId}/workout_templates/${template.workoutId}',
        );
        expect(
          storedAsTagged((await document.get()).data()!),
          strictlyEquals(taggedFixture('workout_template', name)),
        );
        final read = await subject
            .watchUserWorkoutTemplates(template.authorId)
            .first;
        expect(read.single.workoutId, template.workoutId);
      });
    }

    test('saveWorkoutTemplate deletes a field the template cleared', () async {
      final template = _template('full');
      final document = firestore.doc(
        'users/${template.authorId}/workout_templates/${template.workoutId}',
      );
      await document.set({'field_from_a_newer_build': 1});
      await subject.saveWorkoutTemplate(template);

      await subject.saveWorkoutTemplate(
        WorkoutTemplateModel.fromFirestore(
          {...template.toFirestore()}
            ..remove(WorkoutTemplateModelKeys.description),
        ),
      );

      final stored = (await document.get()).data()!;
      expect(stored.containsKey(WorkoutTemplateModelKeys.description), isFalse);
      expect(stored['field_from_a_newer_build'], 1);
    });

    test('deleteWorkoutTemplate removes the document', () async {
      final template = _template('full');
      await subject.saveWorkoutTemplate(template);

      await subject.deleteWorkoutTemplate(
        template.authorId,
        template.workoutId,
      );

      expect(
        await subject.watchUserWorkoutTemplates(template.authorId).first,
        isEmpty,
      );
    });

    test('saves merge, keeping a field this app does not know', () async {
      final exercise = _exercise('full');
      final document = firestore.doc('exercise_templates/${exercise.id}');
      await document.set({'field_from_a_newer_build': 1});

      await subject.saveUserExercise(exercise);

      expect(
        storedAsTagged((await document.get()).data()!),
        strictlyEquals({
          ...taggedFixture('exercise_model', 'full'),
          'field_from_a_newer_build': 1,
        }),
      );
    });
  });

  group('$InMemoryTrainingLibraryRepository', () {
    test('saveUserExercise adds, then replaces, telling watchers', () async {
      final subject = InMemoryTrainingLibraryRepository();
      final exercise = _exercise('full');
      final renamed = ExerciseModel.fromFirestore({
        ...exercise.toFirestore(),
        ExerciseModelKeys.name: 'Renamed',
      });
      final names = subject
          .watchUserExercises(exercise.authorId)
          .map((exercises) => [for (final e in exercises) e.name]);
      final expectation = expectLater(
        names,
        emitsInOrder([
          <String>[],
          [exercise.name],
          ['Renamed'],
        ]),
      );

      await subject.saveUserExercise(exercise);
      await subject.saveUserExercise(renamed);

      await expectation;
    });

    test('saveWorkoutTemplate adds, then replaces, telling watchers', () async {
      final subject = InMemoryTrainingLibraryRepository();
      final template = _template('full');
      final renamed = WorkoutTemplateModel.fromFirestore({
        ...template.toFirestore(),
        WorkoutTemplateModelKeys.name: 'Renamed',
      });
      final names = subject
          .watchUserWorkoutTemplates(template.authorId)
          .map((templates) => [for (final t in templates) t.name]);
      final expectation = expectLater(
        names,
        emitsInOrder([
          <String>[],
          [template.name],
          ['Renamed'],
        ]),
      );

      await subject.saveWorkoutTemplate(template);
      await subject.saveWorkoutTemplate(renamed);

      await expectation;
    });

    test("deleteWorkoutTemplate removes the author's own only", () async {
      final template = _template('full');
      final subject = InMemoryTrainingLibraryRepository(
        workoutTemplates: [template],
      );

      await subject.deleteWorkoutTemplate('other', template.workoutId);
      expect(
        await subject.watchUserWorkoutTemplates(template.authorId).first,
        hasLength(1),
      );
      await subject.deleteWorkoutTemplate(
        template.authorId,
        template.workoutId,
      );
      expect(
        await subject.watchUserWorkoutTemplates(template.authorId).first,
        isEmpty,
      );
    });
  });
}
