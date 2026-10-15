// The training analytics' arithmetic, with the Swift suites' cases
// (AnalyticsExercisePresenterTests): the card and detail figures.
import 'package:compound/training_analytics/logic/training_analytics.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  maths.WorkoutSession on(int day, List<WorkoutExerciseModel> exercises) =>
      mathsSession(fixtureSession('s$day', day: day, exercises: exercises));

  group('mathsSession', () {
    test('keeps what the maths reads', () {
      final session = WorkoutSessionModel(
        id: 's',
        authorId: 'me',
        name: 'Push',
        dateCreated: DateTime(2026, 3, 2, 23),
        dateModified: DateTime(2026, 3, 3),
        endedAt: DateTime(2026, 3, 3, 0, 30),
        isDeload: true,
        exercises: [
          WorkoutExerciseModel(
            id: 'e',
            authorId: 'me',
            templateId: 'press',
            name: 'Press',
            trackingMode: TrackingMode.weightReps,
            index: 1,
            setTargets: const [SetTarget(id: 't', setNumber: 1)],
            sets: [
              WorkoutSetModel(
                id: 'a',
                authorId: 'me',
                index: 1,
                isWarmup: false,
                dateCreated: DateTime(2026, 3, 2),
                completedAt: DateTime(2026, 3, 2),
                reps: 5,
                weightKg: 120,
                machineBaseKg: 20,
                rpe: 8,
                sideRawValue: 'left',
                kindRawValue: 'drop',
                parentSetId: 'p',
              ),
              WorkoutSetModel(
                id: 'b',
                authorId: 'me',
                index: 2,
                isWarmup: true,
                dateCreated: DateTime(2026, 3, 2),
              ),
            ],
          ),
        ],
      );
      final mapped = mathsSession(session);
      // Dated by its end.
      expect(mapped.day, '2026-03-03');
      expect(mapped.isDeload, isTrue);
      final exercise = mapped.exercises.single;
      expect(exercise.plannedSets, 1);
      final [done, warmUp] = exercise.sets;
      expect(done.weightKg, 100);
      expect(done.side, maths.SetSide.left);
      expect(done.kind, maths.SetKind.drop);
      expect(done.parentSetId, 'p');
      expect(done.completed, isTrue);
      expect(warmUp.isWarmup, isTrue);
      expect(warmUp.completed, isFalse);
      expect(warmUp.side, isNull);
    });
  });

  test('muscleTargets reads each exercise', () {
    final targets = muscleTargets([
      fixtureLibraryExercise(
        'bench',
        muscles: const {
          Muscles.chest: MuscleTargetType.primary,
          Muscles.triceps: MuscleTargetType.secondary,
        },
      ),
    ]);
    expect(targets['bench'], {
      maths.Muscle.chest: maths.MuscleTarget.primary,
      maths.Muscle.triceps: maths.MuscleTarget.secondary,
    });
  });

  test("the library lists each id once, the user's first, by name", () {
    final library = exerciseLibrary(
      [fixtureLibraryExercise('b', name: 'bench (mine)')],
      [
        fixtureLibraryExercise('b', name: 'Bench', system: true),
        fixtureLibraryExercise('a', name: 'Arnold Press', system: true),
      ],
    );
    expect([for (final e in library) e.name], ['Arnold Press', 'bench (mine)']);
  });

  test('every muscle is in exactly one region', () {
    final upper = Muscles.values.where(isUpperBody).toSet();
    expect(upper, contains(Muscles.chest));
    expect(upper, isNot(contains(Muscles.quads)));
    expect(Muscles.values.length - upper.length, 7);
  });

  group('exercise cards', () {
    test('an unperformed exercise has no figure; the best come first', () {
      final library = [
        fixtureLibraryExercise('bench'),
        fixtureLibraryExercise('squat'),
        fixtureLibraryExercise('curl'),
      ];
      final sessions = [
        on(2, [
          fixtureExercise('bench', sets: [fixtureSet(weightKg: 80)]),
          fixtureExercise('squat', sets: [fixtureSet(weightKg: 120, reps: 1)]),
        ]),
        on(9, [
          fixtureExercise('bench', sets: [fixtureSet(weightKg: 90)]),
        ]),
      ];
      final cards = exerciseCards(sessions, library);
      expect([for (final c in cards) c.id], ['bench', 'squat', 'curl']);
      final bench = cards.first;
      // Oldest first, each the session's best.
      expect(
        [for (final p in bench.points) p.kg],
        [closeTo(80 * (1 + 5 / 30), 1e-9), closeTo(90 * (1 + 5 / 30), 1e-9)],
      );
      expect(bench.bestKg, closeTo(105, 1e-9));
      expect(cards.last.points, isEmpty);
      expect(cards.last.bestKg, 0);
      expect(
        [for (final c in topExerciseCards(cards)) c.id],
        ['squat', 'bench'],
      );
    });
  });

  group('oneRepMaxByDay', () {
    test("a day is worth its best set; another exercise's are ignored", () {
      final points = oneRepMaxByDay([
        on(2, [
          fixtureExercise(
            'bench',
            sets: [
              fixtureSet(reps: 1),
              fixtureSet(weightKg: 90, reps: 1),
              fixtureSet(weightKg: 200, isWarmup: true),
              fixtureSet(weightKg: 300, completed: false),
              fixtureSet(weightKg: 300, parentSetId: 'x'),
            ],
          ),
          fixtureExercise('squat', sets: [fixtureSet(weightKg: 300)]),
        ]),
        on(2, [
          fixtureExercise('bench', sets: [fixtureSet(weightKg: 95, reps: 1)]),
        ]),
        on(4, [
          fixtureExercise('bench', sets: [fixtureSet(weightKg: 110, reps: 1)]),
        ]),
      ], 'bench');
      expect(points, [
        (date: DateTime(2026, 3, 2), kg: 100.0),
        (date: DateTime(2026, 3, 4), kg: 110.0),
      ]);
    });
  });

  test('lastSevenDays reads the week ending today', () {
    expect(
      lastSevenDays({
        '2026-03-09': 2,
        '2026-03-15': 1,
        '2026-03-02': 9,
      }, '2026-03-15'),
      [2, 0, 0, 0, 0, 0, 1],
    );
    expect(lastSevenDays(null, '2026-03-15'), List.filled(7, 0));
  });

  test('topMuscles ranks by the week, falling back to two defaults', () {
    final none = {for (final m in Muscles.values) m: List<double>.filled(7, 0)};
    expect(topMuscles(none), [Muscles.upperBack, Muscles.rearDelts]);
    final trained = <Muscles, List<double>>{
      ...none,
      Muscles.chest: [0.0, 0, 0, 0, 0, 0, 3],
      Muscles.quads: [0.0, 0, 0, 0, 0, 5, 0],
      Muscles.calves: [0.0, 0, 0, 0, 0, 0, 1],
    };
    expect(topMuscles(trained), [Muscles.quads, Muscles.chest]);
  });

  test('ageOn counts whole years', () {
    final now = DateTime(2026, 3, 14);
    expect(ageOn(null, now), isNull);
    expect(ageOn(DateTime(1990, 3, 14), now), 36);
    expect(ageOn(DateTime(1990, 3, 15), now), 35);
    expect(ageOn(DateTime(1990, 4), now), 35);
  });

  test('dayOf is local midnight', () {
    expect(dayOf('2026-03-02'), DateTime(2026, 3, 2));
  });
}
