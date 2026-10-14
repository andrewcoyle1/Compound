// The rules the Swift suites check (ExerciseOneRMAggregatorTests,
// MuscleBalanceTests, FormulaExpenditureTests, WeightTrendCalculatorTests,
// ExpenditureEngineTests), as functions/coach-maths.test.js ports them, plus
// the edges the fixture does not reach. Expected values are worked by hand from
// the Swift.
import 'dart:math' as math;

import 'package:compound_maths/compound_maths.dart';
import 'package:test/test.dart';

const day0 = '2026-03-01';
String dayAt(int i) => addDays(day0, i);

/// A small deterministic generator (the JavaScript test's), so the noisy cases
/// are the same every run.
double Function() gaussians(int seed) {
  var state = seed;
  double uniform() {
    state = (state * 16807) % 2147483647;
    return state / 2147483647;
  }

  return () =>
      math.sqrt(-2 * math.log(uniform())) * math.cos(2 * math.pi * uniform());
}

List<DailySample> samplesFor(
  int n,
  double? Function(int) intake,
  double? Function(int) weight,
) => [
  for (var i = 0; i < n; i++)
    DailySample(day: dayAt(i), intakeKcal: intake(i), weightKg: weight(i)),
];

List<ExpenditureEstimate> historyFor(
  List<DailySample> samples, {
  double prior = 2500,
  ExpenditureSettings settings = const ExpenditureSettings(),
}) => expenditureHistory(
  samples: samples,
  priorKcal: prior,
  today: dayAt(samples.length),
  settings: settings,
);

WorkoutSet done({
  String? id,
  double? rpe,
  SetSide? side,
  SetKind kind = SetKind.standard,
  String? parentSetId,
  bool isWarmup = false,
  bool completed = true,
}) => WorkoutSet(
  id: id,
  rpe: rpe,
  side: side,
  kind: kind,
  parentSetId: parentSetId,
  isWarmup: isWarmup,
  completed: completed,
);

double hard(List<WorkoutSet> sets) =>
    hardSets(WorkoutExercise(templateId: 't', name: 'T', sets: sets));

void main() {
  group('day keys', () {
    test('add and count days across months and years', () {
      expect(addDays('2026-02-28', 1), '2026-03-01');
      expect(addDays('2026-01-01', -1), '2025-12-31');
      expect(daysBetween('2026-03-30', '2026-04-02'), 3);
      expect(daysBetween('2026-04-02', '2026-03-30'), -3);
    });
  });

  group('estimated 1RM', () {
    test('a single is the weight, RIR counts, nothing past ten to failure', () {
      expect(estimatedOneRepMax(100, 1), 100);
      expect(estimatedOneRepMax(100, 1, rpe: 10), 100);
      expect(estimatedOneRepMax(100, 6), closeTo(120, 1e-9));
      // 8 reps at RPE 8 is 10 reps to failure.
      expect(
        estimatedOneRepMax(100, 8, rpe: 8),
        closeTo(100 * (1 + 10 / 30), 1e-9),
      );
      expect(estimatedOneRepMax(100, 10), 100 * (1 + 10 / 30));
      expect(estimatedOneRepMax(100, 11), isNull);
      expect(estimatedOneRepMax(100, 9, rpe: 8), isNull);
      expect(estimatedOneRepMax(0, 5), isNull);
      expect(estimatedOneRepMax(100, 0), isNull);
    });

    test('an RPE above 10 earns no negative reserve', () {
      expect(repsToFailure(5, 11), 5);
    });

    test('a set without weight or reps has none', () {
      expect(setEstimatedOneRepMax(const WorkoutSet(reps: 5)), isNull);
      expect(setEstimatedOneRepMax(const WorkoutSet(weightKg: 100)), isNull);
      expect(
        setEstimatedOneRepMax(const WorkoutSet(weightKg: 100, reps: 6)),
        closeTo(120, 1e-9),
      );
    });
  });

  group('sets', () {
    test('finished working sets count a pair once and skip sub-sets', () {
      final exercise = WorkoutExercise(
        templateId: 't',
        name: 'T',
        sets: [
          done(isWarmup: true),
          done(side: SetSide.left),
          done(side: SetSide.right),
          done(id: 'p'),
          done(parentSetId: 'p'),
          done(completed: false),
        ],
      );
      expect(completedWorkingSets(exercise), 2);
    });
  });

  group('hard sets', () {
    test('easy sets drop out, sets without RPE count', () {
      expect(
        hard([
          done(rpe: 8),
          done(rpe: 5.5),
          done(),
          done(isWarmup: true),
          done(completed: false),
        ]),
        2,
      );
      expect(hard([done(rpe: 6)]), 1);
      expect(isHardSet(done(isWarmup: true)), isFalse);
    });

    test('drops and mini-sets add half, up to two', () {
      // A drop set with two drops: 1 + 0.5 + 0.5.
      expect(
        hard([
          done(id: 'a', kind: SetKind.drop),
          done(id: 'b', kind: SetKind.drop, parentSetId: 'a'),
          done(id: 'c', kind: SetKind.drop, parentSetId: 'a'),
        ]),
        2,
      );
      // Capped at two however many mini-sets.
      expect(
        hard([
          done(id: 'm', kind: SetKind.myo),
          for (var i = 1; i <= 4; i++) done(id: 'm$i', parentSetId: 'm'),
        ]),
        2,
      );
      expect(
        hard([
          done(id: 'r', kind: SetKind.restPause),
          done(id: 'r1', parentSetId: 'r'),
        ]),
        1.5,
      );
      // A cluster's pieces are one set split up.
      expect(
        hard([
          done(id: 'k', kind: SetKind.cluster),
          done(id: 'k1', parentSetId: 'k'),
        ]),
        1,
      );
    });

    test('a left/right pair is one set, worth its better half', () {
      expect(
        hard([
          done(id: 'l', side: SetSide.left),
          done(id: 'r', side: SetSide.right),
        ]),
        1,
      );
      expect(
        hard([
          done(id: 'l', side: SetSide.left, kind: SetKind.drop),
          done(id: 'r', side: SetSide.right, kind: SetKind.drop),
          done(
            id: 'ld',
            side: SetSide.left,
            kind: SetKind.drop,
            parentSetId: 'l',
          ),
        ]),
        1.5,
      );
      // An easy left half leaves the right half to count.
      expect(
        hard([
          done(id: 'l', side: SetSide.left, rpe: 4),
          done(id: 'r', side: SetSide.right, rpe: 7),
        ]),
        1,
      );
    });
  });

  group('weekly muscle sets', () {
    test('skip future and old sessions, unknown templates and easy work', () {
      final bench = WorkoutExercise(
        templateId: 'bench',
        name: 'Bench',
        sets: [done(), done()],
      );
      final easy = WorkoutExercise(
        templateId: 'bench',
        name: 'Bench',
        sets: [done(rpe: 4)],
      );
      final unknown = WorkoutExercise(
        templateId: 'other',
        name: 'Other',
        sets: [done()],
      );
      WorkoutSession on(String day, List<WorkoutExercise> exercises) =>
          WorkoutSession(
            day: day,
            at: DateTime.utc(2026),
            exercises: exercises,
          );
      final weekly = weeklyMuscleSets(
        [
          on('2026-03-29', [bench]),
          on('2026-03-14', [bench]),
          on('2026-03-28', [bench, easy, unknown]),
          on('2026-03-22', [bench]),
        ],
        {
          'bench': {
            Muscle.chest: MuscleTarget.primary,
            Muscle.triceps: MuscleTarget.secondary,
          },
        },
        '2026-03-28',
        weeks: 2,
      );
      expect(weekly[Muscle.chest], [0, 4]);
      expect(weekly[Muscle.triceps], [0, 2]);
      expect(weekly[Muscle.quads], [0, 0]);
      expect(weekly.length, Muscle.values.length);
    });
  });

  group('formula expenditure', () {
    const man = (weightKg: 80.0, heightCm: 180.0, ageYears: 36);
    // Mifflin: 800 + 1125 − 180 + 5 = 1750.

    test('one PAL per activity answer, no frequency add-on', () {
      for (final level in ActivityLevel.values) {
        expect(
          estimateTdee(
            gender: Gender.male,
            weightKg: man.weightKg,
            heightCm: man.heightCm,
            ageYears: man.ageYears,
            activity: level,
          ),
          closeTo(1750 * level.multiplier, 1e-9),
        );
      }
      expect(ActivityLevel.values.map((a) => a.multiplier), [
        1.4,
        1.55,
        1.7,
        1.85,
        2.0,
      ]);
    });

    test('Cunningham with body fat, the midpoint for a missing sex', () {
      // 80 kg at 20% body fat is 64 kg fat-free: 500 + 22 × 64 = 1908.
      expect(
        estimateTdee(
          gender: Gender.male,
          weightKg: 80,
          heightCm: 180,
          ageYears: 36,
          equation: BmrEquation.cunningham,
          bodyFatPercentage: 20,
        ),
        closeTo(1908 * 1.7, 1e-9),
      );
      expect(
        estimateTdee(weightKg: 80, heightCm: 180, ageYears: 36),
        closeTo((1750 - 83) * 1.7, 1e-9),
      );
    });

    test('a non-finite weight or height reads as the default', () {
      expect(
        estimateTdee(weightKg: double.nan, heightCm: double.infinity),
        estimateTdee(),
      );
    });

    test('raw values parse, unknown ones do not', () {
      expect(Gender.tryParse('prefer_not_to_say'), Gender.preferNotToSay);
      expect(ActivityLevel.tryParse('very_active'), ActivityLevel.veryActive);
      expect(ActivityLevel.tryParse('veryActive'), isNull);
      expect(BmrEquation.tryParse('katchMcArdle'), BmrEquation.cunningham);
      expect(BmrEquation.tryParse(null), isNull);
    });

    test('body-fat aware runs Cunningham only with a usable percentage', () {
      const harris = BmrEquation.harrisBenedict;
      expect(
        resolvedBmrEquation(
          equation: harris,
          method: ExpenditureEstimationMethod.standard,
          bodyFatPercentage: 20,
        ),
        harris,
      );
      expect(
        resolvedBmrEquation(
          equation: harris,
          method: ExpenditureEstimationMethod.bodyFatAware,
        ),
        harris,
      );
      expect(
        resolvedBmrEquation(
          equation: harris,
          method: ExpenditureEstimationMethod.bodyFatAware,
          bodyFatPercentage: 100,
        ),
        harris,
      );
      expect(
        resolvedBmrEquation(
          equation: harris,
          method: ExpenditureEstimationMethod.bodyFatAware,
          bodyFatPercentage: 20,
        ),
        BmrEquation.cunningham,
      );
    });
  });

  group('energy density', () {
    test('Forbes-partitioned with body fat, 7,700 without', () {
      expect(energyDensityKcalPerKg(80, null), 7700);
      expect(energyDensityKcalPerKg(null, 20), 7700);
      expect(energyDensityKcalPerKg(double.nan, 20), 7700);
      expect(energyDensityKcalPerKg(80, 100), 7700);
      expect(energyDensityKcalPerKg(-80, 20), 7700);
      const share = 25 / (25 + 10.4);
      expect(
        energyDensityKcalPerKg(100, 25),
        closeTo(share * 9440 + (1 - share) * 1816, 1e-9),
      );
    });
  });

  group('weight trend', () {
    test('flat stays flat, an outlier is ignored, a shift is confirmed', () {
      expect(weightTrend([]), isEmpty);
      expect(weightTrend([72.4]), [72.4]);
      for (final v in weightTrend(List.filled(10, 72))) {
        expect(v, closeTo(72, 1e-9));
      }
      // A 90 among 72s is more than max(3 kg, 4%) off and nothing confirms it.
      for (final v in weightTrend([72, 72, 72, 90, 72, 72])) {
        expect(v, closeTo(72, 1e-9));
      }
      // A smaller spike is down-weighted, not clamped.
      final spiked = weightTrend([80, 80, 80, 80, 82.5, 80, 80, 80]);
      expect(spiked[4] - 80, inExclusiveRange(0, 0.5));
      // Two readings off the same way confirm a real shift.
      expect(weightTrend([80, 80, 80, 84, 84.1, 84])[5], greaterThan(83.5));
    });

    test('the real gap in days counts, the first weigh-in of a day', () {
      final daily = weightTrend([80, 79.5, 79, 78.5, 78]);
      final weekly = weightTrend(
        [80, 79.5, 79, 78.5, 78],
        days: [
          for (final i in [0, 7, 14, 21, 28]) dayAt(i),
        ],
      );
      expect(
        (weekly[4] - 78).abs(),
        lessThanOrEqualTo((daily[4] - 78).abs() + 1e-9),
      );
      final sameDay = weightTrend(
        [80, 85, 80, 80],
        days: [day0, day0, dayAt(1), dayAt(2)],
      );
      expect(sameDay[3], closeTo(80, 1e-9));
    });

    test('the seed is the median of the first weigh-ins', () {
      expect(median([3, 1, 2]), 2);
      expect(median([4, 1]), 2.5);
      expect(median([]), isNull);
      expect(weightTrend([80, 81]).first, closeTo(80.5, 0.5));
    });
  });

  group('expenditure filter', () {
    test('a second gross weigh-in the same way is used', () {
      final filter = ExpenditureFilter(80, 2500);
      expect(filter.observeWeighIn(90), isFalse);
      expect(filter.heldInnovation, 10);
      expect(filter.observeWeighIn(90), isTrue);
      expect(filter.heldInnovation, isNull);
      expect(filter.levelKg, greaterThan(85));
    });

    test('a gross weigh-in the other way is held again', () {
      final filter = ExpenditureFilter(80, 2500);
      expect(filter.observeWeighIn(90), isFalse);
      expect(filter.observeWeighIn(70), isFalse);
      expect(filter.heldInnovation, -10);
    });

    test('an observation with no finite variance is ignored', () {
      final filter = ExpenditureFilter(80, 2500)
        ..observeIntake(1800, double.infinity);
      expect(filter.intakeKcal, 2500);
    });
  });

  group('expenditure samples', () {
    test('the earlier weigh-in of a day wins; deleted and bad ones drop', () {
      final samples = expenditureSamples(
        today: '2026-04-03',
        measurements: [
          WeighIn(
            day: '2026-04-01',
            weightKg: 81,
            at: DateTime.utc(2026, 4, 1, 9),
          ),
          WeighIn(
            day: '2026-04-01',
            weightKg: 80,
            at: DateTime.utc(2026, 4, 1, 7),
          ),
          WeighIn(
            day: '2026-04-01',
            weightKg: 79,
            at: DateTime.utc(2026, 4, 1, 8),
          ),
          const WeighIn(day: '2026-04-02', weightKg: 70, deleted: true),
          const WeighIn(day: '2026-04-02', weightKg: double.nan),
          const WeighIn(day: '2026-04-02'),
          const WeighIn(day: '2026-04-02', weightKg: 0),
        ],
        steps: [
          const StepRecord(day: '2026-04-02', number: 900),
          const StepRecord(day: '2026-04-02', number: 400),
        ],
      );
      expect(samples.map((s) => s.weightKg), [80, null]);
      expect(samples.map((s) => s.steps), [null, 900]);
    });

    test('nothing before today is no samples', () {
      expect(
        expenditureSamples(
          today: '2026-04-01',
          meals: [(dayKey: '2026-04-01', calories: 500)],
        ),
        isEmpty,
      );
    });
  });

  group('expenditure engine', () {
    test('converges on the true expenditure through noise', () {
      final noise = gaussians(7);
      // True expenditure 2,700: eating 2,200 ± 400, losing 500/7700 kg a day.
      final samples = samplesFor(
        90,
        (_) => 2200 + 400 * noise(),
        (i) => 85 - (500 / 7700) * i + 0.005 * 85 * noise(),
      );
      final last = historyFor(samples, prior: 2300).last;
      expect(last.source, ExpenditureSource.adaptive);
      expect((last.kcal - 2700).abs(), lessThan(1.28 * last.sdKcal! + 50));
      expect(last.sdKcal, lessThan(150));
      expect(
        (last.weeklyTrendChangeKg! + 500 * 7 / 7700).abs(),
        lessThan(0.15),
      );
    });

    test('calibrating until 21 days and 14 weigh-ins, then adaptive', () {
      final history = historyFor(samplesFor(40, (_) => 2400, (_) => 80));
      for (final e in history.take(21)) {
        expect(e.isProvisional, isTrue);
        expect(e.source, ExpenditureSource.prior);
        expect(e.kcal, 2500);
      }
      expect(history[21].source, ExpenditureSource.adaptive);
      expect((history.last.kcal - 2400).abs(), lessThan(15));
      // Weigh-ins alone never calibrate: only the slope is known.
      final weightsOnly = historyFor(
        samplesFor(60, (_) => null, (i) => 80 - 0.05 * i),
      );
      expect(weightsOnly.every((e) => e.isProvisional), isTrue);
      expect(weightsOnly.last.weeklyTrendChangeKg, lessThan(-0.2));
    });

    test('unlogged days only widen the uncertainty', () {
      final logged = historyFor(samplesFor(40, (_) => 2400, (_) => 80));
      final unlogged = historyFor(
        samplesFor(40, (i) => i >= 33 ? null : 2400, (_) => 80),
      );
      expect(unlogged.last.sdKcal, greaterThan(logged.last.sdKcal!));
      final silent = historyFor(
        samplesFor(
          40,
          (i) => i >= 33 ? null : 2400,
          (i) => i >= 33 ? null : 80,
        ),
      );
      for (var i = 35; i <= 40; i++) {
        expect(silent[i].sdKcal, greaterThan(silent[i - 1].sdKcal!));
      }
      expect(
        (silent.last.trendWeightKg! - silent[33].trendWeightKg!).abs(),
        lessThan(0.05),
      );
    });

    test('a partial day is skipped unless it was a fast', () {
      final base = samplesFor(40, (_) => 2400, (_) => 80);
      DailySample with35(DailySample s, {required bool fast}) => DailySample(
        day: s.day,
        intakeKcal: 300,
        weightKg: s.weightKg,
        isFastingDay: fast,
      );
      List<DailySample> withDay35({required bool fast}) => [
        for (final (i, s) in base.indexed)
          if (i == 35) with35(s, fast: fast) else s,
      ];
      final partial = withDay35(fast: false);
      final fasted = withDay35(fast: true);
      expect(historyFor(partial).last.kcal, historyFor(base).last.kcal);
      expect(
        historyFor(fasted).last.kcal,
        lessThan(historyFor(base).last.kcal),
      );
    });

    test('food logs without a single weigh-in stay on the prior', () {
      final history = historyFor(samplesFor(30, (_) => 2400, (_) => null));
      expect(history, hasLength(31));
      for (final e in history) {
        expect(e.source, ExpenditureSource.prior);
        expect(e.trendWeightKg, isNull);
        expect(e.sdKcal, isNull);
      }
      expect(history.last.loggedDays, 28);
    });

    test('fixed mode holds the prior and still tracks the trend', () {
      final history = historyFor(
        samplesFor(40, (_) => 2400, (_) => 80),
        settings: const ExpenditureSettings(
          calculationMode: ExpenditureCalculationMode.fixed,
        ),
      );
      for (final e in history) {
        expect(e.kcal, 2500);
        expect(e.source, ExpenditureSource.fixed);
        expect(e.isProvisional, isFalse);
        expect(e.sdKcal, isNull);
      }
      expect((history.last.trendWeightKg! - 80).abs(), lessThan(0.05));
    });

    test('fixed mode with nothing logged is the fixed prior for today', () {
      final history = expenditureHistory(
        samples: [],
        priorKcal: 2400.5,
        today: day0,
        settings: const ExpenditureSettings(
          calculationMode: ExpenditureCalculationMode.fixed,
        ),
      );
      expect(history.single.source, ExpenditureSource.fixed);
      expect(history.single.isProvisional, isFalse);
      expect(history.single.kcal, 2401);
    });

    test('with no prior the filter is shown unbounded', () {
      // The prior is 0: every logged day counts, and the figure is the filter's
      // own expenditure, not clamped to 60–160% of nothing.
      final last = historyFor(
        samplesFor(40, (_) => 2400, (_) => 80),
        prior: 0,
      ).last;
      expect(last.source, ExpenditureSource.adaptive);
      expect(last.kcal, greaterThan(1000));
    });

    test('a non-finite prior or energy density falls back', () {
      final samples = samplesFor(30, (_) => 2400, (_) => 80);
      final history = expenditureHistory(
        samples: samples,
        priorKcal: double.nan,
        today: dayAt(30),
        kcalPerKg: double.infinity,
      );
      expect(history.first.kcal, 0);
      expect(
        history.last.trendWeightKg,
        expenditureHistory(
          samples: samples,
          priorKcal: 0,
          today: dayAt(30),
        ).last.trendWeightKg,
      );
    });

    test('the step nowcast moves the figure by recent steps', () {
      // More steps in the last week than across the window: a positive nowcast.
      final samples = [
        for (var i = 0; i < 40; i++)
          DailySample(
            day: dayAt(i),
            intakeKcal: 2400,
            weightKg: 80,
            steps: i >= 33 ? 12000 : 6000,
          ),
      ];
      final history = historyFor(
        samples,
        settings: const ExpenditureSettings(stepInformedUpdates: true),
      );
      final last = history.last;
      expect(last.source, ExpenditureSource.adaptive);
      // Window: 28 days, 7 at 12,000 and 21 at 6,000, mean 7,500; the last
      // week's mean 12,000: 4,500 × 0.0004 × 80 ≈ 144 kcal.
      expect(last.stepAdjustmentKcal, closeTo(4500 * 0.0004 * 80, 1));
      // Too few step days: none.
      final sparse = [
        for (final (i, s) in samples.indexed)
          DailySample(
            day: s.day,
            intakeKcal: s.intakeKcal,
            weightKg: s.weightKg,
            steps: i.isEven && i < 20 ? 6000 : null,
          ),
      ];
      expect(
        historyFor(
          sparse,
          settings: const ExpenditureSettings(stepInformedUpdates: true),
        ).last.stepAdjustmentKcal,
        0,
      );
    });
  });
}
