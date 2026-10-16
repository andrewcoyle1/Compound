import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:compound_models/compound_models.dart';
import 'package:training_library_repository/src/training_library_repository.dart';

/// [TrainingLibraryRepository] in memory, for the staging flavor and tests.
/// Seed it from `sample_training_library.dart`.
///
/// A saved gym profile or exercise settings merge over the stored ones field
/// by field, as a Firestore merge does, and every watcher sees the change.
class InMemoryTrainingLibraryRepository implements TrainingLibraryRepository {
  /// Creates an [InMemoryTrainingLibraryRepository] holding everyone's
  /// documents; each read keeps the ones its user owns.
  new({
    List<ExerciseModel> exercises = const [],
    List<WorkoutTemplateModel> workoutTemplates = const [],
    List<GymProfileModel> gymProfiles = const [],
    List<ExerciseSettingsModel> exerciseSettings = const [],
    List<WorkoutSettings> workoutSettings = const [],
  }) : _exercises = List.of(exercises),
       _workoutTemplates = List.of(workoutTemplates),
       _gymProfiles = List.of(gymProfiles),
       _exerciseSettings = List.of(exerciseSettings),
       _workoutSettings = List.of(workoutSettings);

  final List<ExerciseModel> _exercises;
  final List<WorkoutTemplateModel> _workoutTemplates;
  final List<GymProfileModel> _gymProfiles;
  final List<ExerciseSettingsModel> _exerciseSettings;
  final List<WorkoutSettings> _workoutSettings;
  final _gymProfileChanges = StreamController<void>.broadcast(sync: true);

  final _libraryChanges = StreamController<void>.broadcast(sync: true);

  /// [read] now and after every saved exercise or workout.
  Stream<T> _watchLibrary<T>(T Function() read) => Stream.multi((listener) {
    listener.add(read());
    final subscription = _libraryChanges.stream.listen(
      (_) => listener.add(read()),
    );
    // Not `subscription.cancel` itself: `first` would wait on the Future
    // that returns, which never completes under a widget test's fake clock.
    listener.onCancel = () => unawaited(subscription.cancel());
  });

  @override
  Stream<List<ExerciseModel>> watchUserExercises(String uid) => _watchLibrary(
    () =>
        _exercises.where((exercise) => exercise.authorId == uid).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Stream<List<WorkoutTemplateModel>> watchUserWorkoutTemplates(String uid) =>
      _watchLibrary(
        () => [
          for (final template in _workoutTemplates)
            if (template.authorId == uid) template,
        ],
      );

  /// Replaces a stored exercise with the same id, else adds it.
  @override
  Future<void> saveUserExercise(ExerciseModel exercise) async {
    final index = _exercises.indexWhere((stored) => stored.id == exercise.id);
    if (index < 0) {
      _exercises.add(exercise);
    } else {
      _exercises[index] = exercise;
    }
    _libraryChanges.add(null);
  }

  @override
  Future<void> deleteUserExercise(String exerciseId) async {
    _exercises.removeWhere((stored) => stored.id == exerciseId);
    _libraryChanges.add(null);
  }

  /// Replaces the author's stored workout with the same id, else adds it.
  @override
  Future<void> saveWorkoutTemplate(WorkoutTemplateModel template) async {
    final index = _workoutTemplates.indexWhere(
      (stored) =>
          stored.authorId == template.authorId &&
          stored.workoutId == template.workoutId,
    );
    if (index < 0) {
      _workoutTemplates.add(template);
    } else {
      _workoutTemplates[index] = template;
    }
    _libraryChanges.add(null);
  }

  @override
  Future<void> deleteWorkoutTemplate(String uid, String workoutId) async {
    _workoutTemplates.removeWhere(
      (stored) => stored.authorId == uid && stored.workoutId == workoutId,
    );
    _libraryChanges.add(null);
  }

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

  final _settingsChanges = StreamController<void>.broadcast(sync: true);

  @override
  Stream<List<ExerciseSettingsModel>> watchExerciseSettings(String uid) =>
      Stream.multi((listener) {
        List<ExerciseSettingsModel> read() => [
          for (final settings in _exerciseSettings)
            if (settings.authorId == uid) settings,
        ];
        listener.add(read());
        final subscription = _settingsChanges.stream.listen(
          (_) => listener.add(read()),
        );
        // Not `subscription.cancel` itself: `first` would wait on the Future
        // that returns, which never completes under a widget test's fake
        // clock.
        listener.onCancel = () => unawaited(subscription.cancel());
      });

  /// Fails with `not-found` when there are no settings, as Firestore's
  /// `update` does.
  @override
  Future<void> clearExerciseRestOverride(String uid, String exerciseId) async {
    final index = _exerciseSettings.indexWhere(
      (stored) => stored.authorId == uid && stored.id == exerciseId,
    );
    if (index < 0) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message:
            'No document to update: users/$uid/exercise_settings/'
            '$exerciseId',
      );
    }
    final stored = _exerciseSettings[index];
    _exerciseSettings[index] = ExerciseSettingsModel(
      id: stored.id,
      authorId: stored.authorId,
      note: stored.note,
    );
    _settingsChanges.add(null);
  }

  /// Merges as Firestore does: a field left empty keeps what was stored.
  @override
  Future<void> saveExerciseSettings(
    String uid,
    ExerciseSettingsModel settings,
  ) async {
    final index = _exerciseSettings.indexWhere(
      (stored) => stored.authorId == uid && stored.id == settings.id,
    );
    if (index < 0) {
      _exerciseSettings.add(settings);
    } else {
      _exerciseSettings[index] = ExerciseSettingsModel.fromFirestore({
        ..._exerciseSettings[index].toFirestore(),
        ...settings.toFirestore(),
      });
    }
    _settingsChanges.add(null);
  }

  final _workoutSettingsChanges = StreamController<void>.broadcast(sync: true);

  @override
  Stream<WorkoutSettings> watchWorkoutSettings(String uid) =>
      Stream.multi((listener) {
        WorkoutSettings read() =>
            _workoutSettings
                .where((settings) => settings.authorId == uid)
                .firstOrNull ??
            WorkoutSettings(authorId: uid);
        listener.add(read());
        final subscription = _workoutSettingsChanges.stream.listen(
          (_) => listener.add(read()),
        );
        // Not `subscription.cancel` itself: `first` would wait on the
        // Future that returns, which never completes under a widget test's
        // fake clock.
        listener.onCancel = () => unawaited(subscription.cancel());
      });

  /// Replaces the stored settings, as the Firestore save writes every
  /// field the model knows.
  @override
  Future<void> saveWorkoutSettings(WorkoutSettings settings) async {
    _workoutSettings
      ..removeWhere((stored) => stored.authorId == settings.authorId)
      ..add(settings);
    _workoutSettingsChanges.add(null);
  }
}
