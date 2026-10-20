import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/training_enums.dart';

/// Field names of a [SetTarget], exactly as the Swift `CodingKeys` spell
/// them.
abstract final class SetTargetKeys {
  /// `id`.
  static const id = 'id';

  /// `set_number`.
  static const setNumber = 'set_number';

  /// `min_reps`.
  static const minReps = 'min_reps';

  /// `max_reps`.
  static const maxReps = 'max_reps';

  /// `rir_target`.
  static const rirTarget = 'rir_target';

  /// `set_type`.
  static const setType = 'set_type';

  /// `drop_count`.
  static const dropCount = 'drop_count';

  /// `drop_step_percent`.
  static const dropStepPercent = 'drop_step_percent';

  /// `drop_reps`.
  static const dropReps = 'drop_reps';

  /// `mini_set_count`.
  static const miniSetCount = 'mini_set_count';

  /// `amrap_target_reps`.
  static const amrapTargetReps = 'amrap_target_reps';

  /// `partial_reps`.
  static const partialReps = 'partial_reps';

  /// `hold_seconds`.
  static const holdSeconds = 'hold_seconds';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    setNumber,
    minReps,
    maxReps,
    rirTarget,
    setType,
    dropCount,
    dropStepPercent,
    dropReps,
    miniSetCount,
    amrapTargetReps,
    partialReps,
    holdSeconds,
  ];
}

/// What a template asks of one set (Swift `SetTarget`).
class const SetTarget({
  /// The target's id.
  required final String id,

  /// Its place among the exercise's sets, from 1.
  required final int setNumber,

  /// The bottom of the rep range.
  final int? minReps,

  /// The top of the rep range.
  final int? maxReps,

  /// Reps in reserve to aim for.
  final int? rirTarget,

  /// The kind of set.
  final SetTargetSetType setType = SetTargetSetType.standard,

  /// A drop set's drops after its first piece.
  final int? dropCount,

  /// How much lighter each drop is, in per cent; absent means 20.
  final int? dropStepPercent,

  /// The reps each drop asks for; absent means to failure.
  final int? dropReps,

  /// A myo-rep, rest-pause or cluster set's mini-sets.
  final int? miniSetCount,

  /// The reps an AMRAP set sets out to beat.
  final int? amrapTargetReps,

  /// Partial reps after a partials set; absent means to failure.
  final int? partialReps,

  /// How long a stretch or hold lasts, in seconds.
  final int? holdSeconds,
}) {
  /// Creates a [SetTarget].
  this;

  /// Decodes as Swift does: strictly, except `set_type`, which must be
  /// present but reads any value (see [SetTargetSetType.fromFirestore]).
  factory fromFirestore(Map<String, Object?> data) {
    if (!data.containsKey(SetTargetKeys.setType)) {
      throw const FormatException('set_type is missing');
    }
    return SetTarget(
      id: data[SetTargetKeys.id]! as String,
      setNumber: readInt(data[SetTargetKeys.setNumber]),
      minReps: readOptionalInt(data[SetTargetKeys.minReps]),
      maxReps: readOptionalInt(data[SetTargetKeys.maxReps]),
      rirTarget: readOptionalInt(data[SetTargetKeys.rirTarget]),
      setType: SetTargetSetType.fromFirestore(data[SetTargetKeys.setType]),
      dropCount: readOptionalInt(data[SetTargetKeys.dropCount]),
      dropStepPercent: readOptionalInt(data[SetTargetKeys.dropStepPercent]),
      dropReps: readOptionalInt(data[SetTargetKeys.dropReps]),
      miniSetCount: readOptionalInt(data[SetTargetKeys.miniSetCount]),
      amrapTargetReps: readOptionalInt(data[SetTargetKeys.amrapTargetReps]),
      partialReps: readOptionalInt(data[SetTargetKeys.partialReps]),
      holdSeconds: readOptionalInt(data[SetTargetKeys.holdSeconds]),
    );
  }

  /// The Firestore-shaped map Swift writes: `set_type` as a plain string,
  /// and a null field left out.
  Map<String, Object?> toFirestore() => {
    SetTargetKeys.id: id,
    SetTargetKeys.setNumber: setNumber,
    SetTargetKeys.minReps: ?minReps,
    SetTargetKeys.maxReps: ?maxReps,
    SetTargetKeys.rirTarget: ?rirTarget,
    SetTargetKeys.setType: setType.value,
    SetTargetKeys.dropCount: ?dropCount,
    SetTargetKeys.dropStepPercent: ?dropStepPercent,
    SetTargetKeys.dropReps: ?dropReps,
    SetTargetKeys.miniSetCount: ?miniSetCount,
    SetTargetKeys.amrapTargetReps: ?amrapTargetReps,
    SetTargetKeys.partialReps: ?partialReps,
    SetTargetKeys.holdSeconds: ?holdSeconds,
  };
}
