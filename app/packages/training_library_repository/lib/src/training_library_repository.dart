import 'package:compound_models/compound_models.dart';

/// The signed-in user's training library, beside the bundled system
/// exercises and workouts (`PrebuiltCatalogue`). Read-only but for gym
/// profiles, the training settings, and the exercises and workouts a
/// program import or a saved copy adds.
abstract interface class TrainingLibraryRepository {
  /// The exercises at `exercise_templates` whose author is [uid], by name,
  /// as `ExerciseModelManager`'s listener reads them. Re-emitted on every
  /// change.
  Stream<List<ExerciseModel>> watchUserExercises(String uid);

  /// The templates at `users/{uid}/workout_templates`, in Firestore's
  /// order, as `WorkoutTemplateManager` reads them.
  Stream<List<WorkoutTemplateModel>> watchUserWorkoutTemplates(String uid);

  /// Saves [exercise] to `exercise_templates/{exercise.id}`, merged, as
  /// `ExerciseModelManager.saveExerciseModel` does without a picture.
  Future<void> saveUserExercise(ExerciseModel exercise);

  /// Deletes `exercise_templates/{exerciseId}`
  /// (`ExerciseModelManager.deleteExerciseModel`). The rules allow only its
  /// author.
  Future<void> deleteUserExercise(String exerciseId);

  /// Saves [template] to `users/{template.authorId}/workout_templates/
  /// {template.workoutId}`, merged, as `WorkoutTemplateManager
  /// .saveWorkoutTemplate` does without a picture. Every field the model
  /// knows is written as it is in [template]: an optional left null is
  /// deleted, where Swift's merge would keep the stored value. A field this
  /// app does not know survives.
  Future<void> saveWorkoutTemplate(WorkoutTemplateModel template);

  /// Deletes `users/{uid}/workout_templates/{workoutId}`
  /// (`WorkoutTemplateManager.deleteWorkoutTemplate`).
  Future<void> deleteWorkoutTemplate(String uid, String workoutId);

  /// The profiles at `users/{uid}/gym_profiles`, each list completed from
  /// the catalogue ([GymProfileModel.fromFirestore]).
  Stream<List<GymProfileModel>> watchGymProfiles(String uid);

  /// Saves [profile] to `users/{profile.authorId}/gym_profiles/{profile.id}`,
  /// as `GymProfileManager.saveGymProfile` does (`GymProfileManager.swift:40`;
  /// `saveDocument` is `setData(merge: true)`), so a field this app does not
  /// know survives. Every field it knows is written: each equipment list
  /// whole, and a cleared picture or deletion date as a delete, which Swift's
  /// merge would keep. The picture upload Swift can do first is not ported.
  Future<void> saveGymProfile(GymProfileModel profile);

  /// Deletes the profile [profileId] at `users/{uid}/gym_profiles`, as
  /// `GymProfileManager.deleteGymProfile` does (`deleteDocument`).
  Future<void> deleteGymProfile(String uid, String profileId);

  /// The per-exercise settings at `users/{uid}/exercise_settings`, one per
  /// exercise id.
  Stream<List<ExerciseSettingsModel>> watchExerciseSettings(String uid);

  /// The settings at `users/{uid}/workout_settings/workout_settings`, or
  /// Swift's defaults when there is no document or it cannot be read, as
  /// `WorkoutSettingsManager` falls back.
  Stream<WorkoutSettings> watchWorkoutSettings(String uid);

  /// Saves [settings] whole to
  /// `users/{settings.authorId}/workout_settings/workout_settings`, as
  /// `WorkoutSettingsManager.saveSettings` does, creating it if needed.
  ///
  /// Every field the model knows is written as it is in [settings]: an
  /// optional left null is deleted and `rest_durations_by_exercise_type` is
  /// replaced whole, so a document saved here reads back as [settings]. A
  /// field this app does not know survives. Swift's `setData(merge: true)`
  /// keeps the stored value instead, so its "Off" for the superset rest and
  /// "Reset Default Timers" never reach Firestore (`swift-findings.md`);
  /// this writes the same shape without that bug.
  Future<void> saveWorkoutSettings(WorkoutSettings settings);

  /// Deletes the rest override from `users/{uid}/exercise_settings/
  /// {exerciseId}`, leaving its note. Swift sets it to nil and merges, which
  /// keeps the stored override (`swift-findings.md`). An `update`, so a
  /// missing document is refused with `not-found`.
  Future<void> clearExerciseRestOverride(String uid, String exerciseId);

  /// Saves [settings] at `users/{uid}/exercise_settings/{id}`, merged over
  /// what is stored (`ExerciseSettingsManager.setNote` and
  /// `setRestOverride`; the sync engine's `saveDocument` merges). As in
  /// Swift, a field left empty is left as it was stored, not cleared.
  Future<void> saveExerciseSettings(String uid, ExerciseSettingsModel settings);
}
