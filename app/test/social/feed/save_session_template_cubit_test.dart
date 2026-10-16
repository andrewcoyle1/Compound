import 'package:compound/social/feed/save_session_template_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';

class _FailingLibrary extends InMemoryTrainingLibraryRepository {
  new({super.exercises});

  @override
  Future<void> saveWorkoutTemplate(WorkoutTemplateModel template) =>
      Future.error(StateError('offline'));
}

// Ported from Swift's WorkoutSessionSaveAsTemplateTests.
void main() {
  final now = DateTime(2026, 3, 2, 12);
  late AnalyticsRecorder analytics;

  // The reader's own Bench Press; "Mystery Lift" is only the friend's.
  final bench = ExerciseModel.fromFirestore({
    ...fixtureLibraryExercise('bench', name: 'Bench Press').toFirestore(),
    ExerciseModelKeys.authorId: 'me',
  });
  final session = WorkoutSessionModel(
    id: 'session-x',
    authorId: 'friend',
    name: 'Push Day',
    dateCreated: now,
    dateModified: now,
    exercises: [
      fixtureExercise('Bench Press', sets: [fixtureSet(reps: 10)]),
      fixtureExercise('Mystery Lift', sets: [fixtureSet(reps: 10)]),
    ],
  );

  setUp(() => analytics = AnalyticsRecorder());

  SaveSessionTemplateCubit build(TrainingLibraryRepository library) =>
      SaveSessionTemplateCubit(
        library: library,
        analytics: analytics,
        session: session,
        now: () => now,
      );

  Future<List<WorkoutTemplateModel>> saved(TrainingLibraryRepository library) =>
      library.watchUserWorkoutTemplates('me').first;

  group(SaveSessionTemplateCubit, () {
    test('saves the workout as the reader’s and says so', () async {
      final library = InMemoryTrainingLibraryRepository(exercises: [bench]);
      final cubit = build(library);

      await cubit.savePressed(viewerId: 'me', copyName: (n) => '$n (copy)');

      final templates = await saved(library);
      expect(templates, hasLength(1));
      expect(templates.single.authorId, 'me');
      expect(templates.single.name, 'Push Day');
      expect(templates.single.exercises.map((e) => e.exercise.id), ['bench']);
      expect(
        cubit.state,
        const SaveSessionTemplateState(
          status: SaveSessionTemplateStatus.saved,
          savedName: 'Push Day',
        ),
      );
      expect(analytics.names, [
        'WorkoutSessionRow_SaveAsTemplate_Start',
        'WorkoutSessionRow_SaveAsTemplate_Success',
      ]);
      expect(analytics.parameters('WorkoutSessionRow_SaveAsTemplate_Success'), {
        'session_id': 'session-x',
        'exercise_count': 1,
      });
      await cubit.close();
    });

    test('adds copy to a name the reader already has', () async {
      final library = InMemoryTrainingLibraryRepository(
        exercises: [bench],
        workoutTemplates: [
          WorkoutTemplateModel(
            workoutId: 'existing',
            authorId: 'me',
            name: 'Push Day',
            dateCreated: now,
            dateModified: now,
            exercises: const [],
          ),
        ],
      );
      final cubit = build(library);

      await cubit.savePressed(viewerId: 'me', copyName: (n) => '$n (copy)');

      expect(cubit.state.savedName, 'Push Day (copy)');
      expect(
        (await saved(library)).map((t) => t.name),
        containsAll(['Push Day', 'Push Day (copy)']),
      );
      await cubit.close();
    });

    test('an unresolvable workout saves nothing and says why', () async {
      final library = InMemoryTrainingLibraryRepository();
      final cubit = build(library);

      await cubit.savePressed(viewerId: 'me', copyName: (n) => n);

      expect(await saved(library), isEmpty);
      expect(cubit.state.status, SaveSessionTemplateStatus.unresolved);
      expect(analytics.names, ['WorkoutSessionRow_SaveAsTemplate_Unresolved']);
      await cubit.close();
    });

    test('a failed save says so', () async {
      final cubit = build(_FailingLibrary(exercises: [bench]));

      await cubit.savePressed(viewerId: 'me', copyName: (n) => n);

      expect(cubit.state.status, SaveSessionTemplateStatus.failed);
      expect(analytics.names.last, 'WorkoutSessionRow_SaveAsTemplate_Fail');
      await cubit.close();
    });

    test('with no reader it fails without saving', () async {
      final library = InMemoryTrainingLibraryRepository(exercises: [bench]);
      final cubit = build(library);

      await cubit.savePressed(viewerId: null, copyName: (n) => n);

      expect(cubit.state.status, SaveSessionTemplateStatus.failed);
      expect(analytics.names, isEmpty);
      await cubit.close();
    });
  });
}
