import 'dart:math';

import 'package:compound_models/compound_models.dart';
import 'package:program_repository/src/program_rules.dart';

/// A new gym owned by [authorId]: the whole catalogue, as Swift's
/// `GymProfileModel(authorId:name:)` starts one, set up for the unit the
/// user weighs in ([GymProfileAdapting.adaptingDefaults]; pounds only when
/// [weightUnit] is pounds, as `CreateGymProfilePresenter` chooses).
GymProfileModel newGymProfile({
  required String authorId,
  required String name,
  required DateTime now,
  required WeightUnitPreference? weightUnit,
  String Function() newId = newUuid,
  String kilogramStackName = 'Kilogram stack',
}) {
  final catalogue = GymEquipmentCatalogue.instance;
  return GymProfileModel(
    id: newId(),
    authorId: authorId,
    name: name,
    icon: 'dumbbell',
    dateCreated: now,
    dateModified: now,
    freeWeights: catalogue.freeWeights,
    loadableBars: catalogue.loadableBars,
    fixedWeightBars: catalogue.fixedWeightBars,
    bands: catalogue.bands,
    bodyWeights: catalogue.bodyWeights,
    supportEquipment: catalogue.supportEquipment,
    accessoryEquipment: catalogue.accessoryEquipment,
    loadableAccessoryEquipment: catalogue.loadableAccessoryEquipment,
    cableMachines: catalogue.cableMachines,
    plateLoadedMachines: catalogue.plateLoadedMachines,
    pinLoadedMachines: catalogue.pinLoadedMachines,
  ).adaptingDefaults(
    weightUnit == WeightUnitPreference.pounds
        ? ExerciseWeightUnit.pounds
        : ExerciseWeightUnit.kilograms,
    newId: newId,
    kilogramStackName: kilogramStackName,
  );
}

/// [draft] as `GymProfilePresenter.profileToSave` saves it: a blank name
/// becomes [untitledName], and it is stamped modified at [now].
GymProfileModel gymProfileToSave(
  GymProfileModel draft, {
  required DateTime now,
  String untitledName = 'Untitled Gym Profile',
}) => _copy(
  draft,
  name: draft.name.trim().isEmpty ? untitledName : draft.name,
  dateModified: now,
);

/// Swift's `GymProfileModel+UnitDefaults.swift`.
extension GymProfileAdapting on GymProfileModel {
  /// A new gym's catalogue set up for the unit its user weighs in, so its
  /// weights read as they do on the equipment. Only for new gyms: an
  /// existing gym is the user's own record of what is there.
  ///
  /// In pounds, the 45 lb barbell is switched on and chosen, rather than a
  /// 20 kg bar read as 44.09 lb. In kilograms, every pin-loaded and cable
  /// machine gets a kilogram stack switched on and its pound stacks off
  /// ([kilogramStackName] names a stack it has to add; [newId] makes its
  /// id).
  GymProfileModel adaptingDefaults(
    ExerciseWeightUnit unit, {
    String Function() newId = newUuid,
    String kilogramStackName = 'Kilogram stack',
  }) => switch (unit) {
    ExerciseWeightUnit.pounds => _copy(
      this,
      loadableBars: [for (final bar in loadableBars) _poundBar(bar)],
    ),
    ExerciseWeightUnit.kilograms => _copy(
      this,
      cableMachines: [
        for (final machine in cableMachines)
          _inKilograms(machine, newId, kilogramStackName),
      ],
      pinLoadedMachines: [
        for (final machine in pinLoadedMachines)
          _inKilograms(machine, newId, kilogramStackName),
      ],
    ),
  };
}

const _barbellTypeId = 'barbell';
const _poundsPerKilogram = 2.20462;

LoadableBars _poundBar(LoadableBars bar) {
  final fortyFive = bar.baseWeights
      .where(
        (weight) =>
            weight.unit == ExerciseWeightUnit.pounds &&
            (weight.baseWeight - 45).abs() < 0.001,
      )
      .firstOrNull;
  if (bar.typeId != _barbellTypeId || fortyFive == null) return bar;
  return LoadableBars.fromFirestore({
    ...bar.toFirestore(),
    GymEquipmentKeys.baseWeights: [
      for (final weight in bar.baseWeights)
        {
          ...weight.toFirestore(),
          if (weight.id == fortyFive.id) GymEquipmentKeys.isActive: true,
        },
    ],
    GymEquipmentKeys.chosenBaseWeightId: fortyFive.id,
  });
}

/// `StackMachine.inKilograms`: the kilogram stack it has, or one of the
/// same reach in fives (300 lb is 135 kg), switched on and made the
/// default, and its pound stacks switched off.
StackMachine _inKilograms(
  StackMachine machine,
  String Function() newId,
  String kilogramStackName,
) {
  final ranges = [...machine.ranges];
  if (!ranges.any((stack) => stack.unit == ExerciseWeightUnit.kilograms)) {
    // Every stack here is in pounds.
    final reach = ranges.isEmpty
        ? 100.0
        : ranges
              .map((stack) => stack.maxWeight / _poundsPerKilogram)
              .reduce(max);
    ranges.add(
      WeightStack(
        id: newId(),
        name: kilogramStackName,
        minWeight: 5,
        maxWeight: max<double>(5, (reach / 5).floorToDouble() * 5),
        increment: 5,
        unit: ExerciseWeightUnit.kilograms,
        isActive: true,
      ),
    );
  }
  return StackMachine.fromFirestore({
    ...machine.toFirestore(),
    GymEquipmentKeys.ranges: [
      for (final stack in ranges)
        {
          ...stack.toFirestore(),
          GymEquipmentKeys.isActive: stack.unit == ExerciseWeightUnit.kilograms,
        },
    ],
    GymEquipmentKeys.defaultRangeId: ranges
        .firstWhere((stack) => stack.unit == ExerciseWeightUnit.kilograms)
        .id,
  });
}

GymProfileModel _copy(
  GymProfileModel gym, {
  String? name,
  DateTime? dateModified,
  List<LoadableBars>? loadableBars,
  List<StackMachine>? cableMachines,
  List<StackMachine>? pinLoadedMachines,
}) => GymProfileModel(
  id: gym.id,
  authorId: gym.authorId,
  name: name ?? gym.name,
  imageUrl: gym.imageUrl,
  icon: gym.icon,
  dateCreated: gym.dateCreated,
  dateModified: dateModified ?? gym.dateModified,
  deletedAt: gym.deletedAt,
  freeWeights: gym.freeWeights,
  loadableBars: loadableBars ?? gym.loadableBars,
  fixedWeightBars: gym.fixedWeightBars,
  bands: gym.bands,
  bodyWeights: gym.bodyWeights,
  supportEquipment: gym.supportEquipment,
  accessoryEquipment: gym.accessoryEquipment,
  loadableAccessoryEquipment: gym.loadableAccessoryEquipment,
  cableMachines: cableMachines ?? gym.cableMachines,
  plateLoadedMachines: gym.plateLoadedMachines,
  pinLoadedMachines: pinLoadedMachines ?? gym.pinLoadedMachines,
);
