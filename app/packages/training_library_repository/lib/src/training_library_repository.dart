import 'package:compound_models/compound_models.dart';

/// The signed-in user's training library, beside the bundled system
/// exercises and workouts (`PrebuiltCatalogue`). Read-only but for gym
/// profiles.
abstract interface class TrainingLibraryRepository {
  /// The exercises at `exercise_templates` whose author is [uid], by name,
  /// as `ExerciseModelManager`'s listener reads them. Re-emitted on every
  /// change.
  Stream<List<ExerciseModel>> watchUserExercises(String uid);

  /// The templates at `users/{uid}/workout_templates`, in Firestore's
  /// order, as `WorkoutTemplateManager` reads them.
  Stream<List<WorkoutTemplateModel>> watchUserWorkoutTemplates(String uid);

  /// The profiles at `users/{uid}/gym_profiles`, each list completed from
  /// the catalogue ([GymProfileModel.fromFirestore]).
  Stream<List<GymProfileModel>> watchGymProfiles(String uid);

  /// Saves [profile] to `users/{profile.authorId}/gym_profiles/{profile.id}`,
  /// merged over anything there, as `GymProfileManager.saveGymProfile` does
  /// (`GymProfileManager.swift:40`; `saveDocument` is `setData(merge:
  /// true)`). Every equipment list is written whole. The picture upload
  /// Swift can do first is not ported (M5).
  Future<void> saveGymProfile(GymProfileModel profile);

  /// The per-exercise settings at `users/{uid}/exercise_settings`, one per
  /// exercise id.
  Stream<List<ExerciseSettingsModel>> watchExerciseSettings(String uid);

  /// The settings at `users/{uid}/workout_settings/workout_settings`, or
  /// Swift's defaults when there is no document or it cannot be read, as
  /// `WorkoutSettingsManager` falls back.
  Stream<WorkoutSettings> watchWorkoutSettings(String uid);

  /// Saves [settings] at `users/{uid}/exercise_settings/{id}`, merged over
  /// what is stored (`ExerciseSettingsManager.setNote` and
  /// `setRestOverride`; the sync engine's `saveDocument` merges). As in
  /// Swift, a field left empty is left as it was stored, not cleared.
  Future<void> saveExerciseSettings(String uid, ExerciseSettingsModel settings);
}
