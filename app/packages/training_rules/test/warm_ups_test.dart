// Ports WarmupSetGenerationTests.
import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

var _next = 0;

List<WorkoutSet> warmups({
  required double? weight,
  int? reps = 8,
  TrackingMode mode = TrackingMode.weightReps,
  List<SetTarget> targets = const [],
  ExerciseType? type,
  double Function(double)? round,
  int? count,
}) => WarmUps.generate(
  trackingMode: mode,
  workingWeightKg: weight,
  workingReps: reps,
  setTargets: targets,
  newId: () => 'w${_next++}',
  exerciseType: type,
  round: round,
  count: count,
);

List<double?> weights(List<WorkoutSet> sets) => [
  for (final s in sets) s.weightKg,
];

void main() {
  test('heavy low-rep work gets three, moderate two, light one', () {
    expect(warmups(weight: 100, reps: 5), hasLength(3));
    expect(warmups(weight: 100, reps: 6), hasLength(3));
    expect(warmups(weight: 100, reps: 7), hasLength(2));
    expect(warmups(weight: 100, reps: 12), hasLength(2));
    expect(warmups(weight: 100, reps: 15), hasLength(1));
    expect(warmups(weight: 40, reps: 5), hasLength(3));
    expect(warmups(weight: 200, reps: 15), hasLength(1));
  });

  test('isolation and core work get one', () {
    for (final type in [ExerciseType.isolationUpper, ExerciseType.core]) {
      expect(warmups(weight: 30, reps: 5, type: type), hasLength(1));
    }
    expect(
      warmups(weight: 30, reps: 5, type: ExerciseType.compoundLower),
      hasLength(3),
    );
  });

  test('unknown reps get two', () {
    expect(warmups(weight: 100, reps: null), hasLength(2));
    expect(warmups(weight: null, reps: null), hasLength(2));
    expect(warmups(weight: 100, reps: 0), hasLength(2));
    expect(
      warmups(weight: 100, reps: null, targets: const [SetTarget(maxReps: 5)]),
      hasLength(3),
    );
  });

  test('warm-ups ramp up to the working weight', () {
    expect(weights(warmups(weight: 100, reps: 5)), [45, 65, 82]);
    expect(weights(warmups(weight: 60)), [30, 45]);
    expect(weights(warmups(weight: 40, reps: 15)), [24]);
  });

  test('every warm-up is lighter than the working set, heavier in order', () {
    for (final working in [30.0, 60.0, 100.0, 180.0]) {
      for (final reps in [3, 8, 15]) {
        for (final set in warmups(weight: working, reps: reps)) {
          expect(set.weightKg, lessThan(working));
          expect(set.weightKg, greaterThan(0));
        }
      }
    }
    final ascending = weights(warmups(weight: 120, reps: 5));
    expect(ascending, [...ascending]..sort());
  });

  test('an unknown working weight leaves the warm-ups blank', () {
    expect(weights(warmups(weight: null)).every((w) => w == null), isTrue);
  });

  test('warm-up reps taper as the load rises, whatever the working reps', () {
    List<int?> reps(List<WorkoutSet> sets) => [for (final s in sets) s.reps];
    expect(reps(warmups(weight: 100, reps: 5)), [8, 5, 3]);
    expect(reps(warmups(weight: 100, reps: 10)), [8, 3]);
    expect(reps(warmups(weight: 100, reps: 3)), [8, 5, 3]);
    expect(reps(warmups(weight: 100, reps: null)), [8, 3]);
    expect(WarmUps.reps(0.9), 2);
  });

  test('bodyweight warm-ups take the working reps', () {
    expect(
      warmups(
        weight: null,
        reps: 10,
        mode: TrackingMode.repsOnly,
        count: 2,
      ).every((s) => s.reps == 10),
      isTrue,
    );
    expect(
      warmups(
        weight: null,
        reps: null,
        mode: TrackingMode.repsOnly,
        targets: const [SetTarget(minReps: 6, maxReps: 10)],
        count: 1,
      ).single.reps,
      6,
    );
  });

  test('warm-ups are marked, numbered from one, open and distinct', () {
    final sets = warmups(weight: 100, reps: 5);
    expect(sets.every((s) => s.isWarmup), isTrue);
    expect([for (final s in sets) s.index], [1, 2, 3]);
    expect(sets.every((s) => s.completedAt == null), isTrue);
    expect({for (final s in sets) s.id}, hasLength(3));
  });

  test('a planned count sets the ramp', () {
    const cases = {
      0: <int>[],
      1: [60],
      2: [50, 75],
      3: [45, 65, 82],
      4: [45, 60, 75, 85],
      5: [45, 60, 75, 85, 90],
    };
    for (final MapEntry(key: count, value: expected) in cases.entries) {
      expect([
        for (final w in weights(warmups(weight: 100, count: count))) w!.round(),
      ], expected);
    }
  });

  test('a planned count is kept whole', () {
    expect(warmups(weight: 20, reps: 15, count: 3), hasLength(3));
    expect(
      warmups(weight: 100, mode: TrackingMode.timeOnly, count: 3),
      isEmpty,
    );
    expect(
      [for (final s in warmups(weight: 100, reps: 5, count: 4)) s.reps],
      [8, 5, 3, 3],
    );
  });

  test('timed, distance and bodyweight work get none', () {
    expect(warmups(weight: 100, mode: TrackingMode.timeOnly), isEmpty);
    expect(warmups(weight: 100, mode: TrackingMode.distanceTime), isEmpty);
    expect(warmups(weight: null, mode: TrackingMode.repsOnly), isEmpty);
    expect(warmups(weight: 0), isEmpty);
  });

  test('rounding drops warm-ups that land on the bar or each other', () {
    // An empty 20 kg bar: every ramp below 40 kg rounds to the bar.
    double bar(double kg) => kg < 20 ? 20 : (kg / 5).roundToDouble() * 5;
    expect(weights(warmups(weight: 30, reps: 5, round: bar)), [20, 25]);
    expect(weights(warmups(weight: 22.5, reps: 5, round: bar)), [20]);
    expect(weights(warmups(weight: 20, reps: 5, round: bar)), isEmpty);
    // Rounded to nothing at all.
    expect(warmups(weight: 10, reps: 5, round: (_) => 0), isEmpty);
  });

  test('a plan’s assisted warm-ups get more help', () {
    expect(weights(warmups(weight: -30, count: 1)), [-42]);
    expect(warmups(weight: -30), isEmpty);
  });
}
