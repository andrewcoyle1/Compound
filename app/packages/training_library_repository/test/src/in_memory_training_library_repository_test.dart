import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

void main() {
  group(InMemoryTrainingLibraryRepository, () {
    const uid = 'mock_user_123';
    final subject = InMemoryTrainingLibraryRepository(
      exercises: [
        ...sampleUserExercises.reversed,
        PrebuiltCatalogue.instance.exercises.first,
      ],
      workoutTemplates: [
        ...sampleUserWorkoutTemplates,
        PrebuiltCatalogue.instance.workoutTemplates.first,
      ],
      gymProfiles: sampleGymProfiles,
      exerciseSettings: sampleExerciseSettings,
      workoutSettings: sampleWorkoutSettings,
    );

    test("reads $uid's own documents only", () async {
      expect(
        [for (final e in await subject.watchUserExercises(uid).first) e.name],
        ['Plank', 'Push Up'],
      );
      expect(
        await subject.watchUserWorkoutTemplates(uid).first,
        sampleUserWorkoutTemplates,
      );
      expect(await subject.watchGymProfiles(uid).first, sampleGymProfiles);
      expect(
        await subject.watchExerciseSettings(uid).first,
        sampleExerciseSettings,
      );
      expect(
        await subject.watchWorkoutSettings(uid).first,
        sampleWorkoutSettings.single,
      );
    });

    test("gives another user nothing, and Swift's default settings", () async {
      expect(await subject.watchUserExercises('other').first, isEmpty);
      expect(await subject.watchUserWorkoutTemplates('other').first, isEmpty);
      expect(await subject.watchGymProfiles('other').first, isEmpty);
      expect(await subject.watchExerciseSettings('other').first, isEmpty);
      final settings = await subject.watchWorkoutSettings('other').first;
      expect(settings.authorId, 'other');
      expect(settings.rirTracking, isFalse);
      expect(
        (await InMemoryTrainingLibraryRepository()
                .watchWorkoutSettings(uid)
                .first)
            .authorId,
        uid,
      );
    });
  });

  group('samples', () {
    test('build their templates from system exercises', () {
      final upper = sampleUserWorkoutTemplates.first;
      expect(upper.exercises.first.exercise.id, 'system-barbell-bench-press');
      expect(upper.exercises.first.id, 'user-workout-upper_1');
      expect(sampleUserWorkoutTemplates.last.exercises, hasLength(5));
    });

    test('give the sample gym the whole catalogue', () {
      final gym = sampleGymProfiles.single;
      expect(
        gym.plateLoadedMachines,
        GymEquipmentCatalogue.instance.plateLoadedMachines,
      );
      expect(
        GymProfileModel.fromFirestore(gym.toFirestore()).toFirestore(),
        gym.toFirestore(),
      );
    });
  });
}
