/// Finishing a workout (`WorkoutFinishing.swift` and the tracker's retry,
/// `WorkoutTrackerPresenter+Finish`): the session saved, retried while the
/// failure could pass, the device's copy forgotten once it is stored, and
/// the weekly streak stamped on the session and copied to the private
/// settings for the streak reminder.
///
/// Only what a standalone session needs: a mesocycle's rest days, moving
/// the macrocycle on, Strava, Apple Health and the Live Activity are later
/// slices'.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart' as m;
import 'package:training_session/src/active_session_store.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// How a failed save is retried (`RetryBackoff`).
class const RetryBackoff({
  /// The wait before the first retry.
  required final Duration baseDelay,

  /// What each later wait is multiplied by.
  required final double multiplier,

  /// Tries in all, the first included.
  required final int maxAttempts,

  /// The most spent waiting.
  required final Duration maxTotalDelay,
}) {
  /// Four tries over at most a minute: the save, then retries after 2 s,
  /// 6 s and 18 s.
  static const workoutSave = RetryBackoff(
    baseDelay: Duration(seconds: 2),
    multiplier: 3,
    maxAttempts: 4,
    maxTotalDelay: Duration(seconds: 60),
  );

  /// The wait before [attempt] (1 is the first try, which never waits), or
  /// `null` once past the schedule.
  Duration? delayBefore(int attempt, {required Duration alreadyWaited}) {
    if (attempt <= 1 || attempt > maxAttempts) return null;
    final delay = Duration(
      microseconds:
          (baseDelay.inMicroseconds * math.pow(multiplier, attempt - 2))
              .round(),
    );
    return alreadyWaited + delay > maxTotalDelay ? null : delay;
  }
}

/// Firestore's own retry set for writes: everything else it reports is a
/// verdict on the request, the same every time (`isTransientWriteFailure`).
const transientFirestoreCodes = {
  'unknown',
  'deadline-exceeded',
  'resource-exhausted',
  'aborted',
  'internal',
  'unavailable',
};

/// Whether trying the same write again could work. Anything not known to
/// pass is treated as permanent.
bool isTransientWriteFailure(Object error) => switch (error) {
  TimeoutException() => true,
  FirebaseException(:final code) => transientFirestoreCodes.contains(code),
  _ => false,
};

/// What to tell the user about the save; nothing when it works first time.
enum SaveProgress {
  /// It failed and is being tried again.
  retrying,

  /// A retry worked.
  saved,

  /// It will not be saved now; the workout is still on the device.
  failed,
}

/// How finishing went.
class const FinishResult({
  /// The session is stored and the device has forgotten it.
  required final bool saved,

  /// The streak stamped, when the save worked and stamping did.
  final maths.WeeklyStreak? streak,

  /// Why the streak was not stamped; the session is saved either way.
  final Object? streakError,
});

/// The streak as of a moment, with what the reminder needs beside it
/// (`WeeklyStreak.weekEndsAt`, `.lastTrainedAt`).
class const StreakRecord({
  required final maths.WeeklyStreak streak,

  /// The local midnight the week ends at.
  required final DateTime weekEndsAt,

  /// The latest counted session's start.
  required final DateTime? lastTrainedAt,
}) {
  /// [sessions] counted for [uid] as of [now] (finished, not a rest day,
  /// not deleted, not in the future), by local day, in weeks starting on
  /// [firstWeekday] (ISO), each judged by [goal] (`WeeklyStreak.make`).
  factory of(
    Iterable<m.WorkoutSessionModel> sessions, {
    required String uid,
    required int goal,
    required DateTime now,
    required int firstWeekday,
  }) {
    final counted = sessions
        .where(
          (s) =>
              s.authorId == uid &&
              s.endedAt != null &&
              !s.isRestDay &&
              s.deletedAt == null &&
              !s.dateCreated.isAfter(now),
        )
        .toList();
    final today = _dayKey(now);
    final streak = maths.WeeklyStreak.make(
      sessionDays: [for (final s in counted) _dayKey(s.dateCreated)],
      today: today,
      goal: goal,
      firstWeekday: firstWeekday,
    );
    final weekEnd = DateTime.parse(
      maths.addDays(maths.weekStartOf(today, firstWeekday: firstWeekday), 7),
    );
    DateTime? last;
    for (final s in counted) {
      if (last == null || s.dateCreated.isAfter(last)) last = s.dateCreated;
    }
    return StreakRecord(
      streak: streak,
      weekEndsAt: DateTime(weekEnd.year, weekEnd.month, weekEnd.day),
      lastTrainedAt: last,
    );
  }

  /// The private settings' streak fields as `streakReminder` reads them.
  m.PrivateUserSettings get settings => m.PrivateUserSettings(
    weekStreak: streak.weeks,
    weekSessions: streak.sessionsThisWeek,
    weekGoal: streak.goal,
    weekEndsAt: weekEndsAt,
    lastTrainedAt: lastTrainedAt,
  );

  /// Whether [current] already holds these figures, to the millisecond
  /// Firestore keeps (`recordWeeklyStreak` writes only a change).
  bool isRecordedIn(m.PrivateUserSettings? current) {
    bool same(DateTime? a, DateTime? b) =>
        a?.millisecondsSinceEpoch == b?.millisecondsSinceEpoch;
    return current != null &&
        current.weekStreak == streak.weeks &&
        current.weekSessions == streak.sessionsThisWeek &&
        current.weekGoal == streak.goal &&
        same(current.weekEndsAt, weekEndsAt) &&
        same(current.lastTrainedAt, lastTrainedAt);
  }

  static String _dayKey(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-'
        '${two(local.month)}-${two(local.day)}';
  }
}

/// Stores a finished workout and does what follows.
class WorkoutFinisher {
  /// Writes through `sessions` and `users`, and forgets the workout in
  /// `store` once it is saved.
  new({
    required this._sessions,
    required this._users,
    required this._store,
    this._backoff = RetryBackoff.workoutSave,
    this._wait = _delay,
    this._clock = DateTime.now,
  });

  final WorkoutSessionRepository _sessions;
  final UserRepository _users;
  final ActiveSessionStore _store;
  final RetryBackoff _backoff;
  final Future<void> Function(Duration) _wait;
  final DateTime Function() _clock;

  static Future<void> _delay(Duration duration) =>
      Future<void>.delayed(duration);

  /// Saves [session] (already ended, `ActiveSessionController.finish`),
  /// retrying a failure that could pass while [currentUid] is still its
  /// author: a retry after sign-out would write it into whoever signed in
  /// next. Once saved, the device forgets it and the streak is stamped,
  /// counting [history] (the user's other sessions) with it, by the stored
  /// [weeklySessionGoal], against [privateSettings].
  Future<FinishResult> finish(
    m.WorkoutSessionModel session, {
    required List<m.WorkoutSessionModel> history,
    required int? weeklySessionGoal,
    required m.PrivateUserSettings? privateSettings,
    required int firstWeekday,
    required String? Function() currentUid,
    void Function(SaveProgress progress)? onProgress,
  }) async {
    final uid = session.authorId;
    var outcome = await _attempt(session);
    if (outcome == _Outcome.transient) {
      var attempt = 2;
      var waited = Duration.zero;
      while (true) {
        final delay = _backoff.delayBefore(attempt, alreadyWaited: waited);
        if (delay == null) break;
        onProgress?.call(SaveProgress.retrying);
        await _wait(delay);
        waited += delay;
        if (currentUid() != uid) return const FinishResult(saved: false);
        outcome = await _attempt(session);
        if (outcome != _Outcome.transient) break;
        attempt++;
      }
      if (outcome == _Outcome.saved) onProgress?.call(SaveProgress.saved);
    }
    if (outcome != _Outcome.saved) {
      onProgress?.call(SaveProgress.failed);
      return const FinishResult(saved: false);
    }
    await _store.clear();

    // Best-effort, after the save: a session without it reads as before.
    final record = StreakRecord.of(
      [
        for (final s in history)
          if (s.id != session.id) s,
        session,
      ],
      uid: uid,
      goal: maths.weeklySessionGoal(weeklySessionGoal),
      now: _clock(),
      firstWeekday: firstWeekday,
    );
    try {
      await _sessions.updateWeekStreakCount(
        uid,
        session.id,
        record.streak.weeks,
      );
      if (!record.isRecordedIn(privateSettings)) {
        await _users.mergePrivateSettings(uid, record.settings);
      }
    } on Object catch (error) {
      return FinishResult(saved: true, streakError: error);
    }
    return FinishResult(saved: true, streak: record.streak);
  }

  Future<_Outcome> _attempt(m.WorkoutSessionModel session) async {
    try {
      await _sessions.saveSession(session.authorId, session);
      return _Outcome.saved;
    } on Object catch (error) {
      return isTransientWriteFailure(error)
          ? _Outcome.transient
          : _Outcome.permanent;
    }
  }
}

enum _Outcome { saved, transient, permanent }
