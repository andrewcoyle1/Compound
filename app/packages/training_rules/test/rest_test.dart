// Ports RestDurationRulesTests and the SetValidation cases.
import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

final start = DateTime.fromMillisecondsSinceEpoch(1772000000000, isUtc: true);

WorkoutSet set(
  String id, {
  bool warmup = false,
  SetSide? side,
  SetKind kind = SetKind.standard,
  String? parent,
}) => WorkoutSet(
  id: id,
  reps: 8,
  side: side,
  kind: kind,
  parentSetId: parent,
  isWarmup: warmup,
);

WorkoutExercise exercise(List<WorkoutSet> sets) =>
    WorkoutExercise(id: 'e1', sets: sets);

WorkoutExercise member(
  String id,
  int count, {
  int done = 0,
  String? group = 'g',
}) => WorkoutExercise(
  id: id,
  supersetGroupId: group,
  sets: [
    for (var i = 0; i < count; i++)
      WorkoutSet(
        id: '$id${i + 1}',
        index: i + 1,
        reps: 8,
        completedAt: i < done ? start : null,
      ),
  ],
);

const settings = WorkoutSettings(
  defaultRestDurationSeconds: 100,
  warmUpRestScaling: 0.5,
  sideSetRestScaling: 0.25,
  betweenExercisesRestScaling: 2,
  restBetweenSideSets: true,
);

int? rest(
  WorkoutSet after,
  WorkoutExercise exercise, {
  WorkoutSettings settings = settings,
  RestContext context = const RestContext(),
  int? custom,
}) => RestDurationRules.restAfterCompletingInExercise(
  after,
  exercise,
  settings,
  context,
  customRestSeconds: custom,
);

int? restIn(
  String setId,
  List<WorkoutExercise> workout, {
  WorkoutSettings settings = settings,
  int? custom,
}) {
  final e = workout.firstWhere((e) => e.sets.any((s) => s.id == setId));
  return RestDurationRules.restAfterCompleting(
    e.sets.firstWhere((s) => s.id == setId),
    e,
    workout,
    settings,
    const RestContext(),
    customRestSeconds: custom,
  );
}

void main() {
  group('within an exercise', () {
    test('a custom rest wins unscaled', () {
      final warmup = set('w1', warmup: true);
      expect(rest(warmup, exercise([warmup, set('x1')]), custom: 45), 45);
    });

    test('there is never a rest between warm-ups', () {
      final warmup = set('w1', warmup: true);
      expect(
        rest(warmup, exercise([warmup, set('w2', warmup: true), set('x1')])),
        isNull,
      );
    });

    test('the last warm-up rests scaled and only when asked', () {
      final last = set('w2', warmup: true);
      final e = exercise([set('w1', warmup: true), last, set('x1')]);
      expect(rest(last, e), 50);
      expect(
        rest(
          last,
          e,
          settings: const WorkoutSettings(restAfterLastWarmUp: false),
        ),
        isNull,
      );
      expect(const WorkoutSettings().restAfterLastWarmUp, isTrue);
    });

    test('the left half of a pair rests like a side swap', () {
      final left = set('x1-l', side: SetSide.left);
      final e = exercise([
        left,
        set('x1-r', side: SetSide.right),
        set('x2-l', side: SetSide.left),
        set('x2-r', side: SetSide.right),
      ]);
      expect(rest(left, e), 25);
      expect(rest(left, e, settings: const WorkoutSettings()), isNull);
    });

    test('the right half of a pair rests between sets', () {
      final right = set('x1-r', side: SetSide.right);
      final e = exercise([
        set('x1-l', side: SetSide.left),
        right,
        set('x2-l', side: SetSide.left),
        set('x2-r', side: SetSide.right),
      ]);
      expect(rest(right, e), 100);
    });

    test('the last working set rests toward the next exercise', () {
      final last = set('x2');
      final e = exercise([set('x1'), last]);
      expect(rest(last, e), 200);
      expect(
        rest(
          last,
          e,
          settings: const WorkoutSettings(restBetweenExercises: false),
        ),
        isNull,
      );
    });

    test('a set in the middle rests the base duration', () {
      final first = set('x1');
      expect(rest(first, exercise([first, set('x2')])), 100);
    });

    test('scaling to nothing means no rest', () {
      final last = set('w2', warmup: true);
      expect(
        rest(
          last,
          exercise([set('w1', warmup: true), last, set('x1')]),
          settings: const WorkoutSettings(warmUpRestScaling: 0),
        ),
        isNull,
      );
    });

    test('the base is the narrowest setting; a zero override is none', () {
      const typed = WorkoutSettings(
        defaultRestDurationSeconds: 100,
        restDurationsByExerciseType: {ExerciseType.compoundUpper: 70},
      );
      final first = set('x1');
      final e = exercise([first, set('x2')]);
      int? at(RestContext context) =>
          rest(first, e, settings: typed, context: context);
      expect(
        at(
          const RestContext(
            restOverrideSeconds: 30,
            exerciseType: ExerciseType.compoundUpper,
          ),
        ),
        30,
      );
      expect(
        at(
          const RestContext(
            restOverrideSeconds: 0,
            exerciseType: ExerciseType.compoundUpper,
          ),
        ),
        70,
      );
      expect(
        at(const RestContext(exerciseType: ExerciseType.compoundUpper)),
        70,
      );
      expect(at(const RestContext()), 100);
    });

    test("the plan's rest wins over the exercise's; zero is none", () {
      const typed = WorkoutSettings(
        restDurationsByExerciseType: {ExerciseType.compoundUpper: 70},
      );
      final first = set('x1');
      final e = exercise([first, set('x2')]);
      const plan = RestContext(
        restOverrideSeconds: 30,
        exerciseType: ExerciseType.compoundUpper,
        planRestSeconds: 150,
      );
      expect(rest(first, e, settings: typed, context: plan), 150);
      expect(RestDurationRules.baseRestDuration(typed, plan), 150);
      expect(
        rest(
          first,
          e,
          settings: typed,
          context: const RestContext(
            restOverrideSeconds: 30,
            exerciseType: ExerciseType.compoundUpper,
            planRestSeconds: 0,
          ),
        ),
        30,
      );
      expect(
        rest(
          first,
          e,
          settings: typed,
          context: const RestContext(
            exerciseType: ExerciseType.compoundUpper,
            planRestSeconds: 0,
          ),
        ),
        70,
      );
    });

    test("a type's default rest follows its reps", () {
      expect(
        RestDurationRules.defaultSeconds(ExerciseType.compoundLower, 5),
        180,
      );
      expect(
        RestDurationRules.defaultSeconds(ExerciseType.compoundLower, 6),
        180,
      );
      expect(
        RestDurationRules.defaultSeconds(ExerciseType.compoundUpper, 7),
        120,
      );
      expect(
        RestDurationRules.defaultSeconds(ExerciseType.compoundUpper, null),
        120,
      );
      expect(
        RestDurationRules.defaultSeconds(ExerciseType.compoundUpper, 0),
        120,
      );
      expect(
        RestDurationRules.defaultSeconds(ExerciseType.isolationUpper, 5),
        90,
      );
      expect(RestDurationRules.defaultSeconds(ExerciseType.core, 5), 60);
      // A drop's rest is judged on its parent's reps; a warm-up's never is.
      const heavy = RestContext(exerciseType: ExerciseType.compoundLower);
      const parent = WorkoutSet(id: 'p', reps: 5);
      const drop = WorkoutSet(
        id: 'd',
        reps: 12,
        kind: SetKind.drop,
        parentSetId: 'p',
      );
      final e = exercise([parent, drop, set('x2')]);
      expect(rest(drop, e, context: heavy), 180);
      const warm = WorkoutSet(id: 'w', reps: 3, isWarmup: true);
      expect(
        rest(
          warm,
          exercise([warm, set('x')]),
          settings: const WorkoutSettings(),
          context: heavy,
        ),
        90,
      );
    });

    test('there is no rest before a drop', () {
      final parent = set('x1');
      final drop = set('x1-d', kind: SetKind.drop, parent: 'x1');
      final e = exercise([parent, drop, set('x2')]);
      expect(rest(parent, e), isNull);
      expect(rest(drop, e), 100);
    });

    test("myo, rest-pause and cluster rows rest their kind's breath", () {
      const cases = {
        SetKind.myo: 15,
        SetKind.restPause: 20,
        SetKind.cluster: 15,
      };
      for (final MapEntry(key: kind, value: seconds) in cases.entries) {
        final parent = set('x1', kind: kind);
        final first = set('x1-m1', kind: kind, parent: 'x1');
        final last = set('x1-m2', kind: kind, parent: 'x1');
        final e = exercise([parent, first, last, set('x2')]);
        expect(rest(parent, e), seconds);
        expect(rest(first, e), seconds);
        expect(rest(last, e), 100);
        expect(
          rest(
            parent,
            e,
            settings: const WorkoutSettings(
              defaultRestDurationSeconds: 100,
              intraSetRestSeconds: 25,
            ),
          ),
          25,
        );
        expect(
          rest(
            parent,
            e,
            settings: const WorkoutSettings(intraSetRestSeconds: 0),
          ),
          isNull,
        );
      }
    });

    test("each kind's breath is its own; a plain row takes its parent's", () {
      const chosen = WorkoutSettings(
        intraSetRestSeconds: 25,
        intraSetRestMyoSeconds: 10,
        intraSetRestPauseSeconds: 30,
        intraSetRestClusterSeconds: 0,
      );
      int? afterParent(SetKind kind) {
        final parent = set('x1', kind: kind);
        return rest(
          parent,
          exercise([parent, set('x1-m', parent: 'x1'), set('x2')]),
          settings: chosen,
        );
      }

      expect(afterParent(SetKind.myo), 10);
      expect(afterParent(SetKind.restPause), 30);
      expect(afterParent(SetKind.cluster), isNull);
      expect(afterParent(SetKind.standard), isNull);
    });

    test("a sub-set does not end its parent's rest rule", () {
      final last = set('x2');
      final drop = set('x2-d', kind: SetKind.drop, parent: 'x2');
      final e = exercise([set('x1'), last, drop]);
      expect(rest(last, e), isNull);
      expect(rest(drop, e), 200);
      expect(rest(set('elsewhere'), e), 100);
    });
  });

  group('across the workout', () {
    test("the workout's final set rests not at all", () {
      final workout = [
        member('a', 2, done: 1, group: null),
        member('b', 1, done: 1, group: null),
      ];
      expect(restIn('a2', workout), isNull);
      expect(restIn('a2', workout, custom: 60), isNull);
      expect(restIn('a2', [workout[0], member('b', 1, group: null)]), 200);
    });

    test('a superset partner set gets the transition rest', () {
      final workout = [member('a', 2), member('b', 2)];
      expect(restIn('a1', workout), isNull);
      expect(
        restIn(
          'a1',
          workout,
          settings: const WorkoutSettings(supersetTransitionRestSeconds: 15),
        ),
        15,
      );
      expect(
        restIn(
          'a1',
          workout,
          settings: const WorkoutSettings(supersetTransitionRestSeconds: 0),
        ),
        isNull,
      );
    });

    test("the round's last set rests the base", () {
      expect(restIn('b1', [member('a', 2, done: 1), member('b', 2)]), 100);
    });

    test('the last round rests between exercises', () {
      final workout = [
        member('a', 2, done: 1),
        member('b', 2, done: 1),
        member('c', 1, group: null),
      ];
      expect(restIn('a2', workout), isNull);
      expect(
        restIn('b2', [member('a', 2, done: 2), workout[1], workout[2]]),
        200,
      );
      expect(
        restIn('b2', [
          member('a', 2, done: 2),
          workout[1],
          workout[2],
        ], settings: const WorkoutSettings(restBetweenExercises: false)),
        isNull,
      );
    });

    test('a circuit of three rests after the round', () {
      final workout = [member('a', 2), member('b', 2), member('c', 2)];
      expect(restIn('a1', workout), isNull);
      expect(
        restIn('b1', [member('a', 2, done: 1), workout[1], workout[2]]),
        isNull,
      );
      expect(
        restIn('c1', [
          member('a', 2, done: 1),
          member('b', 2, done: 1),
          workout[2],
        ]),
        100,
      );
    });

    test('a drop in a superset comes before the partner', () {
      final first = member('a', 2);
      final withDrop = first.copyWith(
        sets: [...first.sets]
          ..insert(1, set('a1-d', kind: SetKind.drop, parent: 'a1')),
      );
      const transition = WorkoutSettings(
        defaultRestDurationSeconds: 100,
        supersetTransitionRestSeconds: 30,
      );
      final workout = [withDrop, member('b', 2)];
      expect(restIn('a1', workout, settings: transition), isNull);
      expect(restIn('a1-d', workout, settings: transition), 30);
    });

    test(
      'a lone member of its group, a warm-up or a pair keep their rules',
      () {
        expect(restIn('a1', [member('a', 2)]), 100);
        final withWarmup = WorkoutExercise(
          id: 'a',
          supersetGroupId: 'g',
          sets: [set('w', warmup: true), set('a1')],
        );
        expect(restIn('w', [withWarmup, member('b', 1)]), 50);
        final pair = WorkoutExercise(
          id: 'a',
          supersetGroupId: 'g',
          sets: [
            set('l', side: SetSide.left),
            set('r', side: SetSide.right),
          ],
        );
        expect(restIn('l', [pair, member('b', 1)]), 25);
        expect(restIn('a1', [member('a', 2), member('b', 2)], custom: 40), 40);
      },
    );
  });

  group('set validation', () {
    SetProblem? problem(
      WorkoutSet set,
      TrackingMode mode, {
      bool isAssisted = false,
    }) => SetValidation.problem(set, mode, isAssisted: isAssisted);

    test(
      'weight and reps need reps, and no negative weight unless assisted',
      () {
        expect(
          problem(
            const WorkoutSet(id: 's', reps: 8, weightKg: 60),
            TrackingMode.weightReps,
          ),
          isNull,
        );
        expect(
          problem(
            const WorkoutSet(id: 's', weightKg: 60),
            TrackingMode.weightReps,
          ),
          SetProblem.noReps,
        );
        expect(
          problem(
            const WorkoutSet(id: 's', reps: 8, weightKg: -30),
            TrackingMode.weightReps,
          ),
          SetProblem.negativeWeight,
        );
        expect(
          problem(
            const WorkoutSet(id: 's', reps: 8, weightKg: -30),
            TrackingMode.weightReps,
            isAssisted: true,
          ),
          isNull,
        );
      },
    );

    test('every mode asks for its own figures', () {
      expect(
        problem(const WorkoutSet(id: 's', reps: 0), TrackingMode.repsOnly),
        SetProblem.noReps,
      );
      expect(
        problem(const WorkoutSet(id: 's', reps: 1), TrackingMode.repsOnly),
        isNull,
      );
      expect(
        problem(const WorkoutSet(id: 's'), TrackingMode.timeOnly),
        SetProblem.noTime,
      );
      expect(
        problem(
          const WorkoutSet(id: 's', durationSec: 5),
          TrackingMode.timeOnly,
        ),
        isNull,
      );
      expect(
        problem(
          const WorkoutSet(id: 's', durationSec: 5),
          TrackingMode.distanceTime,
        ),
        SetProblem.noDistance,
      );
      expect(
        problem(
          const WorkoutSet(id: 's', distanceMeters: 5),
          TrackingMode.distanceTime,
        ),
        SetProblem.noTime,
      );
      expect(
        problem(
          const WorkoutSet(id: 's', distanceMeters: 5, durationSec: 5),
          TrackingMode.distanceTime,
        ),
        isNull,
      );
    });
  });
}
