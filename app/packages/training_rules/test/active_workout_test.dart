// Ports CorrectionRuleTests, PropagationRuleTests, StopwatchRuleTests,
// WorkoutResumeRuleTests, PrimarySlotTests, ActiveWorkoutLogRuleTests and
// ActiveWorkoutFocusTests (the rules, not the wording).
import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

final start = DateTime.fromMillisecondsSinceEpoch(1000000000, isUtc: true);

DateTime at(num seconds) =>
    start.add(Duration(microseconds: (seconds * 1000000).round()));

/// Sets `<id>-w1…` (warm-ups, open) then `<id>-1…`, the first [done] logged.
WorkoutExercise exercise(
  String id, {
  int done = 0,
  int open = 1,
  String? group,
  int warmups = 0,
  int? reps = 8,
}) => WorkoutExercise(
  id: id,
  templateId: 't-$id',
  name: id.toUpperCase(),
  supersetGroupId: group,
  sets: [
    for (var i = 0; i < warmups; i++)
      WorkoutSet(
        id: '$id-w${i + 1}',
        index: i + 1,
        reps: 5,
        weightKg: 40,
        isWarmup: true,
      ),
    for (var i = 0; i < done + open; i++)
      WorkoutSet(
        id: '$id-${i + 1}',
        index: warmups + i + 1,
        reps: reps,
        weightKg: 80,
        completedAt: i < done ? start : null,
      ),
  ],
);

void main() {
  const settings = WorkoutSettings();

  group('rows', () {
    test('the first open set is current, logged ones done', () {
      final e = exercise('a', done: 1, open: 2);
      expect(ActiveWorkout.currentSet(e)?.id, 'a-2');
      expect(ActiveWorkout.rowState(e.sets[0], e), SetRowState.done);
      expect(ActiveWorkout.rowState(e.sets[1], e), SetRowState.current);
      expect(ActiveWorkout.rowState(e.sets[2], e), SetRowState.upcoming);
      expect(ActiveWorkout.currentSet(exercise('b', done: 1, open: 0)), isNull);
    });
  });

  group('correction', () {
    WorkoutSet set(
      String id, {
      int? reps = 8,
      double? weightKg = 100,
      SetSide? side,
      bool warmup = false,
      double? doneAt,
    }) => WorkoutSet(
      id: id,
      reps: reps,
      weightKg: weightKg,
      side: side,
      isWarmup: warmup,
      completedAt: doneAt == null ? null : at(doneAt * 60),
    );
    WorkoutExercise ex(String id, List<WorkoutSet> sets) =>
        WorkoutExercise(id: id, sets: sets);

    test('the latest logged working set of the card gets the row', () {
      final bench = ex('e1', [
        set('s1', doneAt: 1),
        set('s2', doneAt: 3),
        set('s3'),
      ]);
      final latest = ActiveWorkout.latestCompletedSet([bench]);
      expect(ActiveWorkout.correctionTarget(bench, latest), 's2');
    });

    test('the next log moves the row', () {
      final bench = ex('e1', [
        set('s1', doneAt: 1),
        set('s2', doneAt: 3),
        set('s3', doneAt: 10),
      ]);
      expect(
        ActiveWorkout.correctionTarget(
          bench,
          ActiveWorkout.latestCompletedSet([bench]),
        ),
        's3',
      );
    });

    test('a set logged on another exercise leaves this card without', () {
      final bench = ex('e1', [set('e1-s1', doneAt: 1), set('e1-s2')]);
      final row = ex('e2', [set('e2-s1', doneAt: 2)]);
      final latest = ActiveWorkout.latestCompletedSet([bench, row]);
      expect(ActiveWorkout.correctionTarget(bench, latest), isNull);
      expect(ActiveWorkout.correctionTarget(row, latest), 'e2-s1');
    });

    test('warm-ups and nothing logged get no row', () {
      final bench = ex('e1', [set('w1', warmup: true, doneAt: 1), set('s1')]);
      expect(
        ActiveWorkout.correctionTarget(
          bench,
          ActiveWorkout.latestCompletedSet([bench]),
        ),
        isNull,
      );
      expect(ActiveWorkout.correctionTarget(bench, null), isNull);
      expect(ActiveWorkout.correctionTarget(bench, set('s1')), isNull);
    });

    test('the first of two sets logged at once is the latest', () {
      final bench = ex('e1', [set('s1', doneAt: 1), set('s2', doneAt: 1)]);
      expect(ActiveWorkout.latestCompletedSet([bench])?.id, 's1');
    });

    test('chips map to RPE', () {
      const cases = {0: 10.0, 1: 9, 2: 8, 3: 7, 4: 6, 5: 5, 6: 4, 7: 4, -1: 10};
      cases.forEach(
        (rir, rpe) => expect(ActiveWorkout.rpeForRirChip(rir), rpe),
      );
    });

    test('an RPE shows as a chip', () {
      final cases = <double?, int?>{
        10: 0,
        8: 2,
        6: 4,
        5: 5,
        4: 6,
        3: 6,
        8.5: null,
        null: null,
        11: null,
      };
      for (final MapEntry(key: rpe, value: chip) in cases.entries) {
        expect(ActiveWorkout.rirChipForRpe(rpe), chip);
      }
    });

    test('every chip reads back as itself', () {
      for (final chip in ActiveWorkout.rirChips) {
        expect(
          ActiveWorkout.rirChipForRpe(ActiveWorkout.rpeForRirChip(chip)),
          chip,
        );
      }
    });

    test('a side carries its initial', () {
      final curls = ex('e1', [
        set('l1', side: SetSide.left, doneAt: 1),
        set('r1', side: SetSide.right),
        set('b2', side: SetSide.both),
        set('p3'),
      ]);
      expect(ActiveWorkout.setNumberLabel(curls.sets[0], curls), '1L');
      expect(ActiveWorkout.setNumberLabel(curls.sets[1], curls), '1R');
      expect(ActiveWorkout.setNumberLabel(curls.sets[2], curls), '2');
      expect(ActiveWorkout.setNumberLabel(curls.sets[3], curls), '3');
    });
  });

  group('propagation', () {
    WorkoutSet set(
      String id,
      double? weightKg, {
      int? reps = 8,
      SetSide? side,
      bool done = false,
    }) => WorkoutSet(
      id: id,
      reps: reps,
      weightKg: weightKg,
      side: side,
      completedAt: done ? start : null,
    );
    (WorkoutSet, List<WorkoutSet>) typing(
      double weightKg,
      int index,
      List<WorkoutSet> sets,
    ) {
      final edited = [...sets];
      edited[index] = sets[index].copyWith(weightKg: weightKg);
      return (edited[index], edited);
    }

    List<double?> weights(List<WorkoutSet> sets) => [
      for (final s in sets) s.weightKg,
    ];

    test('an edit carries to open siblings holding the original', () {
      final before = [set('s1', 100), set('s2', 100), set('s3', 100)];
      final (edit, sets) = typing(105, 0, before);
      expect(
        weights(
          ActiveWorkout.propagate(edit: edit, original: before[0], sets: sets),
        ),
        [105, 105, 105],
      );
    });

    test('typing 82.5 leaves the 80 back-off set alone', () {
      final before = [set('s1', 100), set('s2', 100), set('s3', 80)];
      final (edit, sets) = typing(82.5, 0, before);
      expect(
        weights(
          ActiveWorkout.propagate(edit: edit, original: before[0], sets: sets),
        ),
        [82.5, 82.5, 80],
      );
    });

    test('the match is on the original passed in', () {
      final before = [set('s1', 100), set('s2', 100), set('s3', 80)];
      final intermediate = before[0].copyWith(weightKg: 80);
      final (edit, sets) = typing(82.5, 0, before);
      expect(
        weights(
          ActiveWorkout.propagate(edit: edit, original: before[0], sets: sets),
        ),
        [82.5, 82.5, 80],
      );
      expect(
        weights(
          ActiveWorkout.propagate(
            edit: edit,
            original: intermediate,
            sets: sets,
          ),
        ),
        [82.5, 100, 82.5],
      );
    });

    test('an edit stays on its own side', () {
      final before = [
        set('l1', 20, side: SetSide.left),
        set('r1', 20, side: SetSide.right),
        set('l2', 20, side: SetSide.left),
        set('r2', 20, side: SetSide.right),
      ];
      final (edit, sets) = typing(22.5, 0, before);
      expect(
        weights(
          ActiveWorkout.propagate(edit: edit, original: before[0], sets: sets),
        ),
        [22.5, 20, 22.5, 20],
      );
    });

    test('logged siblings are never changed', () {
      final before = [
        set('s1', 100, done: true),
        set('s2', 100),
        set('s3', 100, done: true),
        set('s4', 100),
      ];
      final (edit, sets) = typing(110, 1, before);
      expect(
        weights(
          ActiveWorkout.propagate(edit: edit, original: before[1], sets: sets),
        ),
        [100, 110, 100, 110],
      );
    });

    test('correcting a logged set carries nowhere', () {
      final before = [set('s1', 100, done: true), set('s2', 100)];
      final (edit, sets) = typing(110, 0, before);
      expect(
        ActiveWorkout.propagate(edit: edit, original: before[0], sets: sets),
        sets,
      );
    });

    test('a reps edit carries only where weight and reps both match', () {
      final before = [set('s1', 100), set('s2', 100), set('s3', 100, reps: 12)];
      final sets = [...before]..[0] = before[0].copyWith(reps: 6);
      final result = ActiveWorkout.propagate(
        edit: sets[0],
        original: before[0],
        sets: sets,
      );
      expect([for (final s in result) s.reps], [6, 6, 12]);
      expect(weights(result), [100, 100, 100]);
    });

    test('no change leaves the sets as they are', () {
      final before = [set('s1', 100), set('s2', 100)];
      expect(
        ActiveWorkout.propagate(
          edit: before[0],
          original: before[0],
          sets: before,
        ),
        before,
      );
    });
  });

  group('stopwatch', () {
    test('start and stop answer the seconds held', () {
      final stopwatch = Stopwatch();
      expect(stopwatch.isRunning, isFalse);
      stopwatch.start(start);
      expect(stopwatch.isRunning, isTrue);
      expect(stopwatch.elapsed(at(42.4)), 42);
      expect(stopwatch.elapsed(at(-5)), 0);
      expect(stopwatch.stop(at(42.6)), 43);
      expect(stopwatch.isRunning, isFalse);
      expect(stopwatch.elapsed(at(60)), 0);
    });

    test('a second start keeps the first', () {
      final stopwatch = Stopwatch()
        ..start(start)
        ..start(at(10));
      expect(stopwatch.startedAt, start);
    });

    test('a stop with nothing held answers nothing', () {
      final stopwatch = Stopwatch();
      expect(stopwatch.stop(start), isNull);
      stopwatch.start(start);
      expect(stopwatch.stop(at(0.3)), isNull);
    });

    test('a target counts down and stops at zero', () {
      final stopwatch = Stopwatch(targetSeconds: 45);
      expect(stopwatch.remaining(start), isNull);
      expect(stopwatch.targetInterval, isNull);
      stopwatch.start(start);
      expect(stopwatch.remaining(at(30)), 15);
      expect(stopwatch.remaining(at(50)), 0);
      expect(stopwatch.targetInterval, (start, at(45)));
      stopwatch.targetSeconds = 0;
      expect(stopwatch.targetInterval, isNull);
    });

    test('no target means no countdown', () {
      final stopwatch = Stopwatch()..start(start);
      expect(stopwatch.remaining(at(30)), isNull);
      expect(stopwatch.targetInterval, isNull);
    });
  });

  group('resume', () {
    WorkoutSet set(String id, {bool warmup = false, double? doneAt}) =>
        WorkoutSet(
          id: id,
          reps: 8,
          weightKg: 100,
          isWarmup: warmup,
          completedAt: doneAt == null ? null : at(doneAt),
        );
    final bench = WorkoutExercise(
      id: 'e1',
      sets: [
        set('w1', warmup: true, doneAt: 10),
        set('s1', doneAt: 100),
        set('s2', doneAt: 300),
        set('s3'),
      ],
    );

    test('the receipt holds sets logged since, oldest first', () {
      final squat = WorkoutExercise(
        id: 'e2',
        sets: [set('q1', doneAt: 200), set('q2', doneAt: 300)],
      );
      expect(
        [
          for (final s in ActiveWorkout.receipt([bench, squat], at(150))) s.id,
        ],
        ['q1', 's2', 'q2'],
      );
    });

    test('a screen that never looked owes no receipt', () {
      expect(ActiveWorkout.receipt([bench], null), isEmpty);
    });

    test('nothing logged since means no receipt', () {
      expect(ActiveWorkout.receipt([bench], at(300)), isEmpty);
    });

    test('a rest still counting down is re-armed with its start', () {
      final end = at(90);
      expect(
        RestRestore.plan(restEnd: end, restStartedAt: start, now: at(30)),
        RestRestoreRunning(end, start),
      );
      expect(
        RestRestore.plan(restEnd: end, restStartedAt: null, now: start),
        RestRestoreRunning(end, null),
      );
    });

    test('a rest that ran out while away is ended', () {
      final end = at(90);
      for (final late in [0, 600]) {
        expect(
          RestRestore.plan(
            restEnd: end,
            restStartedAt: start,
            now: end.add(Duration(seconds: late)),
          ),
          RestRestoreEnded(end),
        );
      }
    });

    test('no end means no rest, whatever the start', () {
      expect(
        RestRestore.plan(restEnd: null, restStartedAt: start, now: start),
        const RestRestoreNone(),
      );
    });
  });

  group('primary slot', () {
    const logSet = LogSetAction('e1', 's1');

    test('logs the next set when nothing else is going on', () {
      expect(
        ActiveWorkout.slotAction(
          primary: logSet,
          restEnd: null,
          isPaused: false,
          now: start,
        ),
        const SlotLog('e1', 's1'),
      );
      expect(
        ActiveWorkout.slotAction(
          primary: const NextExerciseAction('e2'),
          restEnd: null,
          isPaused: false,
          now: start,
        ),
        const SlotNext('e2'),
      );
      expect(
        ActiveWorkout.slotAction(
          primary: const FinishAction(),
          restEnd: null,
          isPaused: false,
          now: start,
        ),
        const SlotFinish(),
      );
      expect(
        ActiveWorkout.slotAction(
          primary: null,
          restEnd: null,
          isPaused: false,
          now: start,
        ),
        isNull,
      );
    });

    test('skips a rest still running, and hands back once it ran out', () {
      expect(
        ActiveWorkout.slotAction(
          primary: logSet,
          restEnd: at(30),
          isPaused: false,
          now: start,
        ),
        const SlotSkipRest(),
      );
      for (final end in [start, at(-5)]) {
        expect(
          ActiveWorkout.slotAction(
            primary: logSet,
            restEnd: end,
            isPaused: false,
            now: start,
          ),
          const SlotLog('e1', 's1'),
        );
      }
    });

    test('paused, the slot resumes whatever else is going on', () {
      expect(
        ActiveWorkout.slotAction(
          primary: logSet,
          restEnd: at(30),
          isPaused: true,
          now: start,
        ),
        const SlotResume(),
      );
    });

    test('the grace lasts one second from the rest end', () {
      expect(ActiveWorkout.isInGrace(start, at(-0.1)), isFalse);
      expect(ActiveWorkout.isInGrace(start, start), isTrue);
      expect(ActiveWorkout.isInGrace(start, at(0.99)), isTrue);
      expect(ActiveWorkout.isInGrace(start, at(1)), isFalse);
      expect(ActiveWorkout.isInGrace(start, at(60)), isFalse);
    });

    test('a tap counts only from 0.4 s after the action changed', () {
      expect(ActiveWorkout.acceptsTap(null, start), isTrue);
      expect(ActiveWorkout.acceptsTap(start, start), isFalse);
      expect(ActiveWorkout.acceptsTap(start, at(0.39)), isFalse);
      expect(ActiveWorkout.acceptsTap(start, at(0.41)), isTrue);
      expect(ActiveWorkout.acceptsTap(start, at(5)), isTrue);
    });
  });

  group('log', () {
    final now = at(500);
    const context = RestContext();
    LogOutcome? log(String setId, WorkoutSession session, {int? custom}) =>
        ActiveWorkout.log(
          setId,
          session,
          settings: settings,
          context: context,
          now: now,
          customRestSeconds: custom,
        );
    WorkoutSession session(List<WorkoutExercise> exercises) =>
        WorkoutSession(exercises: exercises);

    test('an invalid set is refused and the session left unchanged', () {
      final before = session([exercise('a', open: 2, reps: null)]);
      final outcome = log('a-1', before)!;
      expect(outcome.problem, SetProblem.noReps);
      expect(outcome.session, before);
      expect(outcome.restSeconds, isNull);
      expect(outcome.focusExerciseId, isNull);
    });

    test('logging stamps the set at now, with its unit and load count', () {
      const bench = WorkoutExercise(
        id: 'a',
        weightUnit: WeightUnit.pounds,
        loadsPerSet: 2,
        sets: [
          WorkoutSet(id: 'a-1', reps: 8, weightKg: 80),
          WorkoutSet(id: 'a-2', reps: 8, weightKg: 80),
        ],
      );
      final outcome = log('a-1', session([bench]))!;
      expect(outcome.problem, isNull);
      final sets = outcome.session.exercises[0].sets;
      expect(sets[0].completedAt, now);
      expect(sets[0].weightUnit, WeightUnit.pounds);
      expect(sets[0].loadCount, 2);
      expect(sets[1].completedAt, isNull);
      expect(outcome.restSeconds, 90);
    });

    test('an unknown or logged set has nothing to log', () {
      final workout = session([exercise('a', done: 1)]);
      expect(log('a-1', workout), isNull);
      expect(log('missing', workout), isNull);
    });

    test("no rest after the workout's final set", () {
      final outcome = log(
        'b-2',
        session([exercise('a', done: 2, open: 0), exercise('b', done: 1)]),
        custom: 120,
      )!;
      expect(outcome.problem, isNull);
      expect(outcome.restSeconds, isNull);
    });

    test('superset A1 moves focus to B', () {
      final outcome = log(
        'a-1',
        session([
          exercise('a', open: 2, group: 'g'),
          exercise('b', open: 2, group: 'g'),
        ]),
      )!;
      expect(outcome.focusExerciseId, 'b');
      expect(outcome.restSeconds, isNull);
    });

    test('a rest set by hand on the row wins', () {
      expect(
        log('a-1', session([exercise('a', open: 2)]), custom: 45)!.restSeconds,
        45,
      );
    });
  });

  group('focus', () {
    test('a superset is one block where its first member is', () {
      final exercises = [
        exercise('a'),
        exercise('b', group: 'g'),
        exercise('c'),
        exercise('d', group: 'g'),
        exercise('e', group: 'h'),
      ];
      expect(ActiveWorkout.blocks(exercises), [
        ['a'],
        ['b', 'd'],
        ['c'],
        ['e'],
      ]);
      expect(ActiveWorkout.blocks([]), isEmpty);
    });

    test('the log button walks a superset in rounds', () {
      final fresh = [
        exercise('a', open: 2, group: 'g'),
        exercise('b', open: 2, group: 'g'),
      ];
      expect(
        ActiveWorkout.primaryAction(fresh, 'a'),
        const LogSetAction('a', 'a-1'),
      );
      final afterA1 = [
        exercise('a', done: 1, group: 'g'),
        exercise('b', open: 2, group: 'g'),
      ];
      expect(
        ActiveWorkout.primaryAction(afterA1, 'b'),
        const LogSetAction('b', 'b-1'),
      );
      expect(
        ActiveWorkout.primaryAction(afterA1, 'a'),
        const NextExerciseAction('b'),
      );
      final afterB1 = [
        exercise('a', done: 1, group: 'g'),
        exercise('b', done: 1, group: 'g'),
      ];
      expect(
        ActiveWorkout.primaryAction(afterB1, 'a'),
        const LogSetAction('a', 'a-2'),
      );
    });

    test('the log button skips a finished member', () {
      final exercises = [
        exercise('a', done: 2, open: 0, group: 'g'),
        exercise('b', done: 2, group: 'g'),
      ];
      expect(
        ActiveWorkout.primaryAction(exercises, 'a'),
        const NextExerciseAction('b'),
      );
      expect(
        ActiveWorkout.primaryAction(exercises, 'b'),
        const LogSetAction('b', 'b-3'),
      );
    });

    test('next wraps and skips finished blocks; finish once all done', () {
      final exercises = [
        exercise('a'),
        exercise('b', done: 1, open: 0),
        exercise('c', done: 1, open: 0),
      ];
      expect(
        ActiveWorkout.primaryAction(exercises, 'b'),
        const NextExerciseAction('a'),
      );
      expect(
        ActiveWorkout.primaryAction(exercises, null),
        const NextExerciseAction('a'),
      );
      final done = [exercise('a', done: 1, open: 0)];
      expect(ActiveWorkout.primaryAction(done, 'a'), const FinishAction());
      expect(
        ActiveWorkout.primaryAction([exercise('a', open: 0)], 'a'),
        isNull,
      );
    });

    test('inside a superset the card goes to the partner', () {
      final exercises = [
        exercise('a', done: 1, group: 'g'),
        exercise('b', open: 2, group: 'g'),
      ];
      for (final rest in [true, false]) {
        expect(
          ActiveWorkout.focusAfterLogging(
            'a-1',
            exercises,
            settings: settings,
            restFollows: rest,
          ),
          'b',
        );
      }
      expect(
        ActiveWorkout.focusAfterLogging(
          'missing',
          exercises,
          settings: settings,
          restFollows: false,
        ),
        isNull,
      );
    });

    test("the round's last set hands back to the first member", () {
      final exercises = [
        exercise('a', done: 1, group: 'g'),
        exercise('b', done: 1, group: 'g'),
      ];
      expect(
        ActiveWorkout.focusAfterLogging(
          'b-1',
          exercises,
          settings: settings,
          restFollows: true,
        ),
        'a',
      );
    });

    test('superset auto-scroll off keeps the card', () {
      final exercises = [
        exercise('a', done: 1, group: 'g'),
        exercise('b', open: 2, group: 'g'),
      ];
      expect(
        ActiveWorkout.focusAfterLogging(
          'a-1',
          exercises,
          settings: const WorkoutSettings(supersetAutoScroll: false),
          restFollows: false,
        ),
        isNull,
      );
    });

    test("a set's pieces come before the partner's round", () {
      List<WorkoutExercise> exercises({required bool dropDone}) {
        final first = exercise('a', done: 1, group: 'g');
        return [
          first.copyWith(
            sets: [...first.sets]
              ..insert(
                1,
                WorkoutSet(
                  id: 'a-1-d1',
                  reps: 8,
                  weightKg: 64,
                  kind: SetKind.drop,
                  parentSetId: 'a-1',
                  completedAt: dropDone ? start : null,
                ),
              ),
          ),
          exercise('b', open: 2, group: 'g'),
        ];
      }

      expect(
        ActiveWorkout.nextSet(['a', 'b'], exercises(dropDone: false))?.setId,
        'a-1-d1',
      );
      expect(
        ActiveWorkout.focusAfterLogging(
          'a-1',
          exercises(dropDone: false),
          settings: settings,
          restFollows: false,
        ),
        isNull,
      );
      expect(
        ActiveWorkout.focusAfterLogging(
          'a-1-d1',
          exercises(dropDone: true),
          settings: settings,
          restFollows: false,
        ),
        'b',
      );
    });

    test('a circuit skips a finished member', () {
      final exercises = [
        exercise('a', done: 1, group: 'g'),
        exercise('b', done: 1, open: 0, group: 'g'),
        exercise('c', open: 2, group: 'g'),
      ];
      expect(
        ActiveWorkout.focusAfterLogging(
          'a-1',
          exercises,
          settings: settings,
          restFollows: false,
        ),
        'c',
      );
    });

    test('a set with more left in the exercise keeps the card', () {
      expect(
        ActiveWorkout.focusAfterLogging(
          'a-1',
          [exercise('a', done: 1), exercise('b')],
          settings: settings,
          restFollows: false,
        ),
        isNull,
      );
    });

    test('a finished exercise stays during its rest, else moves on', () {
      final exercises = [
        exercise('a', done: 1, open: 0),
        exercise('b', done: 1, open: 0),
        exercise('c', group: 'g'),
        exercise('d', group: 'g'),
      ];
      expect(
        ActiveWorkout.focusAfterLogging(
          'a-1',
          exercises,
          settings: settings,
          restFollows: true,
        ),
        isNull,
      );
      expect(
        ActiveWorkout.focusAfterLogging(
          'a-1',
          exercises,
          settings: settings,
          restFollows: false,
        ),
        'c',
      );
      expect(
        ActiveWorkout.focusAfterLogging(
          'a-1',
          exercises,
          settings: const WorkoutSettings(exerciseAutoNext: false),
          restFollows: false,
        ),
        isNull,
      );
    });

    test('the last member of a superset finishing the round stays', () {
      // B is on its last set; A has its second round open but is a partner.
      final exercises = [
        exercise('a', done: 1, open: 0, group: 'g'),
        exercise('b', done: 1, group: 'g'),
      ];
      expect(
        ActiveWorkout.focusAfterLogging(
          'a-1',
          exercises,
          settings: settings,
          restFollows: false,
        ),
        'b',
      );
      final onlyB = [
        exercise('a', done: 1, open: 0, group: 'g'),
        exercise('b', done: 1, open: 2, group: 'g'),
      ];
      expect(
        ActiveWorkout.focusAfterLogging(
          'b-1',
          onlyB,
          settings: settings,
          restFollows: false,
        ),
        isNull,
      );
    });

    test('when the rest ends a finished exercise moves on', () {
      final exercises = [
        exercise('a', done: 1, open: 0),
        exercise('b', done: 1, open: 0),
        exercise('c'),
      ];
      expect(ActiveWorkout.focusWhenRestEnds('a', exercises, settings), 'c');
      expect(
        ActiveWorkout.focusWhenRestEnds(
          'a',
          exercises,
          const WorkoutSettings(exerciseAutoNext: false),
        ),
        isNull,
      );
      expect(ActiveWorkout.focusWhenRestEnds('c', exercises, settings), isNull);
      expect(
        ActiveWorkout.focusWhenRestEnds('missing', exercises, settings),
        isNull,
      );
      expect(
        ActiveWorkout.focusWhenRestEnds('b', [
          exercises[0],
          exercises[1],
        ], settings),
        isNull,
      );
    });

    test('warm-ups come before the first round', () {
      final exercises = [
        exercise('a', open: 2, group: 'g', warmups: 1),
        exercise('b', open: 2, group: 'g'),
      ];
      expect(
        ActiveWorkout.primaryAction(exercises, 'b'),
        const NextExerciseAction('a'),
      );
      expect(
        ActiveWorkout.primaryAction(exercises, 'a'),
        const LogSetAction('a', 'a-w1'),
      );
    });

    test('a block of unknown exercises has no next set', () {
      expect(ActiveWorkout.nextSet(['x'], [exercise('a')]), isNull);
    });
  });
}
