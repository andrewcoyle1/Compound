// Building sessions: from a template (WorkoutSessionModel's template
// initializer, WorkingSetPrefill, the set plan and the warm-ups), and the
// exercises added or swapped part-way through (WorkoutTrackerSwapTests,
// WorkoutTrackerAddExerciseTests, WorkoutTrackerSupersetTests' template
// case).
import 'package:compound_models/compound_models.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

import '../helpers/fixtures.dart';

m.WorkoutTemplateExercise _slot(
  m.ExerciseModel exercise, {
  String? id,
  List<m.SetTarget>? targets,
  String? group,
  int? warmups,
  List<m.MicrocycleSetTargets> byMicrocycle = const [],
}) => m.WorkoutTemplateExercise(
  id: id ?? 'slot-${exercise.id}',
  exercise: exercise,
  setTargets: targets ?? [target(1), target(2), target(3)],
  setRestTimers: false,
  notes: 'Plan note',
  warmupSetCount: warmups,
  restSeconds: 150,
  substituteExerciseIds: const ['alt'],
  supersetGroupId: group,
  linkUrl: 'https://example.com',
  setTargetsByMicrocycle: byMicrocycle,
);

m.WorkoutTemplateModel _template(List<m.WorkoutTemplateExercise> exercises) =>
    m.WorkoutTemplateModel(
      workoutId: 'template-1',
      authorId: author,
      name: 'Push',
      dateCreated: start,
      dateModified: start,
      exercises: exercises,
    );

final m.GymProfileModel _barbell = gym(
  freeWeights: [
    plates([1.25, 2.5, 5, 10, 20]),
  ],
  loadableBars: const [
    m.LoadableBars(
      id: 'barbell',
      typeId: 'barbell',
      name: 'Barbell',
      collarWeight: 0,
      isActive: true,
      baseWeights: [
        m.BarBaseWeight(
          id: 'b',
          baseWeight: 20,
          unit: m.ExerciseWeightUnit.kilograms,
          isActive: true,
        ),
      ],
    ),
  ],
);

final m.ExerciseModel _bench = library(
  'bench',
  name: 'Barbell Bench Press',
  type: m.ExerciseType.compoundUpper,
  variations: [
    variation('bar', [ref(m.EquipmentKind.loadableBar, 'barbell')]),
    variation('db', [ref(m.EquipmentKind.freeWeight, 'dumbbells')]),
  ],
);

void main() {
  test('newUuid is an upper-case version 4 UUID', () {
    final id = newUuid();
    expect(
      id,
      matches(
        RegExp(
          '^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-'
          r'[89AB][0-9A-F]{3}-[0-9A-F]{12}$',
        ),
      ),
    );
    expect(newUuid(), isNot(id));
  });

  test('setTargetsForMicrocycle takes the latest override that has begun', () {
    final slot = _slot(
      _bench,
      targets: [target(1)],
      byMicrocycle: [
        m.MicrocycleSetTargets(fromMicrocycle: 3, setTargets: [target(7)]),
        m.MicrocycleSetTargets(fromMicrocycle: 2, setTargets: [target(5)]),
        m.MicrocycleSetTargets(fromMicrocycle: 2, setTargets: [target(6)]),
      ],
    );
    int first(int? microcycle) =>
        setTargetsForMicrocycle(slot, microcycle).first.setNumber;
    expect(first(null), 1);
    expect(first(0), 1);
    expect(first(1), 1);
    expect(first(2), 5);
    expect(first(4), 7);
  });

  group('defaultSets', () {
    test('empty sets of the kind and effort each target asks for', () {
      final sets = defaultSets(
        authorId: author,
        now: start,
        newId: Ids().call,
        targetCount: 4,
        perSide: true,
        setTargets: [
          target(1, rir: 2),
          target(2, type: m.SetTargetSetType.amrap),
          target(3, type: m.SetTargetSetType.drop),
        ],
      );
      expect(sets.map((s) => s.index), [1, 2, 3, 4]);
      expect(sets.map((s) => s.rpe), [8, 10, null, null]);
      expect(sets.map((s) => s.kindRawValue), [null, 'amrap', 'drop', null]);
      expect(sets.every((s) => s.sideRawValue == 'both'), isTrue);
      expect(sets.every((s) => s.weightKg == null && s.reps == null), isTrue);
    });

    test('at least one', () {
      expect(
        defaultSets(
          authorId: author,
          now: start,
          newId: Ids().call,
          targetCount: 0,
        ),
        hasLength(1),
      );
    });
  });

  group('applyingSetPlan', () {
    final rule = weightRoundingRule(
      exercise: _bench,
      gym: _barbell,
      preferredUnit: m.ExerciseWeightUnit.kilograms,
    );

    List<m.WorkoutSetModel> plan(m.SetTarget planned, {double? weight = 100}) =>
        applyingSetPlan(
          [set('s', weightKg: weight, side: 'left').copyWith(targetReps: null)],
          setTargets: [planned],
          authorId: author,
          now: start,
          newId: Ids().call,
          rounding: rule,
        );

    test('a standard set is left as it is', () {
      expect(plan(target(1)).map((s) => s.id), ['s']);
    });

    test('an AMRAP set carries its target, unless already raised', () {
      expect(
        plan(target(1, type: m.SetTargetSetType.amrap, amrapTargetReps: 10))
            .single
            .targetReps,
        10,
      );
      expect(
        applyingSetPlan(
          [set('s').copyWith(targetReps: 12)],
          setTargets: [
            target(1, type: m.SetTargetSetType.failure, amrapTargetReps: 10),
          ],
          authorId: author,
          now: start,
          newId: Ids().call,
        ).single.targetReps,
        12,
      );
    });

    test('drops step down on weights the equipment makes', () {
      final sets = plan(
        target(
          1,
          type: m.SetTargetSetType.drop,
          dropCount: 2,
          dropStepPercent: 25,
          dropReps: 6,
        ),
      );
      expect(sets.map((s) => s.weightKg), [100, 75, 55]);
      expect(sets.skip(1).every((s) => s.parentSetId == 's'), isTrue);
      expect(sets.skip(1).every((s) => s.kindRawValue == 'drop'), isTrue);
      expect(sets.skip(1).every((s) => s.reps == 6), isTrue);
      expect(sets.skip(1).every((s) => s.sideRawValue == 'left'), isTrue);
      expect(plan(target(1, type: m.SetTargetSetType.drop)).map((s) => s.id), [
        's',
      ]);
    });

    test('a drop without a rule lands on a half kilo, 20 % off', () {
      expect(
        applyingSetPlan(
          [set('s', weightKg: 51)],
          setTargets: [target(1, type: m.SetTargetSetType.drop, dropCount: 1)],
          authorId: author,
          now: start,
          newId: Ids().call,
        ).last.weightKg,
        41,
      );
    });

    test('mini-sets at the set weight, as plain pieces', () {
      for (final type in [
        m.SetTargetSetType.myo,
        m.SetTargetSetType.restPause,
        m.SetTargetSetType.cluster,
      ]) {
        final sets = plan(target(1, type: type, miniSetCount: 2));
        expect(sets.map((s) => s.weightKg), [100, 100, 100]);
        expect(sets.skip(1).every((s) => s.kindRawValue == null), isTrue);
      }
    });

    test('partials, a stretch and a hold follow the set', () {
      final partials = plan(
        target(1, type: m.SetTargetSetType.partials, partialReps: 5),
      );
      expect(partials.last.kindRawValue, 'partials');
      expect(partials.last.reps, 5);
      expect(partials.last.weightKg, 100);
      final stretch = plan(
        target(1, type: m.SetTargetSetType.stretch, holdSeconds: 30),
      );
      expect(stretch.last.kindRawValue, 'stretch');
      expect(stretch.last.weightKg, isNull);
      expect(stretch.last.durationSec, 30);
      final hold = plan(
        target(1, type: m.SetTargetSetType.hold, holdSeconds: 20),
      );
      expect(hold.last.kindRawValue, 'hold');
      expect(hold.last.weightKg, 100);
    });

    test('sets past the targets, and sub-sets, are left alone', () {
      final sets = applyingSetPlan(
        [set('a'), set('b', parent: 'a'), set('c')],
        setTargets: [
          target(1),
          target(2, type: m.SetTargetSetType.drop, dropCount: 1),
        ],
        authorId: author,
        now: start,
        newId: Ids().call,
      );
      expect(sets.map((s) => s.id), ['a', 'b', 'c']);
    });
  });

  group('sessionFromTemplate', () {
    final previous = session(
      [
        exercise(
          'last-bench',
          templateId: 'bench',
          variations: _bench.equipmentVariations,
          chosenVariationId: 'bar',
          sets: [
            set('w', weightKg: 40, warmup: true, done: true),
            set('1', reps: 10, weightKg: 100, done: true),
            set('2', reps: 9, weightKg: 100, done: true),
            set(
              'd',
              reps: 6,
              weightKg: 70,
              kind: 'drop',
              parent: '2',
              done: true,
            ),
          ],
        ),
      ],
      id: 'last',
      templateId: 'template-1',
      ended: start,
      gymProfileId: 'gym-1',
    );

    m.WorkoutSessionModel build({
      m.SetTarget? third,
      r.SessionPrefill prefill = const r.PrefillPreviousValues(),
      bool plansSets = false,
      m.WorkoutSessionModel? last,
      int? warmups,
    }) => sessionFromTemplate(
      authorId: author,
      template: _template([
        _slot(
          _bench,
          targets: [target(1, min: 8, max: 10), target(2), ?third],
          warmups: warmups,
        ),
      ]),
      now: start,
      newId: Ids().call,
      previousSession: last ?? previous,
      gym: _barbell,
      prefill: prefill,
      plansSets: plansSets,
    );

    test('carries the template and the slot onto the session', () {
      final built = build();
      final bench = built.exercises.single;
      expect(built.name, 'Push');
      expect(built.workoutTemplateId, 'template-1');
      expect(built.gymProfileId, 'gym-1');
      expect(built.dateCreated, start);
      expect(built.dateModified, start);
      expect(built.endedAt, isNull);
      expect(bench.templateId, 'bench');
      expect(bench.name, 'Barbell Bench Press');
      expect(bench.imageName, 'BarbellBenchPress');
      expect(bench.index, 1);
      expect(bench.planNotes, 'Plan note');
      expect(bench.planSlotId, 'slot-bench');
      expect(bench.restSeconds, 150);
      expect(bench.linkUrl, 'https://example.com');
      expect(bench.substituteExerciseIds, ['alt']);
      expect(bench.chosenVariationId, 'bar');
      expect(bench.equipmentVariations, hasLength(2));
      expect(bench.weightUnit, m.ExerciseWeightUnit.kilograms);
      expect(bench.setTargets, hasLength(2));
    });

    test("fills working sets with last time's, a set at a time", () {
      final sets = build().exercises.single.sets;
      final working = sets.where((s) => !s.isWarmup).toList();
      expect(working.map((s) => s.weightKg), [100, 100]);
      expect(working.map((s) => s.reps), [10, 9]);
      expect(sets.map((s) => s.index), [
        for (var i = 1; i <= sets.length; i++) i,
      ]);
    });

    test('warms up to the working weight, rounded on the bar', () {
      final warmUps = build().exercises.single.sets.where((s) => s.isWarmup);
      expect(warmUps.map((s) => s.weightKg), [50, 75]);
      expect(warmUps.map((s) => s.reps), [8, 3]);
      expect(warmUps.every((s) => s.kindRawValue == null), isTrue);
      expect(
        build(warmups: 1).exercises.single.sets.where((s) => s.isWarmup),
        hasLength(1),
      );
    });

    test('leaves the working sets empty when asked', () {
      final working = build(prefill: const r.PrefillEmpty())
          .exercises
          .single
          .sets
          .where((s) => !s.isWarmup);
      expect(
        working.every((s) => s.weightKg == null && s.reps == null),
        isTrue,
      );
    });

    test("takes smart progression's suggestion where there is one", () {
      final working = build(
        prefill: const r.PrefillSuggestions({
          'bench#0': r.ProgressionSuggestion(r.Rationale.progressWeight, [
            r.SuggestedSet(weightKg: 102.5, reps: 8),
          ]),
        }),
      ).exercises.single.sets.where((s) => !s.isWarmup);
      expect(working.map((s) => s.weightKg), [102.5, 100]);
      expect(working.map((s) => s.reps), [8, 9]);
    });

    test('lays the set plan on when planning sets', () {
      final sets = build(
        third: target(3, type: m.SetTargetSetType.drop, dropCount: 1),
        plansSets: true,
      ).exercises.single.sets.where((s) => !s.isWarmup).toList();
      expect(sets.map((s) => s.kindRawValue), [null, null, 'drop', 'drop']);
      expect(sets.last.parentSetId, sets[2].id);
    });

    test('reads last time only on the same kind of load', () {
      final onDumbbells = session([
        exercise(
          'last-bench',
          templateId: 'bench',
          variations: _bench.equipmentVariations,
          chosenVariationId: 'db',
          sets: [set('1', reps: 10, weightKg: 30, done: true)],
        ),
      ], gymProfileId: 'gym-1');
      final working = build(last: onDumbbells).exercises.single.sets
          .where((s) => !s.isWarmup);
      expect(working.every((s) => s.weightKg == null), isTrue);
    });

    test('estimates warm-ups from last time when nothing is prefilled', () {
      final warmUps = build(prefill: const r.PrefillEmpty())
          .exercises
          .single
          .sets
          .where((s) => s.isWarmup);
      expect(warmUps.map((s) => s.weightKg), [50, 75]);
      final onlyWarmUps = session([
        exercise(
          'last-bench',
          templateId: 'bench',
          sets: [set('w', weightKg: 40, reps: 10, warmup: true, done: true)],
        ),
      ]);
      expect(
        build(
          prefill: const r.PrefillEmpty(),
          last: onlyWarmUps,
        ).exercises.single.sets.where((s) => s.isWarmup).map((s) => s.weightKg),
        [20, 30],
      );
    });

    test('matches an exercise listed twice to its own last time', () {
      final twice = _template([
        _slot(_bench, id: 'heavy', targets: [target(1)]),
        _slot(_bench, id: 'back-off', targets: [target(1)]),
      ]);
      final last = session([
        exercise(
          'a',
          templateId: 'bench',
          sets: [set('1', weightKg: 100, done: true)],
        ),
        exercise(
          'b',
          templateId: 'bench',
          index: 2,
          sets: [set('2', done: true)],
        ),
      ]);
      final built = sessionFromTemplate(
        authorId: author,
        template: twice,
        now: start,
        newId: Ids().call,
        previousSession: last,
      );
      expect(
        built.exercises.map(
          (e) => e.sets.where((s) => !s.isWarmup).single.weightKg,
        ),
        [100, 80],
      );
      expect(built.exercises.map((e) => e.index), [1, 2]);
      expect(built.gymProfileId, isNull);
    });

    test('a template superset is one block', () {
      final built = sessionFromTemplate(
        authorId: author,
        template: _template([
          _slot(library('a'), group: 'S1'),
          _slot(library('b'), group: 'S1'),
          _slot(library('c')),
        ]),
        now: start,
        newId: Ids().call,
      );
      final ids = built.exercises.map((e) => e.id).toList();
      expect(
        r.ActiveWorkout.blocks(built.exercises.map(rulesExercise).toList()),
        [
          [ids[0], ids[1]],
          [ids[2]],
        ],
      );
    });

    test('a per-side exercise gets both rows, and the unit preferred', () {
      final row = library(
        'row',
        metrics: const [
          m.TrackableExerciseMetric.weight,
          m.TrackableExerciseMetric.repsPerSide,
        ],
      );
      final built = sessionFromTemplate(
        authorId: author,
        template: _template([_slot(row)]),
        now: start,
        newId: Ids().call,
        id: 'given',
        notes: 'Note',
        mesocycleId: 'meso',
        unitPreferences: const {
          'row': UnitPreference(weightUnit: m.ExerciseWeightUnit.pounds),
        },
      );
      expect(built.id, 'given');
      expect(built.notes, 'Note');
      expect(built.mesocycleId, 'meso');
      expect(built.exercises.single.weightUnit, m.ExerciseWeightUnit.pounds);
      // Warm-ups are for the lift, not a side.
      expect(built.exercises.single.sets.map((s) => s.sideRawValue), [
        null,
        null,
        'both',
        'both',
        'both',
      ]);
    });
  });

  test('emptySession has no template and no exercises', () {
    final empty = emptySession(authorId: author, now: start, newId: Ids().call);
    expect(empty.name, 'Workout');
    expect(empty.exercises, isEmpty);
    expect(empty.workoutTemplateId, isNull);
    expect(empty.id, 'id-1');
  });

  group('addingSet', () {
    test('carries the last figures on each side, indexed past the highest', () {
      final split = exercise(
        'e',
        sets: [
          set('w', warmup: true),
          set('l', index: 2, weightKg: 20, side: 'left'),
          set('r', index: 3, weightKg: 22, side: 'right'),
          set('d', index: 9, weightKg: 10, side: 'right', parent: 'r'),
        ],
      );
      final added = addingSet(
        split,
        authorId: author,
        now: start,
        newId: Ids().call,
      ).sets.skip(4);
      expect(added.map((s) => s.sideRawValue), ['left', 'right']);
      expect(added.map((s) => s.weightKg), [20, 22]);
      expect(added.map((s) => s.index), [10, 11]);
      expect(added.every((s) => s.completedAt == null), isTrue);
    });

    test('an exercise with no sets gets an empty one', () {
      final added = addingSet(exercise('e'), authorId: author, now: start).sets;
      expect(added.single.index, 1);
      expect(added.single.weightKg, isNull);
    });
  });

  test('an exercise added part-way through takes its targets and rows', () {
    final row = library(
      'one-arm-row',
      name: 'One-Arm Row',
      metrics: const [
        m.TrackableExerciseMetric.weight,
        m.TrackableExerciseMetric.repsPerSide,
      ],
      variations: [
        variation('bar', [ref(m.EquipmentKind.loadableBar, 'barbell')]),
      ],
    );
    final added = addedExercise(
      _slot(row),
      authorId: author,
      index: 3,
      now: start,
      gym: _barbell,
      preference: null,
      newId: Ids().call,
    );
    expect(added.sets, hasLength(3));
    expect(added.sets.every((s) => s.sideRawValue == 'both'), isTrue);
    expect(added.index, 3);
    expect(added.templateId, 'one-arm-row');
    expect(added.chosenVariationId, 'bar');
    expect(added.setTargets, hasLength(3));
  });

  group('swapping (WorkoutTrackerSwapTests)', () {
    m.WorkoutExerciseModel halfDone({String? group}) => exercise(
      'e1',
      group: group,
      targets: [
        for (var n = 1; n <= 3; n++) target(n, min: n * 2, max: n * 2 + 2),
      ],
      sets: [
        set('w1', done: true, warmup: true),
        set('w2', index: 2, warmup: true),
        set('s1', index: 3, done: true),
        set('s2', index: 4),
        set('s3', index: 5),
      ],
    );
    final replacement = library(
      'dumbbell-press',
      name: 'Dumbbell Press',
      variations: [
        variation('db', [ref(m.EquipmentKind.freeWeight, 'dumbbells')]),
      ],
    );

    test('logged sets stay on the old exercise, out of its superset', () {
      final swap = swapping(
        halfDone(group: 'g'),
        replacement: replacement,
        authorId: author,
        now: start,
      );
      expect(swap.kept!.id, 'e1');
      expect(swap.kept!.templateId, 'template-e1');
      expect(swap.kept!.sets.map((s) => s.id), ['w1', 's1']);
      expect(swap.kept!.supersetGroupId, isNull);
      expect(swap.replacement.supersetGroupId, 'g');
    });

    test('the replacement takes the open working sets only', () {
      final swap = swapping(
        halfDone(),
        replacement: replacement,
        authorId: author,
        now: start,
      );
      expect(swap.replacement.id, isNot('e1'));
      expect(swap.replacement.templateId, 'dumbbell-press');
      expect(swap.replacement.name, 'Dumbbell Press');
      expect(swap.replacement.sets, hasLength(2));
      expect(
        swap.replacement.sets.every(
          (s) => s.completedAt == null && !s.isWarmup,
        ),
        isTrue,
      );
      expect(swap.replacement.sets.map((s) => s.index), [1, 2]);
      expect(swap.replacement.index, 2);
      expect(swap.replacement.equipmentVariations, hasLength(1));
    });

    test('the replacement takes the targets of the open sets', () {
      final swap = swapping(
        halfDone(),
        replacement: replacement,
        authorId: author,
        now: start,
      );
      expect(swap.replacement.setTargets.map((t) => t.setNumber), [1, 2]);
      expect(swap.replacement.setTargets.map((t) => t.minReps), [4, 6]);
    });

    test('with nothing logged the replacement takes its place', () {
      final fresh = exercise(
        'e1',
        sets: [for (var i = 1; i <= 4; i++) set('s$i', index: i)],
      );
      final swap = swapping(
        fresh,
        replacement: replacement,
        authorId: author,
        now: start,
      );
      expect(swap.kept, isNull);
      expect(swap.replacement.id, 'e1');
      expect(swap.replacement.sets, hasLength(4));
      expect(swap.replacement.setTargets.single.minReps, 8);
      expect(swap.replacement.setTargets.single.maxReps, 12);
    });

    test('the plan fields stay on the replacement', () {
      final planned = halfDone().copyWith(
        planNotes: 'Pause at the chest',
        restSeconds: 150,
        linkUrl: 'https://example.com/bench',
        substituteExerciseIds: ['alt-1', 'alt-2'],
        planSlotId: 'slot',
      );
      final swap = swapping(
        planned,
        replacement: replacement,
        authorId: author,
        now: start,
      );
      expect(swap.replacement.planNotes, 'Pause at the chest');
      expect(swap.replacement.restSeconds, 150);
      expect(swap.replacement.linkUrl, 'https://example.com/bench');
      expect(swap.replacement.substituteExerciseIds, ['alt-1', 'alt-2']);
      expect(swap.replacement.planSlotId, 'slot');
    });

    test('three sets when none were open; split when the old was', () {
      final done = exercise('e1', sets: [set('s1', done: true)]);
      expect(
        swapping(
          done,
          replacement: replacement,
          authorId: author,
          now: start,
        ).replacement.sets,
        hasLength(3),
      );
      final split = exercise(
        'e1',
        sets: [
          set('l', side: 'left', done: true),
          set('r', side: 'right'),
          set('l2', side: 'left', index: 2),
          set('r2', side: 'right', index: 2),
        ],
      );
      final perSide = library(
        'lunge',
        metrics: const [m.TrackableExerciseMetric.repsPerSide],
      );
      final sides = swapping(
        split,
        replacement: perSide,
        authorId: author,
        now: start,
        newId: Ids().call,
      ).replacement.sets.map((s) => s.sideRawValue);
      expect(sides, ['left', 'right', 'left', 'right']);
    });
  });

  test('withLibraryExercises takes the library copy; weekOf the week', () {
    final stale = library('bench', name: 'Old name');
    final template = _template([
      _slot(
        stale,
        targets: [target(1)],
        byMicrocycle: [
          m.MicrocycleSetTargets(fromMicrocycle: 2, setTargets: [target(9)]),
        ],
      ),
      _slot(library('gone')),
    ]);

    final current = withLibraryExercises(template, [_bench]);
    expect(current.exercises.first.exercise.name, 'Barbell Bench Press');
    expect(current.exercises.last.exercise.id, 'gone');
    expect(current.workoutId, template.workoutId);
    expect(weekOf(current, 2).exercises.first.setTargets.single.setNumber, 9);
    expect(
      weekOf(current, null).exercises.first.setTargets.single.setNumber,
      1,
    );
  });
}
