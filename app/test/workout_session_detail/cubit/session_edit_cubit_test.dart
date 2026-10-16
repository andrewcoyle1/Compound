import 'package:bloc_test/bloc_test.dart';
import 'package:compound/workout_session_detail/cubit/session_edit_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/analytics_recorder.dart';

const _uid = 'author-1';

/// A session repository whose writes can be refused.
class _Sessions extends InMemoryWorkoutSessionRepository {
  new({required super.sessions});

  Exception? refuse;

  @override
  Future<void> updateEditedSession(String uid, WorkoutSessionModel session) {
    if (refuse case final error?) throw error;
    return super.updateEditedSession(uid, session);
  }

  @override
  Future<void> deleteSession(String uid, String id) {
    if (refuse case final error?) throw error;
    return super.deleteSession(uid, id);
  }
}

/// Ported from Swift's `WorkoutSessionDetailPresenterTests` (with its
/// `+Timing` extension), `WorkoutSessionDeleteFailureTests` and the saved
/// edit's side of `WorkoutSessionStravaLinkTests`. The summary figures,
/// the Strava link and offer, and the exercise line are the read-only
/// screen's and tested with it; supersets, swap and per-exercise units are
/// not in the Flutter editor.
void main() {
  // A Tuesday, so the streak's week is the same whichever day starts it.
  final today = DateTime(2026, 3, 10, 18);
  final start = DateTime(2026, 3, 9, 7);

  WorkoutSetModel set(
    String id, {
    int? reps = 8,
    double? weightKg = 80,
    bool isWarmup = false,
    bool logged = true,
  }) => WorkoutSetModel(
    id: id,
    authorId: _uid,
    index: 1,
    reps: reps,
    weightKg: weightKg,
    isWarmup: isWarmup,
    dateCreated: start,
    completedAt: logged ? start : null,
  );

  WorkoutExerciseModel exercise(
    String id,
    int index,
    List<WorkoutSetModel> sets,
  ) => WorkoutExerciseModel(
    id: id,
    authorId: _uid,
    templateId: 'template-$id',
    name: 'Bench Press',
    trackingMode: TrackingMode.weightReps,
    index: index,
    sets: sets,
  );

  WorkoutSessionModel session({
    List<WorkoutExerciseModel> exercises = const [],
    Duration? duration = const Duration(hours: 1),
    String? notes,
    int? stravaActivityId,
  }) => WorkoutSessionModel(
    id: 'session-1',
    authorId: _uid,
    name: 'Push Day',
    dateCreated: start,
    dateModified: start,
    endedAt: duration == null ? null : start.add(duration),
    notes: notes,
    stravaActivityId: stravaActivityId,
    exercises: exercises,
  );

  late _Sessions sessions;
  late InMemoryUserRepository users;
  late AnalyticsRecorder analytics;

  setUp(() {
    sessions = _Sessions(sessions: [session()]);
    users = InMemoryUserRepository(
      users: {_uid: const UserModel(userId: _uid, weeklySessionGoal: 1)},
    );
    analytics = AnalyticsRecorder();
  });

  var ids = 0;
  SessionEditCubit build(
    WorkoutSessionModel opened, {
    String? uid = _uid,
    StravaRepository? strava,
  }) => SessionEditCubit(
    session: opened,
    sessions: sessions,
    users: users,
    analytics: analytics,
    uid: uid,
    library: InMemoryTrainingLibraryRepository(),
    strava: strava,
    clock: () => today,
    newId: () => 'new-${ids++}',
  );

  Future<SessionEditCubit> editing(WorkoutSessionModel opened) async {
    await sessions.saveSession(_uid, opened);
    final cubit = build(opened);
    await cubit.enterEditMode();
    return cubit;
  }

  Future<WorkoutSessionModel> stored() async =>
      (await sessions.session(_uid, 'session-1'))!;

  final perSide = PrebuiltCatalogue.instance.exercises.firstWhere(
    (e) => e.isPerSide,
  );
  final twoSided = PrebuiltCatalogue.instance.exercises.firstWhere(
    (e) => !e.isPerSide && e.trackingMode == TrackingMode.weightReps,
  );

  group('Whose workout it is', () {
    test('only the author owns the workout', () {
      expect(build(session()).state.isAuthor, isTrue);
      expect(build(session(), uid: 'someone-else').state.isAuthor, isFalse);
    });

    test('a missing user owns nothing', () {
      expect(build(session(), uid: null).state.isAuthor, isFalse);
    });

    blocTest<SessionEditCubit, SessionEditState>(
      'a reader who is not the author cannot edit, move or delete it',
      build: () => build(session(), uid: 'someone-else'),
      act: (cubit) async {
        await cubit.enterEditMode();
        await cubit.changeStart(
          start.subtract(const Duration(hours: 1)),
          firstWeekday: DateTime.monday,
        );
        await cubit.changeDuration(2, 0, firstWeekday: DateTime.monday);
        await cubit.delete(firstWeekday: DateTime.monday);
      },
      expect: () => <SessionEditState>[],
      verify: (_) async {
        expect((await stored()).dateCreated, start);
        expect(analytics.names, isEmpty);
      },
    );
  });

  group('Unsaved changes', () {
    test('are the difference from what was opened', () async {
      final cubit = await editing(session());
      expect(cubit.state.hasUnsavedChanges, isFalse);

      cubit.setNotes('Felt strong');
      expect(cubit.state.hasUnsavedChanges, isTrue);

      cubit.setNotes('');
      expect(cubit.state.hasUnsavedChanges, isFalse);
    });

    test('ending an edit asks only when something changed', () async {
      final cubit = await editing(session());
      cubit.endEditing();
      expect(cubit.state.isEditing, isFalse);

      await cubit.enterEditMode();
      cubit.setNotes('Felt strong');
      expect(cubit.state.hasUnsavedChanges, isTrue);
      cubit.endEditing();
      expect(cubit.state.isEditing, isTrue);

      cubit.discardChanges();
      expect(cubit.state.isEditing, isFalse);
      expect(cubit.state.session.notes, isNull);
    });

    test('a saved timing edit leaves nothing unsaved', () async {
      final cubit = await editing(session());
      cubit.setNotes('Felt strong');

      await cubit.changeStart(
        start.subtract(const Duration(minutes: 10)),
        firstWeekday: DateTime.monday,
      );

      expect(cubit.state.hasUnsavedChanges, isFalse);
      expect(cubit.state.isEditing, isTrue);
      expect((await stored()).notes, 'Felt strong');
    });
  });

  group('Editing', () {
    test('deleting an exercise removes it and renumbers the rest', () async {
      final cubit = await editing(
        session(
          exercises: [
            exercise('e1', 1, [set('s1')]),
            exercise('e2', 2, [set('s2')]),
            exercise('e3', 3, [set('s3')]),
          ],
        ),
      );

      cubit.deleteExercise('e1');

      expect(
        [for (final e in cubit.state.session.exercises) e.id],
        ['e2', 'e3'],
      );
      expect([for (final e in cubit.state.session.exercises) e.index], [1, 2]);
    });

    test('an exercise note is saved trimmed and cleared when empty', () async {
      final cubit = await editing(
        session(
          exercises: [
            exercise('e1', 1, [set('s1')]),
          ],
        ),
      );

      cubit.setExerciseNotes('e1', '  Felt heavy  ');
      expect(cubit.state.session.exercises.single.notes, 'Felt heavy');

      cubit.setExerciseNotes('e1', '   ');
      expect(cubit.state.session.exercises.single.notes, isNull);
    });

    test('a set is added, retyped, re-typed and deleted', () async {
      final cubit = await editing(
        session(
          exercises: [
            exercise('e1', 1, [set('s1')]),
          ],
        ),
      );

      cubit.addSet('e1');
      expect(cubit.state.session.exercises.single.sets, hasLength(2));

      final edited = cubit.state.session.exercises.single.sets.first.copyWith(
        reps: 12,
      );
      cubit.updateSet('e1', edited);
      expect(cubit.state.session.exercises.single.sets.first.reps, 12);

      cubit.setSetType('s1', const r.SetTypeChoice.ofKind(r.SetKind.drop));
      expect(
        cubit.state.session.exercises.single.sets.first.kind,
        SetKind.drop,
      );
      expect(cubit.state.subSetsRemovedBy('s1'), (drops: 1, minis: 0));
      cubit.addSubSet('s1', r.SubSetKind.drop);
      expect(cubit.state.subSetsRemovedBy('s1'), (drops: 2, minis: 0));
      expect(
        cubit.state.loggedRowsLostBy(
          's1',
          const r.SetTypeChoice.ofKind(r.SetKind.standard),
        ),
        0,
      );

      cubit.deleteSet('s1');
      expect(cubit.state.session.exercises.single.sets, hasLength(1));
      expect(analytics.names, [
        'SetTracker_Set_Added',
        'SetTrackerRow_SetTypeChanged',
        'SetTrackerRow_SubSetAdded',
        'SetTrackerRow_SetDeleted',
      ]);
      expect(analytics.parameters('SetTrackerRow_SetTypeChanged'), {
        'set_type': 'drop',
      });
    });

    test('the same set type again changes nothing', () async {
      final cubit = await editing(
        session(
          exercises: [
            exercise('e1', 1, [set('s1')]),
          ],
        ),
      );

      cubit.setSetType('s1', const r.SetTypeChoice.ofKind(r.SetKind.standard));

      expect(cubit.state.hasUnsavedChanges, isFalse);
      expect(analytics.names, isEmpty);
    });

    test('a tick un-logs a logged set and logs an open one', () async {
      final cubit = await editing(
        session(
          exercises: [
            exercise('e1', 1, [set('s1')]),
          ],
        ),
      );

      cubit.toggleSet('s1');
      expect(
        cubit.state.session.exercises.single.sets.single.completedAt,
        isNull,
      );

      cubit.toggleSet('s1');
      expect(
        cubit.state.session.exercises.single.sets.single.completedAt,
        today,
      );
      expect(analytics.parameters('SetTrackerRow_SetCompleted'), {
        'source': 'row',
        'set_id': 's1',
        'exercise_id': 'e1',
        'use_rest_timers': false,
        'rest_duration_seconds': 0,
      });
    });

    test('a set that cannot be logged says why', () async {
      final cubit = await editing(
        session(
          exercises: [
            exercise('e1', 1, [set('s1', reps: null, logged: false)]),
          ],
        ),
      );

      cubit.toggleSet('s1');

      expect(cubit.state.notice, SessionEditNotice.logProblem);
      expect(cubit.state.logProblem, r.SetProblem.noReps);
    });

    test('split L/R splits a per-side exercise and joins it again', () async {
      final cubit = await editing(session());
      cubit.addExercises([perSide]);
      final id = cubit.state.session.exercises.single.id;
      final rows = cubit.state.session.exercises.single.sets.length;

      cubit.toggleSides(id);
      expect(cubit.state.session.exercises.single.sets.length, rows * 2);
      cubit.toggleSides(id);
      expect(cubit.state.session.exercises.single.sets.length, rows);
      expect(analytics.parameters('SetTracker_Sides_Split'), {'split': false});
    });

    test('picked exercises are appended and numbered', () async {
      final cubit = await editing(
        session(
          exercises: [
            exercise('e1', 1, [set('s1')]),
          ],
        ),
      );

      cubit.addExercises([twoSided]);

      expect([for (final e in cubit.state.session.exercises) e.index], [1, 2]);
    });

    test('a picked per-side exercise joins with sided sets', () async {
      final cubit = await editing(session());

      cubit.addExercises([perSide]);

      expect(
        [for (final s in cubit.state.session.exercises.single.sets) s.side],
        [SetSide.both],
      );
    });

    test('a picked two-sided exercise joins with sideless sets', () async {
      final cubit = await editing(session());

      cubit.addExercises([twoSided]);

      expect(
        cubit.state.session.exercises.single.sets.every((s) => s.side == null),
        isTrue,
      );
    });

    test('adding nothing changes nothing', () async {
      final cubit = await editing(
        session(
          exercises: [
            exercise('e1', 1, [set('s1')]),
          ],
        ),
      );

      cubit.addExercises(const []);

      expect(cubit.state.session.exercises, hasLength(1));
      expect(cubit.state.hasUnsavedChanges, isFalse);
    });

    test('edits outside edit mode, or of a missing set, do nothing', () {
      final cubit =
          build(
              session(
                exercises: [
                  exercise('e1', 1, [set('s1')]),
                ],
              ),
            )
            ..addSet('e1')
            ..toggleSet('s1')
            ..setSetType(
              'missing',
              const r.SetTypeChoice.ofKind(r.SetKind.drop),
            )
            ..addSubSet('missing', r.SubSetKind.drop)
            ..toggleSides('missing');

      expect(cubit.state.session.exercises.single.sets, hasLength(1));
      expect(cubit.state.subSetsRemovedBy('missing'), (drops: 0, minis: 0));
      expect(
        cubit.state.loggedRowsLostBy(
          'missing',
          const r.SetTypeChoice.ofKind(r.SetKind.drop),
        ),
        0,
      );
    });
  });

  group('Saving', () {
    test('saving without a change writes nothing', () async {
      final cubit = await editing(session(notes: 'Kept'));

      await cubit.saveChanges(firstWeekday: DateTime.monday);

      expect(cubit.state.isEditing, isFalse);
      expect(analytics.names, isEmpty);
    });

    test('saving a change writes it, leaving edit mode', () async {
      final cubit = await editing(session(notes: 'Before'));
      cubit.setNotes('');

      await cubit.saveChanges(firstWeekday: DateTime.monday);

      expect((await stored()).notes, isNull);
      expect((await stored()).dateModified, today);
      expect(cubit.state.isEditing, isFalse);
      expect(cubit.state.savedId, 1);
      expect(analytics.names, [
        'WorkoutSessionDetailView_SaveChanges_Start',
        'WorkoutSessionDetailView_SaveChanges_Success',
      ]);
    });

    test('a failed save keeps the user in edit mode', () async {
      final cubit = await editing(session());
      cubit.setNotes('Felt strong');
      sessions.refuse = Exception('offline');

      await cubit.saveChanges(firstWeekday: DateTime.monday);

      expect(cubit.state.isEditing, isTrue);
      expect(cubit.state.isSaving, isFalse);
      expect(cubit.state.notice, SessionEditNotice.saveFailed);
      expect(analytics.names.last, 'WorkoutSessionDetailView_SaveChanges_Fail');
    });

    test('a save while not editing does nothing', () async {
      final cubit = build(session());

      await cubit.saveChanges(firstWeekday: DateTime.monday);

      expect(analytics.names, isEmpty);
    });
  });

  group('Timing', () {
    test('moving the start keeps the duration', () async {
      final cubit = build(session());
      final moved = start.add(const Duration(hours: 2));

      await cubit.changeStart(moved, firstWeekday: DateTime.monday);

      final saved = await stored();
      expect(saved.dateCreated, moved);
      expect(saved.endedAt, moved.add(const Duration(hours: 1)));
      expect(cubit.state.savedId, 1);
      expect(analytics.names, [
        'WorkoutSessionDetailView_SaveTiming_Start',
        'WorkoutSessionDetailView_SaveTiming_Success',
      ]);
    });

    test('confirming a duration moves the end, past any pause', () async {
      await sessions.saveSession(_uid, session().copyWith(pausedSeconds: 300));
      final cubit = build(await stored());

      await cubit.changeDuration(2, 15, firstWeekday: DateTime.monday);

      expect(
        (await stored()).endedAt,
        start.add(const Duration(hours: 2, minutes: 20)),
      );
    });

    test('a zero duration is refused', () async {
      final cubit = build(session());

      await cubit.changeDuration(0, 0, firstWeekday: DateTime.monday);

      expect((await stored()).endedAt, start.add(const Duration(hours: 1)));
      expect(analytics.names, isEmpty);
    });

    test('a failed timing save says so', () async {
      final cubit = build(session());
      sessions.refuse = Exception('offline');

      await cubit.changeStart(start, firstWeekday: DateTime.monday);

      expect(cubit.state.notice, SessionEditNotice.timingSaveFailed);
      expect(analytics.names.last, 'WorkoutSessionDetailView_SaveTiming_Fail');
    });
  });

  group('Deleting', () {
    test('deleting the workout removes it', () async {
      final cubit = build(session());

      await cubit.delete(firstWeekday: DateTime.monday);

      expect(await sessions.session(_uid, 'session-1'), isNull);
      expect(cubit.state.isDeleted, isTrue);
      expect(analytics.names, [
        'WorkoutSessionDetailView_DeleteSession_Start',
        'WorkoutSessionDetailView_DeleteSession_Success',
      ]);
    });

    test('a failed delete alerts once and stays', () async {
      final cubit = build(session());
      sessions.refuse = Exception('offline');

      await cubit.delete(firstWeekday: DateTime.monday);

      expect(cubit.state.isDeleted, isFalse);
      expect(cubit.state.notice, SessionEditNotice.deleteFailed);
      expect(cubit.state.noticeId, 1);
      expect(analytics.names, [
        'WorkoutSessionDetailView_DeleteSession_Start',
        'WorkoutSessionDetailView_DeleteSession_Fail',
      ]);
    });
  });

  group('The streak', () {
    test('a delete brings the reminder copy up to date', () async {
      await users.mergePrivateSettings(
        _uid,
        const PrivateUserSettings(weekStreak: 4, weekSessions: 1),
      );
      final cubit = build(session());

      await cubit.delete(firstWeekday: DateTime.monday);

      final private = await users.watchPrivateSettings(_uid).first;
      expect(private?.weekStreak, 0);
      expect(private?.weekSessions, 0);
    });

    test('a moved workout counts in its new week', () async {
      final cubit = build(session());

      await cubit.changeStart(
        start.subtract(const Duration(days: 7)),
        firstWeekday: DateTime.monday,
      );

      final private = await users.watchPrivateSettings(_uid).first;
      expect(private?.weekSessions, 0);
      expect(private?.lastTrainedAt, start.subtract(const Duration(days: 7)));
    });
  });

  group('Strava', () {
    late FakeStravaApi api;

    Future<StravaRepository> connected() async {
      final firestore = FakeFirebaseFirestore();
      api = FakeStravaApi(
        firestore: firestore,
        uid: _uid,
        athlete: const StravaAthlete(id: 1),
      );
      final strava = StravaRepository(
        firestore: firestore,
        api: api,
        sessions: sessions,
        store: InMemoryStravaAccountStore(),
        clientId: 'client',
        uploadContext: (_) async => (
          library: const <ExerciseModel>[],
          weightUnit: WeightUnitPreference.kilograms,
          distanceUnit: DistanceUnitPreference.kilometers,
        ),
      );
      await strava.signIn(_uid);
      return strava;
    }

    test('a saved edit is sent to Strava', () async {
      final strava = await connected();
      await sessions.saveSession(_uid, session(stravaActivityId: 42));
      final cubit = build(session(), strava: strava);
      await cubit.enterEditMode();
      cubit.setNotes('Felt strong');

      await cubit.saveChanges(firstWeekday: DateTime.monday);
      await pumpEventQueue();

      expect([for (final edit in api.edits) edit.id], [42]);
      expect(api.edits.single.description, contains('Felt strong'));
    });

    test('a session not on Strava sends nothing', () async {
      final strava = await connected();
      final cubit = await editing(session());
      final withStrava = build(cubit.state.session, strava: strava);
      await withStrava.enterEditMode();
      withStrava.setNotes('Felt strong');

      await withStrava.saveChanges(firstWeekday: DateTime.monday);
      await pumpEventQueue();

      expect(api.edits, isEmpty);
    });
  });
}
