import 'package:compound_models/compound_models.dart';
import 'package:workout_session_repository/src/workout_session_repository.dart';

/// [WorkoutSessionRepository] over a fixed list, for the staging flavor
/// and tests. Seed it with `sampleWorkoutSessions`.
class InMemoryWorkoutSessionRepository implements WorkoutSessionRepository {
  /// Creates an [InMemoryWorkoutSessionRepository] holding [sessions].
  new({required List<WorkoutSessionModel> sessions})
    : _sessions = List.unmodifiable(sessions);

  final List<WorkoutSessionModel> _sessions;

  @override
  Stream<List<WorkoutSessionModel>> watchSessions(String uid) => Stream.value([
    for (final session in _sessions)
      if (session.authorId == uid) session,
  ]);

  @override
  Future<WorkoutSessionModel?> session(String uid, String id) async {
    for (final session in _sessions) {
      if (session.authorId == uid && session.id == id) return session;
    }
    return null;
  }
}
