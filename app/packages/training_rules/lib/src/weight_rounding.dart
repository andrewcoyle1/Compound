/// What a weight is allowed to be: unit conversion, the plate calculator, an
/// exercise's [WeightStep] and the [WeightRoundingRule] built on it
/// (`UnitConversion.swift`, `PlateCalculator.swift`, `WeightStepper.swift`,
/// `WeightRoundingRule.swift`).
///
/// Resolving a step from a gym profile (`WeightStepper.steps(for:profile:)`)
/// is the gym slice's; everything after that is here.
library;

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:training_rules/src/models.dart';

const _poundsPerKilogram = 2.20462;

/// [kilograms] in [unit].
double convertWeight(double kilograms, WeightUnit unit) =>
    unit == WeightUnit.pounds ? kilograms * _poundsPerKilogram : kilograms;

/// [value], in [unit], as kilograms.
double convertWeightToKg(double value, WeightUnit unit) =>
    unit == WeightUnit.pounds ? value / _poundsPerKilogram : value;

/// [value] from one unit to another, through kilograms.
double convertWeightBetween(double value, WeightUnit from, WeightUnit into) =>
    from == into ? value : convertWeight(convertWeightToKg(value, from), into);

double _thousandths(double value) => (value * 1000).roundToDouble() / 1000;

/// One weight of plate a gym has. [perSleeve] `null` is as many as needed.
class const Plate(final double weight, {final int? perSleeve});

/// Which plates go on one sleeve for a total (`PlateCalculator.Result`).
sealed class PlateLoad extends Equatable {
  const new();
}

/// Plates for one sleeve, heaviest first; empty is the bare bar.
final class Loadable extends PlateLoad {
  const new(this.perSide);

  final List<double> perSide;

  @override
  List<Object?> get props => [perSide];
}

/// Not reachable; the closest totals that are, below and above.
final class NotLoadable extends PlateLoad {
  const new({this.below, this.above});

  final double? below;
  final double? above;

  @override
  List<Object?> get props => [below, above];
}

/// Which plates go on each sleeve of a bar or machine (`PlateCalculator`).
abstract final class PlateCalculator {
  static const _scale = 1000.0;
  static const _epsilon = 0.001;

  /// The plates for one sleeve, the same on each of [sleeves]: greedy from
  /// the heaviest when that works, otherwise any combination the plates and
  /// their counts allow. [total], [bar] and [plates] share a unit.
  static PlateLoad load({
    required double total,
    required double bar,
    required List<Plate> plates,
    int sleeves = 2,
  }) {
    final sleeveCount = math.max(sleeves, 1);
    final usable = plates
        .where((p) => p.weight > 0 && (p.perSleeve ?? 1) > 0)
        .toList();
    final target = (total - bar) / sleeveCount;
    if (target.abs() < _epsilon) return const Loadable([]);
    if (target <= 0) return NotLoadable(above: bar);
    if (usable.isEmpty) return const NotLoadable();
    final greedy = _greedy(target, usable);
    if (greedy != null) return Loadable(greedy);

    final heaviest = usable.map((p) => p.weight).reduce(math.max);
    final sums = _Sums(usable, target + heaviest);
    final wanted = (target * _scale).round();
    if ((wanted - target * _scale).abs() < _epsilon * _scale) {
      final perSide = sums.plates(wanted);
      if (perSide != null) return Loadable(perSide);
    }
    double toTotal(int side) => _thousandths(bar + side / _scale * sleeveCount);
    final below = sums.reachableAtMost((target * _scale).floor());
    final above = sums.reachableAtLeast((target * _scale).ceil());
    return NotLoadable(
      below: below == null ? null : toTotal(below),
      above: above == null ? null : toTotal(above),
    );
  }

  /// [total] if the bar can carry it, else the closer loadable total either
  /// side, the lighter on a tie; [total] when nothing reaches it.
  static double nearestLoadable({
    required double total,
    required double bar,
    required List<Plate> plates,
    int sleeves = 2,
  }) =>
      switch (load(total: total, bar: bar, plates: plates, sleeves: sleeves)) {
        Loadable() => total,
        NotLoadable(below: final below?, above: final above?) =>
          above - total < total - below ? above : below,
        NotLoadable(:final below, :final above) => below ?? above ?? total,
      };

  static List<double>? _greedy(double target, List<Plate> plates) {
    var remaining = target;
    final loaded = <double>[];
    final sorted = [...plates]..sort((a, b) => b.weight.compareTo(a.weight));
    for (final plate in sorted) {
      var used = 0;
      while (remaining + _epsilon >= plate.weight &&
          used < (plate.perSleeve ?? _unlimited)) {
        loaded.add(plate.weight);
        remaining -= plate.weight;
        used++;
      }
    }
    return remaining.abs() < _epsilon ? loaded : null;
  }
}

const _unlimited = 0x7FFFFFFFFFFFFFFF;

/// Every per-sleeve weight the plates make up to a bound, in thousandths: a
/// bounded subset sum where each reachable sum remembers the plate that first
/// reached it, heaviest first.
class _Sums {
  new(List<Plate> plates, double limit) {
    final sorted = [...plates]..sort((a, b) => b.weight.compareTo(a.weight));
    _weights = [for (final p in sorted) (p.weight * 1000).round()];
    // ponytail: one slot per gram up to a tonne a sleeve, as the Swift.
    final size = math.min((limit * 1000).ceil(), 1000000) + 1;
    _via = List.filled(size, -1);
    _via[0] = _unlimited;
    for (final (index, plate) in sorted.indexed) {
      final weight = _weights[index];
      if (weight <= 0 || weight >= size) continue;
      final used = List.filled(size, 0);
      for (var sum = weight; sum < size; sum++) {
        if (_via[sum] == -1 &&
            _via[sum - weight] != -1 &&
            used[sum - weight] < (plate.perSleeve ?? _unlimited)) {
          _via[sum] = index;
          used[sum] = used[sum - weight] + 1;
        }
      }
    }
  }

  late final List<int> _weights;
  late final List<int> _via;

  List<double>? plates(int sum) {
    if (sum >= _via.length || _via[sum] == -1) return null;
    var remaining = sum;
    final loaded = <double>[];
    while (remaining > 0) {
      final weight = _weights[_via[remaining]];
      loaded.add(weight / 1000);
      remaining -= weight;
    }
    return loaded..sort((a, b) => b.compareTo(a));
  }

  int? reachableAtMost(int sum) {
    for (var i = math.min(sum, _via.length - 1); i >= 0; i--) {
      if (_via[i] != -1) return i;
    }
    return null;
  }

  int? reachableAtLeast(int sum) {
    for (var i = math.max(sum, 0); i < _via.length; i++) {
      if (_via[i] != -1) return i;
    }
    return null;
  }
}

/// How an exercise's weight moves, in the display unit (`WeightStep.Kind`).
sealed class StepKind extends Equatable {
  const new();
}

/// A fixed step on a grid from [min], clamped to [min]…[max].
final class StepIncrement extends StepKind {
  const new(this.step, {required this.min, this.max});

  final double step;
  final double min;
  final double? max;

  @override
  List<Object?> get props => [step, min, max];
}

/// Only these weights exist, ascending.
final class StepList extends StepKind {
  const new(this.weights);

  final List<double> weights;

  @override
  List<Object?> get props => [weights];
}

/// Bands alone, with no load.
final class StepBands extends StepKind {
  const new();

  @override
  List<Object?> get props => [];
}

/// How one exercise's weight moves up and down, every number in the display
/// unit (`WeightStep`).
class const WeightStep(
  final StepKind kind, {
  final double? baseWeight,
  final List<Plate> plates = const [],
  final int sleeves = 2,
  final bool isAssisted = false,

  /// Whether the gym's equipment limits what the weight can be.
  final bool constrainsWeight = true,
  final List<String> bands = const [],
}) {
  /// No gym or no equipment: the smallest pair of plates a user would add
  /// (`WeightStepper.fallback`).
  factory fallback(WeightUnit unit) => WeightStep(
    StepIncrement(unit == WeightUnit.pounds ? 5 : 2.5, min: 0),
    constrainsWeight: false,
  );

  /// Stored kg to pounds and back is never exactly the number typed.
  static const epsilon = 0.001;

  bool get isPlateLoaded => baseWeight != null && plates.isNotEmpty;

  /// The next weight up from [value], or the lightest when none is entered.
  double? next(double? value) {
    final from = value ?? (isAssisted ? 0 : null);
    return switch (kind) {
      StepIncrement(:final step, :final min, :final max) =>
        from == null
            ? min
            : _clamp(
                min +
                    (((from - min) / step + epsilon).floorToDouble() + 1) *
                        step,
                min,
                max,
              ),
      StepList(:final weights) =>
        from == null
            ? weights.firstOrNull
            : weights.where((w) => w > from + epsilon).firstOrNull ??
                  weights.lastOrNull,
      StepBands() => null,
    };
  }

  /// The next weight down from [value], never below the lightest.
  double? previous(double? value) {
    final from = value ?? (isAssisted ? 0 : null);
    return switch (kind) {
      StepIncrement(:final step, :final min, :final max) =>
        from == null
            ? min
            : _clamp(
                min +
                    (((from - min) / step - epsilon).ceilToDouble() - 1) * step,
                min,
                max,
              ),
      StepList(:final weights) =>
        from == null
            ? weights.firstOrNull
            : weights.where((w) => w < from - epsilon).lastOrNull ??
                  weights.firstOrNull,
      StepBands() => null,
    };
  }

  /// The weight this equipment makes closest to [value], the lighter on a
  /// tie; bands return [value].
  double nearest(double value) {
    if (isPlateLoaded) {
      return PlateCalculator.nearestLoadable(
        total: value,
        bar: baseWeight!,
        plates: plates,
        sleeves: sleeves,
      );
    }
    switch (kind) {
      case StepIncrement(:final step, :final min, :final max):
        final steps = (value - min) / step;
        final lower = steps.floorToDouble();
        final chosen = steps - lower > 0.5 + epsilon ? lower + 1 : lower;
        return _clamp(min + chosen * step, min, max);
      case StepList(:final weights):
        double? best;
        for (final weight in weights) {
          if (best == null || (weight - value).abs() < (best - value).abs()) {
            best = weight;
          }
        }
        return best ?? value;
      case StepBands():
        return value;
    }
  }

  /// The smallest change this equipment makes; `null` for bands or a single
  /// weight.
  double? get smallestStep => switch (kind) {
    StepIncrement(:final step) => step,
    StepList(:final weights) =>
      [for (var i = 1; i < weights.length; i++) weights[i] - weights[i - 1]]
          .where((gap) => gap > epsilon)
          .fold<double?>(
            null,
            (smallest, gap) =>
                smallest == null || gap < smallest ? gap : smallest,
          ),
    StepBands() => null,
  };

  /// The same equipment giving assistance: mirrored below zero, and never
  /// above zero for an exercise that cannot be loaded.
  WeightStep assisted({required bool bodyweightOnly}) {
    final StepKind mirrored;
    switch (kind) {
      case StepIncrement(:final step, :final min, :final max):
        final positions = max == null
            ? 200
            : ((max - min) / step + epsilon).floorToDouble();
        mirrored = StepIncrement(
          step,
          min: -(min + positions * step),
          max: bodyweightOnly ? 0 : max,
        );
      case StepList(:final weights):
        mirrored = StepList(
          {
            for (final w in weights) -w,
            0.0,
            if (!bodyweightOnly) ...weights,
          }.toList()..sort(),
        );
      case StepBands():
        return this;
    }
    return WeightStep(
      mirrored,
      isAssisted: true,
      constrainsWeight: constrainsWeight,
      bands: bands,
    );
  }

  /// The band after (or before) [index], wrapping round.
  int? band(int? index, {required bool forward}) {
    if (bands.isEmpty) return null;
    if (index == null) return forward ? 0 : bands.length - 1;
    return (index + (forward ? 1 : -1) + bands.length) % bands.length;
  }

  static double _clamp(double value, double min, double? max) =>
      math.min(math.max(_thousandths(value), min), max ?? double.infinity);
}

/// The weight rule progression rounds by: what one exercise's equipment
/// allows in [unit], else the user's unit (`WeightRoundingRule`).
class const WeightRoundingRule({
  required final WeightStep step,
  final WeightUnit unit = WeightUnit.kilograms,
  final WeightUnit? preferredUnit,
}) {
  /// kg in, kg the user could actually load out.
  double round(double weightKg) {
    if (step.constrainsWeight) {
      // To the gram first, as the stepper's own figures are.
      final value = _thousandths(convertWeight(weightKg, unit));
      return convertWeightToKg(step.nearest(value), unit);
    }
    final preferred = preferredUnit;
    if (preferred == null) return weightKg;
    final inUnit = convertWeight(weightKg, preferred);
    final rounded = preferred == WeightUnit.kilograms
        ? (inUnit * 2).roundToDouble() / 2
        : inUnit.roundToDouble();
    return convertWeightToKg(rounded, preferred);
  }

  /// The smallest step this rule expresses, in kg: the equipment's, else
  /// 2.5 kg or 5 lb.
  double get minimumIncrementKg {
    final smallest = step.smallestStep;
    if (step.constrainsWeight && smallest != null) {
      return convertWeightToKg(smallest, unit);
    }
    return preferredUnit == WeightUnit.pounds
        ? convertWeightToKg(5, WeightUnit.pounds)
        : 2.5;
  }
}
