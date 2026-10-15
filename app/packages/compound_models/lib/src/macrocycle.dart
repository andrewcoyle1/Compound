import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/training_enums.dart';

/// Field names of a [Macrocycle], exactly as the Swift `CodingKeys` spell
/// them.
abstract final class MacrocycleKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `name`.
  static const name = 'name';

  /// `mesocycle_ids`.
  static const mesocycleIds = 'mesocycle_ids';

  /// `status`.
  static const status = 'status';

  /// `mesocycle_index`.
  static const mesocycleIndex = 'mesocycle_index';

  /// `mesocycle_started_at`.
  static const mesocycleStartedAt = 'mesocycle_started_at';

  /// `start_microcycle_index`.
  static const startMicrocycleIndex = 'start_microcycle_index';

  /// `skips`.
  static const skips = 'skips';

  /// `iteration`.
  static const iteration = 'iteration';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `date_modified`.
  static const dateModified = 'date_modified';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    name,
    mesocycleIds,
    status,
    mesocycleIndex,
    mesocycleStartedAt,
    startMicrocycleIndex,
    skips,
    iteration,
    dateCreated,
    dateModified,
  ];
}

/// An ordered list of mesocycles and where the user is in it, at
/// `users/{uid}/macrocycles/{id}` (Swift `Macrocycle`).
class const Macrocycle({
  /// The macrocycle's id.
  required final String id,

  /// Its owner's user id.
  required final String authorId,

  /// Its name.
  required final String name,

  /// The mesocycles, in order.
  required final List<String> mesocycleIds,

  /// Only sessions finished after this count towards the current
  /// mesocycle.
  required final DateTime mesocycleStartedAt,

  /// When it was made.
  required final DateTime dateCreated,

  /// When it was last changed.
  required final DateTime dateModified,

  /// Where it stands.
  final MacrocycleStatus status = MacrocycleStatus.active,

  /// The current mesocycle, from 0.
  final int mesocycleIndex = 0,

  /// The microcycle the current mesocycle was joined at, from 0; null from
  /// the first.
  final int? startMicrocycleIndex,

  /// The day plans skipped.
  final List<CycleSkip> skips = const [],

  /// How many times it has been started, from 1.
  final int iteration = 1,
}) {
  /// Creates a [Macrocycle].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does; a null
  /// [startMicrocycleIndex] reads as absent.
  factory fromFirestore(Map<String, Object?> data) => Macrocycle(
    id: data[MacrocycleKeys.id]! as String,
    authorId: data[MacrocycleKeys.authorId]! as String,
    name: data[MacrocycleKeys.name]! as String,
    mesocycleIds: readStringList(data[MacrocycleKeys.mesocycleIds]),
    status: enumFromValue(
      MacrocycleStatus.values,
      data[MacrocycleKeys.status]! as String,
    ),
    mesocycleIndex: readInt(data[MacrocycleKeys.mesocycleIndex]),
    mesocycleStartedAt: data[MacrocycleKeys.mesocycleStartedAt]! as DateTime,
    startMicrocycleIndex: readOptionalInt(
      data[MacrocycleKeys.startMicrocycleIndex],
    ),
    skips: [
      for (final skip in data[MacrocycleKeys.skips]! as List<Object?>)
        CycleSkip.fromFirestore(readMap(skip)),
    ],
    iteration: readInt(data[MacrocycleKeys.iteration]),
    dateCreated: data[MacrocycleKeys.dateCreated]! as DateTime,
    dateModified: data[MacrocycleKeys.dateModified]! as DateTime,
  );

  /// The Firestore-shaped map Swift writes, a null field left out.
  Map<String, Object?> toFirestore() => {
    MacrocycleKeys.id: id,
    MacrocycleKeys.authorId: authorId,
    MacrocycleKeys.name: name,
    MacrocycleKeys.mesocycleIds: mesocycleIds,
    MacrocycleKeys.status: status.value,
    MacrocycleKeys.mesocycleIndex: mesocycleIndex,
    MacrocycleKeys.mesocycleStartedAt: mesocycleStartedAt,
    MacrocycleKeys.startMicrocycleIndex: ?startMicrocycleIndex,
    MacrocycleKeys.skips: [for (final skip in skips) skip.toFirestore()],
    MacrocycleKeys.iteration: iteration,
    MacrocycleKeys.dateCreated: dateCreated,
    MacrocycleKeys.dateModified: dateModified,
  };
}

/// Field names of a [CycleSkip], exactly as the Swift `CodingKeys` spell
/// them.
abstract final class CycleSkipKeys {
  /// `mesocycle_index`.
  static const mesocycleIndex = 'mesocycle_index';

  /// `cycle_index`.
  static const cycleIndex = 'cycle_index';

  /// `position`.
  static const position = 'position';

  /// `template_id`.
  static const templateId = 'template_id';

  /// `date`.
  static const date = 'date';
}

/// A day plan the user skipped (Swift `CycleSkip`).
class const CycleSkip({
  /// The mesocycle it was in, from 0.
  required final int mesocycleIndex,

  /// The microcycle it was in, from 0.
  required final int cycleIndex,

  /// The day plan's place in the microcycle, from 0.
  required final int position,

  /// The day plan's id.
  required final String templateId,

  /// When it was skipped.
  required final DateTime date,
}) {
  /// Creates a [CycleSkip].
  this;

  /// Decodes strictly, as Swift does.
  factory fromFirestore(Map<String, Object?> data) => CycleSkip(
    mesocycleIndex: readInt(data[CycleSkipKeys.mesocycleIndex]),
    cycleIndex: readInt(data[CycleSkipKeys.cycleIndex]),
    position: readInt(data[CycleSkipKeys.position]),
    templateId: data[CycleSkipKeys.templateId]! as String,
    date: data[CycleSkipKeys.date]! as DateTime,
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    CycleSkipKeys.mesocycleIndex: mesocycleIndex,
    CycleSkipKeys.cycleIndex: cycleIndex,
    CycleSkipKeys.position: position,
    CycleSkipKeys.templateId: templateId,
    CycleSkipKeys.date: date,
  };
}
