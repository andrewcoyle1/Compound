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

  /// Saves [session] as [saveSession] does, for a finished workout whose
  /// device copy is kept until the server has it. Completes, as
  /// [saveSession] does, once the device has the session; `confirmed` then
  /// completes once the server has stored it, or fails with its refusal
  /// (which also goes to `onWriteError`). Offline, `confirmed` waits, and a
  /// relaunch loses it: [sessionOnServer] answers then.
  Future<({Future<void> confirmed})> saveSessionConfirmed(
    String uid,
    WorkoutSessionModel session,
  );

  /// Whether the server holds the session [id] of [uid], once it has
  /// answered for every write to it this device is still sending: false
  /// when it refused the save. Offline it waits. After a relaunch, as
  /// [saveSessionConfirmed]'s answer did not survive it.
  Future<bool> sessionOnServer(String uid, String id);

  /// Writes only what editing a finished workout changes
  /// (`WorkoutSessionDetailPresenter.saveChanges` and the timing sheets):
  /// [EditedSessionFields], with a cleared `notes` deleted, as an `update`.
  /// Likes, the streak stamp and the Strava id are never part of it, so one
  /// written meanwhile survives. Fails, as Firestore's update does, when
  /// there is no such session.
  Future<void> updateEditedSession(String uid, WorkoutSessionModel session);

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

/// The fields [WorkoutSessionRepository.updateEditedSession] writes.
abstract final class EditedSessionFields {
  /// Every one of them.
  static const List<String> all = [
    WorkoutSessionModelKeys.exercises,
    WorkoutSessionModelKeys.notes,
    WorkoutSessionModelKeys.dateCreated,
    WorkoutSessionModelKeys.endedAt,
    WorkoutSessionModelKeys.dateModified,
  ];

  /// [session]'s values for them, a cleared one as [cleared].
  static Map<String, Object?> of(
    WorkoutSessionModel session, {
    required Object cleared,
  }) {
    final encoded = session.toFirestore();
    return {for (final key in all) key: encoded[key] ?? cleared};
  }
}
