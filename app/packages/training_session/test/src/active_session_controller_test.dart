// The active session, ported from the presenter-independent parts of
// WorkoutTrackerSaveCoalescingTests, WorkoutTrackerPropagationTests,
// WorkoutTrackerCorrectionTests, WorkoutTrackerSupersetTests,
// WorkoutTrackerAddExerciseTests, WorkoutTrackerDeleteExerciseTests,
// WorkoutTrackerSwapTests, WorkoutTrackerResumeTests and
// WorkoutTrackerFinishTests.
import 'dart:async';

import 'package:compound_models/compound_models.dart' as m;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

import '../helpers/fixtures.dart';

/// Counts what is kept.
class _Store extends InMemoryActiveSessionStore {
  int writes = 0;
  ActiveSessionState? last;
  Exception? failWith;

  @override
  Future<void> save(ActiveSessionState state) async {
    if (failWith case final error?) throw error;
    writes++;
    last = state;
    await super.save(state);
  }
}

/// One exercise, "e1", with sets "s1"… of [weights] × 8 (the Swift
/// `WorkoutTrackerTypingScreen`).
m.WorkoutSessionModel _typing(List<double> weights) => session([
  exercise(
    'e1',
    sets: [
      for (final (i, weight) in weights.indexed)
        set('s${i + 1}', index: i + 1, weightKg: weight),
    ],
  ),
]);

List<double?> _savedWeights(_Store store) => [
  for (final s in store.last!.session.exercises.first.sets) s.weightKg,
];

/// Types [values] into set [number] of the first exercise, a key at a time.
void _type(ActiveSessionController c, int number, List<double> values) {
  for (final value in values) {
    final current = c.session.exercises.first.sets[number - 1];
    c.editSet(current.copyWith(weightKg: value));
  }
}

m.WorkoutSetModel _set(ActiveSessionController c, String id) =>
    c.session.exercises.expand((e) => e.sets).firstWhere((s) => s.id == id);

void main() {
  group('save coalescing', () {
    test('a burst of keystrokes is one write', () {
      fakeAsync((async) {
        final store = _Store();
        final c = controller(_typing([100, 100, 80]), store: store);

        _type(c, 1, [1, 10, 100, 102, 102.5]);
        expect(store.writes, 0);
        expect(c.hasUnsavedChanges, isTrue);

        async.elapse(ActiveSessionController.saveDebounce);
        expect(store.writes, 1);
        expect(_savedWeights(store).first, 102.5);
      });
    });

    test('a flush writes at once and leaves nothing waiting', () {
      fakeAsync((async) {
        final store = _Store();
        final c = controller(_typing([100, 100, 80]), store: store);

        _type(c, 1, [1, 10, 105]);
        c.flush();
        async.flushMicrotasks();
        expect(store.writes, 1);
        expect(_savedWeights(store), [105, 105, 80]);

        async.elapse(const Duration(milliseconds: 600));
        expect(store.writes, 1);
      });
    });

    test('a flush with nothing changed writes nothing', () {
      fakeAsync((async) {
        final store = _Store();
        controller(_typing([100]), store: store).flush();
        async.flushMicrotasks();
        expect(store.writes, 0);
      });
    });

    test('logging a set writes at once', () {
      fakeAsync((async) {
        final store = _Store();
        final c = controller(_typing([100, 100]), store: store);

        _type(c, 1, [1, 10, 105]);
        c.logSet('s1');
        async.flushMicrotasks();

        final saved = store.last!.session.exercises.first.sets;
        expect(saved.first.completedAt, isNotNull);
        expect(saved.map((s) => s.weightKg), [105, 105]);
      });
    });

    test('finishing writes at once, and keeps only what was lifted', () async {
      final store = _Store();
      final c = controller(_typing([100, 100]), store: store);

      _type(c, 1, [1, 10, 105]);
      final finished = await c.finish();

      expect(store.writes, 1);
      expect(store.last!.session.endedAt, isNotNull);
      expect(_savedWeights(store), isEmpty);
      expect(finished.exercises.first.sets, isEmpty);
      expect(c.isDone, isTrue);
      expect(identical(await c.finish(), finished), isTrue);
    });

    test('discarding leaves nothing to write back', () {
      fakeAsync((async) {
        final store = _Store();
        final c = controller(_typing([100, 100]), store: store)..flush();

        _type(c, 1, [1, 10, 105]);
        unawaited(c.discard());
        async.elapse(const Duration(milliseconds: 600));

        expect(store.writes, 0);
        expect(store.load(), completion(isNull));
        c
          ..flush()
          ..selectExercise('e1');
        async.elapse(const Duration(milliseconds: 600));
        expect(store.writes, 0);
      });
    });

    test('a failed write is reported, and later ones still land', () async {
      final store = _Store()..failWith = Exception('disk full');
      final errors = <Object>[];
      final c =
          ActiveSessionController(
              state: ActiveSessionState(session: _typing([100])),
              environment: TrackerEnvironment(
                authorId: author,
                settings: settings(),
              ),
              store: store,
              onSaveError: (error, _) => errors.add(error),
            )
            ..selectExercise('e1')
            ..flush();
      await c.saved;
      expect(errors.single, isA<Exception>());

      store.failWith = null;
      c
        ..selectExercise('e1')
        ..flush();
      await c.saved;
      expect(store.writes, 1);
    });

    test('a failed write with no handler is logged', () async {
      final store = _Store()..failWith = Exception('disk full');
      final c = controller(_typing([100]), store: store)
        ..selectExercise('e1')
        ..flush();
      await c.saved;
      expect(store.writes, 0);
    });
  });

  group('propagation', () {
    test('typing 82.5 leaves the 80 back-off set alone', () {
      final store = _Store();
      final c = controller(_typing([100, 100, 80]), store: store);

      _type(c, 1, [8, 80, 8, 82, 82.5]);
      c.flush();

      expect(weights(c), [82.5, 82.5, 80]);
    });

    test('a pause mid-edit does not commit it', () {
      fakeAsync((async) {
        final store = _Store();
        final c = controller(_typing([100, 100, 80]), store: store);

        _type(c, 1, [8, 80]);
        async.elapse(ActiveSessionController.saveDebounce);
        expect(_savedWeights(store), [80, 100, 80]);
        _type(c, 1, [8, 82, 82.5]);
        c.flush();

        expect(weights(c), [82.5, 82.5, 80]);
      });
    });

    test('siblings do not change while typing', () {
      final c = controller(_typing([100, 100]));
      _type(c, 1, [1, 10, 105]);
      expect(weights(c), [105, 100]);
    });

    test('the keyboard hiding commits the edit', () {
      final c = controller(_typing([100, 100, 100]));
      _type(c, 1, [105]);
      c.commitEdit();
      expect(weights(c), [105, 105, 105]);
    });

    test('editing another set commits the first edit', () {
      final c = controller(_typing([100, 100, 100]));

      _type(c, 1, [105]);
      _type(c, 3, [1]);
      expect(weights(c), [105, 105, 1]);

      _type(c, 3, [90]);
      c.flush();
      expect(weights(c), [105, 105, 90]);
    });

    test('logging the set being typed commits its edit', () {
      final c = controller(_typing([100, 100, 80]));
      _type(c, 1, [8, 82, 82.5]);
      c.logSet('s1');
      expect(weights(c), [82.5, 82.5, 80]);
    });

    test('logging another set logs what it showed', () {
      final c = controller(_typing([100, 100, 100]));
      _type(c, 1, [105]);
      c.logSet('s2');
      expect(weights(c), [105, 100, 105]);
      expect(_set(c, 's2').completedAt, isNotNull);
    });

    test('with propagation off nothing carries', () {
      final c = controller(
        _typing([100, 100]),
        workoutSettings: settings(propagateChanges: false),
      );
      _type(c, 1, [105]);
      c.flush();
      expect(weights(c), [105, 100]);
    });

    test('a keystroke keeps the set logged or open as it was', () {
      final c = controller(_typing([100, 100]))..logSet('s1');
      c.editSet(_set(c, 's1').copyWith(completedAt: null, reps: 9));
      expect(_set(c, 's1').completedAt, isNotNull);
      expect(_set(c, 's1').reps, 9);
      c.editSet(set('ghost'));
    });

    test('an edit to a set deleted meanwhile carries nowhere', () {
      final c = controller(_typing([100, 100]));
      _type(c, 1, [105]);
      c
        ..deleteSet('s1')
        ..commitEdit();
      expect(weights(c), [100]);
    });

    test('an edit that changes nothing on its siblings writes nothing', () {
      final c = controller(_typing([100, 90]));
      _type(c, 1, [105]);
      c.commitEdit();
      expect(weights(c), [105, 90]);
    });
  });

  group('correction', () {
    final start = DateTime.utc(1970, 1, 12, 13, 46, 40);
    ActiveSessionController make({
      bool rirTracking = false,
      FakeClock? clock,
    }) => controller(
      session([
        exercise(
          'exercise-1',
          sets: [
            for (var n = 1; n <= 3; n++) set('set-$n', index: n, weightKg: 60),
          ],
          targets: [for (var n = 1; n <= 3; n++) target(n, min: 8, max: 12)],
        ),
      ], templateId: 'template-1'),
      workoutSettings: settings(
        smartProgressionApplyInSession: true,
        propagateChanges: false,
        rirTracking: rirTracking,
      ),
      clock: clock,
    );
    List<m.WorkoutSetModel> sets(ActiveSessionController c) =>
        c.session.exercises.first.sets;

    test('the row follows the set just logged', () {
      final clock = FakeClock();
      final c = make(rirTracking: true, clock: clock);
      expect(c.correction('exercise-1'), isNull);

      c.logSet('set-1');
      final correction = c.correction('exercise-1')!;
      expect(correction.setId, 'set-1');
      expect(correction.exerciseId, 'exercise-1');
      expect(correction.correctsReps, isTrue);
      expect(correction.canRemoveRep, isTrue);
      expect(correction.showsRir, isTrue);
      expect(correction.selectedRir, isNull);

      clock.advance(const Duration(minutes: 2));
      c.logSet('set-2');
      expect(c.correction('exercise-1')?.setId, 'set-2');
      expect(c.correction('missing'), isNull);
    });

    test('the bar shows the set just logged during its rest', () {
      final clock = FakeClock();
      final c = make(clock: clock);
      expect(c.restCorrection(clock.now), isNull);

      c.logSet('set-1');
      expect(c.restCorrection(clock.now)?.setId, 'set-1');

      c.skipRest();
      expect(c.restCorrection(clock.now), isNull);
    });

    test('taking reps off re-suggests the remaining sets', () {
      final c = make()..logSet('set-1');
      expect(sets(c).skip(1).every((s) => s.weightKg == 60), isTrue);

      c
        ..correctReps('set-1', -1)
        ..correctReps('set-1', -1);

      expect(sets(c)[0].reps, 6);
      expect(sets(c)[0].completedAt, isNotNull);
      expect(
        sets(c).skip(1).every((s) => s.weightKg == 57 && s.reps == 8),
        isTrue,
      );
    });

    test('reps never go below one', () {
      final c = make();
      c
        ..editSet(sets(c)[0].copyWith(reps: 1))
        ..logSet('set-1');
      expect(c.correction('exercise-1')?.canRemoveRep, isFalse);
      c.correctReps('set-1', -1);
      expect(sets(c)[0].reps, 1);
      c
        ..correctReps('set-2', 1)
        ..correctReps('ghost', 1);
      expect(sets(c)[1].reps, 8);
    });

    test('a RIR chip stores the mapped RPE and toggles off', () {
      final c = make(rirTracking: true)
        ..logSet('set-1')
        ..setRir('set-1', 2);
      expect(sets(c)[0].rpe, 8);
      expect(c.correction('exercise-1')?.selectedRir, 2);

      c.setRir('set-1', 4);
      expect(sets(c)[0].rpe, 6);

      c
        ..setRir('set-1', 4)
        ..setRir('set-2', 1);
      expect(sets(c)[0].rpe, isNull);
      expect(sets(c)[1].rpe, isNull);
    });

    test('reps-only work corrects reps; timed work does not', () {
      final clock = FakeClock();
      final c = controller(
        clock: clock,
        session([
          exercise(
            'pull',
            mode: m.TrackingMode.repsOnly,
            sets: [set('p1', weightKg: null), set('p2', weightKg: null)],
          ),
          exercise(
            'plank',
            index: 2,
            mode: m.TrackingMode.timeOnly,
            sets: [set('t1', reps: null, durationSec: 60), set('t2')],
          ),
        ]),
      )..logSet('p1');
      expect(c.correction('pull')?.correctsReps, isTrue);
      clock.advance(const Duration(minutes: 1));
      c.logSet('t1');
      expect(c.correction('plank')?.correctsReps, isFalse);
    });

    test('no chips with RIR tracking off', () {
      final c = make()..logSet('set-1');
      expect(c.correction('exercise-1')?.showsRir, isFalse);
    });

    test('undo un-logs the set and calls off the rest', () {
      final c = make()..logSet('set-1');
      expect(c.restEnd, isNotNull);
      expect(c.restAnchor('exercise-1'), const r.RestBelow('set-1'));

      c.unlog('set-1');

      expect(sets(c)[0].completedAt, isNull);
      expect(c.restEnd, isNull);
      expect(c.restStartedAt, isNull);
      expect(c.correction('exercise-1'), isNull);
      expect(c.restAnchor('exercise-1'), isNull);
      c.unlog('set-2');
    });

    test('the undo stack carries the action names', () {
      final c = make();
      expect(c.undoName, isNull);

      c.logSet('set-1');
      expect(c.undoName, const UndoName(UndoKind.logSet, setLabel: '1'));

      c.undo();
      expect(sets(c)[0].completedAt, isNull);
      expect(c.restStartedAt, isNull);
      expect(c.redoName, const UndoName(UndoKind.logSet, setLabel: '1'));

      c.redo();
      expect(sets(c)[0].completedAt, isNotNull);
      expect(c.redoName, isNull);

      c.unlog('set-1');
      expect(c.undoName, const UndoName(UndoKind.unlogSet, setLabel: '1'));
      c.undo();
      expect(sets(c)[0].completedAt, isNotNull);
      expect(c.undoName == const UndoName(UndoKind.logSet), isFalse);
      expect(
        const UndoName(UndoKind.logSet).hashCode,
        const UndoName(UndoKind.logSet).hashCode,
      );
    });

    test('a deleted set comes back in place', () {
      final c = make()..deleteSet('set-2');
      expect(c.undoName, const UndoName(UndoKind.deleteSet));

      c.undo();
      expect(sets(c).map((s) => s.id), ['set-1', 'set-2', 'set-3']);
    });

    test('three reps taps undo as one', () {
      final c = make()..logSet('set-1');
      for (var i = 0; i < 3; i++) {
        c.correctReps('set-1', 1);
      }
      expect(sets(c)[0].reps, 11);
      expect(c.undoName, const UndoName(UndoKind.changeReps));

      c.undo();
      expect(sets(c)[0].reps, 8);
      expect(sets(c)[0].completedAt, isNotNull);
      expect(c.undoName, const UndoName(UndoKind.logSet, setLabel: '1'));
    });

    test('an undo is skipped once the set has changed', () {
      final c = make()..logSet('set-1');
      final restamped = start.add(const Duration(hours: 1));
      c.updateSet('exercise-1', sets(c)[0].copyWith(completedAt: restamped));

      c.undo();

      expect(sets(c)[0].completedAt, restamped);
    });

    test('an undo of reps on a set logged again since does nothing', () {
      final c = make()
        ..logSet('set-1')
        ..correctReps('set-1', 1);
      c
        ..updateSet(
          'exercise-1',
          sets(c)[0].copyWith(completedAt: start.add(const Duration(hours: 1))),
        )
        ..undo();
      expect(sets(c)[0].reps, 9);
    });

    test('an undo for a deleted exercise or set is skipped', () {
      final c = make()
        ..logSet('set-1')
        ..deleteSet('set-2')
        ..deleteExercise('exercise-1')
        ..undo()
        ..undo();
      expect(c.session.exercises, isEmpty);
    });

    test('clearing forgets every undo; nothing to undo or redo is fine', () {
      final c = make()
        ..undo()
        ..redo()
        ..logSet('set-1')
        ..clearUndo();
      expect(c.undoName, isNull);
    });
  });

  group('supersets', () {
    m.WorkoutExerciseModel member(
      String id,
      int index,
      List<m.WorkoutSetModel> sets, {
      String? group = 'group-1',
    }) => exercise(
      id,
      index: index,
      group: group,
      sets: [for (final s in sets) s.copyWith(id: '$id-${s.id}')],
    );
    final two = [set('set-1'), set('set-2', index: 2)];

    test('logging a superset set moves to the partner', () {
      final c = controller(
        session([member('e1', 1, two), member('e2', 2, two)]),
      )..logSet('e1-set-1');
      expect(c.currentExercise?.id, 'e2');
      expect(c.currentExerciseIndex, 1);
    });

    test('with superset auto-scroll off the focus stays put', () {
      final c = controller(
        session([member('e1', 1, two), member('e2', 2, two)]),
        workoutSettings: settings(supersetAutoScroll: false),
      )..logSet('e1-set-1');
      expect(c.currentExercise?.id, 'e1');
      expect(c.currentExerciseIndex, 0);
    });

    test('a set outside any superset does not move the focus', () {
      final c = controller(
        session([
          member('e1', 1, two, group: null),
          member('e2', 2, [set('set-1')], group: null),
        ]),
      )..logSet('e1-set-1');
      expect(c.currentExercise?.id, 'e1');
    });

    test("another superset's member is not the partner", () {
      final c = controller(
        session([
          member('e1', 1, two),
          member('e2', 2, [set('set-1')], group: 'group-2'),
        ]),
      )..logSet('e1-set-1');
      expect(c.currentExercise?.id, 'e1');
    });

    test('a finished partner is skipped', () {
      final c = controller(
        session([
          member('e1', 1, two),
          member('e2', 2, [set('set-1', done: true)]),
          member('e3', 3, two),
        ]),
      )..logSet('e1-set-1');
      expect(c.currentExercise?.id, 'e3');
    });

    test('the last superset member wraps back to the first', () {
      final c =
          controller(session([member('e1', 1, two), member('e2', 2, two)]))
            ..selectExercise('e2')
            ..logSet('e2-set-1');
      expect(c.currentExercise?.id, 'e1');
    });

    test("finishing one member goes on to the partner's set in the round", () {
      final c = controller(
        session([
          member('e1', 1, [set('set-1')]),
          member('e2', 2, [set('set-1')]),
        ]),
        workoutSettings: settings(exerciseAutoNext: false),
      )..logSet('e1-set-1');
      expect(c.currentExercise?.id, 'e2');
    });

    test('the log button alternates and rests after the round', () {
      final c = controller(
        session([member('e1', 1, two), member('e2', 2, two)]),
      );
      final logged = <String>[];
      final rests = <int?>[];
      for (var i = 0; i < 4; i++) {
        final action = c.primaryAction;
        if (action is! r.LogSetAction) break;
        logged.add('${action.exerciseId}/${action.setId}');
        rests.add(c.logSet(action.setId)?.restSeconds);
      }
      expect(logged, [
        'e1/e1-set-1',
        'e2/e2-set-1',
        'e1/e1-set-2',
        'e2/e2-set-2',
      ]);
      expect(rests, [null, 90, null, null]);
      expect(c.primaryAction, const r.FinishAction());
      expect(c.pressPrimary(), const r.FinishAction());
    });

    test('a transition rest runs between partners when chosen', () {
      final c = controller(
        session([member('e1', 1, two), member('e2', 2, two)]),
        workoutSettings: settings(supersetTransitionRestSeconds: 15),
      );
      expect(c.logSet('e1-set-1')?.restSeconds, 15);
      expect(c.logSet('e2-set-1')?.restSeconds, 90);
    });

    test('editing an already logged set does not move the focus', () {
      final c = controller(
        session([
          member('e1', 1, [set('set-1', done: true), set('set-2', index: 2)]),
          member('e2', 2, two),
        ]),
      )..selectExercise('e1');
      c.updateSet('e1', _set(c, 'e1-set-1').copyWith(weightKg: 90));
      expect(c.currentExercise?.id, 'e1');
    });

    test('add round and remove superset act on every member', () {
      final c = controller(
        session([
          member('e1', 1, two),
          member('e2', 2, [set('set-1')]),
          member('e3', 3, [set('set-1')], group: null),
        ]),
      )..addRound(['e1', 'e2']);
      expect(c.session.exercises.map((e) => e.sets.length), [3, 2, 1]);

      c.removeSuperset(['e1', 'e2']);
      expect(
        c.session.exercises.every((e) => e.supersetGroupId == null),
        isTrue,
      );
    });

    test('deleting a partner dissolves a superset of two', () {
      final c =
          controller(
              session([
                member('e1', 1, [set('set-1')]),
                member('e2', 2, [set('set-1')]),
                member('e3', 3, [set('set-1')], group: 'group-2'),
                member('e4', 4, [set('set-1')], group: 'group-2'),
                member('e5', 5, [set('set-1')], group: 'group-2'),
              ]),
            )
            ..deleteExercise('e2')
            ..deleteExercise('e5')
            ..deleteExercise('missing');
      expect(c.session.exercises.map((e) => e.supersetGroupId), [
        null,
        'group-2',
        'group-2',
      ]);
      expect(c.session.exercises.map((e) => e.index), [1, 2, 3]);
    });

    test('joining and leaving one superset', () {
      final c = controller(session([member('e1', 1, two, group: null)]))
        ..setSupersetGroup('e1', 'g')
        ..setSupersetGroup('missing', 'g');
      expect(c.session.exercises.single.supersetGroupId, 'g');
    });
  });

  group('adding exercises', () {
    m.WorkoutSessionModel legs() => session([
      for (final (i, id) in ['squat', 'press'].indexed)
        exercise(
          id,
          index: i + 1,
          templateId: 't-$id',
          sets: [set('$id-1', reps: 5, weightKg: 100), set('$id-2', reps: 5)],
        ),
    ]);
    final oneArmRow = m.WorkoutTemplateExercise(
      id: 'slot',
      exercise: library(
        'one-arm-row',
        name: 'One-Arm Row',
        metrics: const [
          m.TrackableExerciseMetric.weight,
          m.TrackableExerciseMetric.repsPerSide,
        ],
      ),
      setTargets: [target(1), target(2), target(3)],
      setRestTimers: false,
    );

    test('a unilateral exercise added mid-workout gets rows it can split', () {
      final c = controller(legs())..addExercises([oneArmRow]);
      final row = c.session.exercises.last;
      expect(row.templateId, 'one-arm-row');
      expect(row.sets, hasLength(3));
      expect(row.sets.every((s) => s.sideRawValue == 'both'), isTrue);
      expect(row.index, 3);
      c.addExercises(const []);
      expect(c.session.exercises, hasLength(3));
    });

    test('an added exercise loads last time and its suggestion', () {
      final c = controller(
        legs(),
        history: [
          session(
            [
              exercise(
                'last-row',
                templateId: 'one-arm-row',
                sets: [set('l1', reps: 10, weightKg: 30, done: true)],
              ),
            ],
            id: 'last-week',
            ended: start,
          ),
        ],
      )..addExercises([oneArmRow]);
      final row = c.session.exercises.last;
      expect(c.previousExercise(row)?.id, 'last-row');
      expect(c.suggestion(row), isNotNull);
      expect(c.previousExercise(c.session.exercises.first), isNull);
    });

    test('adding an exercise leaves the card where it was', () {
      final c = controller(legs())
        ..selectExercise('press')
        ..addExercises([oneArmRow]);
      expect(c.currentExercise?.id, 'press');
    });

    test('the first exercise added to an empty workout goes on the card', () {
      final c = controller(session(const []));
      expect(c.currentExercise, isNull);
      expect(c.currentExerciseIndex, 0);
      c.addExercises([oneArmRow]);
      expect(c.currentExercise?.templateId, 'one-arm-row');
    });
  });

  group('deleting', () {
    ActiveSessionController make(List<String> ids) => controller(
      session([
        for (final (i, id) in ids.indexed)
          exercise(
            id,
            index: i + 1,
            templateId: 't-$id',
            sets: [set('$id-1', reps: 5, weightKg: 100), set('$id-2', reps: 5)],
          ),
      ]),
    );

    test("deleting the card's exercise moves on to the next in order", () {
      final c = make(['row', 'squat', 'press', 'curl'])
        ..selectExercise('press')
        ..deleteExercise('press');
      expect(c.currentExercise?.id, 'curl');
      expect(c.currentExerciseIndex, 2);
    });

    test('deleting the last exercise wraps to the first with sets left', () {
      final c = make(['squat', 'press'])
        ..selectExercise('press')
        ..deleteExercise('press');
      expect(c.currentExercise?.id, 'squat');
    });

    test('deleting another exercise leaves the card alone', () {
      final c = make(['squat', 'press', 'curl'])
        ..selectExercise('curl')
        ..deleteExercise('squat');
      expect(c.currentExercise?.id, 'curl');
      expect(c.currentExerciseIndex, 1);
    });

    test('deleting the exercise a rest follows calls the rest off', () {
      final c = make(['squat', 'press'])..pressPrimary();
      expect(c.restEnd, isNotNull);
      c.deleteExercise('squat');
      expect(c.restEnd, isNull);
      expect(c.restStartedAt, isNull);
    });

    test('deleting another exercise keeps the rest', () {
      final c = make(['squat', 'press'])
        ..pressPrimary()
        ..deleteExercise('press');
      expect(c.restEnd, isNotNull);
    });

    test('deleting the set a rest follows calls the rest off', () {
      final c = make(['squat', 'press'])
        ..pressPrimary()
        ..deleteSet('squat-1');
      expect(c.restAnchor('squat'), isNull);
      expect(c.restEnd, isNull);
      c.deleteSet('ghost');
    });

    test('deleting a set takes its pair and sub-rows with it', () {
      final c = controller(
        session([
          exercise(
            'e',
            sets: [
              set('l', side: 'left'),
              set('r', side: 'right'),
              set('d', side: 'right', kind: 'drop', parent: 'r'),
              set('l2', index: 2, side: 'left'),
            ],
          ),
        ]),
      )..deleteSet('l');
      expect(c.session.exercises.single.sets.map((s) => s.id), ['l2']);
    });
  });

  group('swapping (on the screen)', () {
    final halfDone = exercise(
      'e1',
      sets: [
        set('w1', done: true, warmup: true),
        set('w2', index: 2, warmup: true),
        set('s1', index: 3, done: true),
        set('s2', index: 4),
        set('s3', index: 5),
      ],
    );
    final replacement = library('dumbbell-press', name: 'Dumbbell Press');

    test('the replacement goes in right after the old exercise', () {
      final c = controller(
        session([
          halfDone,
          exercise('e2', index: 2, sets: [set('e2-s1')]),
        ]),
      )..swapExercise('e1', replacement);
      final exercises = c.session.exercises;
      expect(exercises, hasLength(3));
      expect(exercises[0].id, 'e1');
      expect(exercises[1].templateId, 'dumbbell-press');
      expect(exercises[2].id, 'e2');
      expect(exercises.map((e) => e.index), [1, 2, 3]);
      expect(c.isComplete(exercises[0]), isTrue);
      expect(c.currentExercise?.id, exercises[1].id);
      c.swapExercise('missing', replacement);
      expect(c.session.exercises, hasLength(3));
    });

    test("the replacement takes the old exercise's place in a superset", () {
      final c = controller(
        session([
          halfDone.copyWith(supersetGroupId: 'group-1'),
          exercise('e2', index: 2, group: 'group-1', sets: [set('e2-s1')]),
        ]),
      )..swapExercise('e1', replacement);
      final grouped = c.session.exercises.where(
        (e) => e.supersetGroupId == 'group-1',
      );
      expect(grouped, hasLength(2));
      expect(grouped.any((e) => e.id == 'e1'), isFalse);
    });

    test('with nothing logged the replacement takes the place and id', () {
      final c = controller(
        session([
          exercise('e1', sets: [set('s1')]),
        ]),
      )..swapExercise('e1', replacement);
      expect(c.session.exercises.single.id, 'e1');
      expect(c.session.exercises.single.templateId, 'dumbbell-press');
    });

    test('last time and suggestions load for the replacement', () {
      final c = controller(
        session([halfDone]),
        history: [
          session(
            [
              exercise(
                'last-dumbbell-press',
                templateId: 'dumbbell-press',
                sets: [set('x', done: true)],
              ),
            ],
            id: 'last-time',
            ended: start,
          ),
        ],
      )..swapExercise('e1', replacement);
      final swapped = c.session.exercises[1];
      expect(c.previousExercise(swapped)?.id, 'last-dumbbell-press');
      expect(c.suggestion(swapped), isNotNull);
    });
  });

  group('reordering', () {
    ActiveSessionController make() => controller(
      session([
        exercise('a', sets: [set('a1')]),
        exercise('b', index: 2, group: 'g', sets: [set('b1')]),
        exercise('c', index: 3, group: 'g', sets: [set('c1')]),
        exercise('d', index: 4, sets: [set('d1')]),
        exercise('done', index: 5, sets: [set('x', done: true)]),
      ]),
    );
    List<String> order(ActiveSessionController c) => [
      for (final e in c.session.exercises) e.id,
    ];

    test('do later sends the block to the end, and the card on', () {
      final c = make();
      expect(c.canDoLater('a'), isTrue);
      expect(c.canDoLater('done'), isFalse);
      expect(c.canDoLater('missing'), isFalse);

      c.doLater('a');
      expect(order(c), ['b', 'c', 'd', 'done', 'a']);
      expect(c.currentExercise?.id, 'b');
      expect(c.session.exercises.map((e) => e.index), [1, 2, 3, 4, 5]);

      c.doLater('c');
      expect(order(c), ['d', 'done', 'a', 'b', 'c']);
      expect(c.currentExercise?.id, 'd');
    });

    test('nothing else to do first: no do later', () {
      final c = controller(
        session([
          exercise('a', sets: [set('a1')]),
          exercise('b', index: 2, sets: [set('b1', done: true)]),
        ]),
      );
      expect(c.canDoLater('a'), isFalse);
    });

    test('do later off the card leaves the card', () {
      final c = make()..doLater('d');
      expect(c.currentExercise?.id, 'a');
    });

    test('do next goes straight after the card block', () {
      final c = make()..doNext('d');
      expect(order(c), ['a', 'd', 'b', 'c', 'done']);
      c
        ..selectExercise('b')
        ..doNext('a');
      expect(order(c), ['d', 'b', 'c', 'a', 'done']);
    });

    test('do next with the card nowhere puts it first', () {
      final c = controller(session(const []))..doNext('missing');
      expect(order(c), isEmpty);
    });

    test('a block moves as one; the card stays on its exercise', () {
      final c = make()..moveBlock('b', 0);
      expect(order(c), ['b', 'c', 'a', 'd', 'done']);
      expect(c.currentExercise?.id, 'a');
      c.moveBlock('b', 0);
      expect(order(c), ['b', 'c', 'a', 'd', 'done']);
    });

    test('the strip shows each block', () {
      final strip = make().strip;
      expect(strip.map((item) => item.id), ['a', 'b', 'd', 'done']);
      expect(strip.first.isCurrent, isTrue);
    });
  });

  group('the card and the button', () {
    test('opens on the first exercise with sets left', () {
      final c = controller(
        session([
          exercise('done', sets: [set('x', done: true)]),
          exercise('next', index: 2, sets: [set('y')]),
        ]),
      );
      expect(c.currentExercise?.id, 'next');
      c.selectExercise('missing');
      expect(c.currentExercise?.id, 'next');
    });

    test('opens on the last exercise when all are done', () {
      final c = controller(
        session([
          exercise('a', sets: [set('x', done: true)]),
          exercise('b', index: 2, sets: [set('y', done: true)]),
        ]),
      );
      expect(c.currentExercise?.id, 'a');
      expect(c.canQuickFinish, isTrue);
      expect(c.hasLoggedSet, isTrue);
    });

    test('a resumed card is kept while it has a set to log', () {
      final workout = session([
        exercise('a', sets: [set('x')]),
        exercise('b', index: 2, sets: [set('y')]),
      ]);
      ActiveSessionController resumed(String card) => ActiveSessionController(
        state: ActiveSessionState(session: workout, cardExerciseId: card),
        environment: TrackerEnvironment(authorId: author, settings: settings()),
        store: InMemoryActiveSessionStore(),
      );
      expect(resumed('b').currentExercise?.id, 'b');
      expect(resumed('gone').currentExercise?.id, 'a');
    });

    test('the button logs, then moves on, then finishes', () {
      final clock = FakeClock();
      final c = controller(
        session([
          exercise('a', sets: [set('a1')]),
          exercise('b', index: 2, sets: [set('b1')]),
        ]),
        workoutSettings: settings(exerciseAutoNext: false),
        clock: clock,
      );
      expect(c.pressPrimary(), const r.LogSetAction('a', 'a1'));
      expect(c.slotAction(clock.now), const r.SlotSkipRest());
      c.skipRest();
      expect(c.pressPrimary(), const r.NextExerciseAction('b'));
      expect(c.currentExercise?.id, 'b');
      expect(c.slotAction(clock.now), const r.SlotLog('b', 'b1'));
      c.togglePause();
      expect(c.slotAction(clock.now), const r.SlotResume());
    });

    test('a set that cannot be logged says why', () {
      final c = controller(
        session([
          exercise('a', sets: [set('a1', reps: null)]),
        ]),
      );
      expect(c.logSet('a1')?.problem, r.SetProblem.noReps);
      expect(c.logSet('missing'), isNull);
      expect(_set(c, 'a1').completedAt, isNull);
    });

    test('a logged set cannot be logged again; the circle toggles', () {
      final c = controller(
        session([
          exercise('a', sets: [set('a1')]),
        ]),
      );
      expect(c.toggleSet('a1')?.problem, isNull);
      expect(c.logSet('a1'), isNull);
      expect(c.toggleSet('a1'), isNull);
      expect(_set(c, 'a1').completedAt, isNull);
      c
        ..updateSet('missing', set('a1'))
        ..updateSet('a', set('ghost'));
    });

    test('an assisted exercise may log a weight below zero', () {
      final c = controller(
        session([
          exercise(
            'dip',
            templateId: 'dip',
            sets: [set('d1', weightKg: -20), set('d2')],
          ),
        ]),
        libraryExercises: [
          library(
            'dip',
            metrics: const [m.TrackableExerciseMetric.weightPerSideAssistance],
            isBodyweight: true,
          ),
        ],
      );
      expect(c.logSet('d1')?.problem, isNull);
      expect(c.weightStep('dip').isAssisted, isTrue);
      expect(c.weightStep('missing').kind, const r.StepIncrement(2.5, min: 0));
    });

    test('a rest set by hand on a row is the rest', () {
      final c = controller(_typing([100, 100]))
        ..setCustomRest('s1', 30)
        ..setCustomRest('s2', 40)
        ..setCustomRest('s2', null);
      expect(c.logSet('s1')?.restSeconds, 30);
      expect(c.state.customRestSeconds, {'s1': 30});
    });

    test('the exercise rest override and plan rest are read', () {
      final c = controller(
        session([
          exercise('a', templateId: 'bench', sets: [set('a1'), set('a2')]),
          exercise(
            'b',
            index: 2,
            restSeconds: 200,
            sets: [set('b1'), set('b2')],
          ),
        ]),
        restOverrides: const {'bench': 150},
      );
      expect(c.logSet('a1')?.restSeconds, 150);
      expect(c.logSet('b1')?.restSeconds, 200);
    });

    test('with rest timers off nothing rests', () {
      final c = controller(
        _typing([100, 100]),
        workoutSettings: settings(useRestTimers: false),
      )..logSet('s1');
      expect(c.restEnd, isNull);
    });
  });

  group('rest and pause', () {
    test('+15s restarts the rest for what is left and more', () {
      final clock = FakeClock();
      final c = controller(_typing([100, 100]), clock: clock)..addRestTime();
      expect(c.restEnd, isNull);

      c.startRest(60);
      clock.advance(const Duration(seconds: 20, milliseconds: 500));
      c.addRestTime();
      expect(c.restEnd, clock.now.add(const Duration(seconds: 55)));
      expect(c.restStartedAt, clock.now);
    });

    test('a rest that ends keeps its start and moves a finished card on', () {
      final c = controller(
        session([
          exercise('a', sets: [set('a1')]),
          exercise('b', index: 2, sets: [set('b1')]),
        ]),
      )..logSet('a1');
      expect(c.currentExercise?.id, 'a');

      c.restEnded();
      expect(c.restEnd, isNull);
      expect(c.restStartedAt, isNotNull);
      expect(c.currentExercise?.id, 'b');
      expect(c.restAnchor('a'), const r.RestBelow('a1'));
      expect(c.restAnchor('b'), const r.RestTop());
      expect(c.restAnchor('missing'), isNull);
    });

    test('pausing stops the clock; resuming adds the pause up', () {
      final clock = FakeClock();
      final c = controller(_typing([100]), clock: clock);
      clock.advance(const Duration(minutes: 3));
      c.togglePause();
      expect(c.isPaused, isTrue);
      clock.advance(const Duration(minutes: 1));
      expect(c.pausedSeconds(clock.now), 60);
      expect(c.elapsed(clock.now), const Duration(minutes: 3));

      c.togglePause();
      expect(c.isPaused, isFalse);
      clock.advance(const Duration(minutes: 1));
      expect(c.elapsed(clock.now), const Duration(minutes: 4));
      expect(
        c.elapsed(start.subtract(const Duration(hours: 1))),
        Duration.zero,
      );
    });

    test('finishing while paused leaves the pause out', () async {
      final clock = FakeClock();
      final c = controller(_typing([100]), clock: clock)..logSet('s1');
      clock.advance(const Duration(minutes: 10));
      c.togglePause();
      clock.advance(const Duration(minutes: 5));

      final finished = await c.finish();

      expect(finished.pausedSeconds, 300);
      expect(finished.endedAt, clock.now);
      expect(finished.dateModified, clock.now);
      expect(c.isPaused, isFalse);
      expect(c.restEnd, isNull);
    });
  });

  group('finishing', () {
    test('keeps only logged sets, stamped with unit and load count', () async {
      final c = controller(
        session([
          exercise(
            'db',
            weightUnit: m.ExerciseWeightUnit.pounds,
            sets: [set('d1'), set('d2')],
          ).copyWith(loadsPerSet: 2),
          exercise('skipped', index: 2, sets: [set('x')]),
        ]),
      )..logSet('d1');
      expect(c.canQuickFinish, isFalse);

      final finished = await c.finish();

      final kept = finished.exercises.first.sets.single;
      expect(kept.id, 'd1');
      expect(kept.weightUnitRawValue, 'pounds');
      expect(kept.loadCount, 2);
      expect(finished.exercises.last.sets, isEmpty);
      expect(finished.pausedSeconds, isNull);
    });

    test('finish at the last set ends the workout then', () async {
      final clock = FakeClock();
      final c = controller(_typing([100, 100]), clock: clock)..logSet('s1');
      final lastSet = clock.now;
      clock.advance(const Duration(hours: 2));

      expect(c.stillTrainingPrompt(clock.now), lastSet);
      final finished = await c.finish(at: lastSet);

      expect(finished.endedAt, lastSet);
      expect(c.stillTrainingPrompt(clock.now), isNull);
    });

    test('nothing logged: nothing to ask about', () {
      final c = controller(_typing([100]));
      expect(c.hasLoggedSet, isFalse);
      expect(c.canQuickFinish, isFalse);
      expect(c.stillTrainingPrompt(start.add(const Duration(days: 1))), isNull);
    });
  });

  group('still training?', () {
    test('an hour with nothing logged asks once', () {
      final clock = FakeClock();
      final c = controller(_typing([100, 100]), clock: clock)..logSet('s1');
      final later = clock.now.add(const Duration(hours: 2));

      expect(c.stillTrainingPrompt(later), isNotNull);
      expect(c.stillTrainingPrompt(later), isNull);
    });

    test('within the hour nothing is asked', () {
      final clock = FakeClock();
      final c = controller(_typing([100, 100]), clock: clock)..logSet('s1');
      expect(
        c.stillTrainingPrompt(clock.now.add(const Duration(minutes: 30))),
        isNull,
      );
    });
  });

  group('resume', () {
    test('a workout kept on the device carries on, rest and all', () async {
      final store = InMemoryActiveSessionStore();
      final clock = FakeClock();
      final first = controller(_typing([100, 100]), store: store, clock: clock)
        ..logSet('s1')
        ..acknowledgeProgressionNote('template-e1')
        ..flush();
      await first.saved;

      clock.advance(const Duration(seconds: 30));
      final resumed = (await ActiveSessionController.resume(
        store: store,
        environment: first.environment,
        clock: clock.call,
      ))!;

      expect(_set(resumed, 's1').completedAt, isNotNull);
      expect(resumed.restEnd, first.restEnd);
      expect(resumed.restStartedAt, first.restStartedAt);
      expect(resumed.state.acknowledgedNoteTemplateIds, {'template-e1'});
      expect(
        resumed.state.progressionBaseline,
        first.state.progressionBaseline,
      );
    });

    test('a rest that ran out while the app was gone is ended once', () async {
      final store = InMemoryActiveSessionStore();
      final clock = FakeClock();
      final first = controller(_typing([100, 100]), store: store, clock: clock)
        ..logSet('s1');
      await first.saved;

      clock.advance(const Duration(minutes: 10));
      final resumed = (await ActiveSessionController.resume(
        store: store,
        environment: first.environment,
        clock: clock.call,
      ))!;

      expect(resumed.restEnd, isNull);
      expect(resumed.restStartedAt, first.restStartedAt);
    });

    test('nothing kept, nothing to resume', () async {
      expect(
        await ActiveSessionController.resume(
          store: InMemoryActiveSessionStore(),
          environment: TrackerEnvironment(
            authorId: author,
            settings: settings(),
          ),
        ),
        isNull,
      );
    });
  });

  group('the rest of the session', () {
    test('open warm-ups go when Smart Warm-Ups is off', () {
      final c = controller(
        session([
          exercise(
            'a',
            sets: [
              set('w1', warmup: true, done: true),
              set('w2', index: 2, warmup: true),
              set('s', index: 3),
            ],
          ),
          exercise('b', index: 2, sets: [set('b1')]),
        ]),
        workoutSettings: settings(addSmartWarmUps: false),
      );
      expect(c.session.exercises.first.sets.map((s) => (s.id, s.index)), [
        ('w1', 1),
        ('s', 2),
      ]);
    });

    test('set types, sub-sets and sides', () {
      final c = controller(
        session([
          exercise(
            'a',
            sets: [set('s1', weightKg: 100), set('s2', index: 2)],
            variations: [
              variation('bar', [ref(m.EquipmentKind.loadableBar, 'barbell')]),
            ],
          ),
        ]),
      )..setSetType('s1', const r.SetTypeChoice.ofKind(r.SetKind.drop));
      final sets = c.session.exercises.single.sets;
      expect(sets.first.kindRawValue, 'drop');
      expect(sets[1].parentSetId, 's1');
      expect(sets[1].weightKg, 80);

      c.addSubSet('s1', r.SubSetKind.drop);
      expect(c.session.exercises.single.sets[2].weightKg, 80);
      c.addSubSet('s2', r.SubSetKind.mini);
      expect(c.session.exercises.single.sets.last.parentSetId, 's2');

      c
        ..splitSides('a')
        ..setSetType('ghost', r.SetTypeChoice.warmup)
        ..addSubSet('ghost', r.SubSetKind.mini)
        ..splitSides('missing')
        ..joinSides('missing');
      final both = controller(
        session([
          exercise('p', sets: [set('l', side: 'both')]),
        ]),
      )..splitSides('p');
      expect(both.session.exercises.single.sets.map((s) => s.sideRawValue), [
        'left',
        'right',
      ]);
      both.joinSides('p');
      expect(both.session.exercises.single.sets.map((s) => s.sideRawValue), [
        'both',
      ]);
    });

    test('add a set, notes and the session note', () {
      final c = controller(_typing([100]))
        ..addSet('e1')
        ..addSet('missing')
        ..setExerciseNotes('e1', '  Felt heavy ')
        ..setExerciseNotes('missing', 'x')
        ..setWorkoutNotes(' Good one ');
      expect(c.session.exercises.single.sets, hasLength(2));
      expect(c.session.exercises.single.notes, 'Felt heavy');
      expect(c.session.notes, 'Good one');
      c
        ..setExerciseNotes('e1', ' ')
        ..setWorkoutNotes('');
      expect(c.session.exercises.single.notes, isNull);
      expect(c.session.notes, isNull);
    });

    test('another variation refits the load and reads its history', () {
      final bench = library(
        'bench',
        variations: [
          variation('bar', [ref(m.EquipmentKind.loadableBar, 'barbell')]),
          variation('db', [ref(m.EquipmentKind.freeWeight, 'dumbbells')]),
        ],
      );
      final c = controller(
        session([
          exercise(
            'e',
            templateId: 'bench',
            variations: bench.equipmentVariations,
            chosenVariationId: 'bar',
            sets: [set('s', weightKg: 61)],
          ),
        ]),
        libraryExercises: [bench],
        history: [
          session(
            [
              exercise(
                'last',
                templateId: 'bench',
                variations: bench.equipmentVariations,
                chosenVariationId: 'db',
                sets: [set('x', done: true)],
              ),
            ],
            id: 'last',
            ended: start,
          ),
        ],
      );
      expect(c.previousExercise(c.session.exercises.single), isNull);

      c
        ..chooseVariation('e', 'db')
        ..chooseVariation('e', 'db')
        ..chooseVariation('missing', 'db');

      expect(c.session.exercises.single.chosenVariationId, 'db');
      expect(c.previousExercise(c.session.exercises.single)?.id, 'last');
    });

    test('refit puts open sets on the edited equipment', () {
      final dumbbells = [ref(m.EquipmentKind.freeWeight, 'dumbbells')];
      final curl = library('curl', variations: [variation('db', dumbbells)]);
      m.GymProfileModel gymWith(List<double> weights) =>
          gym(freeWeights: [plates(weights, id: 'dumbbells', isPlates: false)]);
      final c =
          controller(
              session([
                exercise(
                  'e',
                  templateId: 'curl',
                  variations: curl.equipmentVariations,
                  chosenVariationId: 'db',
                  sets: [
                    set('done', weightKg: 14, done: true),
                    set('open', weightKg: 14),
                  ],
                ),
              ]),
              libraryExercises: [curl],
              workoutGym: gymWith([10, 20]),
            )
            // The gym's dumbbells edited: 12.5 and 15 switched on.
            ..environment = TrackerEnvironment(
              authorId: author,
              settings: settings(),
              library: [curl],
              gym: gymWith([10, 12.5, 15, 20]),
            )
            ..refit('e')
            ..refit('missing');

      expect(weights(c), [14, 15]);
      expect(
        c.session.exercises.single.weightUnit,
        m.ExerciseWeightUnit.kilograms,
      );
    });

    test('a new environment reads history again', () {
      final c = controller(_typing([100]));
      expect(c.previousExercise(c.session.exercises.single), isNull);
      c.environment = TrackerEnvironment(
        authorId: author,
        settings: settings(),
        history: SessionHistory([
          session(
            [
              exercise(
                'last',
                templateId: 'template-e1',
                sets: [set('x', done: true)],
              ),
            ],
            id: 'last',
            ended: start,
          ),
        ]),
      );
      expect(c.previousExercise(c.session.exercises.single)?.id, 'last');
    });

    test('a deload week suggests at the deload weight', () {
      final c = controller(
        session([
          exercise(
            'e',
            templateId: 'bench',
            targets: [target(1, min: 8, max: 10)],
            sets: [set('s')],
          ),
        ], isDeload: true),
        history: [
          for (final day in [1, 2])
            session(
              [
                exercise(
                  'x$day',
                  templateId: 'bench',
                  sets: [
                    set('a$day', reps: 10, weightKg: 100, done: true),
                    set('b$day', reps: 10, done: true, weightKg: null),
                  ],
                ),
              ],
              id: 'd$day',
              created: start.add(Duration(days: day)),
              ended: start.add(Duration(days: day)),
            ),
        ],
      );
      final suggestion = c.suggestion(c.session.exercises.single)!;
      expect(suggestion.sets.first.weightKg, lessThan(100));
      expect(suggestion.sets.last.weightKg, isNull);
    });

    test('live progression: only what was filled in is re-suggested', () {
      final c = controller(
        session([
          exercise(
            'e',
            targets: [target(1, min: 8, max: 12)],
            sets: [
              set('w', warmup: true, weightKg: 40),
              set('s1', index: 2, weightKg: 60, reps: 6),
              set('s2', index: 3, weightKg: 60),
              set('s3', index: 4, weightKg: 60),
              set('drop', index: 5, weightKg: 40, parent: 's3', kind: 'drop'),
            ],
          ),
          exercise(
            'timed',
            index: 2,
            mode: m.TrackingMode.timeOnly,
            sets: [
              set('t', reps: null, durationSec: 30),
              set('t2', durationSec: 30),
            ],
          ),
        ]),
        workoutSettings: settings(
          smartProgressionApplyInSession: true,
          propagateChanges: false,
        ),
      );
      c.editSet(_set(c, 's3').copyWith(weightKg: 65));
      c
        ..commitEdit()
        ..logSet('s1')
        ..logSet('drop')
        ..logSet('t')
        ..logSet('w');
      expect(_set(c, 's2').weightKg, 57);
      expect(_set(c, 's3').weightKg, 65);
    });

    test('live progression stays off without a prescribed range', () {
      final c = controller(
        _typing([60, 60]),
        workoutSettings: settings(smartProgressionApplyInSession: true),
      );
      c
        ..editSet(_set(c, 's1').copyWith(reps: 1))
        ..logSet('s1')
        ..logSet('s2');
      expect(weights(c), [60, 60]);
    });

    test('a progression note acknowledged is kept', () {
      final c = controller(_typing([100]))..acknowledgeProgressionNote('t');
      expect(c.state.acknowledgedNoteTemplateIds, {'t'});
    });
  });
}
