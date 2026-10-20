import 'package:compound_models/src/firestore_enum.dart';

/// Sex for the calorie estimate (Swift `Gender`).
enum Gender implements FirestoreEnum {
  /// `male`.
  male('male'),

  /// `female`.
  female('female'),

  /// `prefer_not_to_say`.
  preferNotToSay('prefer_not_to_say');

  new(this.value);

  @override
  final String value;
}

/// How often the user exercises (Swift `ExerciseFrequency`).
enum ExerciseFrequency implements FirestoreEnum {
  /// `never`.
  never('never'),

  /// `1-2`.
  oneToTwo('1-2'),

  /// `3-4`.
  threeToFour('3-4'),

  /// `5-6`.
  fiveToSix('5-6'),

  /// `daily`.
  daily('daily');

  new(this.value);

  @override
  final String value;
}

/// Daily activity outside exercise (Swift `ActivityLevel`).
enum ActivityLevel implements FirestoreEnum {
  /// `sedentary`.
  sedentary('sedentary'),

  /// `light`.
  light('light'),

  /// `moderate`.
  moderate('moderate'),

  /// `active`.
  active('active'),

  /// `very_active`.
  veryActive('very_active');

  new(this.value);

  @override
  final String value;
}

/// Cardio fitness (Swift `CardioFitnessLevel`).
enum CardioFitnessLevel implements FirestoreEnum {
  /// `beginner`.
  beginner('beginner'),

  /// `novice`.
  novice('novice'),

  /// `intermediate`.
  intermediate('intermediate'),

  /// `advanced`.
  advanced('advanced'),

  /// `elite`.
  elite('elite');

  new(this.value);

  @override
  final String value;
}

/// Unit for height and body measurements (Swift `LengthUnitPreference`).
enum LengthUnitPreference implements FirestoreEnum {
  /// `centimeters`.
  centimeters('centimeters'),

  /// `inches`.
  inches('inches');

  new(this.value);

  @override
  final String value;
}

/// Unit for weights (Swift `WeightUnitPreference`).
enum WeightUnitPreference implements FirestoreEnum {
  /// `kilograms`.
  kilograms('kilograms'),

  /// `pounds`.
  pounds('pounds');

  new(this.value);

  @override
  final String value;
}

/// Unit for distances (Swift `DistanceUnitPreference`).
enum DistanceUnitPreference implements FirestoreEnum {
  /// `kilometers`.
  kilometers('kilometers'),

  /// `miles`.
  miles('miles');

  new(this.value);

  @override
  final String value;
}
