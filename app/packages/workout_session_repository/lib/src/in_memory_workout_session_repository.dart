import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:compound_models/compound_models.dart';
import 'package:workout_session_repository/src/workout_session_repository.dart';

/// [WorkoutSessionRepository] in memory, for the staging flavor and tests.
/// Seed it with `sampleWorkoutSessions`.
///
/// Writes behave as Firestore's do: a save merges over the stored session
/// field by field, an update of a missing session fails with `not-found`,
/// and every watcher sees the change.
class InMemoryWorkoutSessionRepository implements WorkoutSessionRepository {
  /// Creates an [InMemoryWorkoutSessionRepository] holding [sessions], each
  /// in its author's collection.
  new({required List<WorkoutSessionModel> sessions})
    : _sessions = List.of(sessions);

  final List<WorkoutSessionModel> _sessions;
  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<List<WorkoutSessionModel>> watchSessions(String uid) => Stream.multi((
    listener,
  ) {
    List<WorkoutSessionModel> read() => [
      for (final session in _sessions)
        if (session.authorId == uid) session,
    ];
    listener.add(read());
    final subscription = _changes.stream.listen((_) => listener.add(read()));
    // Not `subscription.cancel` itself: `first` would wait on the Future
    // that returns, which never completes under a widget test's fake
    // clock.
    listener.onCancel = () => unawaited(subscription.cancel());
  });

  @override
  Future<WorkoutSessionModel?> session(String uid, String id) async {
    final index = _indexOf(uid, id);
    return index < 0 ? null : _sessions[index];
  }

  @override
  Future<void> saveSession(String uid, WorkoutSessionModel session) async {
    final index = _indexOf(uid, session.id);
    if (index < 0) {
      _sessions.add(session);
    } else {
      _sessions[index] = WorkoutSessionModel.fromFirestore({
        ..._sessions[index].toFirestore(),
        ...session.toFirestore(),
      });
    }
    _changes.add(null);
  }

  @override
  Future<void> updateWeekStreakCount(
    String uid,
    String sessionId,
    int weeks,
  ) async {
    final index = _indexOf(uid, sessionId);
    if (index < 0) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message:
            'No document to update: users/$uid/workout_sessions/$sessionId',
      );
    }
    _sessions[index] = WorkoutSessionModel.fromFirestore({
      ..._sessions[index].toFirestore(),
      WorkoutSessionModelKeys.weekStreakCount: weeks,
    });
    _changes.add(null);
  }

  int _indexOf(String uid, String id) => _sessions.indexWhere(
    (session) => session.authorId == uid && session.id == id,
  );
}
