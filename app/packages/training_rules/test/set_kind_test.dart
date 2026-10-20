// Ports SetKindTests and SetKindUITests (the rules; decoding is the
// compound_models slice's, wording and presenters the app's).
import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

final start = DateTime.fromMillisecondsSinceEpoch(1000000000, isUtc: true);

WorkoutSet set(
  String id, {
  double? weight = 100,
  int? reps = 8,
  SetKind kind = SetKind.standard,
  String? parent,
  SetSide? side,
  bool warmup = false,
  bool logged = false,
}) => WorkoutSet(
  id: id,
  reps: reps,
  weightKg: weight,
  side: side,
  kind: kind,
  parentSetId: parent,
  isWarmup: warmup,
  completedAt: logged ? start : null,
);

WorkoutExercise exercise(List<WorkoutSet> sets) =>
    WorkoutExercise(id: 'e1', templateId: 't1', sets: sets);

List<String> ids(List<WorkoutSet> sets) => [for (final s in sets) s.id];

void main() {
  group('the model', () {
    test("a template's set type maps to a kind", () {
      for (final type in SetTargetSetType.values) {
        final kind = SetKind.fromSetType(type);
        expect(
          kind,
          type == SetTargetSetType.failure
              ? SetKind.amrap
              : SetKind.values.byName(type.name),
        );
      }
    });

    test('partials, stretch and hold do not rest within the set', () {
      for (final kind in [SetKind.partials, SetKind.stretch, SetKind.hold]) {
        expect(kind.restsWithinTheSet, isFalse);
        expect(const WorkoutSettings().intraSetRest(kind), isNull);
        expect(ActiveWorkout.offersMiniSet(set('s1', kind: kind)), isFalse);
      }
    });

    test('only a stretch or hold piece is timed', () {
      expect(set('p', kind: SetKind.stretch, parent: 's1').isTimedPiece, true);
      expect(set('p', kind: SetKind.hold, parent: 's1').isTimedPiece, true);
      expect(set('s1', kind: SetKind.hold).isTimedPiece, false);
      expect(
        set('p', kind: SetKind.partials, parent: 's1').isTimedPiece,
        false,
      );
    });

    test('a timed piece logs with a time and partials with reps', () {
      final stretch = set(
        'p',
        kind: SetKind.stretch,
        parent: 's1',
        reps: null,
        weight: null,
      );
      expect(
        SetValidation.problem(stretch, TrackingMode.weightReps),
        SetProblem.noTime,
      );
      expect(
        SetValidation.canLog(
          stretch.copyWith(durationSec: 30),
          TrackingMode.weightReps,
        ),
        isTrue,
      );
      expect(
        SetValidation.problem(
          set('p', kind: SetKind.partials, parent: 's1', reps: null),
          TrackingMode.weightReps,
        ),
        SetProblem.noReps,
      );
    });

    test('a sub-set is not counted as a set', () {
      final sets = [
        set('s1', logged: true),
        set('s1-d1', kind: SetKind.drop, parent: 's1', logged: true),
        set('s1-d2', kind: SetKind.drop, parent: 's1', logged: true),
        set('s2', logged: true),
      ];
      expect(pairedSetCount(sets), 2);
      expect(fullyCompletedPairedSetCount(sets), 2);
    });

    test('a sub-set between a pair does not break the pair', () {
      final sets = [
        set('s1-l', side: SetSide.left),
        set('s1-r', side: SetSide.right),
        set('s1-d', kind: SetKind.drop, parent: 's1-l', side: SetSide.right),
        set('s2-l', side: SetSide.left),
      ];
      expect(pairedSetCount(sets), 2);
    });

    test("a sub-set shares its parent's number", () {
      final drop = set('s1-d', kind: SetKind.drop, parent: 's1', logged: true);
      final second = set('s2', logged: true);
      final e = exercise([set('s1', logged: true), drop, second]);
      expect(e.workingSetNumber(drop), 1);
      expect(e.workingSetNumber(second), 2);
      expect(e.workingSetCount, 2);
      expect(e.loggedSetCount, 2);
    });

    test('progression history leaves sub-sets out', () {
      final session = WorkoutSession(
        exercises: [
          exercise([
            set('s1', logged: true),
            set('s1-d', kind: SetKind.drop, parent: 's1', logged: true),
            set('s2', logged: true),
          ]),
        ],
      );
      expect(ids(ProgressionPlanner.historyFor('t1', [session]).first), [
        's1',
        's2',
      ]);
    });

    test('a choice records its analytics value', () {
      expect(SetTypeChoice.warmup.eventValue, 'warmup');
      expect(
        const SetTypeChoice.ofKind(SetKind.restPause).eventValue,
        'restPause',
      );
    });
  });

  group('the set-number menu', () {
    const five = [
      SetTypeChoice.ofKind(SetKind.standard),
      SetTypeChoice.warmup,
      SetTypeChoice.ofKind(SetKind.drop),
      SetTypeChoice.ofKind(SetKind.myo),
      SetTypeChoice.ofKind(SetKind.amrap),
    ];

    test('offers the five types, keeping a planned kind', () {
      expect(ActiveWorkout.setTypeOptions(set('s1')), five);
      expect(ActiveWorkout.setTypeOptions(set('w1', warmup: true)), five);
      expect(ActiveWorkout.setTypeOptions(set('s1', kind: SetKind.restPause)), [
        ...five,
        const SetTypeChoice.ofKind(SetKind.restPause),
      ]);
      expect(typeChoiceOf(set('w1', warmup: true)), SetTypeChoice.warmup);
    });

    test('opens from sets of their own only', () {
      expect(ActiveWorkout.offersSetTypes(set('s1')), isTrue);
      expect(ActiveWorkout.offersSetTypes(set('w1', warmup: true)), isTrue);
      expect(
        ActiveWorkout.offersSetTypes(
          set('d1', kind: SetKind.drop, parent: 's1'),
        ),
        isFalse,
      );
    });

    test('another drop or mini-set only where the type takes one', () {
      expect(ActiveWorkout.offersDrop(set('s1', kind: SetKind.drop)), isTrue);
      expect(ActiveWorkout.offersDrop(set('s1')), isFalse);
      expect(
        ActiveWorkout.offersDrop(set('d1', kind: SetKind.drop, parent: 's0')),
        isFalse,
      );
      expect(
        ActiveWorkout.offersDrop(set('w1', kind: SetKind.drop, warmup: true)),
        isFalse,
      );
      for (final kind in [SetKind.myo, SetKind.restPause, SetKind.cluster]) {
        expect(ActiveWorkout.offersMiniSet(set('s1', kind: kind)), isTrue);
      }
      expect(ActiveWorkout.offersMiniSet(set('s1')), isFalse);
      expect(
        ActiveWorkout.offersMiniSet(set('s1', kind: SetKind.amrap)),
        false,
      );
      expect(ActiveWorkout.offersMiniSet(set('m1', parent: 's0')), isFalse);
      expect(
        ActiveWorkout.offersMiniSet(set('w1', kind: SetKind.myo, warmup: true)),
        isFalse,
      );
    });
  });

  group('applying a type', () {
    List<WorkoutSet> applying(
      SetTypeChoice choice,
      String setId,
      List<WorkoutSet> sets,
    ) => ActiveWorkout.applying(
      choice,
      setId,
      sets,
      firstSubSetId: 'new',
      dropWeightKg: 80,
    );

    test('a drop set gets its first drop', () {
      final sets = applying(const SetTypeChoice.ofKind(SetKind.drop), 's1', [
        set('s1'),
        set('s2'),
      ]);
      expect(ids(sets), ['s1', 'new', 's2']);
      expect(sets[0].kind, SetKind.drop);
      expect(subSetKindOf(sets[1]), SubSetKind.drop);
      expect(sets[1].weightKg, 80);
    });

    test("a myo set gets its first mini-set at the set's weight", () {
      final sets = applying(const SetTypeChoice.ofKind(SetKind.myo), 's1', [
        set('s1'),
      ]);
      expect([for (final s in sets) subSetKindOf(s)], [null, SubSetKind.mini]);
      expect(sets[1].weightKg, 100);
    });

    test('a drop set made myo swaps its drops for a mini-set', () {
      final sets = applying(const SetTypeChoice.ofKind(SetKind.myo), 's1', [
        set('s1', kind: SetKind.drop),
        set('d1', kind: SetKind.drop, parent: 's1'),
      ]);
      expect(ids(sets), ['s1', 'new']);
      expect(sets[0].kind, SetKind.myo);
      expect(subSetKindOf(sets[1]), SubSetKind.mini);
    });

    test('a myo set made a drop set swaps its mini-sets for a drop', () {
      final sets = applying(const SetTypeChoice.ofKind(SetKind.drop), 's1', [
        set('s1', kind: SetKind.myo),
        set('m1', parent: 's1'),
      ]);
      expect(ids(sets), ['s1', 'new']);
      expect(subSetKindOf(sets[1]), SubSetKind.drop);
    });

    test('a myo set made a cluster keeps its mini-sets', () {
      final before = [set('s1', kind: SetKind.myo), set('m1', parent: 's1')];
      final sets = applying(
        const SetTypeChoice.ofKind(SetKind.cluster),
        's1',
        before,
      );
      expect(ids(sets), ['s1', 'm1']);
      expect(sets[0].kind, SetKind.cluster);
    });

    test('a repeat pick or an unknown set changes nothing', () {
      final before = [
        set('s1', kind: SetKind.drop),
        set('d1', kind: SetKind.drop, parent: 's1'),
      ];
      expect(
        applying(const SetTypeChoice.ofKind(SetKind.drop), 's1', before),
        before,
      );
      expect(applying(SetTypeChoice.warmup, 'zz', before), before);
    });

    test('a warm-up is plain and has no sub-rows', () {
      final sets = applying(SetTypeChoice.warmup, 's1', [
        set('s1', kind: SetKind.drop),
        set('d1', kind: SetKind.drop, parent: 's1'),
        set('s2'),
      ]);
      expect(ids(sets), ['s1', 's2']);
      expect(sets[0].isWarmup, isTrue);
      expect(sets[0].kind, SetKind.standard);
      final failure = applying(
        const SetTypeChoice.ofKind(SetKind.amrap),
        's1',
        sets,
      );
      expect(failure[0].isWarmup, isFalse);
      expect(failure[0].kind, SetKind.amrap);
    });

    test('both halves of a pair take the type', () {
      final sets = applying(const SetTypeChoice.ofKind(SetKind.amrap), 's1L', [
        set('s1L', side: SetSide.left),
        set('s1R', side: SetSide.right),
      ]);
      expect([for (final s in sets) s.kind], [SetKind.amrap, SetKind.amrap]);
    });
  });

  group('sub-rows', () {
    test('a drop goes under its set after the drops it has', () {
      var sets = [set('s1'), set('s2'), set('s3')];
      sets = ActiveWorkout.addingSubSet(
        SubSetKind.drop,
        's2',
        sets,
        id: 'd1',
        weightKg: 80,
      );
      sets = ActiveWorkout.addingSubSet(
        SubSetKind.drop,
        's2',
        sets,
        id: 'd2',
        weightKg: 60,
      );
      expect(ids(sets), ['s1', 's2', 'd1', 'd2', 's3']);
      expect(sets[2].parentSetId, 's2');
      expect(sets[2].kind, SetKind.drop);
      expect(sets[2].weightKg, 80);
      expect(sets[2].reps, isNull);
      expect(sets[2].completedAt, isNull);
      expect(sets[2].index, 2);
      expect(pairedSetCount(sets), 3);
    });

    test("a mini-set is plain and follows its set's kind", () {
      final sets = ActiveWorkout.addingSubSet(
        SubSetKind.mini,
        's1',
        [set('s1', kind: SetKind.myo)],
        id: 'm1',
        weightKg: 100,
      );
      expect(sets[1].kind, SetKind.standard);
      expect(subSetKindOf(sets[1]), SubSetKind.mini);
      expect(sets[1].weightKg, 100);
    });

    test('adding under an unknown set changes nothing', () {
      final sets = [set('s1')];
      expect(
        ActiveWorkout.addingSubSet(
          SubSetKind.drop,
          'zz',
          sets,
          id: 'd',
          weightKg: 1,
        ),
        sets,
      );
      expect(ActiveWorkout.subSetInsertionIndex('zz', sets), isNull);
    });

    test("a drop is twenty per cent lighter on the equipment's grid", () {
      final kilograms = WeightStep.fallback(WeightUnit.kilograms);
      double? drop(double? kg) =>
          ActiveWorkout.dropWeightKg(kg, kilograms, WeightUnit.kilograms);
      expect(drop(100), 80);
      expect(drop(57.5), 45);
      expect(drop(-30), -30);
      expect(drop(null), isNull);
      // On a rack whose nearest is the parent itself, one weight lighter.
      const rack = WeightStep(StepList([10, 20]));
      expect(ActiveWorkout.dropWeightKg(20, rack, WeightUnit.kilograms), 10);
      // Nothing lighter on the rack: the parent's weight stands.
      expect(ActiveWorkout.dropWeightKg(10, rack, WeightUnit.kilograms), 10);
      // In pounds: 100 lb drops to 80 lb.
      final pounds = WeightStep.fallback(WeightUnit.pounds);
      expect(
        ActiveWorkout.dropWeightKg(
          convertWeightToKg(100, WeightUnit.pounds),
          pounds,
          WeightUnit.pounds,
        ),
        closeTo(convertWeightToKg(80, WeightUnit.pounds), 1e-9),
      );
    });

    test('a planned drop is a share off the piece before', () {
      final kilograms = WeightRoundingRule(
        step: WeightStep.fallback(WeightUnit.kilograms),
        preferredUnit: WeightUnit.kilograms,
      );
      expect(ActiveWorkout.plannedDropWeightKg(100, 20, kilograms), 80);
      expect(ActiveWorkout.plannedDropWeightKg(101, 20, null), 81);
      expect(ActiveWorkout.plannedDropWeightKg(null, 20, kilograms), isNull);
      expect(ActiveWorkout.plannedDropWeightKg(-20, 20, kilograms), -20);
      // 1 % off 20 kg rounds back to 20: one increment lighter instead.
      expect(ActiveWorkout.plannedDropWeightKg(20, 1, kilograms), 17.5);
    });

    String removed(String setId, List<WorkoutSet> sets) {
      final counts = ActiveWorkout.subSetsRemovedByDeleting(setId, sets);
      return '${counts.drops} drops, ${counts.minis} minis';
    }

    test('deleting a set takes its drops with it', () {
      final sets = [
        set('s1'),
        set('d1', kind: SetKind.drop, parent: 's1'),
        set('d2', kind: SetKind.drop, parent: 's1'),
        set('m1', parent: 's1'),
        set('s2'),
      ];
      expect(ActiveWorkout.idsRemovedByDeleting('s1', sets).toSet(), {
        's1',
        'd1',
        'd2',
        'm1',
      });
      expect(ActiveWorkout.idsRemovedByDeleting('d2', sets), ['d2']);
      expect(removed('s1', sets), '2 drops, 1 minis');
      expect(removed('s2', sets), '0 drops, 0 minis');
    });

    test("deleting half of a pair takes both halves' drops", () {
      final sets = [
        set('s1L', side: SetSide.left),
        set('s1R', side: SetSide.right),
        set('d1L', kind: SetKind.drop, parent: 's1L', side: SetSide.left),
        set('d1R', kind: SetKind.drop, parent: 's1R', side: SetSide.right),
      ];
      expect(ActiveWorkout.idsRemovedByDeleting('s1R', sets).toSet(), {
        's1L',
        's1R',
        'd1L',
        'd1R',
      });
      expect(removed('s1L', sets), '1 drops, 0 minis');
    });

    test('a drop becomes current once its set is logged', () {
      final current = exercise([
        set('s1', logged: true),
        set('d1', kind: SetKind.drop, parent: 's1'),
        set('s2'),
      ]);
      expect(
        ActiveWorkout.rowState(current.sets[1], current),
        SetRowState.current,
      );
      expect(
        ActiveWorkout.rowState(current.sets[2], current),
        SetRowState.upcoming,
      );
      expect(current.workingSetNumber(current.sets[2]), 2);
    });

    test('sub-set ordinals count by kind and side', () {
      final sets = [
        set('s1'),
        set('d1', kind: SetKind.drop, parent: 's1'),
        set('m1', parent: 's1'),
        set('d2', kind: SetKind.drop, parent: 's1'),
      ];
      expect(ActiveWorkout.subSetOrdinal(sets[3], sets), 2);
      expect(ActiveWorkout.subSetOrdinal(sets[2], sets), 1);
      expect(ActiveWorkout.subSetOrdinal(sets[0], sets), 0);
      expect(subSetKindOf(sets[0]), isNull);
    });
  });

  group('last time', () {
    test("a drop's last is last time's drop, never its set", () {
      final last = exercise([
        set('p1', logged: true),
        set('pd1', weight: 80, kind: SetKind.drop, parent: 'p1', logged: true),
        set('pd2', weight: 60, kind: SetKind.drop, parent: 'p1', logged: true),
        set('p2', weight: 102.5, logged: true),
      ]);
      final today = exercise([
        set('s1'),
        set('d1', kind: SetKind.drop, parent: 's1'),
        set('d2', kind: SetKind.drop, parent: 's1'),
        set('d3', kind: SetKind.drop, parent: 's1'),
        set('s2'),
        set('d4', kind: SetKind.drop, parent: 's2'),
      ]);
      String? lastId(int index) =>
          ActiveWorkout.lastSet(today.sets[index], today, last)?.id;
      expect(lastId(0), 'p1');
      expect(lastId(1), 'pd1');
      expect(lastId(2), 'pd2');
      expect(lastId(3), isNull);
      expect(lastId(4), 'p2');
      expect(lastId(5), isNull);
      expect(ActiveWorkout.lastSet(today.sets[0], today, null), isNull);
    });

    test("a mini-set's last is matched by kind", () {
      final last = exercise([
        set('p1', kind: SetKind.myo, logged: true),
        set('pd1', weight: 80, kind: SetKind.drop, parent: 'p1', logged: true),
        set('pm1', reps: 5, parent: 'p1', logged: true),
      ]);
      final today = exercise([
        set('s1', kind: SetKind.myo),
        set('m1', parent: 's1'),
      ]);
      expect(ActiveWorkout.lastSet(today.sets[1], today, last)?.id, 'pm1');
    });

    test("a split drop takes its side's, then a row for both", () {
      final last = exercise([
        set('p1', logged: true),
        set('pd1', kind: SetKind.drop, parent: 'p1', logged: true),
      ]);
      final today = exercise([
        set('s1L', side: SetSide.left),
        set('s1R', side: SetSide.right),
        set('dL', kind: SetKind.drop, parent: 's1L', side: SetSide.left),
      ]);
      expect(ActiveWorkout.lastSet(today.sets[2], today, last)?.id, 'pd1');
    });

    test('a drop whose parent is missing, a sub-set or unmatched has none', () {
      final last = exercise([set('p1', logged: true)]);
      final orphan = exercise([set('d', kind: SetKind.drop, parent: 'gone')]);
      expect(ActiveWorkout.lastSet(orphan.sets[0], orphan, last), isNull);
      final nested = exercise([
        set('s1'),
        set('d1', kind: SetKind.drop, parent: 's1'),
        set('d2', kind: SetKind.drop, parent: 'd1'),
      ]);
      expect(ActiveWorkout.lastSet(nested.sets[2], nested, last), isNull);
      final unmatched = exercise([
        set('w', warmup: true),
        set('d', kind: SetKind.drop, parent: 'w'),
      ]);
      expect(ActiveWorkout.lastSet(unmatched.sets[1], unmatched, last), isNull);
    });
  });
}
