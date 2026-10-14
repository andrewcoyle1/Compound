import 'package:compound_models/src/firestore_enum.dart';

/// What an exercise's sets record (Swift `TrackingMode`).
enum TrackingMode implements FirestoreEnum {
  /// `weightReps`.
  weightReps('weightReps'),

  /// `repsOnly`.
  repsOnly('repsOnly'),

  /// `timeOnly`.
  timeOnly('timeOnly'),

  /// `distanceTime`.
  distanceTime('distanceTime');

  new(this.value);

  @override
  final String value;
}

/// The limb a set was worked with (Swift `SetSide`).
enum SetSide implements FirestoreEnum {
  /// `left`.
  left('left'),

  /// `right`.
  right('right'),

  /// `both`: two limbs' work logged once.
  both('both');

  new(this.value);

  @override
  final String value;
}

/// How a set is performed, beyond its figures (Swift `SetKind`).
enum SetKind implements FirestoreEnum {
  /// `standard`, stored as no value at all.
  standard('standard'),

  /// `drop`.
  drop('drop'),

  /// `amrap`.
  amrap('amrap'),

  /// `myo`.
  myo('myo'),

  /// `restPause`.
  restPause('restPause'),

  /// `cluster`.
  cluster('cluster'),

  /// `partials`.
  partials('partials'),

  /// `stretch`.
  stretch('stretch'),

  /// `hold`.
  hold('hold');

  new(this.value);

  @override
  final String value;
}

/// The unit an exercise's weights are entered in (Swift
/// `ExerciseWeightUnit`).
enum ExerciseWeightUnit implements FirestoreEnum {
  /// `kilograms`.
  kilograms('kilograms'),

  /// `pounds`.
  pounds('pounds');

  new(this.value);

  @override
  final String value;
}

/// A gym's kinds of equipment (Swift `EquipmentKind`).
enum EquipmentKind implements FirestoreEnum {
  /// `freeWeight`.
  freeWeight('freeWeight'),

  /// `loadableBar`.
  loadableBar('loadableBar'),

  /// `fixedWeightBar`.
  fixedWeightBar('fixedWeightBar'),

  /// `bands`.
  bands('bands'),

  /// `bodyWeight`.
  bodyWeight('bodyWeight'),

  /// `supportEquipment`.
  supportEquipment('supportEquipment'),

  /// `accessoryEquipment`.
  accessoryEquipment('accessoryEquipment'),

  /// `loadableAccessoryEquipment`.
  loadableAccessoryEquipment('loadableAccessoryEquipment'),

  /// `cableMachine`.
  cableMachine('cableMachine'),

  /// `plateLoadedMachine`.
  plateLoadedMachine('plateLoadedMachine'),

  /// `pinLoadedMachine`.
  pinLoadedMachine('pinLoadedMachine');

  new(this.value);

  @override
  final String value;
}

/// The kind of set a template's set target asks for (Swift
/// `SetTargetSetType`).
enum SetTargetSetType implements FirestoreEnum {
  /// `standard`.
  standard('standard'),

  /// `drop`.
  drop('drop'),

  /// `myo`.
  myo('myo'),

  /// `failure`: written before `amrap` existed, and read as an AMRAP set.
  failure('failure'),

  /// `amrap`.
  amrap('amrap'),

  /// `restPause`.
  restPause('restPause'),

  /// `cluster`.
  cluster('cluster'),

  /// `partials`.
  partials('partials'),

  /// `stretch`.
  stretch('stretch'),

  /// `hold`.
  hold('hold');

  new(this.value);

  /// Reads a stored set type as Swift does, never failing: a raw string,
  /// else a legacy `{"rawValue": …}` object, else a legacy `{"name": "Drop
  /// Set"}` object, else [standard]. It is always written back as a string.
  factory fromFirestore(Object? stored) {
    if (stored is String) {
      return enumFromValueOrNull(values, stored) ?? standard;
    }
    if (stored is Map) {
      return enumFromValueOrNull(values, stored['rawValue']) ??
          switch (stored['name']) {
            'Standard Set' => standard,
            'Drop Set' => drop,
            'Myo Set' => myo,
            'Failure Set' => failure,
            _ => standard,
          };
    }
    return standard;
  }

  @override
  final String value;
}
