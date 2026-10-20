import 'package:compound_models/src/body_enums.dart';
import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';

/// Field names of `users/{uid}/body_measurements/{id}`, exactly as the Swift
/// `CodingKeys` spell them.
///
/// Partial updates and queries take their field names only from here.
abstract final class BodyMeasurementEntryKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `weight_kg`.
  static const weightKg = 'weight_kg';

  /// `body_fat_percentage`.
  static const bodyFatPercentage = 'body_fat_percentage';

  /// `neck_circumference`.
  static const neckCircumference = 'neck_circumference';

  /// `shoulder_circumference`.
  static const shoulderCircumference = 'shoulder_circumference';

  /// `bust_circumference`.
  static const bustCircumference = 'bust_circumference';

  /// `chest_circumference`.
  static const chestCircumference = 'chest_circumference';

  /// `waist_circumference`.
  static const waistCircumference = 'waist_circumference';

  /// `hip_circumference`.
  static const hipCircumference = 'hip_circumference';

  /// `left_bicep_circumference`.
  static const leftBicepCircumference = 'left_bicep_circumference';

  /// `right_bicep_circumference`.
  static const rightBicepCircumference = 'right_bicep_circumference';

  /// `left_forearm_circumference`.
  static const leftForearmCircumference = 'left_forearm_circumference';

  /// `right_forearm_circumference`.
  static const rightForearmCircumference = 'right_forearm_circumference';

  /// `left_wrist_circumference`.
  static const leftWristCircumference = 'left_wrist_circumference';

  /// `right_wrist_circumference`.
  static const rightWristCircumference = 'right_wrist_circumference';

  /// `left_thigh_circumference`.
  static const leftThighCircumference = 'left_thigh_circumference';

  /// `right_thigh_circumference`.
  static const rightThighCircumference = 'right_thigh_circumference';

  /// `left_calf_circumference`.
  static const leftCalfCircumference = 'left_calf_circumference';

  /// `right_calf_circumference`.
  static const rightCalfCircumference = 'right_calf_circumference';

  /// `left_ankle_circumference`.
  static const leftAnkleCircumference = 'left_ankle_circumference';

  /// `right_ankle_circumference`.
  static const rightAnkleCircumference = 'right_ankle_circumference';

  /// `progress_photo_urls`.
  static const progressPhotoUrls = 'progress_photo_urls';

  /// `date`.
  static const date = 'date';

  /// `source`.
  static const source = 'source';

  /// `notes`.
  static const notes = 'notes';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `deleted_at`.
  static const deletedAt = 'deleted_at';

  /// `healthkit_uuid`.
  static const healthKitUuid = 'healthkit_uuid';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    weightKg,
    bodyFatPercentage,
    neckCircumference,
    shoulderCircumference,
    bustCircumference,
    chestCircumference,
    waistCircumference,
    hipCircumference,
    leftBicepCircumference,
    rightBicepCircumference,
    leftForearmCircumference,
    rightForearmCircumference,
    leftWristCircumference,
    rightWristCircumference,
    leftThighCircumference,
    rightThighCircumference,
    leftCalfCircumference,
    rightCalfCircumference,
    leftAnkleCircumference,
    rightAnkleCircumference,
    progressPhotoUrls,
    date,
    source,
    notes,
    dateCreated,
    deletedAt,
    healthKitUuid,
  ];
}

/// A weigh-in, body fat reading or set of circumferences at
/// `users/{uid}/body_measurements/{id}` (Swift `BodyMeasurementEntry`).
class const BodyMeasurementEntry({
  /// The entry's id, and the document id.
  required final String id,

  /// The user it belongs to.
  required final String authorId,

  /// When it was measured.
  required final DateTime date,

  /// Where it came from.
  required final WeightSource source,

  /// When it was logged.
  required final DateTime dateCreated,

  /// Scale weight, in kilograms.
  final double? weightKg,

  /// Body fat, in percent.
  final double? bodyFatPercentage,

  /// The neck circumference, in centimetres.
  final double? neckCircumference,

  /// The shoulder circumference, in centimetres.
  final double? shoulderCircumference,

  /// The bust circumference, in centimetres.
  final double? bustCircumference,

  /// The chest circumference, in centimetres.
  final double? chestCircumference,

  /// The waist circumference, in centimetres.
  final double? waistCircumference,

  /// The hip circumference, in centimetres.
  final double? hipCircumference,

  /// The left bicep circumference, in centimetres.
  final double? leftBicepCircumference,

  /// The right bicep circumference, in centimetres.
  final double? rightBicepCircumference,

  /// The left forearm circumference, in centimetres.
  final double? leftForearmCircumference,

  /// The right forearm circumference, in centimetres.
  final double? rightForearmCircumference,

  /// The left wrist circumference, in centimetres.
  final double? leftWristCircumference,

  /// The right wrist circumference, in centimetres.
  final double? rightWristCircumference,

  /// The left thigh circumference, in centimetres.
  final double? leftThighCircumference,

  /// The right thigh circumference, in centimetres.
  final double? rightThighCircumference,

  /// The left calf circumference, in centimetres.
  final double? leftCalfCircumference,

  /// The right calf circumference, in centimetres.
  final double? rightCalfCircumference,

  /// The left ankle circumference, in centimetres.
  final double? leftAnkleCircumference,

  /// The right ankle circumference, in centimetres.
  final double? rightAnkleCircumference,

  /// Progress photos, as download URLs.
  final List<String>? progressPhotoUrls,

  /// The user's notes.
  final String? notes,

  /// When it was deleted; screens leave such entries out.
  final DateTime? deletedAt,

  /// The Apple Health sample's UUID, upper case, as Swift's `UUID` writes it.
  final String? healthKitUuid,
}) {
  /// Creates a [BodyMeasurementEntry].
  this;

  /// Decodes as Swift's synthesized decoder does, strictly: a missing
  /// required field, a wrong type, an unknown source or a malformed
  /// `healthkit_uuid` throws. Unknown keys are ignored, a null optional
  /// reads as absent, and an integer reads as a double.
  factory fromFirestore(Map<String, Object?> data) => BodyMeasurementEntry(
    id: data[BodyMeasurementEntryKeys.id]! as String,
    authorId: data[BodyMeasurementEntryKeys.authorId]! as String,
    weightKg: readOptionalDouble(data[BodyMeasurementEntryKeys.weightKg]),
    bodyFatPercentage: readOptionalDouble(
      data[BodyMeasurementEntryKeys.bodyFatPercentage],
    ),
    neckCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.neckCircumference],
    ),
    shoulderCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.shoulderCircumference],
    ),
    bustCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.bustCircumference],
    ),
    chestCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.chestCircumference],
    ),
    waistCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.waistCircumference],
    ),
    hipCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.hipCircumference],
    ),
    leftBicepCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.leftBicepCircumference],
    ),
    rightBicepCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.rightBicepCircumference],
    ),
    leftForearmCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.leftForearmCircumference],
    ),
    rightForearmCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.rightForearmCircumference],
    ),
    leftWristCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.leftWristCircumference],
    ),
    rightWristCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.rightWristCircumference],
    ),
    leftThighCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.leftThighCircumference],
    ),
    rightThighCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.rightThighCircumference],
    ),
    leftCalfCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.leftCalfCircumference],
    ),
    rightCalfCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.rightCalfCircumference],
    ),
    leftAnkleCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.leftAnkleCircumference],
    ),
    rightAnkleCircumference: readOptionalDouble(
      data[BodyMeasurementEntryKeys.rightAnkleCircumference],
    ),
    progressPhotoUrls: data[BodyMeasurementEntryKeys.progressPhotoUrls] == null
        ? null
        : readStringList(data[BodyMeasurementEntryKeys.progressPhotoUrls]),
    date: data[BodyMeasurementEntryKeys.date]! as DateTime,
    source: enumFromValue(
      WeightSource.values,
      data[BodyMeasurementEntryKeys.source]! as String,
    ),
    notes: data[BodyMeasurementEntryKeys.notes] as String?,
    dateCreated: data[BodyMeasurementEntryKeys.dateCreated]! as DateTime,
    deletedAt: data[BodyMeasurementEntryKeys.deletedAt] as DateTime?,
    healthKitUuid: _readUuid(data[BodyMeasurementEntryKeys.healthKitUuid]),
  );

  /// The Firestore-shaped map Swift writes: a null field is left out.
  Map<String, Object?> toFirestore() => {
    BodyMeasurementEntryKeys.id: id,
    BodyMeasurementEntryKeys.authorId: authorId,
    BodyMeasurementEntryKeys.weightKg: ?weightKg,
    BodyMeasurementEntryKeys.bodyFatPercentage: ?bodyFatPercentage,
    BodyMeasurementEntryKeys.neckCircumference: ?neckCircumference,
    BodyMeasurementEntryKeys.shoulderCircumference: ?shoulderCircumference,
    BodyMeasurementEntryKeys.bustCircumference: ?bustCircumference,
    BodyMeasurementEntryKeys.chestCircumference: ?chestCircumference,
    BodyMeasurementEntryKeys.waistCircumference: ?waistCircumference,
    BodyMeasurementEntryKeys.hipCircumference: ?hipCircumference,
    BodyMeasurementEntryKeys.leftBicepCircumference: ?leftBicepCircumference,
    BodyMeasurementEntryKeys.rightBicepCircumference: ?rightBicepCircumference,
    BodyMeasurementEntryKeys.leftForearmCircumference:
        ?leftForearmCircumference,
    BodyMeasurementEntryKeys.rightForearmCircumference:
        ?rightForearmCircumference,
    BodyMeasurementEntryKeys.leftWristCircumference: ?leftWristCircumference,
    BodyMeasurementEntryKeys.rightWristCircumference: ?rightWristCircumference,
    BodyMeasurementEntryKeys.leftThighCircumference: ?leftThighCircumference,
    BodyMeasurementEntryKeys.rightThighCircumference: ?rightThighCircumference,
    BodyMeasurementEntryKeys.leftCalfCircumference: ?leftCalfCircumference,
    BodyMeasurementEntryKeys.rightCalfCircumference: ?rightCalfCircumference,
    BodyMeasurementEntryKeys.leftAnkleCircumference: ?leftAnkleCircumference,
    BodyMeasurementEntryKeys.rightAnkleCircumference: ?rightAnkleCircumference,
    BodyMeasurementEntryKeys.progressPhotoUrls: ?progressPhotoUrls,
    BodyMeasurementEntryKeys.date: date,
    BodyMeasurementEntryKeys.source: source.value,
    BodyMeasurementEntryKeys.notes: ?notes,
    BodyMeasurementEntryKeys.dateCreated: dateCreated,
    BodyMeasurementEntryKeys.deletedAt: ?deletedAt,
    BodyMeasurementEntryKeys.healthKitUuid: ?healthKitUuid,
  };
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// A Swift `UUID` field: a UUID string in either case, read upper case as
/// Swift re-encodes it. Anything else throws, as Swift's decoder fails.
String? _readUuid(Object? value) {
  if (value == null) return null;
  final string = value as String;
  if (!_uuid.hasMatch(string)) throw FormatException('Not a UUID', value);
  return string.toUpperCase();
}
