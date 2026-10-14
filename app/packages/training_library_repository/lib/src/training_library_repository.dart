import 'package:compound_models/compound_models.dart';

/// The signed-in user's training library, read-only, beside the bundled
/// system exercises and workouts (`PrebuiltCatalogue`).
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

  /// The per-exercise settings at `users/{uid}/exercise_settings`, one per
  /// exercise id.
  Stream<List<ExerciseSettingsModel>> watchExerciseSettings(String uid);

  /// The settings at `users/{uid}/workout_settings/workout_settings`, or
  /// Swift's defaults when there is no document or it cannot be read, as
  /// `WorkoutSettingsManager` falls back.
  Stream<WorkoutSettings> watchWorkoutSettings(String uid);
}
