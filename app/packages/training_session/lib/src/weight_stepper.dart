/// What an exercise may weigh in one gym (`WeightStepper.swift`,
/// `PinStack.swift`'s stack loads, `WeightRoundingRule.init(exercise:…)`):
/// the gym's equipment resolved once into a [r.WeightStep], which the rules
/// then do all the arithmetic on.
///
/// The step's chip ("Bar 20 kg") and a stack's "Pin 14 + 2 kg" are words, so
/// they are the app's to build; this resolves only the numbers.
library;

import 'dart:math' as math;

import 'package:compound_models/compound_models.dart' as m;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/src/library_exercise.dart';
import 'package:training_session/src/mapping.dart';
import 'package:training_session/src/model_copies.dart';

double _thousandths(double value) => (value * 1000).roundToDouble() / 1000;

double _convert(double value, m.ExerciseWeightUnit from, r.WeightUnit to) =>
    _thousandths(r.convertWeightBetween(value, from.rules, to));

const Set<m.EquipmentKind> _platesCarriers = {
  m.EquipmentKind.loadableBar,
  m.EquipmentKind.plateLoadedMachine,
  m.EquipmentKind.loadableAccessoryEquipment,
};

/// Resolves an exercise's equipment in a gym (`enum WeightStepper`).
abstract final class WeightStepper {
  /// The step for [exercise]'s chosen variation, else its first.
  static r.WeightStep stepsForExercise(
    m.WorkoutExerciseModel exercise,
    m.GymProfileModel? profile,
    r.WeightUnit unit,
  ) => steps(exercise.activeVariation?.resistanceEquipment, profile, unit);

  /// The load from the first item of [refs] the gym has that is not a band,
  /// with every band item's bands beside it. Beside a bar or plate-loaded
  /// machine, plates are what load it, not a load of their own.
  static r.WeightStep steps(
    List<m.EquipmentRef>? refs,
    m.GymProfileModel? profile,
    r.WeightUnit unit,
  ) {
    if (profile == null || refs == null) return fallback(unit);
    final carriesPlates = refs.any((ref) => _platesCarriers.contains(ref.kind));
    // A bar in a landmine is loaded on its free end only.
    final barSleeves = refs.any((ref) => ref.equipmentId.contains('landmine'))
        ? 1
        : 2;
    r.WeightStep? load;
    final bands = <String>[];
    for (final ref in refs) {
      if (carriesPlates && _isPlates(ref, profile)) continue;
      final step = _step(ref, profile, unit, barSleeves);
      if (step == null) continue;
      if (step.kind is r.StepBands) {
        // A name listed in both kg and lb is one band.
        for (final name in step.bands) {
          if (!bands.contains(name)) bands.add(name);
        }
      } else {
        load ??= step;
      }
    }
    if (load != null) {
      return r.WeightStep(
        load.kind,
        baseWeight: load.baseWeight,
        plates: load.plates,
        sleeves: load.sleeves,
        isAssisted: load.isAssisted,
        constrainsWeight: load.constrainsWeight,
        bands: bands,
      );
    }
    if (bands.isEmpty) return fallback(unit);
    return r.WeightStep(
      const r.StepBands(),
      constrainsWeight: false,
      bands: bands,
    );
  }

  /// The unit the load of [refs] is labelled in at [profile]; `null` when it
  /// comes in both units, has no unit (body weight, bands) or is missing.
  static m.ExerciseWeightUnit? equipmentUnit(
    List<m.EquipmentRef>? refs,
    m.GymProfileModel? profile,
  ) {
    if (profile == null || refs == null) return null;
    final carriesPlates = refs.any((ref) => _platesCarriers.contains(ref.kind));
    for (final ref in refs) {
      if (carriesPlates && _isPlates(ref, profile)) continue;
      if (ref.kind == m.EquipmentKind.bodyWeight) return null;
      final units = _labelUnits(ref, profile);
      if (units == null) continue;
      final distinct = units.toSet();
      return distinct.length == 1 ? distinct.first : null;
    }
    return null;
  }

  /// No gym or no equipment: the smallest pair of plates a user would add.
  static r.WeightStep fallback(r.WeightUnit unit) =>
      r.WeightStep.fallback(unit);

  /// Every active plate in the gym, in [unit] when any are labelled in it,
  /// ascending, with how many fit on one of [sleeves]. A weight iron and
  /// bumper plates both come in adds their counts, unlimited if either is;
  /// one too few for every sleeve is left out.
  static List<r.Plate> availablePlates(
    m.GymProfileModel profile,
    r.WeightUnit unit, {
    int sleeves = 2,
  }) {
    final listed = [
      for (final item in profile.freeWeights)
        if (item.isActive && item.isPlates) ...item.range,
    ];
    final labelled = listed.any((entry) => entry.unit.rules == unit);
    final entries = listed.where(
      (entry) => entry.isActive && (!labelled || entry.unit.rules == unit),
    );
    final byWeight = <double, List<m.FreeWeightsAvailable>>{};
    for (final entry in entries) {
      byWeight
          .putIfAbsent(
            _convert(entry.availableWeights, entry.unit, unit),
            () => [],
          )
          .add(entry);
    }
    return [
      for (final MapEntry(key: weight, value: group) in byWeight.entries)
        if (_perSleeve(group, sleeves) case final perSleeve
            when weight > 0 && (perSleeve ?? 1) > 0)
          r.Plate(weight, perSleeve: perSleeve),
    ]..sort((a, b) => a.weight.compareTo(b.weight));
  }

  static int? _perSleeve(List<m.FreeWeightsAvailable> group, int sleeves) =>
      group.any((entry) => entry.count == null)
      ? null
      : group.fold<int>(0, (sum, entry) => sum + entry.count!) ~/
            math.max(sleeves, 1);

  static bool _isPlates(m.EquipmentRef ref, m.GymProfileModel profile) {
    if (ref.kind != m.EquipmentKind.freeWeight) return false;
    return profile.freeWeights
            .where((item) => item.typeId == ref.equipmentId)
            .firstOrNull
            ?.isPlates ??
        ref.equipmentId.endsWith('plates');
  }

  static T? _active<T extends m.GymEquipmentItem>(
    List<T> items,
    String typeId,
  ) =>
      items.where((item) => item.typeId == typeId && item.isActive).firstOrNull;

  static List<m.ExerciseWeightUnit>? _labelUnits(
    m.EquipmentRef ref,
    m.GymProfileModel profile,
  ) {
    final id = ref.equipmentId;
    List<m.ExerciseWeightUnit> plateUnits() => [
      for (final item in profile.freeWeights)
        if (item.isActive && item.isPlates)
          for (final entry in item.range)
            if (entry.isActive) entry.unit,
    ];
    List<m.ExerciseWeightUnit>? stackUnits(m.StackMachine? machine) =>
        machine?.ranges.where((s) => s.isActive).map((s) => s.unit).toList();
    return switch (ref.kind) {
      m.EquipmentKind.loadableBar =>
        _active(profile.loadableBars, id) == null ? null : plateUnits(),
      m.EquipmentKind.plateLoadedMachine =>
        _active(profile.plateLoadedMachines, id) == null ? null : plateUnits(),
      m.EquipmentKind.cableMachine => stackUnits(
        _active(profile.cableMachines, id),
      ),
      m.EquipmentKind.pinLoadedMachine => stackUnits(
        _active(profile.pinLoadedMachines, id),
      ),
      m.EquipmentKind.freeWeight => _active(
        profile.freeWeights,
        id,
      )?.range.where((e) => e.isActive).map((e) => e.unit).toList(),
      m.EquipmentKind.fixedWeightBar => _active(
        profile.fixedWeightBars,
        id,
      )?.baseWeights.where((e) => e.isActive).map((e) => e.unit).toList(),
      m.EquipmentKind.bodyWeight ||
      m.EquipmentKind.bands ||
      m.EquipmentKind.supportEquipment ||
      m.EquipmentKind.accessoryEquipment ||
      m.EquipmentKind.loadableAccessoryEquipment => null,
    };
  }

  static r.WeightStep? _step(
    m.EquipmentRef ref,
    m.GymProfileModel profile,
    r.WeightUnit unit,
    int barSleeves,
  ) {
    // A gym can hold several items of one type; the first switched on wins.
    final id = ref.equipmentId;
    switch (ref.kind) {
      case m.EquipmentKind.loadableBar:
        final bar = _active(profile.loadableBars, id);
        final base = bar == null ? null : _loadedBaseWeight(bar);
        if (bar == null || base == null) return null;
        final barWeight = _convert(base.baseWeight, base.unit, unit);
        final collars = _convert(
          bar.collarWeight * 2,
          m.ExerciseWeightUnit.kilograms,
          unit,
        );
        return _plateLoaded(
          _thousandths(barWeight + collars),
          barSleeves,
          profile,
          unit,
        );
      case m.EquipmentKind.plateLoadedMachine:
        final machine = _active(profile.plateLoadedMachines, id);
        if (machine == null) return null;
        return _plateLoaded(
          _convert(machine.baseWeight, machine.unit, unit),
          machine.sleeves,
          profile,
          unit,
        );
      case m.EquipmentKind.cableMachine:
        return _ranged(_active(profile.cableMachines, id), unit);
      case m.EquipmentKind.pinLoadedMachine:
        return _ranged(_active(profile.pinLoadedMachines, id), unit);
      case m.EquipmentKind.freeWeight:
        final item = _active(profile.freeWeights, id);
        if (item == null) return null;
        final weights = _inUnit([
          for (final entry in item.range)
            if (entry.isActive) (entry.availableWeights, entry.unit),
        ], unit);
        return weights.isEmpty ? null : r.WeightStep(r.StepList(weights));
      case m.EquipmentKind.fixedWeightBar:
        final bar = _active(profile.fixedWeightBars, id);
        if (bar == null) return null;
        final weights = _inUnit([
          for (final entry in bar.baseWeights)
            if (entry.isActive) (entry.baseWeight, entry.unit),
        ], unit);
        return weights.isEmpty ? null : r.WeightStep(r.StepList(weights));
      case m.EquipmentKind.bands:
        final item = _active(profile.bands, id);
        if (item == null) return null;
        double kilograms(m.BandsAvailable band) => _convert(
          band.availableResistance,
          band.unit,
          r.WeightUnit.kilograms,
        );
        final active = item.range.where((band) => band.isActive).toList()
          ..sort((a, b) => kilograms(a).compareTo(kilograms(b)));
        return active.isEmpty
            ? null
            : r.WeightStep(
                const r.StepBands(),
                constrainsWeight: false,
                bands: [for (final band in active) band.name],
              );
      case m.EquipmentKind.bodyWeight:
        // External load on top of the body: 1.25 kg, or 2.5 lb.
        return r.WeightStep(
          r.StepIncrement(unit == r.WeightUnit.pounds ? 2.5 : 1.25, min: 0),
          constrainsWeight: false,
        );
      case m.EquipmentKind.supportEquipment ||
          m.EquipmentKind.accessoryEquipment ||
          m.EquipmentKind.loadableAccessoryEquipment:
        return null;
    }
  }

  /// The bar the user chose to load, else the heaviest switched on (the
  /// first of equals, as Swift's `max` keeps).
  static m.BarBaseWeight? _loadedBaseWeight(m.LoadableBars bar) {
    final active = bar.baseWeights.where((weight) => weight.isActive).toList();
    final chosen = active
        .where((weight) => weight.id == bar.chosenBaseWeightId)
        .firstOrNull;
    if (chosen != null) return chosen;
    double kilograms(m.BarBaseWeight weight) =>
        r.convertWeightToKg(weight.baseWeight, weight.unit.rules);
    m.BarBaseWeight? heaviest;
    for (final weight in active) {
      if (heaviest == null || kilograms(heaviest) < kilograms(weight)) {
        heaviest = weight;
      }
    }
    return heaviest;
  }

  /// Every sleeve is loaded alike, so the smallest change is one of the
  /// smallest plates on each.
  static r.WeightStep _plateLoaded(
    double base,
    int sleeves,
    m.GymProfileModel profile,
    r.WeightUnit unit,
  ) {
    final plates = availablePlates(profile, unit, sleeves: sleeves);
    final step = plates.isEmpty
        ? (unit == r.WeightUnit.pounds ? 5.0 : 2.5)
        : plates.first.weight * sleeves;
    return r.WeightStep(
      r.StepIncrement(step, min: base),
      baseWeight: base,
      plates: plates,
      sleeves: sleeves,
    );
  }

  /// The stack in [unit] when the machine has one, else its default, else
  /// the first. A plain stack steps on its grid from the lightest pin;
  /// add-ons or an uneven stack give every load it can make.
  static r.WeightStep? _ranged(m.StackMachine? machine, r.WeightUnit unit) {
    if (machine == null) return null;
    final stacks = machine.ranges.where((stack) => stack.isActive).toList();
    final chosen =
        stacks.where((stack) => stack.unit.rules == unit).firstOrNull ??
        stacks
            .where((stack) => stack.id == machine.defaultRangeId)
            .firstOrNull ??
        stacks.firstOrNull;
    if (chosen == null) return null;
    double inUnit(double value) => _convert(value, chosen.unit, unit);
    final stack = _Stack(
      minWeight: inUnit(chosen.minWeight),
      maxWeight: inUnit(chosen.maxWeight),
      increment: inUnit(chosen.increment),
      addOns: _Stack.usable(chosen.addOns).map(inUnit).toList(),
      weights: chosen.weights?.map(inUnit).toList(),
    );
    if (stack.addOns.isEmpty && stack.weights == null) {
      if (stack.increment <= 0) return null;
      // The top pin, not the stored maximum: worked out in the stack's own
      // unit, where its grid is exact, then converted.
      final ownPins = _Stack(
        minWeight: chosen.minWeight,
        maxWeight: chosen.maxWeight,
        increment: chosen.increment,
        addOns: const [],
        weights: chosen.weights,
      ).pinPositions;
      return r.WeightStep(
        r.StepIncrement(
          stack.increment,
          min: stack.lightestPin,
          max: ownPins.isEmpty ? stack.maxWeight : inUnit(ownPins.last),
        ),
      );
    }
    final loads = stack.loads();
    return loads.isEmpty ? null : r.WeightStep(r.StepList(loads));
  }

  /// The weights labelled in [unit] when any are, else all of them
  /// converted; ascending, without duplicates.
  static List<double> _inUnit(
    List<(double, m.ExerciseWeightUnit)> weights,
    r.WeightUnit unit,
  ) {
    final matching = [
      for (final (weight, from) in weights)
        if (from.rules == unit) weight,
    ];
    final chosen = matching.isNotEmpty
        ? matching
        : [for (final (weight, from) in weights) _convert(weight, from, unit)];
    return _distinct(chosen);
  }
}

List<double> _distinct(Iterable<double> values) =>
    values.map(_thousandths).toSet().toList()..sort();

/// A weight stack's numbers in one unit (`WeightStack`'s pins and loads).
class _Stack({
  required final double minWeight,
  required final double maxWeight,
  required final double increment,
  required final List<double> addOns,
  required final List<double>? weights,
}) {
  static const maxAddOns = 6;

  static List<double> usable(List<double> addOns) =>
      addOns.where((weight) => weight > 0).take(maxAddOns).toList();

  double get lightestPin => minWeight > 0 ? minWeight : increment;

  List<double> get pinPositions {
    final listed = weights;
    if (listed != null) return _distinct(listed.where((w) => w > 0));
    if (increment <= 0 || lightestPin > maxWeight) return [];
    final count = ((maxWeight - lightestPin) / increment + 0.001).floor();
    return _distinct([
      for (var i = 0; i <= count; i++) lightestPin + i * increment,
    ]);
  }

  List<double> loads() {
    final sums = [
      for (var mask = 0; mask < 1 << addOns.length; mask++)
        [
          for (var i = 0; i < addOns.length; i++)
            if (mask & (1 << i) != 0) addOns[i],
        ].fold<double>(0, (sum, weight) => sum + weight),
    ];
    return _distinct([
      for (final pin in pinPositions)
        for (final sum in sums) pin + sum,
    ]);
  }
}

/// What a weight may be for [exercise] in [gym], in [preferredUnit] (kg
/// without one), on [resistanceEquipment] or else the exercise's first
/// variation; mirrored below zero for an assisted exercise
/// (`WeightRoundingRule.init(exercise:gymProfile:…)`).
r.WeightRoundingRule weightRoundingRule({
  required m.ExerciseModel? exercise,
  required m.GymProfileModel? gym,
  required m.ExerciseWeightUnit? preferredUnit,
  List<m.EquipmentRef>? resistanceEquipment,
}) {
  final unit = preferredUnit?.rules ?? r.WeightUnit.kilograms;
  final refs =
      resistanceEquipment ??
      exercise?.equipmentVariations.firstOrNull?.resistanceEquipment;
  var step = WeightStepper.steps(refs, gym, unit);
  if (exercise != null && exercise.isAssisted) {
    step = step.assisted(bodyweightOnly: exercise.isBodyweight);
  }
  return r.WeightRoundingRule(
    step: step,
    unit: unit,
    preferredUnit: preferredUnit?.rules,
  );
}

/// [rule] as the progression engine takes it.
r.ProgressionRounding progressionRounding(r.WeightRoundingRule rule) =>
    r.ProgressionRounding(
      round: rule.round,
      minimumIncrementKg: rule.minimumIncrementKg,
    );
