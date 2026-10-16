/// The Body Metrics screens' arithmetic (Swift `BodyMeasurementKind`,
/// `BodyMetricsPresenter`, `BodyMeasurementDetailPresenter`,
/// `VisualBodyFatPresenter` and `BodyRatioPresenter.entries`): the one table
/// of the eighteen circumferences, and the readings each card and detail
/// screen shows. Pure, so the bloc and the widgets only read it.
library;

import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound_maths/compound_maths.dart'
    show BodyRatioKind, bodyRatio;
import 'package:compound_models/compound_models.dart';

/// Centimetres in an inch.
const centimetresPerInch = 2.54;

/// A whole-number wheel's span.
typedef WheelRange = ({int min, int max});

/// The circumferences the user can log, and everything that differs between
/// them: the stored field, both wheels' spans and where each opens. One
/// table, as Swift's, so the logger, the cards and the detail screen are
/// one module each, never eighteen. [name] is Swift's raw value.
enum BodyMeasurementKind {
  neck(
    BodyMeasurementEntryKeys.neckCircumference,
    (min: 10, max: 60),
    (min: 4, max: 24),
    40,
    16,
  ),
  shoulders(
    BodyMeasurementEntryKeys.shoulderCircumference,
    (min: 80, max: 150),
    (min: 32, max: 60),
    115,
    45,
  ),
  bust(
    BodyMeasurementEntryKeys.bustCircumference,
    (min: 70, max: 130),
    (min: 28, max: 52),
    95,
    37,
  ),
  chest(
    BodyMeasurementEntryKeys.chestCircumference,
    (min: 80, max: 140),
    (min: 32, max: 56),
    105,
    41,
  ),
  waist(
    BodyMeasurementEntryKeys.waistCircumference,
    (min: 60, max: 120),
    (min: 24, max: 48),
    80,
    32,
  ),
  hips(
    BodyMeasurementEntryKeys.hipCircumference,
    (min: 80, max: 130),
    (min: 32, max: 52),
    95,
    37,
  ),
  leftBicep(
    BodyMeasurementEntryKeys.leftBicepCircumference,
    (min: 25, max: 50),
    (min: 10, max: 20),
    35,
    14,
  ),
  rightBicep(
    BodyMeasurementEntryKeys.rightBicepCircumference,
    (min: 25, max: 50),
    (min: 10, max: 20),
    35,
    14,
  ),
  leftForearm(
    BodyMeasurementEntryKeys.leftForearmCircumference,
    (min: 20, max: 40),
    (min: 8, max: 16),
    30,
    12,
  ),
  rightForearm(
    BodyMeasurementEntryKeys.rightForearmCircumference,
    (min: 20, max: 40),
    (min: 8, max: 16),
    30,
    12,
  ),
  leftWrist(
    BodyMeasurementEntryKeys.leftWristCircumference,
    (min: 15, max: 25),
    (min: 6, max: 10),
    18,
    7,
  ),
  rightWrist(
    BodyMeasurementEntryKeys.rightWristCircumference,
    (min: 15, max: 25),
    (min: 6, max: 10),
    18,
    7,
  ),
  leftThigh(
    BodyMeasurementEntryKeys.leftThighCircumference,
    (min: 45, max: 80),
    (min: 18, max: 32),
    60,
    24,
  ),
  rightThigh(
    BodyMeasurementEntryKeys.rightThighCircumference,
    (min: 45, max: 80),
    (min: 18, max: 32),
    60,
    24,
  ),
  leftCalf(
    BodyMeasurementEntryKeys.leftCalfCircumference,
    (min: 30, max: 50),
    (min: 12, max: 20),
    38,
    15,
  ),
  rightCalf(
    BodyMeasurementEntryKeys.rightCalfCircumference,
    (min: 30, max: 50),
    (min: 12, max: 20),
    38,
    15,
  ),
  leftAnkle(
    BodyMeasurementEntryKeys.leftAnkleCircumference,
    (min: 18, max: 30),
    (min: 7, max: 12),
    22,
    9,
  ),
  rightAnkle(
    BodyMeasurementEntryKeys.rightAnkleCircumference,
    (min: 18, max: 30),
    (min: 7, max: 12),
    22,
    9,
  );

  new(
    this.key,
    this.centimetres,
    this.inches,
    this.defaultCentimetres,
    this.defaultInches,
  );

  /// The stored field, in centimetres.
  final String key;

  /// The centimetre wheel's span.
  final WheelRange centimetres;

  /// The inch wheel's span.
  final WheelRange inches;

  /// Where the centimetre wheel opens with nothing logged.
  final int defaultCentimetres;

  /// Where the inch wheel opens with nothing logged.
  final int defaultInches;

  /// This measurement on [entry], in centimetres, if logged.
  double? valueOf(BodyMeasurementEntry entry) =>
      entry.toFirestore()[key] as double?;

  /// [entry] with this measurement set to [centimetres], every other field
  /// as it was (Swift `withUpdated`).
  BodyMeasurementEntry update(BodyMeasurementEntry entry, double centimetres) =>
      BodyMeasurementEntry.fromFirestore({
        ...entry.toFirestore(),
        key: centimetres,
      });

  /// The kind whose raw value is [name], if any.
  static BodyMeasurementKind? tryParse(String? name) =>
      values.where((kind) => kind.name == name).firstOrNull;
}

/// A group of cards on Body Metrics, in Swift's order.
enum BodyMetricsGroup {
  /// Scale weight and visual body fat.
  weightAndBodyFat([]),

  /// Neck to hips.
  upperBody([
    BodyMeasurementKind.neck,
    BodyMeasurementKind.shoulders,
    BodyMeasurementKind.bust,
    BodyMeasurementKind.chest,
    BodyMeasurementKind.waist,
    BodyMeasurementKind.hips,
  ]),

  /// Biceps, forearms and wrists.
  arms([
    BodyMeasurementKind.leftBicep,
    BodyMeasurementKind.rightBicep,
    BodyMeasurementKind.leftForearm,
    BodyMeasurementKind.rightForearm,
    BodyMeasurementKind.leftWrist,
    BodyMeasurementKind.rightWrist,
  ]),

  /// Thighs, calves and ankles.
  legs([
    BodyMeasurementKind.leftThigh,
    BodyMeasurementKind.rightThigh,
    BodyMeasurementKind.leftCalf,
    BodyMeasurementKind.rightCalf,
    BodyMeasurementKind.leftAnkle,
    BodyMeasurementKind.rightAnkle,
  ]);

  new(this.kinds);

  /// Its circumferences.
  final List<BodyMeasurementKind> kinds;
}

/// [measurements] that are not deleted and have a reading for [value], as
/// that reading, oldest first.
List<MetricPoint> readingsOf(
  Iterable<BodyMeasurementEntry> measurements,
  double? Function(BodyMeasurementEntry entry) value,
) => [
  for (final entry in measurements)
    if (entry.deletedAt == null)
      if (value(entry) case final reading?) (date: entry.date, value: reading),
]..sort((a, b) => a.date.compareTo(b.date));

/// Like [readingsOf], with each reading's entry id, for deleting it.
List<({String id, DateTime date, double value})> entriesOf(
  Iterable<BodyMeasurementEntry> measurements,
  double? Function(BodyMeasurementEntry entry) value,
) => [
  for (final entry in measurements)
    if (entry.deletedAt == null)
      if (value(entry) case final reading?)
        (id: entry.id, date: entry.date, value: reading),
]..sort((a, b) => a.date.compareTo(b.date));

/// Each entry's [kind] ratio, oldest first: the waist over the profile's
/// [heightCm], or over the same entry's hips.
double? Function(BodyMeasurementEntry entry) ratioOf(
  BodyRatioKind kind, {
  double? heightCm,
}) =>
    (entry) => bodyRatio(
      kind,
      waistCm: entry.waistCircumference,
      hipCm: entry.hipCircumference,
      heightCm: heightCm,
    );

/// [centimetres] in [unit].
double inLength(double centimetres, LengthUnitPreference? unit) =>
    unit == LengthUnitPreference.inches
    ? centimetres / centimetresPerInch
    : centimetres;
