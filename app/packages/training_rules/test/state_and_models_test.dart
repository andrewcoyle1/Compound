// Ports the pure parts of ActiveWorkoutStateTests and WorkoutSetSideTests,
// and covers the value types.
import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

final start = DateTime.fromMillisecondsSinceEpoch(1000000000, isUtc: true);

WorkoutSet set(
  String id, {
  int? reps = 5,
  double? weightKg = 100,
  bool isWarmup = false,
  SetSide? side,
  int index = 1,
  double? doneAt,
}) => WorkoutSet(
  id: id,
  index: index,
  reps: reps,
  weightKg: weightKg,
  side: side,
  isWarmup: isWarmup,
  completedAt: doneAt == null
      ? null
      : start.add(Duration(seconds: doneAt.toInt())),
);

WorkoutExercise exercise(String id, List<WorkoutSet> sets) =>
    WorkoutExercise(id: id, sets: sets);

void main() {
  group('row states', () {
    test('the first set not logged is current, warm-ups included', () {
      final squat = exercise('e1', [
        set('w1', isWarmup: true, doneAt: 0),
        set('w2', isWarmup: true),
        set('s1'),
        set('s2'),
      ]);
      expect(
        [for (final s in squat.sets) ActiveWorkout.rowState(s, squat)],
        [
          SetRowState.done,
          SetRowState.current,
          SetRowState.upcoming,
          SetRowState.upcoming,
        ],
      );
    });

    test('a skipped set stays current', () {
      final squat = exercise('e1', [
        set('s1'),
        set('s2', doneAt: 0),
        set('s3'),
      ]);
      expect(
        [for (final s in squat.sets) ActiveWorkout.rowState(s, squat)],
        [SetRowState.current, SetRowState.done, SetRowState.upcoming],
      );
    });
  });

  group('progression reason', () {
    final last = exercise('e0', [
      set('a', doneAt: 0),
      set('b', reps: 6, doneAt: 1),
      set('r', reps: 1, side: SetSide.right, doneAt: 1),
      set('w', reps: 1, isWarmup: true, doneAt: 0),
    ]);
    const heavier = ProgressionSuggestion(Rationale.progressWeight, [
      SuggestedSet.none,
      SuggestedSet(weightKg: 102.5, reps: 5),
    ]);

    test('says what changed and why', () {
      expect(
        ActiveWorkout.progressionReason(suggestion: heavier, last: last),
        const ProgressionReason(
          rationale: Rationale.progressWeight,
          changeKg: 2.5,
          lastMinReps: 5,
        ),
      );
      expect(
        ActiveWorkout.progressionReason(
          suggestion: const ProgressionSuggestion(Rationale.addReps, [
            SuggestedSet(weightKg: 100, reps: 6),
          ]),
          last: last,
        ),
        const ProgressionReason(rationale: Rationale.addReps, addedReps: 1),
      );
      expect(
        ActiveWorkout.progressionReason(
          suggestion: const ProgressionSuggestion(Rationale.deload, [
            SuggestedSet(weightKg: 90, reps: 8),
          ]),
          last: last,
        ),
        const ProgressionReason(rationale: Rationale.deload, changeKg: -10),
      );
      expect(
        ActiveWorkout.progressionReason(
          suggestion: heavier,
          last: exercise('e0', [set('a', reps: null, doneAt: 0)]),
        ),
        const ProgressionReason(
          rationale: Rationale.progressWeight,
          changeKg: 2.5,
        ),
      );
    });

    test('goes once the first working set is edited', () {
      final asSuggested = exercise('e1', [
        set('w', weightKg: 60, isWarmup: true),
        set('a', weightKg: 102.5),
      ]);
      ProgressionReason? reason(WorkoutExercise planned) =>
          ActiveWorkout.progressionReason(
            suggestion: const ProgressionSuggestion(Rationale.progressWeight, [
              SuggestedSet(weightKg: 102.5, reps: 5),
            ]),
            planned: planned,
            last: last,
          );
      expect(reason(asSuggested), isNotNull);
      expect(reason(exercise('e1', [set('a')])), isNull);
      expect(reason(exercise('e1', [set('a', weightKg: null)])), isNull);
      expect(
        reason(exercise('e1', [set('a', weightKg: 102.5, reps: 6)])),
        isNull,
      );
      expect(reason(exercise('e1', [])), isNotNull);
      expect(
        ActiveWorkout.progressionReason(
          suggestion: const ProgressionSuggestion(Rationale.addReps, [
            SuggestedSet(reps: 6),
          ]),
          planned: exercise('e1', [set('a', reps: 6)]),
          last: last,
        ),
        isNotNull,
      );
      expect(
        ActiveWorkout.progressionReason(
          suggestion: const ProgressionSuggestion(Rationale.addReps, []),
          planned: asSuggested,
          last: last,
        ),
        isNull,
      );
    });

    test('nothing is said when nothing changed', () {
      const hold = ProgressionSuggestion(Rationale.hold, [
        SuggestedSet(weightKg: 100, reps: 5),
      ]);
      const roundedAway = ProgressionSuggestion(Rationale.progressWeight, [
        SuggestedSet(weightKg: 100, reps: 5),
      ]);
      expect(
        ActiveWorkout.progressionReason(suggestion: hold, last: last),
        isNull,
      );
      expect(
        ActiveWorkout.progressionReason(suggestion: roundedAway, last: last),
        isNull,
      );
      expect(
        ActiveWorkout.progressionReason(
          suggestion: ProgressionSuggestion.noHistory(1),
          last: last,
        ),
        isNull,
      );
      expect(
        ActiveWorkout.progressionReason(suggestion: hold, last: null),
        isNull,
      );
      expect(
        ActiveWorkout.progressionReason(suggestion: null, last: last),
        isNull,
      );
      expect(
        ActiveWorkout.progressionReason(
          suggestion: heavier,
          last: exercise('e0', [set('a')]),
        ),
        isNull,
      );
      expect(
        ActiveWorkout.progressionReason(
          suggestion: const ProgressionSuggestion(Rationale.progressWeight, [
            SuggestedSet(reps: 5),
          ]),
          last: last,
        ),
        isNull,
      );
      expect(
        ActiveWorkout.progressionReason(
          suggestion: const ProgressionSuggestion(Rationale.addReps, [
            SuggestedSet(weightKg: 100, reps: 5),
          ]),
          last: last,
        ),
        isNull,
      );
      expect(
        ActiveWorkout.progressionReason(
          suggestion: const ProgressionSuggestion(Rationale.addReps, [
            SuggestedSet(weightKg: 100),
          ]),
          last: last,
        ),
        isNull,
      );
    });
  });

  group('rest anchor', () {
    test('the rest timer sits under the working set it follows', () {
      final squat = exercise('e1', [
        set('s1', doneAt: 0),
        set('s2', doneAt: 60),
        set('s3'),
      ]);
      final rested = ActiveWorkout.latestCompletedSet([squat]);
      expect(rested?.id, 's2');
      expect(
        ActiveWorkout.restAnchor(
          squat,
          restedSet: rested,
          restStartedAt: start.add(const Duration(seconds: 61)),
        ),
        const RestBelow('s2'),
      );
      expect(
        ActiveWorkout.restAnchor(squat, restedSet: rested, restStartedAt: null),
        const RestBelow('s2'),
      );
    });

    test('goes to the top after a warm-up, another exercise or no set', () {
      final warmedUp = exercise('e1', [
        set('w', isWarmup: true, doneAt: 0),
        set('s1'),
      ]);
      expect(
        ActiveWorkout.restAnchor(
          warmedUp,
          restedSet: warmedUp.sets[0],
          restStartedAt: start,
        ),
        const RestTop(),
      );
      final bench = exercise('e2', [set('b1', doneAt: 0)]);
      expect(
        ActiveWorkout.restAnchor(
          exercise('e1', [set('s1')]),
          restedSet: bench.sets[0],
          restStartedAt: start,
        ),
        const RestTop(),
      );
      expect(
        ActiveWorkout.restAnchor(
          warmedUp,
          restedSet: null,
          restStartedAt: start,
        ),
        const RestTop(),
      );
      expect(
        ActiveWorkout.restAnchor(
          warmedUp,
          restedSet: warmedUp.sets[1],
          restStartedAt: start,
        ),
        const RestTop(),
      );
    });

    test('is left out once a later set is logged', () {
      final squat = exercise('e1', [
        set('s1', doneAt: 0),
        set('s2', doneAt: 120),
      ]);
      expect(
        ActiveWorkout.restAnchor(
          squat,
          restedSet: ActiveWorkout.latestCompletedSet([squat]),
          restStartedAt: start.add(const Duration(seconds: 1)),
        ),
        isNull,
      );
    });
  });

  group('the log button', () {
    test('logs the current set, then moves on, then finishes', () {
      final squat = exercise('e1', [set('s1', doneAt: 0), set('s2')]);
      final bench = exercise('e2', [set('b1')]);
      expect(
        ActiveWorkout.primaryAction([squat, bench], 'e1'),
        const LogSetAction('e1', 's2'),
      );
      final squatDone = exercise('e1', [
        set('s1', doneAt: 0),
        set('s2', doneAt: 1),
      ]);
      expect(
        ActiveWorkout.primaryAction([squatDone, bench], 'e1'),
        const NextExerciseAction('e2'),
      );
      expect(
        ActiveWorkout.primaryAction([bench, squatDone], 'e1'),
        const NextExerciseAction('e2'),
      );
      final benchDone = exercise('e2', [set('b1', doneAt: 2)]);
      expect(
        ActiveWorkout.primaryAction([squatDone, benchDone], 'e2'),
        const FinishAction(),
      );
      expect(ActiveWorkout.primaryAction([], null), isNull);
    });
  });

  group('sides', () {
    test('splitting makes a left and a right of each row for both', () {
      var next = 0;
      final sets = splittingSides([
        set('set-1'),
        set('set-2', index: 2, side: SetSide.both, reps: 8, doneAt: 0),
        set('set-3', index: 3, side: SetSide.both, reps: 6),
      ], () => 'new-${next++}');
      expect(
        [for (final s in sets) s.side],
        [null, SetSide.left, SetSide.right, SetSide.left, SetSide.right],
      );
      expect([for (final s in sets) s.index], [1, 2, 3, 4, 5]);
      expect([for (final s in sets) s.reps], [5, 8, 8, 6, 6]);
      expect(
        [for (final s in sets) s.completedAt != null],
        [false, true, true, false, false],
      );
      expect(sets[1].id, 'set-2');
      expect({for (final s in sets) s.id}, hasLength(5));
      expect(exercise('e', sets).workingSetCount, 3);
    });

    test('joining turns each pair into one row', () {
      final sets = joiningSides([
        set('set-1', side: SetSide.left, weightKg: 20, doneAt: 0),
        set('set-2', index: 2, side: SetSide.right, weightKg: 22.5),
        set('set-3', index: 3, side: SetSide.left, weightKg: 25, doneAt: 0),
        set('set-4', index: 4, side: SetSide.right, weightKg: 27.5, doneAt: 0),
        set('set-5', index: 5, side: SetSide.right, weightKg: 30),
        set('w', index: 6, isWarmup: true),
      ]);
      expect([for (final s in sets) s.id], ['set-1', 'set-3', 'set-5', 'w']);
      expect(
        [for (final s in sets) s.side],
        [SetSide.both, SetSide.both, SetSide.both, null],
      );
      expect([for (final s in sets) s.index], [1, 2, 3, 4]);
      expect([for (final s in sets) s.weightKg], [20, 25, 30, 100]);
      expect(
        [for (final s in sets) s.completedAt != null],
        [false, true, false, false],
      );
    });

    test('split and sides per set follow the rows', () {
      final both = exercise('e', [set('a', side: SetSide.both)]);
      final split = exercise('e', [
        set('l', side: SetSide.left),
        set('r', side: SetSide.right),
      ]);
      final plain = exercise('e', [set('a')]);
      expect(both.isPerSide && !both.isSplit, isTrue);
      expect(both.sidesPerSet, [SetSide.both]);
      expect(split.isPerSide && split.isSplit, isTrue);
      expect(split.sidesPerSet, [SetSide.left, SetSide.right]);
      expect(!plain.isPerSide && !plain.isSplit, isTrue);
      expect(plain.sidesPerSet, [null]);
    });

    test('a half-finished pair counts as one set logged, none done', () {
      final sets = [
        set('l', side: SetSide.left, doneAt: 0),
        set('r', side: SetSide.right),
      ];
      expect(exercise('e', sets).loggedSetCount, 1);
      expect(fullyCompletedPairedSetCount(sets), 0);
      expect(pairedSetIds(sets, 'missing'), isEmpty);
    });

    test('last time matches a limb, then a row for both, never the other', () {
      final previous = exercise('p', [
        set('pl', side: SetSide.left, weightKg: 20),
        set('pr', side: SetSide.right, weightKg: 22.5),
      ]);
      final left = set('l', side: SetSide.left);
      final right = set('r', side: SetSide.right);
      final current = exercise('c', [left, right]);
      expect(previous.matchingSet(left, current)?.weightKg, 20);
      expect(previous.matchingSet(right, current)?.weightKg, 22.5);
      final leftOnly = exercise('p', [
        set('pl', side: SetSide.left, weightKg: 20),
      ]);
      expect(leftOnly.matchingSet(right, current), isNull);
      final before = exercise('p', [set('old', weightKg: 20)]);
      expect(before.matchingSet(left, current)?.weightKg, 20);
      expect(before.matchingSet(right, current)?.weightKg, 20);
    });

    test('a row for both reads last time’s pair by set number', () {
      final previous = exercise('p', [
        for (var n = 0; n < 3; n++) ...[
          set('l$n', side: SetSide.left, weightKg: 20.0 + n * 2),
          set('r$n', side: SetSide.right, weightKg: 21.0 + n * 2),
        ],
      ]);
      final rows = [
        for (var n = 1; n <= 3; n++) set('b$n', index: n, side: SetSide.both),
      ];
      final current = exercise('c', rows);
      expect(
        [for (final r in rows) previous.matchingSet(r, current)?.weightKg],
        [20, 22, 24],
      );
    });

    test('a warm-up matches by its place among the warm-ups', () {
      final previous = exercise('p', [
        set('pw1', isWarmup: true, weightKg: 40),
        set('pw2', isWarmup: true, weightKg: 60),
        set('p1'),
      ]);
      final today = exercise('c', [
        set('w1', isWarmup: true),
        set('w2', isWarmup: true),
        set('w3', isWarmup: true),
        set('s1'),
      ]);
      expect(previous.matchingSet(today.sets[1], today)?.weightKg, 60);
      expect(previous.matchingSet(today.sets[2], today), isNull);
      expect(previous.matchingSet(set('stray', isWarmup: true), today), isNull);
    });
  });

  group('loads', () {
    test('the kind of load a variation lifts', () {
      String? kind(List<(EquipmentKind, String)> refs) =>
          loadKind([for (final (k, id) in refs) EquipmentRef(k, id)]);
      expect(
        kind([
          (EquipmentKind.freeWeight, 'weight_plates'),
          (EquipmentKind.loadableBar, 'barbell'),
        ]),
        'barAndPlates',
      );
      expect(
        kind([(EquipmentKind.plateLoadedMachine, 'sled')]),
        'plateMachine',
      );
      expect(kind([(EquipmentKind.cableMachine, 'c')]), 'stack');
      expect(kind([(EquipmentKind.pinLoadedMachine, 'p')]), 'stack');
      expect(
        kind([
          (EquipmentKind.freeWeight, 'weight_plates'),
          (EquipmentKind.freeWeight, 'dumbbells'),
        ]),
        'freeWeight:dumbbells',
      );
      expect(
        kind([(EquipmentKind.freeWeight, 'weight_plates')]),
        'freeWeight:weight_plates',
      );
      expect(kind([(EquipmentKind.fixedWeightBar, 'f')]), 'fixedBar');
      expect(kind([(EquipmentKind.bodyWeight, 'bw')]), 'bodyweight');
      expect(kind([(EquipmentKind.bands, 'b')]), 'bands');
      expect(kind([(EquipmentKind.supportEquipment, 'bench')]), isNull);
    });

    test('either side unknown is the same load', () {
      const bar = [EquipmentRef(EquipmentKind.loadableBar, 'barbell')];
      const bench = [EquipmentRef(EquipmentKind.supportEquipment, 'bench')];
      expect(isSameLoad(null, bar), isTrue);
      expect(isSameLoad(bar, null), isTrue);
      expect(isSameLoad(bench, bar), isTrue);
      expect(isSameLoad(bar, bar), isTrue);
    });
  });

  group('value types', () {
    test('compare by value', () {
      expect(
        const ProgressionSuggestion(Rationale.hold, [SuggestedSet(reps: 1)]),
        const ProgressionSuggestion(Rationale.hold, [SuggestedSet(reps: 1)]),
      );
      expect(const StepBands(), const StepBands());
      expect(const RestTop(), const RestTop());
      expect(const RestBelow('a'), isNot(const RestBelow('b')));
      expect(
        const NextExerciseAction('a'),
        isNot(const NextExerciseAction('b')),
      );
      expect(const LogSetAction('a', 's'), const LogSetAction('a', 's'));
      expect(const SlotLog('a', 's'), isNot(const SlotLog('a', 't')));
      expect(const SlotNext('a'), isNot(const SlotNext('b')));
      expect(RestRestoreEnded(start), RestRestoreEnded(start));
      expect(
        const LogOutcome(session: WorkoutSession(exercises: [])),
        const LogOutcome(session: WorkoutSession(exercises: [])),
      );
      expect(
        const StripItem(
          id: 'a',
          names: [],
          imageNames: [],
          supersetLetter: null,
          doneWorkingSets: 0,
          totalWorkingSets: 0,
          isCurrent: false,
        ),
        isNot(
          const StripItem(
            id: 'b',
            names: [],
            imageNames: [],
            supersetLetter: null,
            doneWorkingSets: 0,
            totalWorkingSets: 0,
            isCurrent: false,
          ),
        ),
      );
      expect(const SetTarget(minReps: 1), isNot(const SetTarget(minReps: 2)));
      expect(
        const WorkoutExercise(id: 'a'),
        isNot(const WorkoutExercise(id: 'b')),
      );
      expect(
        const WorkoutSession(exercises: [], isDeload: true),
        isNot(const WorkoutSession(exercises: [])),
      );
      expect(const SupersetBlockRow(exerciseId: 'e').id, 'warmups-e');
    });

    test('their fields are what they compare', () {
      // Equal constants are identical, so props are read for the hash.
      for (final value in <Object>[
        const RestTop(),
        const FinishAction(),
        const SlotSkipRest(),
        const RestRestoreNone(),
        const StepBands(),
        const LogOutcome(session: WorkoutSession(exercises: [])),
        const ProgressionSuggestion(Rationale.hold, []),
      ]) {
        expect(value.hashCode, isA<int>());
      }
      expect(const RestTop().props, isEmpty);
      expect(
        const WorkoutExercise(id: 'a', name: 'A').copyWith(),
        const WorkoutExercise(id: 'a', name: 'A'),
      );
    });

    test('a set copies with fields cleared or kept', () {
      const full = WorkoutSet(
        id: 's',
        reps: 5,
        weightKg: 50,
        durationSec: 3,
        distanceMeters: 4,
        rpe: 8,
        side: SetSide.left,
        targetReps: 6,
        bands: ['Red'],
        weightUnit: WeightUnit.pounds,
        loadCount: 2,
        machineBaseKg: 10,
      );
      expect(full.copyWith(), full);
      expect(full.loadKg, 40);
      final cleared = full.copyWith(
        reps: null,
        weightKg: null,
        durationSec: null,
        distanceMeters: null,
        rpe: 9,
        side: null,
        targetReps: null,
        bands: null,
        weightUnit: null,
        loadCount: null,
      );
      expect(cleared.reps, isNull);
      expect(cleared.weightKg, isNull);
      expect(cleared.loadKg, isNull);
      expect(cleared.rpe, 9);
      expect(cleared.side, isNull);
      expect(cleared.machineBaseKg, 10);
    });
  });
}
