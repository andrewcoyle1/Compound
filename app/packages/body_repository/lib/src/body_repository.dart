import 'package:body_repository/src/body_rules.dart';
import 'package:compound_models/compound_models.dart';

/// The signed-in user's body data, steps and weight goal.
abstract interface class BodyRepository {
  /// The entries at `users/{uid}/body_measurements` whose author is [uid],
  /// as the Swift app's listener reads them, less deleted ones (screens
  /// leave out any with a `deleted_at`), oldest first. Re-emitted on every
  /// change.
  Stream<List<BodyMeasurementEntry>> watchMeasurements(String uid);

  /// The step counts at `users/{uid}/steps` whose author is [uid], less
  /// deleted ones, oldest first. Swift listens to the whole collection and
  /// its screens filter on author and `deleted_at`, as this does.
  Stream<List<StepsModel>> watchSteps(String uid);

  /// The settings at `users/{uid}/analytics_settings/analytics_settings`,
  /// or Swift's defaults when there is no document or it cannot be read, as
  /// `AnalyticsSettingsManager` falls back.
  Stream<AnalyticsSettings> watchAnalyticsSettings(String uid);

  /// Saves [settings] whole to
  /// `users/{settings.authorId}/analytics_settings/analytics_settings`,
  /// merged, as `AnalyticsSettingsManager.saveSettings` does (`saveDocument`
  /// is `setData(merge: true)`). A null `dailyStepGoal` keeps the stored
  /// goal, as in Swift.
  Future<void> saveAnalyticsSettings(AnalyticsSettings settings);

  /// The goal at `users/{uid}/goals/{currentGoalId ?? uid}`, as
  /// `GoalManager.signIn` picks it: pass the user's `currentGoalId`. Goals
  /// saved before goal ids live under the user id. Null when there is none
  /// or it cannot be read. Whatever its status, as Swift's `currentGoal`.
  Stream<WeightGoal?> watchCurrentGoal(String uid, {String? currentGoalId});

  /// Saves [entry] to `users/{entry.authorId}/body_measurements/{entry.id}`,
  /// merged over anything there, as `BodyMeasurementsManager
  /// .saveBodyMeasurement` does (`BodyMeasurementsManager.swift:56`;
  /// `saveDocument` is `setData(merge: true)`). The Apple Health export
  /// Swift does first is `health_repository`'s `saveMeasurement`.
  ///
  /// A merge leaves a field the entry omits as it was, so this cannot clear
  /// a value: Swift's `withCleared` has exactly that bug
  /// (`swift-findings.md`). Use [clearMeasurementFields] to clear.
  Future<void> saveMeasurement(BodyMeasurementEntry entry);

  /// Removes [fields] from `users/{uid}/body_measurements/{entryId}`, with
  /// `FieldValue.delete()`, so the value is gone on every device (Swift's
  /// merge cannot do this; see [saveMeasurement]).
  ///
  /// Each field must be one of [clearableMeasurementFields]: an optional
  /// value, never one the model requires. Anything else throws an
  /// [ArgumentError] before writing. An `update`, so a missing entry is
  /// refused with `not-found`.
  Future<void> clearMeasurementFields(
    String uid,
    String entryId,
    Set<String> fields,
  );

  /// Saves [steps] to `users/{steps.authorId}/steps/{steps.id}`, merged, as
  /// `StepsManager.createStepsEntry` and its Apple Health import do
  /// (`saveDocument` is `setData(merge: true)`).
  Future<void> saveSteps(StepsModel steps);

  /// Saves a new [goal] to `users/{goal.userId}/goals/{goal.goalId}`,
  /// merged, as `GoalManager.saveGoal` does (`GoalManager.swift:44-47`).
  ///
  /// Only for a goal with a new id. The rules freeze `goal_id`, `user_id`,
  /// `starting_weight_kg` and `created_at` once written, so saving over an
  /// existing goal with any of them changed is refused; a fresh start is a
  /// new goal, after which the caller points `submitted_current_goal_id` at
  /// it and abandons the old one with [abandonGoal].
  Future<void> saveGoal(WeightGoal goal);

  /// Marks the goal at `users/{uid}/goals/{goalId}` abandoned, writing
  /// `status` and nothing else, as `GoalManager.saveGoal` does for the goal
  /// a new one replaces (`GoalManager.swift:52-58`). Swift does this only
  /// when the replaced goal is active, and ignores a failure. Fails, as
  /// Firestore's `update` does, when there is no such goal.
  Future<void> abandonGoal(String uid, String goalId);
}
