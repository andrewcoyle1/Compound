// Ports PlateCalculatorTests' PlateLoadingTests and the loading the plate
// calculator's presenter and the weight keyboard read (their words are the
// app's), and SetKeyboardPresenterTests' stack breakdown.

import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

void main() {
  group('PlateLoading', () {
    test('a bar says what goes on each side', () {
      const loading = PlateLoading(perSide: [25, 10, 10, 2.5], base: 20);
      expect(loading.total, 115);
      expect(loading.plates, 47.5);
      expect(loading.counts, [(25.0, 1), (10.0, 2), (2.5, 1)]);
    });

    test('a single-sleeve machine sums its plates and base', () {
      const loading = PlateLoading(perSide: [20, 5], base: 18, sleeves: 1);
      expect(loading.total, 43);
      expect(loading.plates, 25);
    });

    test('an empty bar has no counts', () {
      const loading = PlateLoading(perSide: [], base: 20);
      expect(loading.counts, isEmpty);
      expect(loading.total, 20);
    });

    group('of a step', () {
      const plates = [Plate(2.5), Plate(5), Plate(10), Plate(25)];
      WeightStep bar(double base) => WeightStep(
        StepIncrement(5, min: base),
        baseWeight: base,
        plates: plates,
      );

      test('loads the weight on the bar', () {
        expect(
          PlateLoading.of(bar(20), 70),
          const PlateLoading(perSide: [25], base: 20),
        );
        expect(
          PlateLoading.of(bar(7), 57),
          const PlateLoading(perSide: [25], base: 7),
        );
      });

      test('no weight yet is the bare bar', () {
        expect(
          PlateLoading.of(bar(20), null),
          const PlateLoading(perSide: [], base: 20),
        );
      });

      test('a weight the plates cannot make has none', () {
        expect(PlateLoading.of(bar(20), 21), isNull);
      });

      test('equipment with no bar has none', () {
        expect(
          PlateLoading.of(const WeightStep(StepIncrement(5, min: 5)), 50),
          isNull,
        );
      });

      test('a single-sleeve machine keeps its sleeves', () {
        const machine = WeightStep(
          StepIncrement(2.5, min: 18),
          baseWeight: 18,
          plates: plates,
          sleeves: 1,
        );
        expect(
          PlateLoading.of(machine, 43),
          const PlateLoading(perSide: [25], base: 18, sleeves: 1),
        );
      });
    });
  });

  group('PinStack', () {
    const stack = PinStack(pins: [7, 14, 21, 28], addOns: [2, 2]);

    void expectBreakdown(double total, double pin, List<double> addOns) {
      final breakdown = stack.breakdown(total)!;
      expect(breakdown.pin, pin);
      expect(breakdown.addOns, addOns);
    }

    test('as few add-ons as possible, the first listed among equals', () {
      expectBreakdown(16, 14, [2]);
      expectBreakdown(18, 14, [2, 2]);
    });

    test('a pin alone needs no add-on', () {
      expectBreakdown(14, 14, []);
    });

    test('a weight the stack cannot make has no breakdown', () {
      expect(stack.breakdown(15), isNull);
    });
  });

  test('a plate keeps its colour', () {
    expect(const Plate(25, colour: '#E53935').colour, '#E53935');
  });
}
