/// What an exercise is loaded with in one session, decided as it joins
/// (`SessionLoadChoice.swift`): the variation, the unit its weights are
/// entered in, how many of the weight one set lifts, and a plate-loaded
/// machine's base.
library;

import 'package:compound_models/compound_models.dart' as m;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/src/library_exercise.dart';
import 'package:training_session/src/mapping.dart';
import 'package:training_session/src/model_copies.dart';
import 'package:training_session/src/weight_stepper.dart';

/// The user's units for one exercise (`ExerciseUnitPreference`), which the
/// Swift app keeps on the device.
class const UnitPreference({
  final m.ExerciseWeightUnit weightUnit = m.ExerciseWeightUnit.kilograms,

  /// Whether the user chose [weightUnit] for this exercise; when not, it is
  /// only the app-wide unit and the equipment's label wins.
  final bool weightUnitIsChosen = false,
});

String _key(m.EquipmentKind kind, String id) => '${kind.value}:$id';

/// Every item [gym] has switched on, as `kind:typeId`.
Set<String> _availableRefs(m.GymProfileModel gym) => {
  for (final (kind, items) in <(m.EquipmentKind, List<m.GymEquipmentItem>)>[
    (m.EquipmentKind.freeWeight, gym.freeWeights),
    (m.EquipmentKind.loadableBar, gym.loadableBars),
    (m.EquipmentKind.fixedWeightBar, gym.fixedWeightBars),
    (m.EquipmentKind.bands, gym.bands),
    (m.EquipmentKind.bodyWeight, gym.bodyWeights),
    (m.EquipmentKind.supportEquipment, gym.supportEquipment),
    (m.EquipmentKind.accessoryEquipment, gym.accessoryEquipment),
    (
      m.EquipmentKind.loadableAccessoryEquipment,
      gym.loadableAccessoryEquipment,
    ),
    (m.EquipmentKind.cableMachine, gym.cableMachines),
    (m.EquipmentKind.plateLoadedMachine, gym.plateLoadedMachines),
    (m.EquipmentKind.pinLoadedMachine, gym.pinLoadedMachines),
  ])
    for (final item in items)
      if (item.isActive) _key(kind, item.typeId),
};

/// The choices (`enum SessionLoadChoice`).
abstract final class SessionLoadChoice {
  /// The variation the exercise starts on: last time's when that session
  /// was in this gym and the gym can still do it, else the first this gym
  /// can do, else the first.
  static String? variationId({
    required List<m.EquipmentVariation> variations,
    required m.WorkoutExerciseModel? previous,
    required String? previousGymId,
    required m.GymProfileModel? gym,
  }) {
    final available = gym == null ? null : _availableRefs(gym);
    bool isPerformable(m.EquipmentVariation variation) =>
        available == null ||
        [
          ...variation.resistanceEquipment,
          ...variation.supportEquipment,
        ].every((ref) => available.contains(_key(ref.kind, ref.equipmentId)));
    final used = previous?.activeVariation?.id;
    if (previous != null && previousGymId == gym?.id && used != null) {
      final variation = variations.where((v) => v.id == used).firstOrNull;
      if (variation != null && isPerformable(variation)) return variation.id;
    }
    return (variations.where(isPerformable).firstOrNull ??
            variations.firstOrNull)
        ?.id;
  }

  /// The user's choice for the exercise, else the unit the equipment is
  /// labelled in, else the app-wide unit.
  static m.ExerciseWeightUnit? weightUnit({
    required UnitPreference? preference,
    required List<m.EquipmentRef>? refs,
    required m.GymProfileModel? gym,
  }) {
    if (preference != null && preference.weightUnitIsChosen) {
      return preference.weightUnit;
    }
    return WeightStepper.equipmentUnit(refs, gym) ?? preference?.weightUnit;
  }

  /// 2 for a weight in each hand: `weightPerSide` on an exercise not worked
  /// a side at a time.
  static int? loadsPerSet(m.ExerciseModel exercise) =>
      exercise.trackableMetrics.contains(
            m.TrackableExerciseMetric.weightPerSide,
          ) &&
          !exercise.isPerSide
      ? 2
      : null;

  /// The base, in kg, of the plate-loaded machine [refs] load on in [gym]
  /// when it is set to enter plates only; `null` otherwise.
  static double? machineBaseKg({
    required List<m.EquipmentRef>? refs,
    required m.GymProfileModel? gym,
  }) {
    if (gym == null || refs == null) return null;
    for (final ref in refs) {
      if (ref.kind != m.EquipmentKind.plateLoadedMachine) continue;
      final machine = gym.plateLoadedMachines
          .where((item) => item.typeId == ref.equipmentId && item.isActive)
          .firstOrNull;
      if (machine == null) continue;
      if (!machine.excludesBaseFromLoad || machine.baseWeight <= 0) {
        return null;
      }
      return r.convertWeightToKg(machine.baseWeight, machine.unit.rules);
    }
    return null;
  }
}

/// The exercise put on [exercise]'s equipment as the session would choose
/// it in [gym]: added part-way through, or swapped in
/// (`WorkoutExerciseModel.takeLoad`).
m.WorkoutExerciseModel takingLoad(
  m.WorkoutExerciseModel session, {
  required m.ExerciseModel exercise,
  required m.GymProfileModel? gym,
  required UnitPreference? preference,
  m.WorkoutExerciseModel? previous,
  String? previousGymId,
}) {
  final chosen = SessionLoadChoice.variationId(
    variations: exercise.equipmentVariations,
    previous: previous,
    previousGymId: previousGymId,
    gym: gym,
  );
  final loaded = session.copyWith(
    equipmentVariations: exercise.equipmentVariations,
    chosenVariationId: chosen,
  );
  final refs = loaded.activeVariation?.resistanceEquipment;
  return loaded.copyWith(
    weightUnit: SessionLoadChoice.weightUnit(
      preference: preference,
      refs: refs,
      gym: gym,
    ),
    loadsPerSet: SessionLoadChoice.loadsPerSet(exercise),
    machineBaseKg: SessionLoadChoice.machineBaseKg(refs: refs, gym: gym),
  );
}

/// After the equipment or the gym changes: the unit again, and every open
/// set on a weight the new equipment makes (`refitLoad`). Logged sets keep
/// what was lifted.
m.WorkoutExerciseModel refittingLoad(
  m.WorkoutExerciseModel session, {
  required m.ExerciseModel? library,
  required m.GymProfileModel? gym,
  required UnitPreference? preference,
}) {
  final refs = session.activeVariation?.resistanceEquipment;
  final unit = SessionLoadChoice.weightUnit(
    preference: preference,
    refs: refs,
    gym: gym,
  );
  final rule = weightRoundingRule(
    exercise: library,
    gym: gym,
    preferredUnit: unit,
    resistanceEquipment: refs,
  );
  return session.copyWith(
    weightUnit: unit,
    machineBaseKg: SessionLoadChoice.machineBaseKg(refs: refs, gym: gym),
    sets: [
      for (final set in session.sets)
        if (set.completedAt == null && set.weightKg != null)
          set.copyWith(weightKg: rule.round(set.weightKg!))
        else
          set,
    ],
  );
}

/// Whether two variations lift the same kind of load (`isSameLoad`).
bool sameLoad(List<m.EquipmentRef>? lhs, List<m.EquipmentRef>? rhs) =>
    r.isSameLoad(rulesRefs(lhs), rulesRefs(rhs));
