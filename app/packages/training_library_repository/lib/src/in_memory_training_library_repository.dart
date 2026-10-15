import 'dart:async';

import 'package:compound_models/compound_models.dart';
import 'package:training_library_repository/src/training_library_repository.dart';

/// [TrainingLibraryRepository] in memory, for the staging flavor and tests.
/// Seed it from `sample_training_library.dart`.
///
/// A saved gym profile merges over the stored one field by field, as a
/// Firestore merge does, and every gym profile watcher sees the change.
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
       _gymProfiles = List.of(gymProfiles),
       _exerciseSettings = List.unmodifiable(exerciseSettings),
       _workoutSettings = List.unmodifiable(workoutSettings);

  final List<ExerciseModel> _exercises;
  final List<WorkoutTemplateModel> _workoutTemplates;
  final List<GymProfileModel> _gymProfiles;
  final List<ExerciseSettingsModel> _exerciseSettings;
  final List<WorkoutSettings> _workoutSettings;
  final _gymProfileChanges = StreamController<void>.broadcast(sync: true);

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
  Stream<List<GymProfileModel>> watchGymProfiles(String uid) =>
      Stream.multi((listener) {
        List<GymProfileModel> read() => [
          for (final profile in _gymProfiles)
            if (profile.authorId == uid) profile,
        ];
        listener.add(read());
        final subscription = _gymProfileChanges.stream.listen(
          (_) => listener.add(read()),
        );
        // Not `subscription.cancel` itself: `first` would wait on the
        // Future that returns, which never completes under a widget test's
        // fake clock.
        listener.onCancel = () => unawaited(subscription.cancel());
      });

  @override
  Future<void> saveGymProfile(GymProfileModel profile) async {
    final index = _gymProfiles.indexWhere(
      (stored) =>
          stored.authorId == profile.authorId && stored.id == profile.id,
    );
    if (index < 0) {
      _gymProfiles.add(profile);
    } else {
      _gymProfiles[index] = GymProfileModel.fromFirestore({
        ..._gymProfiles[index].toFirestore(),
        ...profile.toFirestore(),
      });
    }
    _gymProfileChanges.add(null);
  }

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
