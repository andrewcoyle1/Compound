// Ports ExerciseStripTests and SupersetBlockLayoutTests.
import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

final start = DateTime.fromMillisecondsSinceEpoch(1000000000, isUtc: true);

WorkoutExercise stripExercise(
  String id, {
  int done = 0,
  int open = 1,
  String? group,
  int warmups = 0,
  bool warmupsDone = false,
}) => WorkoutExercise(
  id: id,
  name: id.toUpperCase(),
  supersetGroupId: group,
  sets: [
    for (var i = 0; i < warmups; i++)
      WorkoutSet(
        id: '$id-w${i + 1}',
        index: i + 1,
        isWarmup: true,
        completedAt: warmupsDone ? start : null,
      ),
    for (var i = 0; i < done + open; i++)
      WorkoutSet(
        id: '$id-${i + 1}',
        index: warmups + i + 1,
        reps: 8,
        weightKg: 80,
        completedAt: i < done ? start : null,
      ),
  ],
);

WorkoutExercise blockExercise(
  String id, {
  int working = 2,
  int warmups = 0,
  int loggedWarmups = 0,
  bool split = false,
  TrackingMode mode = TrackingMode.weightReps,
  String? group = 'g',
}) => WorkoutExercise(
  id: id,
  name: id.toUpperCase(),
  trackingMode: mode,
  supersetGroupId: group,
  sets: [
    for (var i = 0; i < warmups; i++)
      WorkoutSet(
        id: '$id-w${i + 1}',
        index: i + 1,
        isWarmup: true,
        completedAt: i < loggedWarmups ? start : null,
      ),
    for (var n = 0; n < working; n++)
      for (final side in split ? [SetSide.left, SetSide.right] : [null])
        WorkoutSet(
          id: '$id-${n + 1}${side?.initial ?? ''}',
          index: warmups + n + 1,
          reps: 8,
          weightKg: 80,
          side: side,
        ),
  ],
);

List<String> layout(List<SupersetBlockRow> rows) => [
  for (final row in rows)
    if (row.setId == null)
      'warmups:${row.exerciseId}'
    else
      '${row.badge}:${row.setId}',
];

List<String> ids(List<WorkoutExercise> exercises) => [
  for (final e in exercises) e.id,
];

void main() {
  group('strip', () {
    test('each block is one item counting working sets only', () {
      final items = ActiveWorkout.stripProgress([
        stripExercise('a', done: 2, open: 2, warmups: 2, warmupsDone: true),
        stripExercise('b', open: 3),
      ], 'a');
      expect([for (final i in items) i.id], ['a', 'b']);
      expect(items[0].doneWorkingSets, 2);
      expect(items[0].totalWorkingSets, 4);
      expect(items[0].fraction, 0.5);
      expect(items[0].isCurrent, isTrue);
      expect(items[1].isCurrent, isFalse);
      expect(items[1].doneWorkingSets, 0);
    });

    test('a superset is one item with its letter, current from any', () {
      final items = ActiveWorkout.stripProgress([
        stripExercise('a', group: 'g'),
        stripExercise('b', done: 1),
        stripExercise('c', done: 1, group: 'g'),
        stripExercise('d', group: 'h'),
        stripExercise('e', group: 'h'),
      ], 'c');
      expect([for (final i in items) i.id], ['a', 'b', 'd']);
      expect(items[0].names, ['A', 'C']);
      expect(items[0].imageNames, hasLength(2));
      expect(items[0].supersetLetter, 'A');
      expect(items[0].isCurrent, isTrue);
      expect(items[0].doneWorkingSets, 1);
      expect(items[0].totalWorkingSets, 3);
      expect(items[1].supersetLetter, isNull);
      expect(items[2].supersetLetter, 'B');
    });

    test('an item is complete only when every working set is logged', () {
      final items = ActiveWorkout.stripProgress([
        stripExercise('a', done: 2, open: 0, warmups: 1),
        stripExercise('b', done: 1),
        stripExercise('c', open: 0),
      ], null);
      expect([for (final i in items) i.isComplete], [true, false, false]);
      expect(items.every((i) => !i.isCurrent), isTrue);
      expect(items[2].fraction, 0);
    });

    test('a pair counts done only once both halves are', () {
      final items = ActiveWorkout.stripProgress([
        WorkoutExercise(
          id: 'a',
          sets: [
            WorkoutSet(id: 'l', side: SetSide.left, completedAt: start),
            const WorkoutSet(id: 'r', side: SetSide.right),
          ],
        ),
      ], 'a');
      expect(items.single.doneWorkingSets, 0);
      expect(items.single.totalWorkingSets, 1);
    });

    test('no exercises is no items', () {
      expect(ActiveWorkout.stripProgress([], 'a'), isEmpty);
    });

    test('forward comes in trailing, back leading, else trailing', () {
      final order = [
        ['a'],
        ['b', 'd'],
        ['c'],
      ];
      expect(ActiveWorkout.entryEdge('a', 'c', order), Edge.trailing);
      expect(ActiveWorkout.entryEdge('c', 'a', order), Edge.leading);
      expect(ActiveWorkout.entryEdge('a', 'd', order), Edge.trailing);
      expect(ActiveWorkout.entryEdge('c', 'b', order), Edge.leading);
      expect(ActiveWorkout.entryEdge('d', 'b', order), Edge.trailing);
      expect(ActiveWorkout.entryEdge(null, 'a', order), Edge.trailing);
      expect(ActiveWorkout.entryEdge('c', 'new', order), Edge.trailing);
    });

    test('a block moves to the place it was dropped on', () {
      final exercises = [
        stripExercise('a'),
        stripExercise('b'),
        stripExercise('c'),
        stripExercise('d'),
      ];
      expect(ids(ActiveWorkout.movingBlock('a', 2, exercises)), [
        'b',
        'c',
        'a',
        'd',
      ]);
      expect(ids(ActiveWorkout.movingBlock('d', 1, exercises)), [
        'a',
        'd',
        'b',
        'c',
      ]);
      expect(ids(ActiveWorkout.movingBlock('a', 3, exercises)), [
        'b',
        'c',
        'd',
        'a',
      ]);
    });

    test('a superset moves as one block and is never split', () {
      final exercises = [
        stripExercise('a'),
        stripExercise('b', group: 'g'),
        stripExercise('c', group: 'g'),
        stripExercise('d'),
      ];
      expect(ids(ActiveWorkout.movingBlock('b', 2, exercises)), [
        'a',
        'd',
        'b',
        'c',
      ]);
      expect(ids(ActiveWorkout.movingBlock('d', 0, exercises)), [
        'd',
        'a',
        'b',
        'c',
      ]);
    });

    test('moving nowhere, an unknown block or past the end', () {
      final exercises = [
        stripExercise('a'),
        stripExercise('b'),
        stripExercise('c'),
      ];
      expect(ids(ActiveWorkout.movingBlock('b', 1, exercises)), [
        'a',
        'b',
        'c',
      ]);
      expect(ids(ActiveWorkout.movingBlock('zz', 0, exercises)), [
        'a',
        'b',
        'c',
      ]);
      expect(ids(ActiveWorkout.movingBlock('a', 9, exercises)), [
        'b',
        'c',
        'a',
      ]);
      expect(ids(ActiveWorkout.movingBlock('c', -3, exercises)), [
        'c',
        'a',
        'b',
      ]);
    });

    test('a duplicated exercise id keeps its first copy', () {
      final exercises = [
        stripExercise('a'),
        stripExercise('a', done: 1, open: 0),
      ];
      expect(
        ActiveWorkout.movingBlock(
          'a',
          0,
          exercises,
        ).first.sets.first.completedAt,
        isNull,
      );
      expect(ActiveWorkout.stripProgress(exercises, null), hasLength(2));
    });
  });

  group('superset block', () {
    List<SupersetBlockRow> rows(List<WorkoutExercise> members) =>
        ActiveWorkout.blockRows(members, 'A');

    test('only a superset of two or more is a block', () {
      final exercises = [
        blockExercise('a', group: null),
        blockExercise('b'),
        blockExercise('c', group: 'h'),
        blockExercise('d'),
      ];
      expect(ids(ActiveWorkout.supersetBlock('b', exercises)!), ['b', 'd']);
      expect(ids(ActiveWorkout.supersetBlock('d', exercises)!), ['b', 'd']);
      expect(ActiveWorkout.supersetBlock('a', exercises), isNull);
      expect(ActiveWorkout.supersetBlock('c', exercises), isNull);
      expect(ActiveWorkout.supersetBlock(null, exercises), isNull);
    });

    test('the rows run in rounds', () {
      expect(layout(rows([blockExercise('a'), blockExercise('b')])), [
        'A1·1:a-1',
        'A2·1:b-1',
        'A1·2:a-2',
        'A2·2:b-2',
      ]);
    });

    test('uneven members and a circuit', () {
      expect(
        layout(
          rows([
            blockExercise('a', working: 3),
            blockExercise('b', working: 1),
            blockExercise('c'),
          ]),
        ),
        [
          'A1·1:a-1',
          'A2·1:b-1',
          'A3·1:c-1',
          'A1·2:a-2',
          'A3·2:c-2',
          'A1·3:a-3',
        ],
      );
    });

    test('warm-ups stay grouped above the first round', () {
      expect(
        layout(
          rows([
            blockExercise('a', working: 1, warmups: 2, loggedWarmups: 1),
            blockExercise('b', working: 1, warmups: 1),
          ]),
        ),
        ['warmups:a', 'A1W:a-w2', 'A2W:b-w1', 'A1·1:a-1', 'A2·1:b-1'],
      );
    });

    test('a left and right pair is one entry in its round', () {
      expect(
        layout(rows([blockExercise('a', split: true), blockExercise('b')])),
        [
          'A1·1L:a-1L',
          'A1·1R:a-1R',
          'A2·1:b-1',
          'A1·2L:a-2L',
          'A1·2R:a-2R',
          'A2·2:b-2',
        ],
      );
    });

    test('each row has its own id', () {
      final result = rows([
        blockExercise('a', warmups: 1, loggedWarmups: 1),
        blockExercise('b', warmups: 1, loggedWarmups: 1),
      ]);
      expect({for (final r in result) r.id}, hasLength(result.length));
    });

    test('no working sets is only the warm-ups', () {
      expect(rows([blockExercise('a', working: 0)]), isEmpty);
    });

    test('only the set the log button logs next is current', () {
      final first = blockExercise('a');
      final second = blockExercise('b');
      final next = ActiveWorkout.nextSetId([first, second], 'a');
      expect(next, 'a-1');
      expect(ActiveWorkout.nextSetId([first, second], 'zz'), 'a-1');
      expect(
        ActiveWorkout.blockRowState(first.sets[0], first, isNext: true),
        SetRowState.current,
      );
      expect(
        ActiveWorkout.blockRowState(second.sets[0], second, isNext: false),
        SetRowState.upcoming,
      );
      final logged = first.copyWith(
        sets: [
          first.sets[0].copyWith(completedAt: start),
          first.sets[1],
        ],
      );
      expect(ActiveWorkout.nextSetId([logged, second], 'b'), 'b-1');
      expect(
        ActiveWorkout.blockRowState(logged.sets[0], logged, isNext: false),
        SetRowState.done,
      );
    });

    test('headings only when every member shares its columns', () {
      ({WeightUnit weight, DistanceUnit distance}) kilograms(
        WorkoutExercise e,
      ) => (weight: WeightUnit.kilograms, distance: DistanceUnit.meters);
      ({WeightUnit weight, DistanceUnit distance}) poundsForB(
        WorkoutExercise e,
      ) => (
        weight: e.id == 'b' ? WeightUnit.pounds : WeightUnit.kilograms,
        distance: e.id == 'b' ? DistanceUnit.miles : DistanceUnit.meters,
      );
      expect(
        ActiveWorkout.blockSharesColumns([
          blockExercise('a'),
          blockExercise('b'),
        ], kilograms),
        isTrue,
      );
      expect(
        ActiveWorkout.blockSharesColumns([
          blockExercise('a'),
          blockExercise('b', mode: TrackingMode.repsOnly),
        ], kilograms),
        isFalse,
      );
      expect(
        ActiveWorkout.blockSharesColumns([
          blockExercise('a'),
          blockExercise('b'),
        ], poundsForB),
        isFalse,
      );
      expect(
        ActiveWorkout.blockSharesColumns([
          blockExercise('a', mode: TrackingMode.repsOnly),
          blockExercise('b', mode: TrackingMode.repsOnly),
        ], poundsForB),
        isTrue,
      );
      expect(
        ActiveWorkout.blockSharesColumns([
          blockExercise('a', mode: TrackingMode.distanceTime),
          blockExercise('b', mode: TrackingMode.distanceTime),
        ], poundsForB),
        isFalse,
      );
    });

    test('each round ends on its last row', () {
      expect(
        [
          for (final r in rows([
            blockExercise('a', warmups: 1),
            blockExercise('b', working: 1),
          ]))
            r.endsRound,
        ],
        [true, false, true, true],
      );
    });

    test('supersets are lettered in workout order, none past Z', () {
      final exercises = [
        blockExercise('a', group: 'g1'),
        blockExercise('b', group: 'g1'),
        blockExercise('c', group: null),
        blockExercise('d', group: 'g2'),
        blockExercise('e', group: 'g2'),
        blockExercise('f', group: 'lone'),
      ];
      expect(ActiveWorkout.supersetLetters(exercises), {'g1': 'A', 'g2': 'B'});
      expect(
        ActiveWorkout.blockRows([exercises[3], exercises[4]], 'B').first,
        const SupersetBlockRow(exerciseId: 'd', setId: 'd-1', badge: 'B1·1'),
      );
      expect(ActiveWorkout.letter(25), 'Z');
      expect(ActiveWorkout.letter(26), isNull);
      expect(ActiveWorkout.letter(-1), isNull);
      final many = [
        for (var i = 0; i < 27; i++) ...[
          blockExercise('x$i', group: 'g$i'),
          blockExercise('y$i', group: 'g$i'),
        ],
      ];
      expect(ActiveWorkout.supersetLetters(many), hasLength(26));
    });

    test('a drop stays under its set in the round', () {
      var first = blockExercise('a');
      first = first.copyWith(
        sets: ActiveWorkout.addingSubSet(
          SubSetKind.drop,
          'a-1',
          first.sets,
          id: 'a-1d',
          weightKg: 64,
        ),
      );
      first = first.copyWith(
        sets: ActiveWorkout.addingSubSet(
          SubSetKind.drop,
          'a-2',
          first.sets,
          id: 'a-2d',
          weightKg: 64,
        ),
      );
      expect(layout(rows([first, blockExercise('b')])), [
        'A1·1:a-1',
        'A1·1:a-1d',
        'A2·1:b-1',
        'A1·2:a-2',
        'A1·2:a-2d',
        'A2·2:b-2',
      ]);
      final logged = [...first.sets]
        ..[0] = first.sets[0].copyWith(completedAt: start);
      first = first.copyWith(sets: logged);
      expect(ActiveWorkout.nextSetId([first, blockExercise('b')], 'a'), 'a-1d');
      first = first.copyWith(
        sets: [...first.sets]..[1] = first.sets[1].copyWith(completedAt: start),
      );
      expect(ActiveWorkout.nextSetId([first, blockExercise('b')], 'a'), 'b-1');
    });

    test('a drop on a split pair follows the pair', () {
      var first = blockExercise('a', working: 1, split: true);
      first = first.copyWith(
        sets: ActiveWorkout.addingSubSet(
          SubSetKind.drop,
          'a-1L',
          first.sets,
          id: 'a-1Ld',
          weightKg: 16,
        ),
      );
      expect(layout(rows([first, blockExercise('b', working: 1)])), [
        'A1·1L:a-1L',
        'A1·1R:a-1R',
        'A1·1L:a-1Ld',
        'A2·1:b-1',
      ]);
    });

    test('member labels', () {
      expect(ActiveWorkout.memberLabel('B', 1), 'B2');
    });
  });
}
