// The volume tiers, daily sets per muscle and the volume suggestion, checked
// case for case against the Swift suites (VolumeRecommendationTests,
// MuscleBalanceTests, AnalyticsExercisePresenterTests): the inputs and
// expected values are the Swift tests' own.
import 'package:compound_maths/compound_maths.dart';
import 'package:test/test.dart';

VolumeInputs inputs({
  List<double> weeks = const [12, 12, 12, 12],
  double? trend = 0,
  double? adherence = 1,
  double? rpeDrift = 0,
  int? age = 30,
}) => VolumeInputs(
  weeklySets: weeks,
  trendPercentPerWeek: trend,
  adherence: adherence,
  rpeDrift: rpeDrift,
  age: age,
);

final day0 = DateTime.fromMillisecondsSinceEpoch(
  1700000000 * 1000,
  isUtc: true,
);
DateTime day(int offset) => day0.add(Duration(days: offset));

void main() {
  group('VolumeTier', () {
    test('every muscle shares the same tiers', () {
      final cases = <double, VolumeTier>{
        0.0: VolumeTier.belowMaintenance,
        3.5: VolumeTier.belowMaintenance,
        4.0: VolumeTier.maintaining,
        9.5: VolumeTier.maintaining,
        10.0: VolumeTier.productive,
        20.0: VolumeTier.productive,
        20.5: VolumeTier.high,
      };
      for (final MapEntry(key: sets, value: tier) in cases.entries) {
        expect(VolumeTier.of(sets), tier);
      }
    });
  });

  group('dailyMuscleSets', () {
    test('credits each day and muscle, skipping unknown templates', () {
      const bench = WorkoutExercise(
        templateId: 'bench',
        name: 'Bench',
        sets: [
          WorkoutSet(completed: true),
          WorkoutSet(completed: true, rpe: 4),
          WorkoutSet(isWarmup: true, completed: true),
          WorkoutSet(),
        ],
      );
      const easy = WorkoutExercise(
        templateId: 'bench',
        name: 'Bench',
        sets: [WorkoutSet(completed: true, rpe: 5)],
      );
      const unknown = WorkoutExercise(
        templateId: 'other',
        name: 'Other',
        sets: [WorkoutSet(completed: true)],
      );
      WorkoutSession on(String day, List<WorkoutExercise> exercises) =>
          WorkoutSession(
            day: day,
            at: DateTime.utc(2026),
            exercises: exercises,
          );
      final daily = dailyMuscleSets(
        [
          on('2026-03-01', [bench, easy, unknown]),
          on('2026-03-01', [bench]),
          on('2026-03-02', [bench]),
        ],
        {
          'bench': {
            Muscle.chest: MuscleTarget.primary,
            Muscle.triceps: MuscleTarget.secondary,
          },
        },
      );
      expect(daily[Muscle.chest], {'2026-03-01': 2, '2026-03-02': 1});
      expect(daily[Muscle.triceps], {'2026-03-01': 1, '2026-03-02': 0.5});
      expect(daily.containsKey(Muscle.quads), isFalse);
    });
  });

  group('recommendVolume', () {
    test('flat strength with steady effort adds ten to twenty percent', () {
      final result = recommendVolume(inputs(trend: 0.2));
      expect(result.action, VolumeAction.add);
      expect(result.baselineSets, 12);
      // 12 × 1.1 = 13.2 → 13; 12 × 1.2 = 14.4 → 14.
      expect(result.suggestedSets, (low: 13.0, high: 14.0));
      expect(result.trendPercentPerWeek, 0.2);
      expect(result.adherence, 1);
      expect(result.rpeDrift, 0);
    });

    test('the step up is at least one set', () {
      final result = recommendVolume(inputs(weeks: [5, 5, 5, 5]));
      expect(result.action, VolumeAction.add);
      expect(result.suggestedSets, (low: 6.0, high: 6.0));
    });

    test('rising strength keeps the current volume', () {
      final result = recommendVolume(inputs(trend: 1.5));
      expect(result.action, VolumeAction.keep);
      expect(result.suggestedSets, (low: 12.0, high: 12.0));
    });

    test('falling strength reduces twenty to thirty-three percent', () {
      final result = recommendVolume(inputs(trend: -1));
      expect(result.action, VolumeAction.reduce);
      // 12 × 0.67 = 8.04 → 8; 12 × 0.8 = 9.6 → 10.
      expect(result.suggestedSets, (low: 8.0, high: 10.0));
    });

    test('rising RPE at the same load reduces', () {
      expect(
        recommendVolume(inputs(trend: 2, rpeDrift: 1)).action,
        VolumeAction.reduce,
      );
      expect(
        recommendVolume(inputs(trend: 2, rpeDrift: 0.5)).action,
        VolumeAction.keep,
      );
    });

    test('missed planned sets come first', () {
      final result = recommendVolume(inputs(trend: -3, adherence: 0.7));
      expect(result.action, VolumeAction.beConsistent);
      expect(result.suggestedSets, (low: 12.0, high: 12.0));
      expect(recommendVolume(inputs(adherence: 0.8)).action, VolumeAction.add);
    });

    test('the flat band edges', () {
      final cases = {
        0.5: VolumeAction.add,
        -0.5: VolumeAction.add,
        0.51: VolumeAction.keep,
        -0.51: VolumeAction.reduce,
      };
      for (final MapEntry(key: trend, value: action) in cases.entries) {
        expect(recommendVolume(inputs(trend: trend)).action, action);
      }
    });

    test('too little history asks for more', () {
      expect(
        recommendVolume(inputs(weeks: [0, 0, 0, 6])).action,
        VolumeAction.needsMoreData,
      );
      final noTrend = recommendVolume(inputs(trend: null));
      expect(noTrend.action, VolumeAction.needsMoreData);
      expect(noTrend.suggestedSets, isNull);
      expect(recommendVolume(inputs(weeks: [])).suggestedSets, isNull);
    });

    test('only the last four weeks are read', () {
      final result = recommendVolume(inputs(weeks: [30, 30, 12, 12, 12, 12]));
      expect(result.baselineSets, 12);
    });

    test('a new user starts from the productive band', () {
      final result = recommendVolume(inputs(weeks: [0, 0, 3, 3], trend: 2));
      expect(result.action, VolumeAction.keep);
      expect(result.suggestedSets, (low: 10.0, high: 10.0));
    });

    test('a reduction never goes under the floor', () {
      final young = recommendVolume(inputs(weeks: [5, 5, 5, 5], trend: -2));
      expect(young.suggestedSets!.low, 4);
      final older = recommendVolume(
        inputs(weeks: [5, 5, 5, 5], trend: -2, age: 65),
      );
      expect(older.suggestedSets, (low: 6.0, high: 6.0));
    });

    test('over twenty sets is flagged as high', () {
      expect(
        recommendVolume(inputs(weeks: [22, 24, 22, 24])).isHighVolume,
        isTrue,
      );
      expect(recommendVolume(inputs()).isHighVolume, isFalse);
    });

    test('the baseline is the median week', () {
      expect(median([4, 20, 10, 12]), 11);
      expect(median([3, 1, 2]), 2);
      expect(median([]), isNull);
    });
  });

  group('trendPercentPerWeek', () {
    test('is percent of the mean per week', () {
      // +1 kg a week around a 100 kg mean is +1% a week.
      final trend = trendPercentPerWeek([
        (at: day(0), value: 99),
        (at: day(7), value: 100),
        (at: day(14), value: 101),
        (at: day(3), value: 0),
      ]);
      expect(trend, closeTo(1, 1e-9));
    });

    test('needs three sessions over a week', () {
      expect(
        trendPercentPerWeek([
          (at: day(0), value: 100),
          (at: day(7), value: 101),
        ]),
        isNull,
      );
      expect(
        trendPercentPerWeek([
          (at: day(0), value: 100),
          (at: day(2), value: 101),
          (at: day(4), value: 102),
        ]),
        isNull,
      );
    });
  });

  group('rpeDrift', () {
    test('compares the same load', () {
      final midpoint = day(14);
      final sets = <EffortSample>[
        (at: day(1), weightKg: 100, rpe: 7),
        (at: day(3), weightKg: 100, rpe: 7),
        (at: day(20), weightKg: 100, rpe: 8.5),
        // A heavier load only after the midpoint has nothing to compare
        // with.
        (at: day(21), weightKg: 110, rpe: 9.5),
      ];
      expect(rpeDrift(sets, midpoint), 1.5);
      expect(rpeDrift(sets.sublist(0, 2), midpoint), isNull);
    });

    test('takes the most used load, then the larger drift', () {
      final midpoint = day(14);
      final sets = <EffortSample>[
        (at: day(1), weightKg: 80, rpe: 7),
        (at: day(20), weightKg: 80, rpe: 7.5),
        (at: day(2), weightKg: 90, rpe: 7),
        (at: day(21), weightKg: 90, rpe: 9),
        (at: day(3), weightKg: 60, rpe: 6),
        (at: day(4), weightKg: 60, rpe: 6),
        (at: day(22), weightKg: 60, rpe: 6),
      ];
      expect(rpeDrift(sets, midpoint), 0);
      expect(rpeDrift(sets.sublist(0, 4), midpoint), 2);
    });
  });

  group('volumeInputs', () {
    const author = 'author-1';
    WorkoutSession session(
      int offset,
      String templateId, {
      required int done,
      required int planned,
      bool isDeload = false,
    }) => WorkoutSession(
      day: addDays('2023-11-14', offset),
      at: day(offset),
      isDeload: isDeload,
      exercises: [
        WorkoutExercise(
          templateId: templateId,
          name: author,
          plannedSets: planned,
          sets: [
            for (var i = 0; i < planned; i++)
              WorkoutSet(reps: 8, weightKg: 100, completed: i < done),
          ],
        ),
      ],
    );
    const templates = {
      'bench': {Muscle.chest: MuscleTarget.primary},
      'fly': {Muscle.chest: MuscleTarget.secondary},
    };

    test('reads adherence from planned sets on exercises that train the '
        'muscle', () {
      final result = volumeInputs(
        Muscle.chest,
        sessions: [
          session(10, 'bench', done: 3, planned: 4),
          session(20, 'bench', done: 4, planned: 4),
          // Only exercises that train the muscle directly count.
          session(21, 'fly', done: 0, planned: 4),
          // A deload week is not read against its targets.
          session(22, 'bench', done: 1, planned: 4, isDeload: true),
          // Outside the window.
          session(-10, 'bench', done: 0, planned: 4),
        ],
        templates: templates,
        end: day(27),
        endDay: addDays('2023-11-14', 27),
      );
      expect(result.adherence, 7 / 8);
      expect(result.weeklySets.length, VolumeRecommendation.windowWeeks);
      expect(result.age, isNull);
    });

    test('reads the trend and drift of the primary exercises', () {
      WorkoutSession lift(int offset, double kg, double rpe) => WorkoutSession(
        day: addDays('2023-11-14', offset),
        at: day(offset),
        exercises: [
          WorkoutExercise(
            templateId: 'bench',
            name: 'Bench',
            sets: [
              WorkoutSet(reps: 5, weightKg: kg, rpe: rpe, completed: true),
              WorkoutSet(
                reps: 5,
                weightKg: kg,
                rpe: rpe,
                completed: true,
                isWarmup: true,
              ),
              WorkoutSet(reps: 5, completed: true, rpe: rpe),
            ],
          ),
        ],
      );
      final result = volumeInputs(
        Muscle.chest,
        sessions: [lift(2, 100, 7), lift(9, 100, 7), lift(16, 100, 8)],
        templates: templates,
        end: day(20),
        endDay: addDays('2023-11-14', 20),
        age: 40,
      );
      expect(result.trendPercentPerWeek, isNotNull);
      expect(result.rpeDrift, 0.5);
      expect(result.adherence, isNull);
      expect(result.age, 40);
      expect(result.weeklySets, [0, 2, 2, 2]);
    });

    test('a local end opens a local window', () {
      final result = volumeInputs(
        Muscle.chest,
        sessions: const [],
        templates: templates,
        end: DateTime(2026, 3, 28, 12),
        endDay: '2026-03-28',
      );
      expect(result.weeklySets, [0, 0, 0, 0]);
      expect(result.trendPercentPerWeek, isNull);
      expect(result.rpeDrift, isNull);
    });
  });
}
