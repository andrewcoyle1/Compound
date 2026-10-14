import 'package:compound_models/compound_models.dart';
import 'package:training_library_repository/src/training_library_repository.dart';

/// [TrainingLibraryRepository] over fixed data, for the staging flavor and
/// tests. Seed it from `sample_training_library.dart`.
class InMemoryTrainingLibraryRepository implements TrainingLibraryRepository {
  /// Creates an [InMemoryTrainingLibraryRepository] holding everyone's
  /// documents; each read keeps the ones its user owns.
  new({
    List<ExerciseModel> exercises = const [],
    List<WorkoutTemplateModel> workoutTemplates = const [],
    List<GymProfileModel> gymProfiles = const [],
    List<ExerciseSettingsModel> exerciseSettings = const [],
    List<WorkoutSettings> workoutSettings = const [],
  }) : _exercises = List.unmodifiable(exercises),
       _workoutTemplates = List.unmodifiable(workoutTemplates),
       _gymProfiles = List.unmodifiable(gymProfiles),
       _exerciseSettings = List.unmodifiable(exerciseSettings),
       _workoutSettings = List.unmodifiable(workoutSettings);

  final List<ExerciseModel> _exercises;
  final List<WorkoutTemplateModel> _workoutTemplates;
  final List<GymProfileModel> _gymProfiles;
  final List<ExerciseSettingsModel> _exerciseSettings;
  final List<WorkoutSettings> _workoutSettings;

  @override
  Stream<List<ExerciseModel>> watchUserExercises(String uid) => Stream.value(
    _exercises.where((exercise) => exercise.authorId == uid).toList()
      ..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Stream<List<WorkoutTemplateModel>> watchUserWorkoutTemplates(String uid) =>
      Stream.value([
        for (final template in _workoutTemplates)
          if (template.authorId == uid) template,
      ]);

  @override
  Stream<List<GymProfileModel>> watchGymProfiles(String uid) => Stream.value([
    for (final profile in _gymProfiles)
      if (profile.authorId == uid) profile,
  ]);

  @override
  Stream<List<ExerciseSettingsModel>> watchExerciseSettings(String uid) =>
      Stream.value([
        for (final settings in _exerciseSettings)
          if (settings.authorId == uid) settings,
      ]);

  @override
  Stream<WorkoutSettings> watchWorkoutSettings(String uid) => Stream.value(
    _workoutSettings
            .where((settings) => settings.authorId == uid)
            .firstOrNull ??
        WorkoutSettings(authorId: uid),
  );
}
