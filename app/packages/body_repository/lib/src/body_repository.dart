import 'package:compound_models/compound_models.dart';

/// The signed-in user's body data, steps and weight goal, read-only.
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

  /// The goal at `users/{uid}/goals/{currentGoalId ?? uid}`, as
  /// `GoalManager.signIn` picks it: pass the user's `currentGoalId`. Goals
  /// saved before goal ids live under the user id. Null when there is none
  /// or it cannot be read. Whatever its status, as Swift's `currentGoal`.
  Stream<WeightGoal?> watchCurrentGoal(String uid, {String? currentGoalId});
}
