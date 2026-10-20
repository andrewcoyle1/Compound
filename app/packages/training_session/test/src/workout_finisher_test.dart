// What happens once the user says they are done (WorkoutTrackerFinishTests'
// save and retry, WorkoutFinishing's streak stamp), on in-memory
// repositories.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:compound_models/compound_models.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/fixtures.dart';

FirebaseException _firestore(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

/// Sessions in memory whose saves fail with [saveErrors] first.
class _Sessions extends InMemoryWorkoutSessionRepository {
  new() : super(sessions: []);

  final List<Exception> saveErrors = [];
  Exception? streakError;
  int saveAttempts = 0;

  /// The server's answer to each save; at once when null.
  Completer<void>? server;

  /// What [sessionOnServer] answers after a relaunch.
  final onServer = Completer<bool>();

  @override
  Future<({Future<void> confirmed})> saveSessionConfirmed(
    String uid,
    m.WorkoutSessionModel session,
  ) async {
    final write = await super.saveSessionConfirmed(uid, session);
    return (confirmed: server?.future ?? write.confirmed);
  }

  @override
  Future<bool> sessionOnServer(String uid, String id) => onServer.future;

  @override
  Future<void> saveSession(String uid, m.WorkoutSessionModel session) async {
    saveAttempts++;
    if (saveErrors.isNotEmpty) throw saveErrors.removeAt(0);
    await super.saveSession(uid, session);
  }

  @override
  Future<void> updateWeekStreakCount(
    String uid,
    String sessionId,
    int weeks,
  ) async {
    if (streakError case final error?) throw error;
    await super.updateWeekStreakCount(uid, sessionId, weeks);
  }
}

class _Users extends InMemoryUserRepository {
  int merges = 0;

  @override
  Future<void> mergePrivateSettings(
    String uid,
    m.PrivateUserSettings settings, {
    Set<String> clearing = const {},
  }) {
    merges++;
    return super.mergePrivateSettings(uid, settings, clearing: clearing);
  }
}

// Thursday 15 October 2026, local time.
final _now = DateTime(2026, 10, 15, 18);

m.WorkoutSessionModel _finished(String id, DateTime created) => session(
  [
    exercise('e-$id', sets: [set('s-$id', done: true)]),
  ],
  id: id,
  created: created.toUtc(),
  ended: created.toUtc().add(const Duration(hours: 1)),
);

void main() {
  late _Sessions sessions;
  late _Users users;
  late InMemoryActiveSessionStore store;
  late List<Duration> waits;
  late List<SaveProgress> progress;
  late List<(Object, bool)> failures;
  late String? signedIn;

  final workout = _finished('session-1', _now);

  setUp(() async {
    sessions = _Sessions();
    users = _Users();
    store = InMemoryActiveSessionStore();
    await store.save(ActiveSessionState(session: workout));
    waits = [];
    progress = [];
    failures = [];
    signedIn = author;
  });

  WorkoutFinisher finisher() => WorkoutFinisher(
    sessions: sessions,
    users: users,
    store: store,
    wait: (delay) async => waits.add(delay),
    clock: () => _now,
  );

  Future<FinishResult> finish({
    List<m.WorkoutSessionModel> history = const [],
    m.PrivateUserSettings? privateSettings,
  }) => finisher().finish(
    workout,
    history: history,
    weeklySessionGoal: 2,
    privateSettings: privateSettings,
    firstWeekday: DateTime.monday,
    currentUid: () => signedIn,
    onProgress: progress.add,
    onAttemptFailed: (error, {required isTransient}) =>
        failures.add((error, isTransient)),
  );

  group('saving', () {
    test('a save that works first time is not news', () async {
      final result = await finish();

      expect(result.saved, isTrue);
      expect(result.sentBefore, isFalse);
      expect(sessions.saveAttempts, 1);
      expect(progress, isEmpty);
      expect(await result.onServer, isTrue);
      expect(await store.load(), isNull);
      expect((await sessions.session(author, 'session-1'))?.endedAt, isNotNull);
    });

    test('a transient failure is retried until it works', () async {
      sessions.saveErrors.addAll([
        _firestore('unavailable'),
        TimeoutException('slow'),
      ]);

      final result = await finish();

      expect(result.saved, isTrue);
      expect(sessions.saveAttempts, 3);
      expect(waits, [const Duration(seconds: 2), const Duration(seconds: 6)]);
      expect(progress, [
        SaveProgress.retrying,
        SaveProgress.retrying,
        SaveProgress.saved,
      ]);
      expect(await result.onServer, isTrue);
      expect(await store.load(), isNull);
    });

    test('a permanent failure is surfaced without retrying', () async {
      sessions.saveErrors.add(_firestore('permission-denied'));

      final result = await finish();

      expect(result.saved, isFalse);
      expect(result.onServer, isNull);
      expect(sessions.saveAttempts, 1);
      expect(progress, [SaveProgress.failed]);
      // Still on the device, for Training to offer again.
      expect(await store.load(), isNotNull);
    });

    test('a permanent failure on a retry ends the retries', () async {
      sessions.saveErrors.addAll([
        _firestore('aborted'),
        _firestore('invalid-argument'),
      ]);

      expect((await finish()).saved, isFalse);
      expect(sessions.saveAttempts, 2);
      expect(progress, [SaveProgress.retrying, SaveProgress.failed]);
      // Each failed attempt is reported (`finish_workout_save_error`).
      expect([for (final (_, transient) in failures) transient], [true, false]);
    });

    test('a save that never works ends with the failure', () async {
      sessions.saveErrors.addAll(
        List.filled(10, _firestore('deadline-exceeded')),
      );

      final result = await finish();

      expect(result.saved, isFalse);
      expect(sessions.saveAttempts, RetryBackoff.workoutSave.maxAttempts);
      expect(progress, [
        SaveProgress.retrying,
        SaveProgress.retrying,
        SaveProgress.retrying,
        SaveProgress.failed,
      ]);
      expect(await store.load(), isNotNull);
    });

    test('signing out stops the retries, saying nothing more', () async {
      sessions.saveErrors.add(_firestore('unavailable'));
      signedIn = null;

      final result = await finish();

      expect(result.saved, isFalse);
      expect(sessions.saveAttempts, 1);
      expect(progress, [SaveProgress.retrying]);
    });
  });

  group('the server', () {
    test('the device keeps the workout until the server has it', () async {
      sessions.server = Completer();

      final result = await finish();

      expect(result.saved, isTrue);
      // Offline: the summary does not wait, only the clean-up.
      expect((await store.load())?.saved, SavedFinish.awaitingServer);
      // Not offered in the tracker meanwhile.
      expect(
        await ActiveSessionController.resume(
          store: store,
          environment: TrackerEnvironment(
            authorId: author,
            settings: settings(),
          ),
        ),
        isNull,
      );
      sessions.server!.complete();
      expect(await result.onServer, isTrue);
      expect(await store.load(), isNull);
    });

    test('a refusal keeps it for the tracker, and finishing it again does '
        'not send it to Health or Strava again', () async {
      sessions.server = Completer();

      final result = await finish();
      sessions.server!.completeError(_firestore('permission-denied'));

      expect(await result.onServer, isFalse);
      final kept = await store.load();
      expect(kept?.saved, SavedFinish.refused);
      expect(kept?.session.id, workout.id);
      final controller = await ActiveSessionController.resume(
        store: store,
        environment: TrackerEnvironment(authorId: author, settings: settings()),
      );
      expect(controller?.session.id, workout.id);
      await controller!.finish();
      expect((await store.load())?.saved, SavedFinish.refused);

      sessions.server = null;
      final again = await finish();
      expect(again.sentBefore, isTrue);
      expect(await again.onServer, isTrue);
      expect(await store.load(), isNull);
    });

    test('a workout started meanwhile is left alone', () async {
      sessions.server = Completer();
      final next = ActiveSessionState(session: _finished('session-2', _now));
      await store.save(next);

      final result = await finish();
      expect((await store.load())?.session.id, 'session-2');
      sessions.server!.complete();
      expect(await result.onServer, isTrue);
      expect((await store.load())?.session.id, 'session-2');
      expect((await store.load())?.saved, isNull);
    });

    group('settleKept, after a relaunch', () {
      Future<void> keep(String authorId) => store.save(
        ActiveSessionState(
          session: m.WorkoutSessionModel.fromFirestore({
            ...workout.toFirestore(),
            m.WorkoutSessionModelKeys.authorId: authorId,
          }),
          saved: SavedFinish.awaitingServer,
        ),
      );

      test('answers nothing with none waiting', () async {
        expect(await finisher().settleKept(author), isNull);
        await store.clear();
        expect(await finisher().settleKept(author), isNull);
        await keep('someone-else');
        expect(await finisher().settleKept(author), isNull);
      });

      test('forgets the workout once the server has it', () async {
        await keep(author);
        final settled = finisher().settleKept(author);
        sessions.onServer.complete(true);
        expect(await settled, isTrue);
        expect(await store.load(), isNull);
      });

      test('keeps it for the tracker when the server refused it', () async {
        await keep(author);
        final settled = finisher().settleKept(author);
        sessions.onServer.complete(false);
        expect(await settled, isFalse);
        expect((await store.load())?.saved, SavedFinish.refused);
      });
    });
  });

  group('the streak', () {
    final lastWeek = [
      _finished('mon', DateTime(2026, 10, 5, 7)),
      _finished('wed', DateTime(2026, 10, 7, 7)),
    ];

    test('is stamped on the session and copied for the reminder', () async {
      final result = await finish(
        history: [
          ...lastWeek,
          _finished('tue', DateTime(2026, 10, 13, 7)),
          workout,
        ],
      );

      expect(result.streak?.weeks, 2);
      expect(result.streakError, isNull);
      expect((await sessions.session(author, 'session-1'))?.weekStreakCount, 2);
      final settings = await users.watchPrivateSettings(author).first;
      expect(settings?.weekStreak, 2);
      expect(settings?.weekSessions, 2);
      expect(settings?.weekGoal, 2);
      expect(settings?.weekEndsAt, DateTime(2026, 10, 19));
      expect(settings?.lastTrainedAt, workout.dateCreated);
    });

    test('is not copied again when the settings hold it', () async {
      final record = StreakRecord.of(
        [workout],
        uid: author,
        goal: 2,
        now: _now,
        firstWeekday: DateTime.monday,
      );

      await finish(
        privateSettings: m.PrivateUserSettings.fromFirestore(
          m.taggedJsonToFirestore(
            m.firestoreToTaggedJson(record.settings.toFirestore()),
          ),
        ),
      );

      expect(users.merges, 0);
    });

    test('failing leaves the save standing', () async {
      sessions.streakError = _firestore('not-found');

      final result = await finish();

      expect(result.saved, isTrue);
      expect(result.streakError, isA<FirebaseException>());
      expect(result.streak, isNull);
    });
  });

  group('StreakRecord', () {
    test('counts only finished, own, live, past sessions', () {
      final record = StreakRecord.of(
        [
          _finished('ok', DateTime(2026, 10, 12, 7)),
          session(
            const [],
            id: 'open',
            created: DateTime(2026, 10, 13).toUtc(),
          ),
          _finished('theirs', DateTime(2026, 10, 13)).copyWith(),
          session(
            const [],
            id: 'rest',
            created: DateTime(2026, 10, 13).toUtc(),
            ended: DateTime(2026, 10, 13).toUtc(),
            isRestDay: true,
          ),
          session(
            const [],
            id: 'other',
            authorId: 'someone',
            created: DateTime(2026, 10, 13).toUtc(),
            ended: DateTime(2026, 10, 13).toUtc(),
          ),
          m.WorkoutSessionModel.fromFirestore({
            ..._finished('deleted', DateTime(2026, 10, 14)).toFirestore(),
            m.WorkoutSessionModelKeys.deletedAt: DateTime.utc(2026, 10, 14),
          }),
          _finished('future', DateTime(2026, 10, 16)),
        ],
        uid: author,
        goal: 3,
        now: _now,
        firstWeekday: DateTime.sunday,
      );
      expect(record.streak.sessionsThisWeek, 2);
      expect(record.weekEndsAt, DateTime(2026, 10, 18));
      expect(record.lastTrainedAt, DateTime(2026, 10, 13).toUtc());
      expect(record.isRecordedIn(null), isFalse);
      expect(
        record.isRecordedIn(
          m.PrivateUserSettings(
            weekStreak: record.streak.weeks,
            weekSessions: 2,
            weekGoal: 3,
            weekEndsAt: record.weekEndsAt,
            lastTrainedAt: record.lastTrainedAt,
          ),
        ),
        isTrue,
      );
      expect(
        record.isRecordedIn(
          m.PrivateUserSettings(
            weekStreak: record.streak.weeks,
            weekSessions: 2,
            weekGoal: 3,
            weekEndsAt: record.weekEndsAt,
          ),
        ),
        isFalse,
      );
    });

    test('with nothing counted there is no last session', () {
      final record = StreakRecord.of(
        const [],
        uid: author,
        goal: 3,
        now: _now,
        firstWeekday: DateTime.monday,
      );
      expect(record.lastTrainedAt, isNull);
      expect(record.settings.weekStreak, 0);
      // The last session gone: the reminder's copy loses it too.
      expect(record.clearing, {'last_trained_at'});
      expect(
        record.isRecordedIn(m.PrivateUserSettings(lastTrainedAt: _now)),
        isFalse,
      );
    });

    test('a counted session clears nothing', () {
      final record = StreakRecord.of(
        [_finished('ok', DateTime(2026, 10, 12, 7))],
        uid: author,
        goal: 3,
        now: _now,
        firstWeekday: DateTime.monday,
      );
      expect(record.clearing, isEmpty);
    });
  });

  test('RetryBackoff: no wait before the first try, none past the budget', () {
    const backoff = RetryBackoff.workoutSave;
    expect(backoff.delayBefore(1, alreadyWaited: Duration.zero), isNull);
    expect(
      backoff.delayBefore(4, alreadyWaited: const Duration(seconds: 8)),
      const Duration(seconds: 18),
    );
    expect(backoff.delayBefore(5, alreadyWaited: Duration.zero), isNull);
    expect(
      backoff.delayBefore(4, alreadyWaited: const Duration(seconds: 50)),
      isNull,
    );
  });

  test("isTransientWriteFailure: Firestore's retry set and time-outs", () {
    for (final code in transientFirestoreCodes) {
      expect(isTransientWriteFailure(_firestore(code)), isTrue);
    }
    expect(isTransientWriteFailure(_firestore('permission-denied')), isFalse);
    expect(isTransientWriteFailure(TimeoutException('slow')), isTrue);
    expect(isTransientWriteFailure(StateError('bad')), isFalse);
  });

  test('the default wait really waits', () async {
    final finisher = WorkoutFinisher(
      sessions: sessions,
      users: users,
      store: store,
      backoff: const RetryBackoff(
        baseDelay: Duration(milliseconds: 1),
        multiplier: 1,
        maxAttempts: 2,
        maxTotalDelay: Duration(seconds: 1),
      ),
    );
    sessions.saveErrors.add(_firestore('unavailable'));

    final result = await finisher.finish(
      workout,
      history: const [],
      weeklySessionGoal: null,
      privateSettings: null,
      firstWeekday: DateTime.monday,
      currentUid: () => author,
    );

    expect(result.saved, isTrue);
  });
}
