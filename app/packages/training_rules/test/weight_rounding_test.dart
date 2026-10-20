// Ports PlateCalculatorTests, the WeightStep cases of WeightStepperTests and
// WeightRoundingRuleTests, with each step built as WeightStepper resolves it
// from the Swift suites' gym (resolving from a gym is the gym slice's).
import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

const _platesKg = [Plate(1.25), Plate(2.5), Plate(5), Plate(10), Plate(20)];

const barbell = WeightStep(
  StepIncrement(2.5, min: 20),
  baseWeight: 20,
  plates: _platesKg,
);
const sled = WeightStep(
  StepIncrement(2.5, min: 40),
  baseWeight: 40,
  plates: _platesKg,
);
const cable = WeightStep(StepIncrement(5, min: 5, max: 50));
const dumbbells = WeightStep(StepList([10, 12.5, 15, 20]));
const fixedBars = WeightStep(StepList([10, 20, 30]));
const vest = WeightStep(StepIncrement(1.25, min: 0), constrainsWeight: false);
const bands = WeightStep(
  StepBands(),
  constrainsWeight: false,
  bands: ['Light', 'Heavy'],
);
final fallback = WeightStep.fallback(WeightUnit.kilograms);

void main() {
  group('plate calculator', () {
    const plates = [
      Plate(1.25),
      Plate(2.5),
      Plate(5),
      Plate(10),
      Plate(15),
      Plate(20),
      Plate(25),
    ];
    PlateLoad load(
      double total, {
      double bar = 20,
      List<Plate> plates = plates,
      int sleeves = 2,
    }) => PlateCalculator.load(
      total: total,
      bar: bar,
      plates: plates,
      sleeves: sleeves,
    );
    double nearest(
      double total, {
      double bar = 20,
      List<Plate> plates = plates,
      int sleeves = 2,
    }) => PlateCalculator.nearestLoadable(
      total: total,
      bar: bar,
      plates: plates,
      sleeves: sleeves,
    );

    test('greedy from the heaviest', () {
      expect(load(100), const Loadable([25, 15]));
      expect(load(142.5), const Loadable([25, 25, 10, 1.25]));
    });

    test('a bare bar is loadable; below it offers the bar', () {
      expect(load(20), const Loadable([]));
      expect(load(10), const NotLoadable(above: 20));
    });

    test('unreachable offers the nearest loadable totals', () {
      expect(load(101), const NotLoadable(below: 100, above: 102.5));
    });

    test('a greedy miss is still loadable', () {
      expect(
        load(80, plates: const [Plate(15), Plate(20)]),
        const Loadable([15, 15]),
      );
    });

    test('no plates at all', () {
      expect(load(60, plates: const []), const NotLoadable());
      expect(nearest(60, plates: const []), 60);
      expect(
        load(60, plates: const [Plate(0), Plate(5, perSleeve: 0)]),
        const NotLoadable(),
      );
    });

    test('running out of plates is not loadable', () {
      const capped = [Plate(20, perSleeve: 1)];
      expect(load(100, plates: capped), const NotLoadable(below: 60));
      expect(nearest(100, plates: capped), 60);
    });

    test('limited plates fall to the next one down', () {
      expect(
        load(100, plates: const [Plate(5), Plate(15), Plate(20, perSleeve: 1)]),
        const Loadable([20, 15, 5]),
      );
    });

    test('one sleeve takes the whole load', () {
      expect(load(58, bar: 18, sleeves: 1), const Loadable([25, 15]));
      expect(nearest(19, bar: 18, sleeves: 1), 19.25);
      expect(
        load(20.5, bar: 18, plates: _platesKg, sleeves: 0),
        const Loadable([2.5]),
      );
    });

    test('the nearest is the closer total, the lighter on a tie', () {
      expect(nearest(100), 100);
      expect(nearest(101), 100);
      expect(nearest(102), 102.5);
      expect(nearest(101.25), 100);
      expect(nearest(15), 20);
    });

    test('a greedy miss with no exact sum offers the totals either side', () {
      expect(
        load(81, plates: const [Plate(15), Plate(20)]),
        const NotLoadable(below: 80, above: 90),
      );
    });

    test('a lone plate and a plate under a gram', () {
      expect(
        load(21, plates: const [Plate(5)]),
        const NotLoadable(below: 20, above: 30),
      );
      expect(
        load(
          51,
          plates: const [Plate(10, perSleeve: 1), Plate(0.0004, perSleeve: 1)],
        ),
        const NotLoadable(below: 40),
      );
    });
  });

  group('weight step', () {
    test('steps for every kind', () {
      final cases = <(WeightStep, double?, double?, double?)>[
        (barbell, 60, 62.5, 57.5),
        (barbell, null, 20, 20),
        (barbell, 21, 22.5, 20),
        (sled, 40, 42.5, 40),
        (cable, 20, 25, 15),
        (cable, 50, 50, 45),
        (cable, 5, 10, 5),
        (cable, 22, 25, 20),
        (dumbbells, 15, 20, 12.5),
        (dumbbells, 20, 20, 15),
        (dumbbells, 10, 12.5, 10),
        (dumbbells, 11, 12.5, 10),
        (fixedBars, 20, 30, 10),
        (vest, 0, 1.25, 0),
        (vest, null, 0, 0),
        (fallback, 20, 22.5, 17.5),
      ];
      for (final (step, from, up, down) in cases) {
        expect(step.next(from), up, reason: '$step up from $from');
        expect(step.previous(from), down, reason: '$step down from $from');
      }
      expect(const WeightStep(StepList([])).next(null), isNull);
      expect(const WeightStep(StepList([])).next(5), isNull);
      expect(const WeightStep(StepList([])).previous(5), isNull);
    });

    test('an assisted machine steps below zero to its deepest', () {
      final step = cable.assisted(bodyweightOnly: true);
      expect(step.next(-30), -25);
      expect(step.previous(-30), -35);
      expect(step.previous(-50), -50);
      expect(step.next(-5), 0);
      expect(step.next(0), 0);
      expect(step.previous(null), -5);
      expect(step.isAssisted, isTrue);
    });

    test('an assisted grid with no top goes two hundred steps deep', () {
      final step = fallback.assisted(bodyweightOnly: false);
      expect(step.kind, const StepIncrement(2.5, min: -500));
      expect(step.constrainsWeight, isFalse);
    });

    test('an assisted rack mirrors its weights', () {
      expect(
        dumbbells.assisted(bodyweightOnly: true).kind,
        const StepList([-20, -15, -12.5, -10, 0]),
      );
      expect(
        dumbbells.assisted(bodyweightOnly: false).kind,
        const StepList([-20, -15, -12.5, -10, 0, 10, 12.5, 15, 20]),
      );
      expect(bands.assisted(bodyweightOnly: true), same(bands));
    });

    test('nothing else steps below zero', () {
      for (final step in [cable, dumbbells, vest, fallback]) {
        expect(step.previous(0), greaterThanOrEqualTo(0));
        expect(step.previous(null), greaterThanOrEqualTo(0));
      }
    });

    test('a bar shows its plates; body weight does not', () {
      expect(barbell.isPlateLoaded, isTrue);
      expect(vest.isPlateLoaded, isFalse);
    });

    test('bands cycle by name, lightest first', () {
      expect(bands.band(null, forward: true), 0);
      expect(bands.band(null, forward: false), 1);
      expect(bands.band(1, forward: true), 0);
      expect(bands.band(0, forward: false), 1);
      expect(barbell.band(0, forward: true), isNull);
      expect(bands.next(10), isNull);
      expect(bands.previous(10), isNull);
    });

    test('the smallest step is the grid or the smallest gap', () {
      expect(cable.smallestStep, 5);
      expect(dumbbells.smallestStep, 2.5);
      expect(fixedBars.smallestStep, 10);
      expect(barbell.smallestStep, 2.5);
      expect(bands.smallestStep, isNull);
      expect(const WeightStep(StepList([10])).smallestStep, isNull);
      expect(const WeightStep(StepList([10, 10, 15, 25])).smallestStep, 5);
    });

    test('nearest picks the lighter of two equally close weights', () {
      expect(dumbbells.nearest(17.5), 15);
      expect(dumbbells.nearest(100), 20);
      expect(cable.nearest(1), 5);
      expect(cable.nearest(48), 50);
      expect(cable.nearest(80), 50);
      expect(barbell.nearest(61), 60);
      expect(bands.nearest(7), 7);
      expect(const WeightStep(StepList([])).nearest(7), 7);
    });

    test('no gym falls back to 2.5 kg or 5 lb', () {
      expect(WeightStep.fallback(WeightUnit.kilograms).next(100), 102.5);
      expect(WeightStep.fallback(WeightUnit.pounds).next(100), 105);
    });

    test('a pound stack in kilograms steps on its converted grid', () {
      const pin = WeightStep(StepIncrement(4.536, min: 4.536, max: 45.359));
      expect(pin.next(null), 4.536);
      expect(pin.next(4.536), 9.072);
      const pounds = WeightStep(StepIncrement(10, min: 10, max: 100));
      expect(pounds.next(50), 60);
      expect(pounds.previous(10), 10);
      expect(pounds.next(100), 100);
    });

    test('kilogram plates convert for a pound user', () {
      final plates = [
        for (final p in _platesKg)
          Plate(
            (convertWeightBetween(
                          p.weight,
                          WeightUnit.kilograms,
                          WeightUnit.pounds,
                        ) *
                        1000)
                    .roundToDouble() /
                1000,
          ),
      ];
      final step = WeightStep(
        StepIncrement(plates.first.weight * 2, min: 44.092),
        baseWeight: 44.092,
        plates: plates,
      );
      expect(step.next(44.092), 49.604);
    });

    test('a single-sleeve machine steps one plate', () {
      const tBar = WeightStep(
        StepIncrement(1.25, min: 18),
        baseWeight: 18,
        plates: _platesKg,
        sleeves: 1,
      );
      expect(tBar.next(18), 19.25);
      expect(tBar.nearest(20.5), 20.5);
    });

    test('collars are added to the bar', () {
      const collared = WeightStep(
        StepIncrement(2.5, min: 25),
        baseWeight: 25,
        plates: _platesKg,
      );
      expect(collared.next(null), 25);
      expect(collared.nearest(22), 25);
      expect(collared.nearest(61), 60);
    });
  });

  group('rounding rule', () {
    test('equipment that constrains the weight rounds onto it', () {
      const rule = WeightRoundingRule(
        step: cable,
        preferredUnit: WeightUnit.kilograms,
      );
      expect(rule.round(23), 25);
      expect(rule.minimumIncrementKg, 5);
      const tBar = WeightRoundingRule(
        step: WeightStep(
          StepIncrement(1.25, min: 18),
          baseWeight: 18,
          plates: _platesKg,
          sleeves: 1,
        ),
      );
      expect(tBar.round(20.6), 20.5);
      expect(tBar.minimumIncrementKg, 1.25);
    });

    test('a kilogram user on a pound stack uses the pound stack', () {
      const rule = WeightRoundingRule(
        step: WeightStep(StepIncrement(5, min: 5, max: 500)),
        unit: WeightUnit.pounds,
        preferredUnit: WeightUnit.kilograms,
      );
      expect(
        rule.round(45),
        closeTo(convertWeightToKg(100, WeightUnit.pounds), 1e-9),
      );
      expect(rule.minimumIncrementKg, closeTo(2.268, 0.001));
    });

    test('unconstrained equipment rounds to the user unit', () {
      final kg = WeightRoundingRule(
        step: fallback,
        preferredUnit: WeightUnit.kilograms,
      );
      expect(kg.round(23.3), 23.5);
      expect(kg.minimumIncrementKg, 2.5);
      final lb = WeightRoundingRule(
        step: fallback,
        preferredUnit: WeightUnit.pounds,
      );
      expect(
        lb.round(convertWeightToKg(100.4, WeightUnit.pounds)),
        closeTo(convertWeightToKg(100, WeightUnit.pounds), 1e-9),
      );
      expect(lb.minimumIncrementKg, closeTo(2.268, 0.001));
      final none = WeightRoundingRule(step: fallback);
      expect(none.round(23.3), 23.3);
      expect(none.minimumIncrementKg, 2.5);
    });

    test('a single weight constrains but has no step of its own', () {
      const rule = WeightRoundingRule(step: WeightStep(StepList([16])));
      expect(rule.round(20), 16);
      expect(rule.minimumIncrementKg, 2.5);
    });

    test('a dumbbell rack rounds onto the rack', () {
      const rack = WeightRoundingRule(
        step: WeightStep(StepList([20, 22.5, 25])),
      );
      expect(rack.round(23), 22.5);
      expect(rack.round(23.75), 22.5);
    });

    test('an assisted weight rounds on the mirrored stack', () {
      final onStack = WeightRoundingRule(
        step: cable.assisted(bodyweightOnly: true),
        preferredUnit: WeightUnit.kilograms,
      );
      expect(onStack.round(-27), -25);
      expect(onStack.round(-80), -50);
      expect(onStack.round(10), 0);
      final noGym = WeightRoundingRule(
        step: fallback.assisted(bodyweightOnly: true),
        preferredUnit: WeightUnit.kilograms,
      );
      expect(noGym.round(-27.4), -27.5);
    });

    test('every rounded weight is one the keyboard reaches', () {
      for (final (step, unit) in [
        (cable, WeightUnit.kilograms),
        (dumbbells, WeightUnit.kilograms),
        (fixedBars, WeightUnit.kilograms),
        (barbell, WeightUnit.kilograms),
        (sled, WeightUnit.kilograms),
        (
          const WeightStep(StepIncrement(10, min: 10, max: 200)),
          WeightUnit.pounds,
        ),
      ]) {
        final rule = WeightRoundingRule(step: step, unit: unit);
        for (var kg = 0.0; kg <= 120; kg += 3.7) {
          final rounded = convertWeight(rule.round(kg), unit);
          var reached = step.next(null);
          for (var i = 0; i < 500; i++) {
            final value = reached;
            if (value == null || value >= rounded - 0.01) break;
            final next = step.next(value);
            if (next == null || next <= value) break;
            reached = next;
          }
          expect(reached, closeTo(rounded, 0.01), reason: '$kg kg on $step');
        }
      }
    });
  });

  group('units', () {
    test('conversions go through kilograms', () {
      expect(convertWeight(100, WeightUnit.pounds), closeTo(220.462, 1e-9));
      expect(convertWeight(100, WeightUnit.kilograms), 100);
      expect(convertWeightToKg(220.462, WeightUnit.pounds), closeTo(100, 1e-9));
      expect(
        convertWeightBetween(10, WeightUnit.pounds, WeightUnit.pounds),
        10,
      );
      expect(
        convertWeightBetween(100, WeightUnit.kilograms, WeightUnit.pounds),
        closeTo(220.462, 1e-9),
      );
    });
  });
}
