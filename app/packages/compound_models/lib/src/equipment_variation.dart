import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/training_enums.dart';

/// Field names of an [EquipmentRef], exactly as the Swift `CodingKeys`
/// spell them.
abstract final class EquipmentRefKeys {
  /// `kind`.
  static const kind = 'kind';

  /// `id`.
  static const id = 'id';

  /// Every field, in declaration order.
  static const List<String> all = [kind, id];
}

/// One piece of a gym's equipment, by kind and id (Swift `EquipmentRef`).
class const EquipmentRef({
  /// The kind of equipment.
  required final EquipmentKind kind,

  /// The equipment's id within its kind, stored as `id`.
  required final String equipmentId,
}) {
  /// Creates an [EquipmentRef].
  this;

  /// Decodes strictly: an unknown kind throws, which drops this ref from a
  /// lossy list rather than the whole document.
  factory fromFirestore(Map<String, Object?> data) => EquipmentRef(
    kind: enumFromValue(
      EquipmentKind.values,
      data[EquipmentRefKeys.kind]! as String,
    ),
    equipmentId: data[EquipmentRefKeys.id]! as String,
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    EquipmentRefKeys.kind: kind.value,
    EquipmentRefKeys.id: equipmentId,
  };
}

/// Field names of an [EquipmentVariation], exactly as the Swift
/// `CodingKeys` spell them.
abstract final class EquipmentVariationKeys {
  /// `id`.
  static const id = 'id';

  /// `resistance_equipment`.
  static const resistanceEquipment = 'resistance_equipment';

  /// `support_equipment`.
  static const supportEquipment = 'support_equipment';

  /// Every field, in declaration order.
  static const List<String> all = [id, resistanceEquipment, supportEquipment];
}

/// One way of doing an exercise: the equipment that loads it and the
/// equipment that supports it (Swift `EquipmentVariation`).
class const EquipmentVariation({
  /// The variation's id.
  required final String id,

  /// What provides the resistance.
  final List<EquipmentRef> resistanceEquipment = const [],

  /// What supports the lift, such as a bench.
  final List<EquipmentRef> supportEquipment = const [],
}) {
  /// Creates an [EquipmentVariation].
  this;

  /// Decodes as Swift does: `id` is required, and each list is read ref by
  /// ref, skipping one Swift cannot read (a kind a later build added); a
  /// missing or unreadable list reads as empty.
  factory fromFirestore(Map<String, Object?> data) => EquipmentVariation(
    id: data[EquipmentVariationKeys.id]! as String,
    resistanceEquipment: _refs(
      data[EquipmentVariationKeys.resistanceEquipment],
    ),
    supportEquipment: _refs(data[EquipmentVariationKeys.supportEquipment]),
  );

  static List<EquipmentRef> _refs(Object? stored) =>
      lossyList(stored, (ref) => EquipmentRef.fromFirestore(readMap(ref))) ??
      const [];

  /// The Firestore-shaped map Swift writes; both lists are always written.
  Map<String, Object?> toFirestore() => {
    EquipmentVariationKeys.id: id,
    EquipmentVariationKeys.resistanceEquipment: [
      for (final ref in resistanceEquipment) ref.toFirestore(),
    ],
    EquipmentVariationKeys.supportEquipment: [
      for (final ref in supportEquipment) ref.toFirestore(),
    ],
  };
}
