import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

typedef _Rules = WorkoutEditorRules;

ExerciseModel _model(String id) => ExerciseModel.fromFirestore({
  ExerciseModelKeys.id: id,
  ExerciseModelKeys.authorId: 'official',
  ExerciseModelKeys.name: id,
});

WorkoutTemplateExercise _exercise(String id, [String? group]) =>
    WorkoutTemplateExercise(
      id: id,
      exercise: _model('bench'),
      setTargets: const [SetTarget(id: 't1', setNumber: 1)],
      setRestTimers: false,
      supersetGroupId: group,
    );

/// Exercises named by id, with the group each is in.
List<WorkoutTemplateExercise> _list(List<(String, String?)> entries) => [
  for (final (id, group) in entries) _exercise(id, group),
];

List<String> _ids(List<WorkoutTemplateExercise> exercises) => [
  for (final e in exercises) e.id,
];

List<String?> _groups(List<WorkoutTemplateExercise> exercises) => [
  for (final e in exercises) e.supersetGroupId,
];

String Function() _ids$() {
  var next = 0;
  return () => 'id-${next++}';
}

List<SetTarget> _sets(int count) => [
  for (var i = 1; i <= count; i++) SetTarget(id: 's$i', setNumber: i),
];

void main() {
  group('copies', () {
    test('keep every field unless told, and clear on a null', () {
      const target = SetTarget(
        id: 't',
        setNumber: 1,
        minReps: 8,
        maxReps: 10,
        rirTarget: 2,
        setType: SetTargetSetType.drop,
        dropCount: 2,
        dropStepPercent: 30,
        dropReps: 6,
        miniSetCount: 3,
        amrapTargetReps: 9,
        partialReps: 4,
        holdSeconds: 20,
      );
      expect(
        sameDocument(target.copyWith().toFirestore(), target.toFirestore()),
        isTrue,
      );
      final cleared = target.copyWith(
        id: 'u',
        setNumber: 2,
        minReps: () => null,
        maxReps: () => null,
        rirTarget: () => null,
        dropCount: () => null,
        dropStepPercent: () => null,
        dropReps: () => null,
        miniSetCount: () => null,
        amrapTargetReps: () => null,
        partialReps: () => null,
        holdSeconds: () => null,
      );
      expect(cleared.toFirestore(), {
        SetTargetKeys.id: 'u',
        SetTargetKeys.setNumber: 2,
        SetTargetKeys.setType: 'drop',
      });
      expect(target.dropStep, 30);
      expect(cleared.dropStep, 20);

      final exercise = WorkoutTemplateExercise(
        id: 'e',
        exercise: _model('bench'),
        setTargets: const [],
        setRestTimers: true,
        notes: 'n',
        warmupSetCount: 1,
        restSeconds: 60,
        substituteExerciseIds: const ['x'],
        supersetGroupId: 'g',
        linkUrl: 'https://a.b',
        setTargetsByMicrocycle: const [
          MicrocycleSetTargets(fromMicrocycle: 2, setTargets: []),
        ],
      );
      expect(
        sameDocument(exercise.copyWith().toFirestore(), exercise.toFirestore()),
        isTrue,
      );
      final changed = exercise.copyWith(
        id: 'f',
        setTargets: _sets(1),
        setRestTimers: false,
        notes: () => null,
        warmupSetCount: () => null,
        restSeconds: () => null,
        substituteExerciseIds: const [],
        supersetGroupId: () => null,
        linkUrl: () => null,
        setTargetsByMicrocycle: const [],
      );
      expect(changed.toFirestore().keys, {
        WorkoutTemplateExerciseKeys.id,
        WorkoutTemplateExerciseKeys.exercise,
        WorkoutTemplateExerciseKeys.setTargets,
        WorkoutTemplateExerciseKeys.setRestTimers,
      });
    });

    test('sameDocument compares maps and lists all the way down', () {
      expect(
        sameDocument(
          {
            'a': [
              1,
              {'b': 2},
            ],
          },
          {
            'a': [
              1,
              {'b': 2},
            ],
          },
        ),
        isTrue,
      );
      expect(sameDocument({'a': 1}, {'b': 1}), isFalse);
      expect(sameDocument({'a': 1}, {'a': 1, 'b': 2}), isFalse);
      expect(sameDocument([1], [1, 2]), isFalse);
      expect(sameDocument([1], [2]), isFalse);
    });
  });

  group('new exercises', () {
    test('a picked exercise starts with one numbered standard set', () {
      final newId = _ids$();
      final exercise = _Rules.templateExercise(_model('bench'), newId: newId);
      expect(exercise.id, 'id-0');
      expect(exercise.setRestTimers, isFalse);
      expect(exercise.setTargets.single.toFirestore(), {
        SetTargetKeys.id: 'id-1',
        SetTargetKeys.setNumber: 1,
        SetTargetKeys.minReps: 8,
        SetTargetKeys.maxReps: 12,
        SetTargetKeys.setType: 'standard',
      });
    });

    test('confirming does not add an exercise the workout already has', () {
      final existing = [
        WorkoutTemplateExercise(
          id: 'a',
          exercise: _model('squat'),
          setTargets: const [],
          setRestTimers: false,
        ),
      ];
      final added = _Rules.addingPicked(existing, [
        _model('squat'),
        _model('lunge'),
        _model('lunge'),
      ], newId: _ids$());
      expect([for (final e in added) e.exercise.id], ['squat', 'lunge']);
    });
  });

  group('the wizard', () {
    GymProfileModel gym(String id) => GymProfileModel.fromFirestore({
      GymProfileModelKeys.id: id,
      GymProfileModelKeys.authorId: 'u',
      GymProfileModelKeys.name: id,
    });
    WorkoutTemplateModel template(String? gymId) => WorkoutTemplateModel(
      workoutId: 'wt-1',
      authorId: 'u',
      name: 'Leg Day',
      description: 'keep',
      imageUrl: 'https://image',
      gymProfileId: gymId,
      dateCreated: DateTime.utc(2026),
      dateModified: DateTime.utc(2026),
      exercises: const [],
    );

    test('editing keeps the gym while it exists', () {
      expect(
        _Rules.gymWithoutAsking(template('gym-1'), [
          gym('gym-1'),
          gym('x'),
        ])?.id,
        'gym-1',
      );
    });

    test('a single gym needs no asking; several do', () {
      expect(_Rules.gymWithoutAsking(null, [gym('gym-1')])?.id, 'gym-1');
      expect(_Rules.gymWithoutAsking(null, [gym('a'), gym('b')]), isNull);
      expect(
        _Rules.gymWithoutAsking(template('gone'), [gym('a'), gym('b')]),
        isNull,
      );
      expect(_Rules.gymWithoutAsking(null, const []), isNull);
    });

    test('editing saves under the original id, author and dates', () {
      final now = DateTime.utc(2026, 10, 15);
      final saved = _Rules.savedTemplate(
        existing: template('gym-1'),
        uid: 'other',
        name: 'New Name',
        gymProfileId: 'gym-2',
        exercises: [_exercise('a')],
        now: now,
        newId: _ids$(),
      );
      expect(saved.workoutId, 'wt-1');
      expect(saved.authorId, 'u');
      expect(saved.name, 'New Name');
      expect(saved.description, 'keep');
      expect(saved.imageUrl, 'https://image');
      expect(saved.gymProfileId, 'gym-2');
      expect(saved.dateCreated, DateTime.utc(2026));
      expect(saved.dateModified, now);
    });

    test("a new workout is the user's, with a new id", () {
      final now = DateTime.utc(2026, 10, 15);
      final saved = _Rules.savedTemplate(
        existing: null,
        uid: 'u',
        name: 'Push',
        gymProfileId: 'gym-1',
        exercises: [_exercise('a')],
        now: now,
        newId: _ids$(),
      );
      expect(saved.workoutId, 'id-0');
      expect(saved.authorId, 'u');
      expect(saved.dateCreated, now);
      expect(saved.description, isNull);
    });
  });

  // DefineWorkoutRulesTests.swift
  group('grouping', () {
    test('two or more chosen share one group, gathered where the first is', () {
      final grouped = _Rules.grouping(
        {'b', 'd'},
        _list([('a', null), ('b', null), ('c', null), ('d', null)]),
        groupId: 'g',
      );
      expect(_ids(grouped), ['a', 'b', 'd', 'c']);
      expect(_groups(grouped), [null, 'g', 'g', null]);
    });

    test('one chosen exercise makes no superset', () {
      final exercises = _list([('a', null), ('b', null)]);
      expect(_Rules.grouping({'a'}, exercises, groupId: 'g'), exercises);
      expect(
        _Rules.grouping({'a', 'missing'}, exercises, groupId: 'g'),
        exercises,
      );
    });

    test('joining a new superset dissolves an old one left with one', () {
      final grouped = _Rules.grouping(
        {'b', 'c'},
        _list([('a', 'old'), ('b', 'old'), ('c', null)]),
        groupId: 'new',
      );
      expect(_groups(grouped), [null, 'new', 'new']);
    });

    test('removing a member of three keeps the others together', () {
      expect(
        _groups(
          _Rules.removingFromSuperset(
            'b',
            _list([('a', 'g'), ('b', 'g'), ('c', 'g')]),
          ),
        ),
        ['g', null, 'g'],
      );
    });

    test('removing a member of two dissolves the superset', () {
      expect(
        _groups(
          _Rules.removingFromSuperset(
            'a',
            _list([('a', 'g'), ('b', 'g'), ('c', null)]),
          ),
        ),
        [null, null, null],
      );
    });

    test('a superset of one from elsewhere is dissolved', () {
      expect(
        _groups(
          _Rules.dissolvingLoneGroups(
            _list([('a', 'lone'), ('b', 'g'), ('c', 'g')]),
          ),
        ),
        [null, 'g', 'g'],
      );
    });

    test('supersets are lettered by first appearance', () {
      expect(
        _Rules.supersetLetters(
          _list([
            ('a', null),
            ('b', 'second'),
            ('c', 'first'),
            ('d', 'second'),
            ('e', 'first'),
            ('f', 'lone'),
          ]),
        ),
        {'second': 'A', 'first': 'B'},
      );
    });

    test('past Z the supersets are numbered', () {
      final letters = _Rules.supersetLetters([
        for (var i = 0; i < 27; i++) ...[
          _exercise('a$i', 'g$i'),
          _exercise('b$i', 'g$i'),
        ],
      ]);
      expect(letters['g25'], 'Z');
      expect(letters['g26'], '27');
    });

    test('a superset is one block where its first member is', () {
      expect(_Rules.blocks(_list([('a', 'g'), ('b', null), ('c', 'g')])), [
        ['a', 'c'],
        ['b'],
      ]);
    });
  });

  group('moving', () {
    test('moving a member down moves the whole superset', () {
      final moved = _Rules.moving(
        _list([('a1', 'a'), ('a2', 'a'), ('x', null), ('y', null)]),
        {0},
        3,
      );
      expect(_ids(moved), ['x', 'a1', 'a2', 'y']);
    });

    test('moving a member up moves the whole superset', () {
      final moved = _Rules.moving(
        _list([('x', null), ('a1', 'a'), ('a2', 'a')]),
        {2},
        0,
      );
      expect(_ids(moved), ['a1', 'a2', 'x']);
    });

    test('a member changes places within its own superset', () {
      final exercises = _list([
        ('x', null),
        ('a1', 'a'),
        ('a2', 'a'),
        ('y', null),
      ]);
      expect(_ids(_Rules.moving(exercises, {2}, 1)), ['x', 'a2', 'a1', 'y']);
      expect(_ids(_Rules.moving(exercises, {1}, 3)), ['x', 'a2', 'a1', 'y']);
    });

    test('an exercise dropped inside another superset lands beside it', () {
      final exercises = _list([('a1', 'a'), ('a2', 'a'), ('x', null)]);
      final below = _list([('x', null), ('a1', 'a'), ('a2', 'a')]);
      expect(_ids(_Rules.moving(exercises, {2}, 1)), ['x', 'a1', 'a2']);
      expect(_ids(_Rules.moving(below, {0}, 2)), ['a1', 'a2', 'x']);
    });

    test('moving an exercise on its own is a plain move', () {
      final exercises = _list([('x', null), ('y', null), ('z', null)]);
      expect(_ids(_Rules.moving(exercises, {0}, 3)), ['y', 'z', 'x']);
    });

    test('a superset whose members are apart moves as one', () {
      final exercises = _list([('a1', 'a'), ('x', null), ('a2', 'a')]);
      expect(_ids(_Rules.moving(exercises, {0}, 0)), ['a1', 'a2', 'x']);
    });
  });

  // SetTargetPresenter and WorkoutBuildUnsavedChangesTests
  group('set targets', () {
    test('a new set asks for what the last one did', () {
      final added = _Rules.addingSet(const [
        SetTarget(id: 'a', setNumber: 1, minReps: 6, maxReps: 8, rirTarget: 1),
      ], newId: _ids$());
      expect(added.last.toFirestore(), {
        SetTargetKeys.id: 'id-0',
        SetTargetKeys.setNumber: 2,
        SetTargetKeys.minReps: 6,
        SetTargetKeys.maxReps: 8,
        SetTargetKeys.rirTarget: 1,
        SetTargetKeys.setType: 'standard',
      });
      final first = _Rules.addingSet(const [], newId: _ids$()).single;
      expect((first.minReps, first.maxReps, first.setNumber), (8, 12, 1));
    });

    test('deleting a set renumbers the rest', () {
      expect(
        [for (final t in _Rules.deletingSet(_sets(3), 's1')) t.setNumber],
        [1, 2],
      );
    });

    test('a minimum above the maximum is swapped', () {
      final ordered = _Rules.orderedRanges(const [
        SetTarget(id: 'a', setNumber: 1, minReps: 12, maxReps: 8),
        SetTarget(id: 'b', setNumber: 2, minReps: 8),
      ]);
      expect((ordered[0].minReps, ordered[0].maxReps), (8, 12));
      expect((ordered[1].minReps, ordered[1].maxReps), (8, null));
    });

    test('a typed rep count is at least one, or none', () {
      expect(_Rules.typedReps(' 10 '), 10);
      expect(_Rules.typedReps('0'), 1);
      expect(_Rules.typedReps(''), isNull);
      expect(_Rules.typedReps('x'), isNull);
    });
  });

  // SetTargetPlanPresenterTests: the detail sheet's rules
  group("a set's plan", () {
    const base = SetTarget(id: 's1', setNumber: 1, minReps: 8, maxReps: 8);

    test('the picker offers every kind but the legacy one', () {
      expect(_Rules.kinds, hasLength(9));
      expect(_Rules.kinds, isNot(contains(SetTargetSetType.failure)));
      expect(_Rules.dropSteps, [10, 20, 25, 30]);
      expect(_Rules.holdSecondsChoices, [15, 20, 30, 45, 60]);
    });

    test('choosing drop set starts with two drops', () {
      expect(_Rules.withKind(base, SetTargetSetType.drop)!.dropCount, 2);
    });

    test('mini-sets start at three for each kind that takes them', () {
      for (final kind in _Rules.miniSetKinds) {
        final planned = _Rules.withKind(base, kind)!;
        expect(planned.setType, kind);
        expect(planned.miniSetCount, 3);
      }
    });

    test("an AMRAP target starts from the set's reps", () {
      expect(_Rules.withKind(base, SetTargetSetType.amrap)!.amrapTargetReps, 8);
      const top = SetTarget(id: 't', setNumber: 1, maxReps: 10);
      expect(_Rules.withKind(top, SetTargetSetType.amrap)!.amrapTargetReps, 10);
      expect(
        _Rules.withKind(base, SetTargetSetType.failure)!.setType,
        SetTargetSetType.amrap,
      );
    });

    test('a stretch or hold starts at 30 seconds', () {
      for (final kind in [SetTargetSetType.stretch, SetTargetSetType.hold]) {
        expect(_Rules.withKind(base, kind)!.holdSeconds, 30);
      }
    });

    test('partials start to failure; standard keeps the plan', () {
      expect(
        _Rules.withKind(base, SetTargetSetType.partials)!.partialReps,
        isNull,
      );
      final drop = _Rules.withKind(base, SetTargetSetType.drop)!;
      expect(
        _Rules.withKind(drop, SetTargetSetType.standard)!.setType,
        SetTargetSetType.standard,
      );
    });

    test('picking the kind already chosen changes nothing', () {
      expect(_Rules.withKind(base, SetTargetSetType.standard), isNull);
      const legacy = SetTarget(
        id: 'l',
        setNumber: 1,
        setType: SetTargetSetType.failure,
      );
      expect(_Rules.shownKind(legacy.setType), SetTargetSetType.amrap);
      expect(_Rules.withKind(legacy, SetTargetSetType.amrap), isNull);
    });

    test('a legacy failure set is written as AMRAP on edit', () {
      const legacy = SetTarget(
        id: 'l',
        setNumber: 1,
        setType: SetTargetSetType.failure,
      );
      expect(_Rules.planned(legacy).setType, SetTargetSetType.amrap);
      expect(_Rules.planned(base), same(base));
    });

    test('a typed target that is not a count is no target', () {
      expect(_Rules.plannedReps(0), isNull);
      expect(_Rules.plannedReps(9.6), 10);
      expect(_Rules.plannedReps(double.infinity), isNull);
      expect(_Rules.plannedReps(1000), isNull);
      expect(_Rules.plannedReps(null), isNull);
    });

    test('a hold time or partial count outside the choices is offered too', () {
      expect(_Rules.holdChoices(40), [15, 20, 30, 40, 45, 60]);
      expect(_Rules.holdChoices(30), [15, 20, 30, 45, 60]);
      expect(_Rules.partialRepsChoices(null), [
        null,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ]);
      expect(_Rules.partialRepsChoices(12).last, 12);
    });
  });

  // MicrocycleVariationSummaryTests
  group("the exercise's plan", () {
    test('links are saved only as web addresses', () {
      expect(
        _Rules.validatedLink(' https://youtu.be/abc '),
        'https://youtu.be/abc',
      );
      expect(
        _Rules.validatedLink('HTTP://example.com/x?y=1'),
        'HTTP://example.com/x?y=1',
      );
      expect(_Rules.validatedLink('example.com'), isNull);
      expect(_Rules.validatedLink('ftp://example.com'), isNull);
      expect(_Rules.validatedLink('https://'), isNull);
      expect(_Rules.validatedLink('javascript:alert(1)'), isNull);
      expect(_Rules.validatedLink(''), isNull);
      expect(_Rules.validatedLink('http://[::1'), isNull);
    });

    test('rest runs from 15 seconds to 10 minutes in 15 second steps', () {
      final seconds = _Rules.restSecondsChoices.nonNulls.toList();
      expect(_Rules.restSecondsChoices.first, isNull);
      expect((seconds.first, seconds.last, seconds.length), (15, 600, 40));
      expect(
        _Rules.choices(_Rules.restSecondsChoices, 50).nonNulls,
        contains(50),
      );
      expect(_Rules.choices(_Rules.warmupSetChoices, 5), [
        null,
        0,
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(
        _Rules.choices(_Rules.warmupSetChoices, 2),
        _Rules.warmupSetChoices,
      );
      expect(
        _Rules.choices(_Rules.warmupSetChoices, null),
        _Rules.warmupSetChoices,
      );
    });
  });

  group('weekly variation', () {
    MicrocycleSetTargets week(int from, int sets) =>
        MicrocycleSetTargets(fromMicrocycle: from, setTargets: _sets(sets));

    test('nothing varies without overrides', () {
      expect(_Rules.variationSegments(_sets(2), const []), isNull);
    });

    test('consecutive overrides bound each other and the last runs on', () {
      expect(_Rules.variationSegments(_sets(2), [week(9, 4), week(2, 3)]), [
        (from: 1, through: 1, sets: 2),
        (from: 2, through: 8, sets: 3),
        (from: 9, through: null, sets: 4),
      ]);
    });

    test('an override from week 1 replaces the base', () {
      expect(_Rules.variationSegments(_sets(3), [week(1, 2)]), [
        (from: 1, through: null, sets: 2),
      ]);
    });

    test('the next week follows the last, else the first free one', () {
      expect(_Rules.nextVariationWeek(const []), 2);
      expect(_Rules.nextVariationWeek(const [4]), 5);
      expect(_Rules.nextVariationWeek(const [52]), 2);
      expect(
        _Rules.nextVariationWeek([for (var w = 2; w <= 52; w++) w]),
        isNull,
      );
      expect(_Rules.nextVariationWeek(const [0]), 2);
    });

    test("a week cannot step onto another's or out of 2 to 52", () {
      expect(_Rules.canStepVariation(2, -1, const [3, 52]), isFalse);
      expect(_Rules.canStepVariation(2, 1, const [3, 52]), isFalse);
      expect(_Rules.canStepVariation(3, 1, const [2, 52]), isTrue);
      expect(_Rules.canStepVariation(52, 1, const [2, 3]), isFalse);
    });
  });
}
