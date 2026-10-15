import 'package:compound_models/compound_models.dart';
import 'package:program_repository/src/gym_defaults.dart';
import 'package:program_repository/src/import/program_importer.dart';
import 'package:program_repository/src/program_repository.dart';
import 'package:program_repository/src/program_rules.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';

/// Sets up the user's training across the repositories, in the order the
/// Swift app writes: starting a prebuilt program, and saving a gym and
/// making it the usual one.
class TrainingSetupService {
  /// Creates a [TrainingSetupService] writing through `programs`, `library`
  /// and `users`. `now` and `newId` are the clock and the id maker,
  /// replaceable in tests.
  new({
    required this._programs,
    required this._library,
    required this._users,
    this._now = DateTime.now,
    this._newId = newUuid,
  });

  final ProgramRepository _programs;
  final TrainingLibraryRepository _library;
  final UserRepository _users;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Starts [template] for [uid], as `CoreInteractor.startPrebuiltMesocycle`
  /// does (`MesocycleManager.swift:267`), and returns the user's copy:
  ///
  /// 1. saves the user's own copy of it ([copyMesocycle]);
  /// 2. ends every other running macrocycle (`MacrocycleManager.start`);
  /// 3. saves a new macrocycle of the copy alone, active from its first
  ///    microcycle (`setActiveMesocycle`, `startMacrocycle`);
  /// 4. points the profile's `submitted_active_mesocycle_id` at the copy.
  ///
  /// Each step waits for the one before, and a failure stops there, as in
  /// Swift. The copy has a new id, so Swift's shortcut for re-activating
  /// the mesocycle already under way never applies here.
  Future<Mesocycle> startPrebuiltMesocycle(
    String uid,
    Mesocycle template,
  ) async {
    final now = _now();
    final copy = copyMesocycle(
      template,
      authorId: uid,
      now: now,
      newId: _newId,
    );
    await _programs.saveMesocycle(copy);
    for (final other in await _programs.watchMacrocycles(uid).first) {
      if (!isRunning(other)) continue;
      await _programs.saveMacrocycle(
        Macrocycle.fromFirestore({
          ...other.toFirestore(),
          MacrocycleKeys.status: MacrocycleStatus.ended.value,
          MacrocycleKeys.dateModified: now,
        }),
      );
    }
    // Swift makes it `notStarted` and then `started()`, which for a
    // macrocycle never started is exactly this.
    await _programs.saveMacrocycle(
      Macrocycle(
        id: _newId(),
        authorId: uid,
        name: copy.name,
        mesocycleIds: [copy.id],
        mesocycleStartedAt: now,
        dateCreated: now,
        dateModified: now,
      ),
    );
    await _users.updateUserFields(uid, [
      UserField.submittedActiveMesocycleId(copy.id),
    ]);
    return copy;
  }

  /// Saves a library workout of [uid]'s own from the mesocycle day
  /// [template], with a new id, that no longer follows the mesocycle
  /// (`WorkoutTemplateDetailPresenter.onSaveCopyPressed`). When a workout
  /// in [library] has its name, ignoring case, it is named [copyName] of
  /// it. Returns what was saved.
  Future<WorkoutTemplateModel> saveWorkoutCopy(
    String uid,
    WorkoutTemplateModel template, {
    required Iterable<WorkoutTemplateModel> library,
    required String Function(String name) copyName,
  }) async {
    final now = _now();
    final copy = WorkoutTemplateModel(
      workoutId: _newId(),
      authorId: uid,
      name: workoutCopyName(template.name, library, copyName),
      description: template.description,
      gymProfileId: template.gymProfileId,
      dateCreated: now,
      dateModified: now,
      exercises: template.exercises,
    );
    await _library.saveWorkoutTemplate(copy);
    return copy;
  }

  /// Saves an imported program in Swift's order
  /// (`ImportProgramPresenter.save`): the exercises it brings
  /// ([ProgramImportResult.newExercises], then [created]), the
  /// mesocycles, then the macrocycle, not started. A failure stops there.
  Future<void> saveImportedProgram(
    ProgramImportResult result, {
    List<ExerciseModel> created = const [],
  }) async {
    for (final exercise in [...result.newExercises, ...created]) {
      await _library.saveUserExercise(exercise);
    }
    for (final mesocycle in result.mesocycles) {
      await _programs.saveMesocycle(mesocycle);
    }
    await _programs.saveMacrocycle(result.macrocycle);
  }

  /// A new exercise of [uid]'s named [name], for a name an import could
  /// not match: weight and reps, no muscle groups yet, one-sided when the
  /// sheet counts its reps per side (`ImportProgramPresenter.newExercise`).
  ExerciseModel newImportedExercise(
    String uid,
    String name, {
    required bool perSide,
  }) {
    final now = _now();
    return ExerciseModel(
      id: _newId(),
      authorId: uid,
      name: name,
      trackableMetrics: const [
        TrackableExerciseMetric.weight,
        TrackableExerciseMetric.reps,
      ],
      laterality: perSide ? Laterality.unilateral : Laterality.bilateral,
      muscleGroups: const {},
      isBodyweight: false,
      rangeOfMotion: 0,
      stability: 0,
      bodyWeightContribution: 0,
      alternateNames: const [],
      isSystemExercise: false,
      dateCreated: now,
      dateModified: now,
      clickCount: 0,
      bookmarkCount: 0,
      favouriteCount: 0,
    );
  }

  /// Saves [draft] as `GymProfilePresenter` does on Continue
  /// ([gymProfileToSave]: a blank name becomes [untitledName], stamped
  /// modified now), and returns what was saved. Start a new gym with
  /// [newGymProfile].
  Future<GymProfileModel> saveGymProfile(
    GymProfileModel draft, {
    String untitledName = 'Untitled Gym Profile',
  }) async {
    final profile = gymProfileToSave(
      draft,
      now: _now(),
      untitledName: untitledName,
    );
    await _library.saveGymProfile(profile);
    return profile;
  }

  /// Makes [gymProfileId] the user's usual gym
  /// (`submitted_favourite_gym_profile_id`). Onboarding calls it after
  /// [saveGymProfile] succeeds; Swift logs a failure here and carries on.
  Future<void> setFavouriteGymProfile(String uid, String gymProfileId) =>
      _users.updateUserFields(uid, [
        UserField.submittedFavouriteGymProfileId(gymProfileId),
      ]);
}

/// What a copy of the workout [name] is called: [copyName] of it when a
/// workout in [library] already has the name, ignoring case, else [name].
String workoutCopyName(
  String name,
  Iterable<WorkoutTemplateModel> library,
  String Function(String name) copyName,
) {
  final lower = name.toLowerCase();
  return library.any((other) => other.name.toLowerCase() == lower)
      ? copyName(name)
      : name;
}
