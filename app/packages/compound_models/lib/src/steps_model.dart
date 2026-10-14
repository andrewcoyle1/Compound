import 'package:compound_models/src/body_enums.dart';
import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';

/// Field names of `users/{uid}/steps/{id}`, exactly as the Swift
/// `CodingKeys` spell them.
///
/// Partial updates and queries take their field names only from here.
abstract final class StepsModelKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `number`.
  static const number = 'number';

  /// `date`.
  static const date = 'date';

  /// `source`.
  static const source = 'source';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `date_modified`.
  static const dateModified = 'date_modified';

  /// `deleted_at`.
  static const deletedAt = 'deleted_at';

  /// `healthkit_id`.
  static const healthKitId = 'healthkit_id';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    number,
    date,
    source,
    dateCreated,
    dateModified,
    deletedAt,
    healthKitId,
  ];
}

/// A step count at `users/{uid}/steps/{id}` (Swift `StepsModel`).
class const StepsModel({
  /// The entry's id, and the document id.
  required final String id,

  /// The user it belongs to.
  required final String authorId,

  /// The number of steps.
  required final int number,

  /// The day, or moment, it counts for.
  required final DateTime date,

  /// Where it came from.
  required final StepsSource source,

  /// When it was written.
  required final DateTime dateCreated,

  /// When it was last changed.
  required final DateTime dateModified,

  /// When it was deleted; screens leave such entries out.
  final DateTime? deletedAt,

  /// The Apple Health id it was imported under.
  final String? healthKitId,
}) {
  /// Creates a [StepsModel].
  this;

  /// Decodes as Swift's synthesized decoder does, strictly: a missing
  /// required field, a wrong type or an unknown source throws. Unknown keys
  /// are ignored, a null optional reads as absent, and a whole-number
  /// double reads as an integer.
  factory fromFirestore(Map<String, Object?> data) => StepsModel(
    id: data[StepsModelKeys.id]! as String,
    authorId: data[StepsModelKeys.authorId]! as String,
    number: readInt(data[StepsModelKeys.number]),
    date: data[StepsModelKeys.date]! as DateTime,
    source: enumFromValue(
      StepsSource.values,
      data[StepsModelKeys.source]! as String,
    ),
    dateCreated: data[StepsModelKeys.dateCreated]! as DateTime,
    dateModified: data[StepsModelKeys.dateModified]! as DateTime,
    deletedAt: data[StepsModelKeys.deletedAt] as DateTime?,
    healthKitId: data[StepsModelKeys.healthKitId] as String?,
  );

  /// The Firestore-shaped map Swift writes: a null field is left out.
  Map<String, Object?> toFirestore() => {
    StepsModelKeys.id: id,
    StepsModelKeys.authorId: authorId,
    StepsModelKeys.number: number,
    StepsModelKeys.date: date,
    StepsModelKeys.source: source.value,
    StepsModelKeys.dateCreated: dateCreated,
    StepsModelKeys.dateModified: dateModified,
    StepsModelKeys.deletedAt: ?deletedAt,
    StepsModelKeys.healthKitId: ?healthKitId,
  };
}
