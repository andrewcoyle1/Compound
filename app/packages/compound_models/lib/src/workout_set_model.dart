import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/training_enums.dart';

/// Field names of a [WorkoutSetModel], exactly as the Swift `CodingKeys`
/// spell them. `isWarmup` alone is camelCase.
abstract final class WorkoutSetModelKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `index`.
  static const index = 'index';

  /// `reps`.
  static const reps = 'reps';

  /// `weight_kg`.
  static const weightKg = 'weight_kg';

  /// `duration_sec`.
  static const durationSec = 'duration_sec';

  /// `distance_meters`.
  static const distanceMeters = 'distance_meters';

  /// `rpe`.
  static const rpe = 'rpe';

  /// `side`.
  static const side = 'side';

  /// `kind`.
  static const kind = 'kind';

  /// `parent_set_id`.
  static const parentSetId = 'parent_set_id';

  /// `target_reps`.
  static const targetReps = 'target_reps';

  /// `bands`.
  static const bands = 'bands';

  /// `weight_unit`.
  static const weightUnit = 'weight_unit';

  /// `load_count`.
  static const loadCount = 'load_count';

  /// `machine_base_kg`.
  static const machineBaseKg = 'machine_base_kg';

  /// `isWarmup`: camelCase, unlike every other field.
  static const isWarmup = 'isWarmup';

  /// `completed_at`.
  static const completedAt = 'completed_at';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    index,
    reps,
    weightKg,
    durationSec,
    distanceMeters,
    rpe,
    side,
    kind,
    parentSetId,
    targetReps,
    bands,
    weightUnit,
    loadCount,
    machineBaseKg,
    isWarmup,
    completedAt,
    dateCreated,
  ];
}

/// One logged or planned set of a session's exercise (Swift
/// `WorkoutSetModel`).
///
/// `side`, `kind` and `weight_unit` are kept as the stored strings, as
/// Swift keeps them, so a value a later build writes survives a read and a
/// write unchanged; [side], [kind] and [weightUnit] read them.
class const WorkoutSetModel({
  /// The set's id.
  required final String id,

  /// The session's author.
  required final String authorId,

  /// Its number in the exercise, warm-ups included, from 1.
  required final int index,

  /// Whether this is a warm-up set.
  required final bool isWarmup,

  /// When the set was created.
  required final DateTime dateCreated,

  /// Reps done.
  final int? reps,

  /// The total weight in kg, a machine base included.
  final double? weightKg,

  /// Time under load, in seconds.
  final int? durationSec,

  /// Distance covered, in meters.
  final double? distanceMeters,

  /// Rate of perceived exertion.
  final double? rpe,

  /// The stored `side`, read through [side].
  final String? sideRawValue,

  /// The stored `kind`, read through [kind]; absent means standard.
  final String? kindRawValue,

  /// The set this row is a drop, mini-set or cluster of.
  final String? parentSetId,

  /// The reps an AMRAP set sets out to beat.
  final int? targetReps,

  /// Resistance bands used, by name.
  final List<String>? bands,

  /// The stored `weight_unit`, read through [weightUnit].
  final String? weightUnitRawValue,

  /// How many of the weight were lifted at once; absent is one.
  final int? loadCount,

  /// A plate-loaded machine's base weight in kg, entered without it.
  final double? machineBaseKg,

  /// When the set was logged; absent while it is still to do.
  final DateTime? completedAt,
}) {
  /// Creates a [WorkoutSetModel].
  this;

  /// Decodes as Swift's hand-written decoder does: strictly, except that
  /// `bands`, `weight_unit`, `load_count` and `machine_base_kg` read as
  /// absent when they cannot be read, so one bad field never costs the
  /// session.
  factory fromFirestore(Map<String, Object?> data) => WorkoutSetModel(
    id: data[WorkoutSetModelKeys.id]! as String,
    authorId: data[WorkoutSetModelKeys.authorId]! as String,
    index: readInt(data[WorkoutSetModelKeys.index]),
    reps: readOptionalInt(data[WorkoutSetModelKeys.reps]),
    weightKg: readOptionalDouble(data[WorkoutSetModelKeys.weightKg]),
    durationSec: readOptionalInt(data[WorkoutSetModelKeys.durationSec]),
    distanceMeters: readOptionalDouble(
      data[WorkoutSetModelKeys.distanceMeters],
    ),
    rpe: readOptionalDouble(data[WorkoutSetModelKeys.rpe]),
    sideRawValue: data[WorkoutSetModelKeys.side] as String?,
    kindRawValue: data[WorkoutSetModelKeys.kind] as String?,
    parentSetId: data[WorkoutSetModelKeys.parentSetId] as String?,
    targetReps: readOptionalInt(data[WorkoutSetModelKeys.targetReps]),
    bands: lenientStringList(data[WorkoutSetModelKeys.bands]),
    weightUnitRawValue: lenientString(data[WorkoutSetModelKeys.weightUnit]),
    loadCount: lenientInt(data[WorkoutSetModelKeys.loadCount]),
    machineBaseKg: lenientDouble(data[WorkoutSetModelKeys.machineBaseKg]),
    isWarmup: data[WorkoutSetModelKeys.isWarmup]! as bool,
    completedAt: data[WorkoutSetModelKeys.completedAt] as DateTime?,
    dateCreated: data[WorkoutSetModelKeys.dateCreated]! as DateTime,
  );

  /// The limb the set was worked with; null when not one-sided or unknown.
  SetSide? get side => enumFromValueOrNull(SetSide.values, sideRawValue);

  /// How the set is performed; an absent or unknown kind is standard.
  SetKind get kind =>
      enumFromValueOrNull(SetKind.values, kindRawValue) ?? SetKind.standard;

  /// The unit the weight was entered in; null when unrecorded or unknown.
  ExerciseWeightUnit? get weightUnit =>
      enumFromValueOrNull(ExerciseWeightUnit.values, weightUnitRawValue);

  /// The Firestore-shaped map Swift writes: a null field is left out.
  Map<String, Object?> toFirestore() => {
    WorkoutSetModelKeys.id: id,
    WorkoutSetModelKeys.authorId: authorId,
    WorkoutSetModelKeys.index: index,
    WorkoutSetModelKeys.reps: ?reps,
    WorkoutSetModelKeys.weightKg: ?weightKg,
    WorkoutSetModelKeys.durationSec: ?durationSec,
    WorkoutSetModelKeys.distanceMeters: ?distanceMeters,
    WorkoutSetModelKeys.rpe: ?rpe,
    WorkoutSetModelKeys.side: ?sideRawValue,
    WorkoutSetModelKeys.kind: ?kindRawValue,
    WorkoutSetModelKeys.parentSetId: ?parentSetId,
    WorkoutSetModelKeys.targetReps: ?targetReps,
    WorkoutSetModelKeys.bands: ?bands,
    WorkoutSetModelKeys.weightUnit: ?weightUnitRawValue,
    WorkoutSetModelKeys.loadCount: ?loadCount,
    WorkoutSetModelKeys.machineBaseKg: ?machineBaseKg,
    WorkoutSetModelKeys.isWarmup: isWarmup,
    WorkoutSetModelKeys.completedAt: ?completedAt,
    WorkoutSetModelKeys.dateCreated: dateCreated,
  };
}
