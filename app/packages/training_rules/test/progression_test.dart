// Ports ProgressionEngineTests, AMRAPProgressionTests, ProgressionAuditTests,
// ProgressionPlannerTests, ProgressionSuggestionDisplayTests (the row
// mapping) and the deload cases of WorkoutSessionModelTests.
import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

final start = DateTime.fromMillisecondsSinceEpoch(1000000000, isUtc: true);

double roundToHalfKg(double kg) => (kg * 2).roundToDouble() / 2;

double roundToFiveKgDown(double kg) => (kg / 5).floorToDouble() * 5;

typedef Logged = (double? kg, int? reps, double? rpe);

List<WorkoutSet> sets(List<Logged> values, {bool completed = true}) => [
  for (final (i, (kg, reps, rpe)) in values.indexed)
    WorkoutSet(
      id: 'set-${i + 1}',
      index: i + 1,
      reps: reps,
      weightKg: kg,
      rpe: rpe,
      completedAt: completed ? start : null,
    ),
];

List<WorkoutSet> timedSets(
  List<int> durations, {
  List<double?> distances = const [],
  bool completed = true,
}) => [
  for (final (i, duration) in durations.indexed)
    WorkoutSet(
      id: 'set-${i + 1}',
      index: i + 1,
      durationSec: duration,
      distanceMeters: i < distances.length ? distances[i] : null,
      completedAt: completed ? start : null,
    ),
];

List<SetTarget> targets(
  int? min,
  int? max,
  int count, {
  int? rir,
  SetTargetSetType type = SetTargetSetType.standard,
}) => [
  for (var n = 1; n <= count; n++)
    SetTarget(
      setNumber: n,
      minReps: min,
      maxReps: max,
      rirTarget: rir,
      setType: type,
    ),
];

ProgressionInput input({
  required List<List<WorkoutSet>> history,
  TrackingMode mode = TrackingMode.weightReps,
  List<SetTarget> setTargets = const [],
  ProgressionAdjustmentMode adjustmentMode =
      ProgressionAdjustmentMode.weightFirst,
  double Function(double) round = roundToHalfKg,
  double incrementKg = 2.5,
  ExerciseType? type,
  AmrapProgression? amrap,
}) => ProgressionInput(
  trackingMode: mode,
  setTargets: setTargets,
  history: history,
  adjustmentMode: adjustmentMode,
  rounding: ProgressionRounding(round: round, minimumIncrementKg: incrementKg),
  exerciseType: type,
  amrap: amrap,
);

ProgressionSuggestion suggest(ProgressionInput input) =>
    ProgressionEngine.suggest(input);

void main() {
  group('the engine', () {
    test('no history suggests nothing', () {
      final s = suggest(input(setTargets: targets(8, 12, 3), history: []));
      expect(s.rationale, Rationale.noHistory);
      expect(s.sets, List.filled(3, SuggestedSet.none));
      expect(
        suggest(input(setTargets: targets(8, 12, 2), history: [[]])).rationale,
        Rationale.noHistory,
      );
      expect(ProgressionSuggestion.noHistory(-1).sets, isEmpty);
    });

    test('weight-first adds weight when most sets reach the top', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 4),
          history: [
            sets([(60, 12, 8), (60, 12, 8), (60, 12, 8), (60, 10, 8)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.progressWeight);
      expect(
        s.sets,
        List.filled(4, const SuggestedSet(weightKg: 62.5, reps: 8)),
      );
    });

    test('weight-first adds reps when only one set reaches the top', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 4),
          history: [
            sets([
              (60, 12, null),
              (60, 10, null),
              (60, 9, null),
              (60, 8, null),
            ]),
          ],
        ),
      );
      expect(s.rationale, Rationale.addReps);
      expect(s.sets, const [
        SuggestedSet(weightKg: 60, reps: 12),
        SuggestedSet(weightKg: 60, reps: 11),
        SuggestedSet(weightKg: 60, reps: 10),
        SuggestedSet(weightKg: 60, reps: 9),
      ]);
    });

    test('weight-first needs more than half the sets at the top', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 4),
          history: [
            sets([
              (60, 12, null),
              (60, 12, null),
              (60, 10, null),
              (60, 10, null),
            ]),
          ],
        ),
      );
      expect(s.rationale, Rationale.addReps);
    });

    test('reps-first adds a rep until every set has caught up', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 3),
          history: [
            sets([(60, 12, null), (60, 10, null), (60, 9, null)]),
          ],
          adjustmentMode: ProgressionAdjustmentMode.repsFirst,
        ),
      );
      expect(s.rationale, Rationale.addReps);
      expect(s.sets, const [
        SuggestedSet(weightKg: 60, reps: 12),
        SuggestedSet(weightKg: 60, reps: 11),
        SuggestedSet(weightKg: 60, reps: 10),
      ]);
    });

    test('reps-first adds weight once every set is at the top', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 3),
          history: [
            sets([(60, 12, 8), (60, 12, 8), (60, 12, 8)]),
          ],
          adjustmentMode: ProgressionAdjustmentMode.repsFirst,
        ),
      );
      expect(s.rationale, Rationale.progressWeight);
      expect(
        s.sets,
        List.filled(3, const SuggestedSet(weightKg: 62.5, reps: 8)),
      );
    });

    test('one miss repeats the session exactly', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 3),
          history: [
            sets([(60, 12, null), (60, 8, null), (60, 6, null)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.hold);
      expect(s.sets, const [
        SuggestedSet(weightKg: 60, reps: 12),
        SuggestedSet(weightKg: 60, reps: 8),
        SuggestedSet(weightKg: 60, reps: 6),
      ]);
    });

    test('two missed sessions reset from the estimated one-rep max', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 3),
          history: [
            sets([(60, 7, null), (60, 7, null), (60, 6, null)]),
            sets([(60, 7, null), (60, 6, null), (60, 6, null)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.deload);
      expect(s.sets, const [
        SuggestedSet(weightKg: 55.5, reps: 8),
        SuggestedSet(weightKg: 55.5, reps: 8),
        SuggestedSet(weightKg: 54, reps: 8),
      ]);
    });

    test('a reset takes between five and fifteen per cent off', () {
      final nearMiss = suggest(
        input(
          setTargets: targets(5, 6, 1, rir: 0),
          history: [
            sets([(100, 4, null)]),
            sets([(100, 4, null)]),
          ],
        ),
      );
      expect(nearMiss.sets, const [SuggestedSet(weightKg: 95, reps: 5)]);
      final badMiss = suggest(
        input(
          setTargets: targets(10, 12, 1, rir: 3),
          history: [
            sets([(100, 2, null)]),
            sets([(100, 2, null)]),
          ],
        ),
      );
      expect(badMiss.sets, const [SuggestedSet(weightKg: 85, reps: 10)]);
    });

    test('a reset without an estimate takes ten per cent', () {
      final s = suggest(
        input(
          setTargets: targets(12, 15, 1),
          history: [
            sets([(60, 11, null)]),
            sets([(60, 11, null)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.deload);
      expect(s.sets, const [SuggestedSet(weightKg: 54, reps: 12)]);
    });

    test('a reset that would round up is rounded down instead', () {
      // 60 × 0.9 = 54 rounds to 55 on a five grid: one step lower, 50.
      double nearestFive(double kg) => (kg / 5).roundToDouble() * 5;
      final s = suggest(
        input(
          setTargets: targets(12, 15, 1),
          history: [
            sets([(60, 11, null)]),
            sets([(60, 11, null)]),
          ],
          round: nearestFive,
          incrementKg: 5,
        ),
      );
      expect(s.sets.single.weightKg, 50);
      // Where one step lower would be no weight at all, the rounded-up
      // weight stands.
      final light = suggest(
        input(
          setTargets: targets(12, 15, 1),
          history: [
            sets([(4, 11, null)]),
            sets([(4, 11, null)]),
          ],
          round: nearestFive,
          incrementKg: 5,
        ),
      );
      expect(light.sets.single.weightKg, 5);
    });

    test(
      'a reset of assistance gives more assistance; none without weight',
      () {
        final assisted = suggest(
          input(
            setTargets: targets(8, 12, 1),
            history: [
              sets([(-30, 5, null)]),
              sets([(-30, 5, null)]),
            ],
          ),
        );
        expect(assisted.rationale, Rationale.deload);
        expect(assisted.sets.single.weightKg, -33);
        final bodyweight = suggest(
          input(
            setTargets: targets(8, 12, 1),
            history: [
              sets([(null, 5, null)]),
              sets([(null, 5, null)]),
            ],
          ),
        );
        expect(bodyweight.sets.single, const SuggestedSet(reps: 8));
      },
    );

    test('a reset works from the load, a machine base kept out', () {
      final withBase = [
        const WorkoutSet(id: 's', reps: 7, weightKg: 70, machineBaseKg: 10),
      ].map((s) => s.copyWith(completedAt: start)).toList();
      final s = suggest(
        input(setTargets: targets(8, 12, 1), history: [withBase, withBase]),
      );
      // 60 × (1 + 7/30) = 74, worked back to 55.5, held to 85 % of 70.
      expect(s.sets.single.weightKg, 59.5);
    });

    test('misses stopped short of failure do not reset', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 2),
          history: [
            sets([(60, 7, 8), (60, 7, 8)]),
            sets([(60, 7, 8), (60, 6, 8)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.hold);
    });

    test('misses at a lighter weight do not deload', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 3),
          history: [
            sets([(60, 7, null), (60, 7, null), (60, 6, null)]),
            sets([(55, 7, null), (55, 6, null), (55, 6, null)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.hold);
    });

    test('without an RPE the top must be reached twice', () {
      final once = suggest(
        input(
          setTargets: targets(8, 12, 2),
          history: [
            sets([(60, 12, null), (60, 12, null)]),
            sets([(60, 11, null), (60, 10, null)]),
          ],
        ),
      );
      expect(once.rationale, Rationale.addReps);
      expect([for (final s in once.sets) s.weightKg], [60, 60]);
      final twice = suggest(
        input(
          setTargets: targets(8, 12, 2),
          history: [
            sets([(60, 12, null), (60, 12, null)]),
            sets([(60, 12, null), (60, 12, null)]),
          ],
        ),
      );
      expect(twice.rationale, Rationale.progressWeight);
      expect([for (final s in twice.sets) s.weightKg], [62.5, 62.5]);
      final lighter = suggest(
        input(
          setTargets: targets(8, 12, 1),
          history: [
            sets([(60, 12, null)]),
            sets([(57.5, 12, null)]),
          ],
        ),
      );
      expect(lighter.rationale, Rationale.addReps);
      final onlyOnce = suggest(
        input(
          setTargets: targets(8, 12, 1),
          history: [
            sets([(60, 12, null)]),
          ],
        ),
      );
      expect(onlyOnce.rationale, Rationale.addReps);
    });

    test('a compound lift without a target needs a rep in reserve', () {
      Rationale rationale(double rpe, ExerciseType? type) => suggest(
        input(
          setTargets: targets(8, 12, 1),
          history: [
            sets([(60, 12, rpe)]),
          ],
          type: type,
        ),
      ).rationale;
      expect(rationale(10, ExerciseType.compoundUpper), Rationale.addReps);
      expect(
        rationale(9.5, ExerciseType.compoundUpper),
        Rationale.progressWeight,
      );
      expect(
        rationale(10, ExerciseType.isolationUpper),
        Rationale.progressWeight,
      );
      expect(rationale(10, null), Rationale.progressWeight);
    });

    test('an over-effort set does not earn weight', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 3, rir: 2),
          history: [
            sets([(60, 12, 9.5), (60, 10, 8), (60, 9, 8)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.addReps);
    });

    test('a missing rep range is the default, not last time', () {
      final s = suggest(
        input(
          history: [
            sets([(60, 10, null)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.addReps);
      expect(s.sets, const [SuggestedSet(weightKg: 60, reps: 11)]);
    });

    test('rounding that swallows the increment adds a second one', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 1),
          history: [
            sets([(60, 12, 8)]),
          ],
          round: roundToFiveKgDown,
        ),
      );
      expect(s.rationale, Rationale.progressWeight);
      expect(s.sets, const [SuggestedSet(weightKg: 65, reps: 8)]);
    });

    test('the step is a share of the working weight', () {
      final squat = suggest(
        input(
          setTargets: targets(5, 8, 1),
          history: [
            sets([(140, 8, 8)]),
          ],
          type: ExerciseType.compoundLower,
        ),
      );
      expect(squat.sets, const [SuggestedSet(weightKg: 147, reps: 5)]);
    });

    test('a step too big for the weight adds a rep instead', () {
      ProgressionSuggestion at(int reps) => suggest(
        input(
          setTargets: targets(8, 12, 1),
          history: [
            sets([(12, reps, 8)]),
          ],
          round: (kg) => (kg / 2).roundToDouble() * 2,
          incrementKg: 2,
          type: ExerciseType.isolationUpper,
        ),
      );
      expect(at(12).rationale, Rationale.addReps);
      expect(at(12).sets, const [SuggestedSet(weightKg: 12, reps: 13)]);
      expect(at(14).sets, const [SuggestedSet(weightKg: 12, reps: 15)]);
      expect(at(15).rationale, Rationale.progressWeight);
      expect(at(15).sets, const [SuggestedSet(weightKg: 14, reps: 8)]);
    });

    test('each set progresses from its own reference', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 3),
          history: [
            sets([(100, 12, 8), (90, 12, 8), (80, 12, 8)]),
          ],
        ),
      );
      expect([for (final x in s.sets) x.weightKg], [102.5, 92.5, 82.5]);
    });

    test('an intensity technique is prefilled but never progressed', () {
      for (final type in [
        SetTargetSetType.drop,
        SetTargetSetType.partials,
        SetTargetSetType.stretch,
        SetTargetSetType.hold,
      ]) {
        final setTargets = [
          ...targets(8, 12, 2),
          SetTarget(setNumber: 3, minReps: 8, maxReps: 12, setType: type),
        ];
        final s = suggest(
          input(
            setTargets: setTargets,
            history: [
              sets([(60, 12, 8), (60, 12, 8), (60, 9, 8)]),
            ],
          ),
        );
        expect(s.rationale, Rationale.progressWeight);
        expect(s.sets, const [
          SuggestedSet(weightKg: 62.5, reps: 8),
          SuggestedSet(weightKg: 62.5, reps: 8),
          SuggestedSet(weightKg: 60, reps: 9),
        ]);
      }
    });

    test('the last target applies to sets past the end of the list', () {
      final s = suggest(
        input(
          setTargets: const [
            SetTarget(minReps: 8, maxReps: 12),
            SetTarget(setNumber: 2, minReps: 5, maxReps: 8),
          ],
          history: [
            sets([(60, 12, 8), (60, 8, 8), (60, 8, 8)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.progressWeight);
      expect([for (final x in s.sets) x.reps], [8, 5, 5]);
    });

    test('more targets than sets: the last logged set stands for the rest', () {
      final s = suggest(
        input(
          setTargets: targets(8, 12, 3),
          history: [
            sets([(60, 12, 8)]),
          ],
        ),
      );
      expect(
        s.sets,
        List.filled(3, const SuggestedSet(weightKg: 62.5, reps: 8)),
      );
    });

    test('reps-only work raises the range', () {
      final s = suggest(
        input(
          mode: TrackingMode.repsOnly,
          setTargets: targets(8, 12, 3),
          history: [
            sets([(null, 12, 8), (null, 12, 8), (null, 12, 8)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.progressWeight);
      expect(s.sets, List.filled(3, const SuggestedSet(reps: 13)));
    });

    test('timed work grows by a tenth; unfinished holds', () {
      final grows = suggest(
        input(
          mode: TrackingMode.timeOnly,
          history: [
            timedSets([60, 60]),
          ],
        ),
      );
      expect(grows.rationale, Rationale.progressWeight);
      expect([for (final s in grows.sets) s.durationSec], [65, 65]);
      final holds = suggest(
        input(
          mode: TrackingMode.timeOnly,
          history: [
            timedSets([60, 60], completed: false),
          ],
        ),
      );
      expect(holds.rationale, Rationale.hold);
      expect([for (final s in holds.sets) s.durationSec], [60, 60]);
    });

    test('distance grows by a twentieth on a step that suits it', () {
      List<double?> further(double meters) => [
        for (final s in suggest(
          input(
            mode: TrackingMode.distanceTime,
            history: [
              timedSets([300], distances: [meters]),
            ],
          ),
        ).sets)
          s.distanceMeters,
      ];
      expect(further(1000), [1050]);
      expect(further(100), [105]);
      expect(further(10), [11]);
      expect(further(5000), [5250]);
      final kept = suggest(
        input(
          mode: TrackingMode.distanceTime,
          history: [
            timedSets([300]),
          ],
        ),
      );
      expect(kept.sets.single, const SuggestedSet(durationSec: 300));
      expect(
        suggest(
          input(
            mode: TrackingMode.timeOnly,
            history: [
              [WorkoutSet(id: 'x', completedAt: start)],
            ],
          ),
        ).sets.single,
        SuggestedSet.none,
      );
    });

    test('a technique set is carried over in timed work too', () {
      final s = suggest(
        input(
          mode: TrackingMode.timeOnly,
          setTargets: [
            const SetTarget(),
            const SetTarget(setNumber: 2, setType: SetTargetSetType.hold),
          ],
          history: [
            timedSets([60, 30]),
          ],
        ),
      );
      expect([for (final x in s.sets) x.durationSec], [65, 30]);
    });
  });

  group('live adjustment', () {
    List<SuggestedSet?> adjustment(
      int? reps, {
      double? rpe,
      double? kg = 60,
      SetTarget? target = const SetTarget(minReps: 8, maxReps: 12),
      int remaining = 2,
      TrackingMode mode = TrackingMode.weightReps,
      ExerciseType? type,
    }) => ProgressionEngine.adjustRemaining(
      completed: sets([(kg, reps, rpe)]).single,
      target: target,
      remaining: sets(List.filled(remaining, (60, 8, null)), completed: false),
      mode: mode,
      rounding: const ProgressionRounding(
        round: roundToHalfKg,
        minimumIncrementKg: 2.5,
      ),
      exerciseType: type,
    );

    test('missing by two lightens the remaining sets', () {
      expect(
        adjustment(6),
        List.filled(2, const SuggestedSet(weightKg: 57, reps: 8)),
      );
    });

    test('missing by one keeps the weight', () {
      expect(
        adjustment(7),
        List.filled(2, const SuggestedSet(weightKg: 60, reps: 8)),
      );
    });

    test('beating the range easily adds weight', () {
      expect(
        adjustment(14, rpe: 7),
        List.filled(2, const SuggestedSet(weightKg: 62.5, reps: 8)),
      );
      expect(
        adjustment(14),
        List.filled(2, const SuggestedSet(weightKg: 62.5, reps: 8)),
      );
    });

    test('beating the range at a hard RPE changes nothing', () {
      expect(adjustment(14, rpe: 9), [null, null]);
    });

    test('a set inside its range changes nothing', () {
      expect(adjustment(10), [null, null]);
    });

    test('only weight and reps are adjusted live', () {
      expect(adjustment(6, mode: TrackingMode.repsOnly), [null, null]);
      expect(adjustment(6, kg: null), [null, null]);
      expect(adjustment(null), [null, null]);
    });

    test('an unprescribed range is never missed', () {
      expect(adjustment(3, target: null), [null, null]);
    });

    test('a step too big waits for next session', () {
      final adjusted = ProgressionEngine.adjustRemaining(
        completed: sets([(12, 14, 7)]).single,
        target: const SetTarget(minReps: 8, maxReps: 12),
        remaining: sets([(12, 8, null)], completed: false),
        mode: TrackingMode.weightReps,
        rounding: ProgressionRounding(
          round: (kg) => (kg / 2).roundToDouble() * 2,
          minimumIncrementKg: 2,
        ),
        exerciseType: ExerciseType.isolationUpper,
      );
      expect(adjusted, [null]);
    });

    test('nothing heavier on the equipment waits too', () {
      final adjusted = ProgressionEngine.adjustRemaining(
        completed: sets([(30, 14, 7)]).single,
        target: const SetTarget(minReps: 8, maxReps: 12),
        remaining: sets([(30, 8, null)], completed: false),
        mode: TrackingMode.weightReps,
        rounding: ProgressionRounding(
          round: (kg) => kg > 30 ? 30 : kg,
          minimumIncrementKg: 2.5,
        ),
      );
      expect(adjusted, [null]);
    });

    test('a live miss on assistance adds assistance', () {
      final adjusted = ProgressionEngine.adjustRemaining(
        completed: sets([(-30, 4, null)]).single,
        target: const SetTarget(minReps: 8, maxReps: 12),
        remaining: sets([(-30, null, null)], completed: false),
        mode: TrackingMode.weightReps,
        rounding: const ProgressionRounding(
          round: roundToHalfKg,
          minimumIncrementKg: 2.5,
        ),
      );
      expect(adjusted.single!.weightKg, lessThan(-30));
    });

    test('a lighter weight the rounding swallows steps down once', () {
      final adjusted = ProgressionEngine.adjustRemaining(
        completed: sets([(10, 4, null)]).single,
        target: const SetTarget(minReps: 8, maxReps: 12),
        remaining: sets([(10, 8, null)], completed: false),
        mode: TrackingMode.weightReps,
        rounding: ProgressionRounding(
          round: (kg) => (kg / 5).roundToDouble() * 5,
          minimumIncrementKg: 5,
        ),
      );
      expect(adjusted.single!.weightKg, 5);
    });
  });

  group('audit', () {
    test('at the top of the rack a rep is added', () {
      double rack(double w) => (w - 10).abs() < (w - 30).abs() ? 10 : 30;
      final top = sets([(30, 12, null), (30, 12, null), (30, 12, null)]);
      final s = suggest(
        input(
          setTargets: targets(8, 12, 3),
          history: [top, top],
          round: rack,
          incrementKg: 20,
        ),
      );
      expect(
        s.sets,
        List.filled(3, const SuggestedSet(weightKg: 30, reps: 13)),
      );
      expect(s.rationale, Rationale.addReps);
    });

    test('no weight logged adds a rep', () {
      final top = sets([(null, 12, null), (null, 12, null), (null, 12, null)]);
      final s = suggest(
        input(setTargets: targets(8, 12, 3), history: [top, top]),
      );
      expect(s.sets, List.filled(3, const SuggestedSet(reps: 13)));
    });

    test('no range uses the default', () {
      final twelves = sets([(60, 12, null), (60, 12, null), (60, 12, null)]);
      final once = suggest(
        input(setTargets: targets(null, null, 3), history: [twelves]),
      );
      final twice = suggest(
        input(setTargets: targets(null, null, 3), history: [twelves, twelves]),
      );
      expect(once.sets.first.reps, 12);
      expect(twice.rationale, Rationale.progressWeight);
      expect(twice.sets.first.weightKg, greaterThan(60));
      expect(twice.sets.first.reps, 8);
    });

    test('below the default range is not a miss', () {
      final s = suggest(
        input(
          setTargets: targets(null, null, 3),
          history: [
            sets([(40, 5, null), (40, 5, null), (40, 5, null)]),
          ],
        ),
      );
      expect(s.rationale, Rationale.addReps);
      expect(s.sets.first.reps, 6);
    });

    test('one end of a range is widened', () {
      final tens = sets([(80, 10, null), (80, 10, null), (80, 10, null)]);
      final low = suggest(
        input(setTargets: targets(6, null, 3), history: [tens, tens]),
      );
      expect(low.rationale, Rationale.progressWeight);
      expect(low.sets.first.reps, 6);
      final high = suggest(
        input(setTargets: targets(null, 10, 3), history: [tens, tens]),
      );
      expect(high.sets.first.reps, 6);
      final inverted = suggest(
        input(setTargets: targets(10, 8, 3), history: [tens, tens]),
      );
      expect(inverted.rationale, Rationale.progressWeight);
      expect(inverted.sets.first.reps, 10);
    });

    test('reps-only keeps climbing', () {
      final thirteen = sets([
        (null, 13, null),
        (null, 13, null),
        (null, 13, null),
      ]);
      final s = suggest(
        input(
          mode: TrackingMode.repsOnly,
          setTargets: targets(8, 12, 3),
          history: [thirteen, thirteen],
        ),
      );
      expect(s.sets, List.filled(3, const SuggestedSet(reps: 14)));
    });

    test('an AMRAP set at failure is within its target', () {
      final history = [
        ...sets([(100, 5, 8), (100, 5, 8)]),
        sets([(100, 9, 10)]).single.copyWith(index: 3),
      ];
      final s = suggest(
        input(
          setTargets: [
            ...targets(5, 5, 2),
            const SetTarget(
              setNumber: 3,
              minReps: 5,
              maxReps: 5,
              setType: SetTargetSetType.amrap,
            ),
          ],
          history: [history],
          type: ExerciseType.compoundLower,
        ),
      );
      expect(s.rationale, Rationale.progressWeight);
    });

    test('short holds and distances grow by at least a step', () {
      final hold = [
        WorkoutSet(
          id: 'h',
          durationSec: 10,
          distanceMeters: 20,
          completedAt: start,
        ),
      ];
      expect(
        suggest(
          input(
            mode: TrackingMode.timeOnly,
            setTargets: targets(null, null, 1),
            history: [hold],
          ),
        ).sets.first.durationSec,
        15,
      );
      expect(
        suggest(
          input(
            mode: TrackingMode.distanceTime,
            setTargets: targets(null, null, 1),
            history: [hold],
          ),
        ).sets.first.distanceMeters,
        21,
      );
    });

    test('fewer sets than planned holds', () {
      final one = [WorkoutSet(id: 'h', durationSec: 60, completedAt: start)];
      expect(
        suggest(
          input(
            mode: TrackingMode.timeOnly,
            setTargets: targets(null, null, 3),
            history: [one],
          ),
        ).rationale,
        Rationale.hold,
      );
    });
  });

  group('AMRAP', () {
    const rule = AmrapProgression(ceiling: 12);
    double heavier(double kg) => kg + 2.5;
    WorkoutSet amrap(int? reps, {double? kg = 100, int? target = 8}) =>
        WorkoutSet(
          id: 'a',
          reps: reps,
          weightKg: kg,
          kind: SetKind.amrap,
          targetReps: target,
          completedAt: start,
        );
    SuggestedSet next(WorkoutSet last, WorkoutSet? previous) => rule.next(
      templateTarget: 8,
      last: last,
      previous: previous,
      heavier: heavier,
    );

    test('a target beaten twice running goes up a rep', () {
      expect(
        next(amrap(10), amrap(9)),
        const SuggestedSet(weightKg: 100, reps: 9, targetReps: 9),
      );
    });

    test('a target beaten once, or only met, holds', () {
      expect(next(amrap(10), amrap(8)).targetReps, 8);
      expect(next(amrap(8), amrap(11)).targetReps, 8);
      expect(next(amrap(10), null).targetReps, 8);
      expect(next(amrap(10), null).weightKg, 100);
      expect(next(amrap(null), amrap(11)).targetReps, 8);
    });

    test("the standing target is last session's", () {
      expect(next(amrap(10, target: 10), amrap(11, target: 9)).targetReps, 10);
      expect(next(amrap(11, target: 10), amrap(11, target: 9)).targetReps, 11);
    });

    test("a set without a target is judged against the template's", () {
      expect(
        next(amrap(9, target: null), amrap(9, target: null)).targetReps,
        9,
      );
    });

    test('at the ceiling it adds weight and resets the target', () {
      expect(
        next(amrap(14, target: 12), amrap(13, target: 12)),
        const SuggestedSet(weightKg: 102.5, reps: 8, targetReps: 8),
      );
    });

    test('bodyweight work keeps raising past the ceiling', () {
      final s = next(
        amrap(14, kg: null, target: 12),
        amrap(13, kg: null, target: 12),
      );
      expect(s.targetReps, 13);
      expect(s.weightKg, isNull);
    });

    test('a target rises only after two sessions at the weight', () {
      final s = next(amrap(9, kg: 102.5), amrap(13, target: null));
      expect(s.targetReps, 8);
      expect(s.weightKg, 102.5);
    });

    ProgressionInput amrapInput(
      AmrapProgression? amrapRule, {
      SetTargetSetType type = SetTargetSetType.amrap,
    }) {
      final standard = WorkoutSet(
        id: 's',
        reps: 9,
        weightKg: 100,
        completedAt: start,
      );
      return input(
        setTargets: [
          const SetTarget(minReps: 8, maxReps: 12),
          SetTarget(
            setNumber: 2,
            minReps: 8,
            maxReps: 12,
            setType: type,
            amrapTargetReps: 8,
          ),
        ],
        history: [
          [standard, amrap(11)],
          [standard, amrap(10)],
        ],
        amrap: amrapRule,
      );
    }

    test('the engine raises a planned target and leaves the rest', () {
      for (final type in [SetTargetSetType.amrap, SetTargetSetType.failure]) {
        final s = suggest(amrapInput(rule, type: type));
        expect(
          s.sets[1],
          const SuggestedSet(weightKg: 100, reps: 9, targetReps: 9),
        );
        expect(s.sets[0].targetReps, isNull);
        expect(s.sets[0].weightKg, 100);
      }
    });

    test('the AMRAP increment is the engine increment', () {
      final s = suggest(
        input(
          setTargets: const [
            SetTarget(
              minReps: 8,
              maxReps: 12,
              setType: SetTargetSetType.amrap,
              amrapTargetReps: 8,
            ),
          ],
          history: [
            [amrap(14, target: 12)],
            [amrap(13, target: 12)],
          ],
          amrap: rule,
        ),
      );
      expect(
        s.sets.single,
        const SuggestedSet(weightKg: 102.5, reps: 8, targetReps: 8),
      );
      // With one session the earlier set is missing, and the target holds.
      final one = suggest(
        input(
          setTargets: const [
            SetTarget(
              minReps: 8,
              maxReps: 12,
              setType: SetTargetSetType.amrap,
              amrapTargetReps: 8,
            ),
          ],
          history: [
            [amrap(14, target: 12)],
          ],
          amrap: rule,
        ),
      );
      expect(one.sets.single.targetReps, 12);
    });

    test('without the rule an AMRAP set progresses as before', () {
      expect(
        suggest(amrapInput(null)).sets.every((s) => s.targetReps == null),
        isTrue,
      );
    });

    test('the rule runs only with the set plan and raise target on', () {
      expect(AmrapProgression.fromSettings(const WorkoutSettings()), isNull);
      expect(
        AmrapProgression.fromSettings(const WorkoutSettings(setPlanning: true)),
        rule,
      );
      expect(
        AmrapProgression.fromSettings(
          const WorkoutSettings(setPlanning: true, amrapAddsWeightAtTarget: 15),
        )?.ceiling,
        15,
      );
      expect(
        AmrapProgression.fromSettings(
          const WorkoutSettings(setPlanning: true, amrapRaisesTarget: false),
        ),
        isNull,
      );
      expect(
        AmrapProgression.fromSettings(
          const WorkoutSettings(setPlanning: true, amrapAddsWeight: false),
        ),
        const AmrapProgression(),
      );
      // The legacy "never" reads as 12 and as the switch off.
      expect(
        AmrapProgression.fromSettings(
          const WorkoutSettings(
            setPlanning: true,
            amrapAddsWeightAtTarget: WorkoutSettings.legacyNeverAddsWeight,
          ),
        ),
        const AmrapProgression(),
      );
      expect(
        const WorkoutSettings(
          amrapAddsWeightAtTarget: WorkoutSettings.legacyNeverAddsWeight,
        ).amrapWeightCeiling,
        12,
      );
    });
  });

  group('effort and load increments', () {
    test('RIR and RPE are one scale read from opposite ends', () {
      expect(EffortScale.rpeFromRir(2), 8);
      expect(EffortScale.rirFromRpe(8.5), 1.5);
      expect(EffortScale.rirChoice(8.4), 2);
      expect(EffortScale.rirChoice(11), 0);
      expect(EffortScale.rirChoice(2), 6);
      expect(EffortScale.rirText(2), '2');
      expect(EffortScale.rirText(6), '6+');
    });

    test('the step and reserve by type', () {
      expect(LoadIncrement.targetFraction(ExerciseType.compoundLower), 0.05);
      expect(LoadIncrement.targetFraction(ExerciseType.compoundUpper), 0.025);
      expect(LoadIncrement.targetFraction(null), 0.025);
      expect(LoadIncrement.targetFraction(ExerciseType.core), 0.05);
      expect(LoadIncrement.defaultReserve(ExerciseType.compoundLower), 1);
      expect(LoadIncrement.defaultReserve(ExerciseType.isolationLower), isNull);
      expect(LoadIncrement.defaultReserve(null), isNull);
    });

    test('the load for a one-rep max is Epley turned round', () {
      expect(loadForOneRepMax(100, 1, 0), 100);
      expect(loadForOneRepMax(100, 0, -1), 100);
      expect(loadForOneRepMax(130, 8, 1), closeTo(100, 1e-9));
    });
  });

  group('deload', () {
    double halfKilo(double kg) => (kg * 2).roundToDouble() / 2;
    WorkoutExercise bench(List<WorkoutSet> sets) =>
        WorkoutExercise(id: 'e', sets: sets);
    WorkoutSet working(int index, double? kg, {bool warmup = false}) =>
        WorkoutSet(
          id: 's$index',
          index: index,
          reps: 8,
          weightKg: kg,
          isWarmup: warmup,
        );

    test('a deload halves the sets at ninety per cent', () {
      final session = MesocycleDeload.apply(
        WorkoutSession(
          exercises: [
            bench([
              working(1, 100),
              working(2, 80),
              working(3, 80),
              working(4, 80),
            ]),
          ],
        ),
        (_) => halfKilo,
      );
      expect(session.isDeload, isTrue);
      final sets = session.exercises.single.sets;
      expect([for (final s in sets) s.weightKg], [90, 72]);
      expect([for (final s in sets) s.index], [1, 2]);
      expect([for (final s in sets) s.reps], [8, 8]);
    });

    test('warm-ups stay and an odd count rounds up', () {
      final sets = MesocycleDeload.apply(
        WorkoutSession(
          exercises: [
            bench([
              working(1, 40, warmup: true),
              working(2, 100),
              working(3, 100),
              working(4, 100),
            ]),
          ],
        ),
        (_) => halfKilo,
      ).exercises.single.sets;
      expect([for (final s in sets) s.isWarmup], [true, false, false]);
      expect([for (final s in sets) s.weightKg], [36, 90, 90]);
      expect(MesocycleDeload.setCount(1), 1);
      expect(MesocycleDeload.setCount(5), 3);
      expect(MesocycleDeload.setCount(0), 0);
    });

    test('no weight and zero stay as they are', () {
      final sets = MesocycleDeload.apply(
        WorkoutSession(
          exercises: [
            bench([working(1, null), working(2, 0)]),
          ],
        ),
        (_) => halfKilo,
      ).exercises.single.sets;
      expect([for (final s in sets) s.weightKg], [null]);
      expect(MesocycleDeload.keptSets([working(1, 0)]).single.weightKg, 0);
    });

    test('a deload is always lighter', () {
      double fives(double kg) => (kg / 5).roundToDouble() * 5;
      expect(MesocycleDeload.lighterWeight(15, fives), 10);
      expect(
        MesocycleDeload.lighterWeight(5, (kg) {
          final r = fives(kg);
          return r < 5 ? 5 : r;
        }),
        5,
      );
      expect(MesocycleDeload.lighterWeight(-30, halfKilo), -33);
    });

    test('a pair and its pieces go together', () {
      final kept = MesocycleDeload.keptSets([
        const WorkoutSet(id: 'l1', side: SetSide.left),
        const WorkoutSet(id: 'r1', side: SetSide.right),
        const WorkoutSet(id: 'd1', parentSetId: 'l1'),
        const WorkoutSet(id: 'l2', side: SetSide.left),
        const WorkoutSet(id: 'r2', side: SetSide.right),
      ]);
      expect([for (final s in kept) s.id], ['l1', 'r1', 'd1']);
    });
  });

  group('planner', () {
    WorkoutExercise logged(
      String id,
      String templateId,
      int index,
      double kg,
    ) => WorkoutExercise(
      id: id,
      templateId: templateId,
      index: index,
      sets: [
        WorkoutSet(id: '$id-1', reps: 8, weightKg: kg, completedAt: start),
      ],
    );
    final sessions = [
      WorkoutSession(
        exercises: [
          logged('n-heavy', 'bench', 1, 100),
          logged('n-row', 'row', 2, 50),
          logged('n-backoff', 'bench', 3, 60),
        ],
      ),
      WorkoutSession(exercises: [logged('o-heavy', 'bench', 1, 97.5)]),
    ];
    List<List<double?>> weights(List<List<WorkoutSet>> history) => [
      for (final session in history) [for (final s in session) s.weightKg],
    ];

    test('the first occurrence reads every session', () {
      expect(weights(ProgressionPlanner.historyFor('bench', sessions)), [
        [100],
        [97.5],
      ]);
    });

    test('the second occurrence reads only the second appearances', () {
      expect(
        weights(
          ProgressionPlanner.historyFor('bench', sessions, occurrence: 1),
        ),
        [
          [60],
        ],
      );
    });

    test('history is at most three deep and skips sessions with nothing', () {
      final many = [
        for (var i = 0; i < 5; i++)
          WorkoutSession(exercises: [logged('e$i', 'bench', 1, 100.0 + i)]),
      ];
      expect(ProgressionPlanner.historyFor('bench', many), hasLength(3));
      const unlogged = WorkoutSession(
        exercises: [
          WorkoutExercise(
            id: 'x',
            templateId: 'bench',
            sets: [
              WorkoutSet(id: 'open', reps: 8),
              WorkoutSet(id: 'warm', isWarmup: true),
            ],
          ),
        ],
      );
      expect(ProgressionPlanner.historyFor('bench', [unlogged]), isEmpty);
    });

    test('a pair is read once, by its left', () {
      final session = WorkoutSession(
        exercises: [
          WorkoutExercise(
            id: 'x',
            templateId: 'curl',
            sets: [
              WorkoutSet(id: 'l', side: SetSide.left, completedAt: start),
              WorkoutSet(id: 'r', side: SetSide.right, completedAt: start),
            ],
          ),
        ],
      );
      expect(
        [
          for (final s in ProgressionPlanner.historyFor('curl', [
            session,
          ]).single)
            s.id,
        ],
        ['l'],
      );
    });

    test('history skips deloads and other loads', () {
      const bar = [EquipmentRef(EquipmentKind.loadableBar, 'barbell')];
      const dumbbells = [EquipmentRef(EquipmentKind.freeWeight, 'dumbbells')];
      WorkoutSession squat(
        List<EquipmentRef> refs,
        double kg, {
        bool? deload,
      }) => WorkoutSession(
        isDeload: deload,
        exercises: [
          WorkoutExercise(
            id: 'e',
            templateId: 'squat',
            resistanceEquipment: refs,
            sets: [
              WorkoutSet(id: 's', reps: 8, weightKg: kg, completedAt: start),
            ],
          ),
        ],
      );
      final history = ProgressionPlanner.historyFor('squat', [
        squat(bar, 90, deload: true),
        squat(dumbbells, 30),
        squat(bar, 100, deload: false),
      ], loadedWith: bar);
      expect(weights(history), [
        [100],
      ]);
    });

    test('a context carries its occurrence into its key', () {
      final rounding = ProgressionRounding(
        round: (kg) => kg,
        minimumIncrementKg: 2.5,
      );
      ProgressionContext context(int occurrence) => ProgressionContext(
        templateId: 'bench',
        trackingMode: TrackingMode.weightReps,
        setTargets: const [],
        rounding: rounding,
        occurrence: occurrence,
      );
      expect(context(0).historyKey, 'bench#0');
      expect(context(1).historyKey, 'bench#1');
      expect(
        ProgressionPlanner.suggestions(
          contexts: [context(0)],
          history: const [],
          adjustmentMode: ProgressionAdjustmentMode.weightFirst,
        )['bench#0']?.rationale,
        Rationale.noHistory,
      );
    });
  });

  group('suggestions on rows', () {
    WorkoutExercise exercise(List<WorkoutSet> sets) =>
        WorkoutExercise(id: 'e', sets: sets);
    const three = ProgressionSuggestion(Rationale.progressWeight, [
      SuggestedSet(weightKg: 60, reps: 8),
      SuggestedSet(weightKg: 62.5, reps: 8),
      SuggestedSet(weightKg: 65, reps: 6),
    ]);

    test('each working set reads its own suggestion, in order', () {
      final sets = [
        for (var i = 1; i <= 3; i++) WorkoutSet(id: 's$i', index: i),
      ];
      final model = exercise(sets);
      expect(
        [for (final s in sets) three.suggestedSetFor(s, model)?.weightKg],
        [60, 62.5, 65],
      );
    });

    test('a left and a right share the one suggestion', () {
      final sets = [
        const WorkoutSet(id: 's1L', side: SetSide.left),
        const WorkoutSet(id: 's1R', side: SetSide.right),
        const WorkoutSet(id: 's2L', side: SetSide.left),
        const WorkoutSet(id: 's2R', side: SetSide.right),
      ];
      final model = exercise(sets);
      expect(
        [for (final s in sets) three.suggestedSetFor(s, model)?.weightKg],
        [60, 60, 62.5, 62.5],
      );
    });

    test('a warm-up, a set past the end, or nothing to say has none', () {
      const warmup = WorkoutSet(id: 'w1', isWarmup: true);
      const working = WorkoutSet(id: 's1', index: 2);
      final model = exercise([warmup, working]);
      const one = ProgressionSuggestion(Rationale.hold, [
        SuggestedSet(weightKg: 60, reps: 8),
      ]);
      expect(one.suggestedSetFor(warmup, model), isNull);
      expect(one.suggestedSetFor(working, model)?.weightKg, 60);
      final past = exercise([
        const WorkoutSet(id: 'a'),
        const WorkoutSet(id: 'b'),
      ]);
      expect(one.suggestedSetFor(past.sets[1], past), isNull);
      final none = ProgressionSuggestion.noHistory(2);
      expect(none.suggestedSetFor(past.sets[0], past), isNull);
      expect(one.setAt(-1), isNull);
    });
  });

  group('prefill', () {
    const suggestion = ProgressionSuggestion(Rationale.progressWeight, [
      SuggestedSet(weightKg: 101, reps: 6),
      SuggestedSet(reps: 7, targetReps: 9),
    ]);
    final previous = [
      WorkoutSet(id: 'w', isWarmup: true, weightKg: 40, completedAt: start),
      WorkoutSet(
        id: 'p1',
        weightKg: 95,
        reps: 8,
        durationSec: 40,
        distanceMeters: 300,
        bands: const ['Red'],
        completedAt: start,
      ),
      WorkoutSet(
        id: 'p1d',
        parentSetId: 'p1',
        weightKg: 70,
        completedAt: start,
      ),
      WorkoutSet(
        id: 'p2L',
        side: SetSide.left,
        weightKg: 90,
        reps: 9,
        completedAt: start,
      ),
      WorkoutSet(
        id: 'p2R',
        side: SetSide.right,
        weightKg: 85,
        reps: 9,
        completedAt: start,
      ),
    ];
    const built = [
      WorkoutSet(id: 's1', weightKg: 1, reps: 1, isWarmup: true),
      WorkoutSet(id: 's1d', parentSetId: 's1', weightKg: 50),
      WorkoutSet(id: 's2', targetReps: 3),
      WorkoutSet(id: 's3', weightKg: 20, reps: 5),
    ];

    List<WorkoutSet> prefill(
      SessionPrefill prefill, {
      List<WorkoutSet>? last,
    }) => prefillWorkingSets(
      built,
      prefill: prefill,
      templateId: 't',
      previousSets: last,
      round: roundToHalfKg,
    );

    test('empty leaves every working set as built', () {
      expect(prefill(const PrefillEmpty(), last: previous), built);
    });

    test('previous values fill from last time, a pair read by its left', () {
      final sets = prefill(const PrefillPreviousValues(), last: previous);
      expect(sets[0].weightKg, 95);
      expect(sets[0].bands, ['Red']);
      expect(sets[0].durationSec, 40);
      expect(sets[0].distanceMeters, 300);
      expect(sets[0].isWarmup, isFalse);
      expect(sets[1], built[1]);
      expect(sets[2].weightKg, 90);
      expect(sets[2].targetReps, 3);
      expect(sets[3], built[3]);
    });

    test('suggestions win field by field, and are rounded', () {
      final sets = prefill(
        const PrefillSuggestions({'t#0': suggestion}),
        last: previous,
      );
      expect(sets[0].weightKg, 101);
      expect(sets[0].reps, 6);
      expect(sets[2].weightKg, 90);
      expect(sets[2].reps, 7);
      expect(sets[2].targetReps, 9);
      expect(sets[3], built[3]);
      final noLast = prefill(const PrefillSuggestions({'t#0': suggestion}));
      expect(noLast[0].weightKg, 101);
      expect(noLast[0].bands, isNull);
    });

    test('a missing or noHistory suggestion falls back to last time', () {
      for (final option in [
        const PrefillSuggestions({}),
        PrefillSuggestions({'t#0': ProgressionSuggestion.noHistory(3)}),
      ]) {
        expect(prefill(option, last: previous)[0].weightKg, 95);
      }
      expect(const PrefillEmpty().suggestionFor('t'), isNull);
    });

    test('a row with no weight anywhere stays without one', () {
      final sets = prefillWorkingSets(
        const [WorkoutSet(id: 'a')],
        prefill: const PrefillSuggestions({
          't#0': ProgressionSuggestion(Rationale.addReps, [
            SuggestedSet(reps: 9),
          ]),
        }),
        templateId: 't',
        previousSets: null,
        round: roundToHalfKg,
      );
      expect(sets.single.weightKg, isNull);
      expect(sets.single.reps, 9);
    });
  });
}
