import 'package:compound_models/compound_models.dart';

/// The signed-in user's workout sessions, read-only.
abstract interface class WorkoutSessionRepository {
  /// Every session at `users/{uid}/workout_sessions` whose author is [uid],
  /// as the Swift app's listener reads them, re-emitted on every change.
  Stream<List<WorkoutSessionModel>> watchSessions(String uid);

  /// The session [id] of [uid], or null when there is none or it cannot be
  /// read.
  Future<WorkoutSessionModel?> session(String uid, String id);
}
