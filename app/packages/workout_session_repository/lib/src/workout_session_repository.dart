import 'package:compound_models/compound_models.dart';

/// The signed-in user's workout sessions.
abstract interface class WorkoutSessionRepository {
  /// Every session at `users/{uid}/workout_sessions` whose author is [uid],
  /// as the Swift app's listener reads them, re-emitted on every change.
  Stream<List<WorkoutSessionModel>> watchSessions(String uid);

  /// The session [id] of [uid], or null when there is none or it cannot be
  /// read.
  Future<WorkoutSessionModel?> session(String uid, String id);

  /// Saves [session] whole, merged over what is stored, so a field this
  /// build does not know survives (`WorkoutSessionManager.saveWorkoutSession`;
  /// the sync engine's `saveDocument` is `setData(merge: true)`).
  Future<void> saveSession(String uid, WorkoutSessionModel session);

  /// Deletes the session [id] of [uid] (`WorkoutSessionManager
  /// .deleteWorkoutSession`): unticking a rest day, or the rest a workout
  /// trained through.
  Future<void> deleteSession(String uid, String id);

  /// Sets only `week_streak_count` on a stored session, so it cannot undo
  /// an edit made meanwhile (`setWeekStreakCount`). Fails, as Firestore's
  /// update does, when there is no such session.
  Future<void> updateWeekStreakCount(String uid, String sessionId, int weeks);

  /// Sets only `strava_activity_id` on a stored session, once Strava has
  /// made the activity it was uploaded as (`setStravaActivityId`). Fails, as
  /// Firestore's update does, when there is no such session.
  Future<void> updateStravaActivityId(
    String uid,
    String sessionId,
    int activityId,
  );
}
