// "Last time" and the planned session: the session manager's lookups,
// previousWorkoutReference, smart progression and plannedSession.
import 'package:compound_models/compound_models.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

import '../helpers/fixtures.dart';

DateTime _day(int day) => DateTime.utc(2026, 10, day, 9);

m.WorkoutSessionModel _done(
  String id, {
  required int day,
  String? templateId = 'push',
  String? mesocycleId,
  List<m.WorkoutExerciseModel>? exercises,
  bool? isDeload,
  bool finished = true,
}) => session(
  exercises ??
      [
        exercise(
          '$id-bench',
          templateId: 'bench',
          sets: [set('$id-1', reps: 10, weightKg: 100, done: true)],
        ),
      ],
  id: id,
  templateId: templateId,
  mesocycleId: mesocycleId,
  created: _day(day),
  ended: finished ? _day(day).add(const Duration(hours: 1)) : null,
  isDeload: isDeload,
);

final m.GymProfileModel _barbellGym = gym(
  id: 'home',
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
  type: m.ExerciseType.compoundUpper,
  variations: [
    variation('bar', [ref(m.EquipmentKind.loadableBar, 'barbell')]),
  ],
);

m.WorkoutTemplateModel _template({String? gymProfileId}) =>
    m.WorkoutTemplateModel(
      workoutId: 'push',
      authorId: author,
      name: 'Push',
      dateCreated: start,
      dateModified: start,
      gymProfileId: gymProfileId,
      exercises: [
        m.WorkoutTemplateExercise(
          id: 'slot',
          exercise: library('bench', name: 'Stale copy'),
          setTargets: [target(1, min: 8, max: 10)],
          setRestTimers: false,
          setTargetsByMicrocycle: [
            m.MicrocycleSetTargets(
              fromMicrocycle: 2,
              setTargets: [
                target(1, min: 8, max: 10),
                target(2, min: 8, max: 10),
              ],
            ),
          ],
        ),
      ],
    );

void main() {
  group('lookups', () {
    final history = SessionHistory([
      _done('old', day: 1),
      _done('open', day: 5, finished: false),
      _done('meso', day: 3, mesocycleId: 'm1'),
      _done('other', day: 4, templateId: 'pull'),
      _done(
        'squat-only',
        day: 6,
        exercises: [exercise('sq', templateId: 'squat')],
      ),
    ]);

    test('the last of a template, finished or not, by start', () {
      expect(history.lastForTemplate('push')?.id, 'squat-only');
      expect(history.lastForTemplate('legs'), isNull);
    });

    test('finished ones of a template, latest ended first', () {
      expect(history.completedForTemplate('push').map((s) => s.id), [
        'squat-only',
        'meso',
        'old',
      ]);
      expect(
        history
            .completedForTemplate('push', mesocycleId: 'm1')
            .map((s) => s.id),
        ['meso'],
      );
      expect(history.completedForTemplate('push', limit: 1), hasLength(1));
      expect(history.completedForTemplate('push', limit: -1), isEmpty);
    });

    test('finished ones holding an exercise, whatever the workout', () {
      expect(history.completedContainingExercise('bench').map((s) => s.id), [
        'other',
        'meso',
        'old',
      ]);
    });

    group('previousSessions', () {
      List<String> ids(
        m.PreviousWorkoutReferenceOption scope, {
        String exercise = 'bench',
        String? template = 'push',
        String? mesocycle,
      }) => [
        for (final s in history.previousSessions(
          exerciseTemplateId: exercise,
          workoutTemplateId: template,
          mesocycleId: mesocycle,
          scope: scope,
        ))
          s.id,
      ];

      test("the same workout's sessions holding the exercise", () {
        expect(ids(m.PreviousWorkoutReferenceOption.sameWorkout), [
          'meso',
          'old',
        ]);
      });

      test("the mesocycle's, when within one", () {
        expect(
          ids(
            m.PreviousWorkoutReferenceOption.workoutsInMesocycle,
            mesocycle: 'm1',
          ),
          ['meso'],
        );
        expect(ids(m.PreviousWorkoutReferenceOption.workoutsInMesocycle), [
          'meso',
          'old',
        ]);
      });

      test('anywhere the exercise was done, by scope or as the fallback', () {
        expect(ids(m.PreviousWorkoutReferenceOption.anyExercise), [
          'other',
          'meso',
          'old',
        ]);
        expect(
          ids(m.PreviousWorkoutReferenceOption.sameWorkout, template: 'legs'),
          ['other', 'meso', 'old'],
        );
        expect(
          ids(m.PreviousWorkoutReferenceOption.sameWorkout, template: null),
          ['other', 'meso', 'old'],
        );
      });
    });
  });

  group('previousExercises', () {
    test('the latest on the same load, outside a deload, that was done', () {
      final current = session([
        exercise(
          'today',
          templateId: 'bench',
          variations: _bench.equipmentVariations,
        ),
      ], templateId: 'push');
      final history = SessionHistory([
        _done('deload', day: 9, isDeload: true),
        _done(
          'dumbbells',
          day: 8,
          exercises: [
            exercise(
              'db',
              templateId: 'bench',
              variations: [
                variation('db', [ref(m.EquipmentKind.freeWeight, 'dumbbells')]),
              ],
            ),
          ],
        ),
        _done(
          'skipped',
          day: 7,
          exercises: [exercise('planned-only', templateId: 'bench')],
        ),
        _done('done', day: 6),
      ]);

      final previous = history.previousExercises(
        session: current,
        exercises: current.exercises,
        scope: m.PreviousWorkoutReferenceOption.sameWorkout,
      );

      expect(previous['bench#0']?.id, 'done-bench');
    });

    test('else the last time it was planned, else nothing', () {
      final current = session([exercise('today', templateId: 'bench')]);
      final planned = SessionHistory([
        _done(
          'skipped',
          day: 7,
          exercises: [exercise('planned-only', templateId: 'bench')],
        ),
      ]);
      expect(
        planned
            .previousExercises(
              session: current,
              exercises: current.exercises,
              scope: m.PreviousWorkoutReferenceOption.anyExercise,
            )['bench#0']
            ?.id,
        'planned-only',
      );
      final none = const SessionHistory([]).previousExercises(
        session: current,
        exercises: current.exercises,
        scope: m.PreviousWorkoutReferenceOption.anyExercise,
      );
      expect(none, {'bench#0': null});
    });
  });

  group('suggestions', () {
    final history = SessionHistory([
      for (final day in [1, 3])
        _done(
          'd$day',
          day: day,
          exercises: [
            exercise(
              'e$day',
              templateId: 'bench',
              sets: [
                set('a$day', reps: 10, weightKg: 100, done: true),
                set('b$day', reps: 10, weightKg: 100, done: true),
              ],
            ),
          ],
        ),
    ]);

    test('progress the weight after two sessions at the top', () {
      final context = sessionContext(
        exercise(
          'today',
          templateId: 'bench',
          targets: [target(1, min: 8, max: 10)],
        ),
        library: _bench,
        gym: _barbellGym,
        preferredUnit: m.ExerciseWeightUnit.kilograms,
      );
      final suggestion = history.suggestions(
        contexts: [context],
        workoutTemplateId: 'push',
        mesocycleId: null,
        settings: settings(),
      )['bench#0']!;
      expect(suggestion.rationale, r.Rationale.progressWeight);
      expect(suggestion.sets.first.weightKg, 102.5);
      expect(suggestion.sets.first.reps, 8);
    });

    test('contexts round on the equipment chosen, else the first', () {
      final noLibrary = sessionContext(
        exercise('today', templateId: 'bench'),
        library: null,
        gym: _barbellGym,
        preferredUnit: null,
      );
      expect(noLibrary.exerciseType, isNull);
      expect(noLibrary.resistanceEquipment, isNull);
      expect(noLibrary.rounding.round(101.3), 101.3);
      final fromTemplate = templateContext(
        _template().exercises.single,
        gym: _barbellGym,
        load: null,
        occurrence: 1,
      );
      expect(fromTemplate.historyKey, 'bench#1');
      expect(fromTemplate.resistanceEquipment, isNull);
      expect(fromTemplate.setTargets.single.maxReps, 10);
    });
  });

  test('sessionLoads: the equipment each exercise starts on, and its unit', () {
    final previous = _done(
      'last',
      day: 1,
      exercises: [
        exercise(
          'x',
          templateId: 'bench',
          variations: _bench.equipmentVariations,
          chosenVariationId: 'bar',
        ),
      ],
    );
    final template = withLibraryExercises(_template(), [_bench]);
    final loads = sessionLoads(
      template,
      previous: previous,
      gym: _barbellGym,
      unitPreferences: const {},
    );
    expect(loads.single.resistanceEquipment?.single.equipmentId, 'barbell');
    expect(loads.single.weightUnit, m.ExerciseWeightUnit.kilograms);
  });

  group('sessionPrefill', () {
    final week = weekOf(withLibraryExercises(_template(), [_bench]), null);

    r.SessionPrefill prefill(m.InitialLogFillOption fill) => sessionPrefill(
      week,
      mesocycleId: null,
      loads: const [],
      settings: settings(fill: fill),
      history: const SessionHistory([]),
      workoutGym: _barbellGym,
    );

    test('as Initial Log Fill asks', () {
      expect(
        prefill(m.InitialLogFillOption.previousValues),
        isA<r.PrefillPreviousValues>(),
      );
      expect(prefill(m.InitialLogFillOption.empty), isA<r.PrefillEmpty>());
      final suggestions = prefill(
        m.InitialLogFillOption.smartProgression,
      ) as r.PrefillSuggestions;
      expect(
        suggestions.byExercise['bench#0']?.rationale,
        r.Rationale.noHistory,
      );
    });
  });

  group('plannedSession', () {
    final history = SessionHistory([
      _done(
        'last',
        day: 3,
        exercises: [
          exercise(
            'x',
            templateId: 'bench',
            variations: _bench.equipmentVariations,
            chosenVariationId: 'bar',
            sets: [set('1', reps: 10, weightKg: 100, done: true)],
          ),
        ],
      ),
    ]);

    m.WorkoutSessionModel plan({
      String? templateGym,
      m.GymProfileModel? workoutGym,
      int? microcycle,
      m.WorkoutSettings? workoutSettings,
    }) => plannedSession(
      authorId: author,
      template: _template(gymProfileId: templateGym),
      library: [_bench],
      history: history,
      settings: workoutSettings ?? settings(),
      gyms: [_barbellGym],
      workoutGym: workoutGym,
      now: start,
      newId: Ids().call,
      microcycleIndex: microcycle,
      mesocycleId: microcycle == null ? null : 'meso',
    );

    test('is built from the library copy, last time and the template gym', () {
      final planned = plan(templateGym: 'home');
      expect(planned.gymProfileId, 'home');
      expect(planned.exercises.single.name, 'Lift');
      expect(
        planned.exercises.single.sets.where((s) => !s.isWarmup).single.weightKg,
        100,
      );
    });

    test('falls back to the workout gym, and takes the week', () {
      final planned = plan(workoutGym: _barbellGym, microcycle: 2);
      expect(planned.gymProfileId, 'home');
      expect(planned.mesocycleId, 'meso');
      expect(
        planned.exercises.single.sets.where((s) => !s.isWarmup),
        hasLength(2),
      );
      expect(plan().gymProfileId, isNull);
    });

    test('smart progression suggests, and the set plan is laid on', () {
      final planned = plan(
        templateGym: 'home',
        workoutGym: _barbellGym,
        workoutSettings: settings(
          fill: m.InitialLogFillOption.smartProgression,
          setPlanning: true,
        ),
      );
      final working = planned.exercises.single.sets.where((s) => !s.isWarmup);
      // One session at the top without an RPE: a rep more, not weight.
      expect(working.single.weightKg, 100);
      expect(working.single.reps, 10);
    });
  });
}
