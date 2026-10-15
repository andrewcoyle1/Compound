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

  /// Sets only `week_streak_count` on a stored session, so it cannot undo
  /// an edit made meanwhile (`setWeekStreakCount`). Fails, as Firestore's
  /// update does, when there is no such session.
  Future<void> updateWeekStreakCount(String uid, String sessionId, int weeks);
}
