import 'package:compound_models/src/firestore_values.dart';

/// Field names of an [ExerciseSettingsModel], exactly as the Swift
/// `CodingKeys` spell them.
abstract final class ExerciseSettingsModelKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `note`.
  static const note = 'note';

  /// `rest_duration_override`.
  static const restDurationOverride = 'rest_duration_override';

  /// Every field, in declaration order.
  static const List<String> all = [id, authorId, note, restDurationOverride];
}

/// The user's note and rest for one exercise, at
/// `users/{uid}/exercise_settings/{exerciseId}` (Swift
/// `ExerciseSettingsModel`).
class const ExerciseSettingsModel({
  /// The exercise's id, which is also the document's.
  required final String id,

  /// The user.
  required final String authorId,

  /// The user's standing note on the exercise.
  final String? note,

  /// The rest after its sets, in seconds, ahead of the workout settings.
  final int? restDurationOverride,
}) {
  /// Creates an [ExerciseSettingsModel].
  this;

  /// Decodes strictly, as Swift does.
  factory fromFirestore(Map<String, Object?> data) => ExerciseSettingsModel(
    id: data[ExerciseSettingsModelKeys.id]! as String,
    authorId: data[ExerciseSettingsModelKeys.authorId]! as String,
    note: data[ExerciseSettingsModelKeys.note] as String?,
    restDurationOverride: readOptionalInt(
      data[ExerciseSettingsModelKeys.restDurationOverride],
    ),
  );

  /// The Firestore-shaped map Swift writes, a null field left out.
  Map<String, Object?> toFirestore() => {
    ExerciseSettingsModelKeys.id: id,
    ExerciseSettingsModelKeys.authorId: authorId,
    ExerciseSettingsModelKeys.note: ?note,
    ExerciseSettingsModelKeys.restDurationOverride: ?restDurationOverride,
  };
}
