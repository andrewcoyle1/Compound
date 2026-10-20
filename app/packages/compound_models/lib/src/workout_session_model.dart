import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/workout_exercise_model.dart';

/// Field names of `users/{uid}/workout_sessions/{id}`, exactly as the Swift
/// `CodingKeys` spell them.
///
/// Partial updates and queries take their field names only from here.
abstract final class WorkoutSessionModelKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `name`.
  static const name = 'name';

  /// `workout_template_id`.
  static const workoutTemplateId = 'workout_template_id';

  /// `mesocycle_id`.
  static const mesocycleId = 'mesocycle_id';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `date_modified`.
  static const dateModified = 'date_modified';

  /// `ended_at`.
  static const endedAt = 'ended_at';

  /// `notes`.
  static const notes = 'notes';

  /// `exercises`.
  static const exercises = 'exercises';

  /// `deleted_at`.
  static const deletedAt = 'deleted_at';

  /// `is_rest_day`.
  static const isRestDay = 'is_rest_day';

  /// `liked_by_user_ids`.
  static const likedByUserIds = 'liked_by_user_ids';

  /// `week_streak_count`.
  static const weekStreakCount = 'week_streak_count';

  /// `paused_seconds`.
  static const pausedSeconds = 'paused_seconds';

  /// `strava_activity_id`.
  static const stravaActivityId = 'strava_activity_id';

  /// `gym_profile_id`.
  static const gymProfileId = 'gym_profile_id';

  /// `is_deload`.
  static const isDeload = 'is_deload';

  /// `hidden`: set only by report moderation.
  static const hidden = 'hidden';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    name,
    workoutTemplateId,
    mesocycleId,
    dateCreated,
    dateModified,
    endedAt,
    notes,
    exercises,
    deletedAt,
    isRestDay,
    likedByUserIds,
    weekStreakCount,
    pausedSeconds,
    stravaActivityId,
    gymProfileId,
    isDeload,
    hidden,
  ];
}

/// A workout, logged or under way, at `users/{uid}/workout_sessions/{id}`
/// (Swift `WorkoutSessionModel`).
class const WorkoutSessionModel({
  /// The session's id, and the document id.
  required final String id,

  /// The user who did it.
  required final String authorId,

  /// The session's name.
  required final String name,

  /// When it started.
  required final DateTime dateCreated,

  /// When it was last changed.
  required final DateTime dateModified,

  /// Its exercises.
  required final List<WorkoutExerciseModel> exercises,

  /// The template it was started from.
  final String? workoutTemplateId,

  /// The mesocycle it belongs to.
  final String? mesocycleId,

  /// When it finished; absent while under way.
  final DateTime? endedAt,

  /// The user's notes.
  final String? notes,

  /// When it was deleted.
  final DateTime? deletedAt,

  /// Whether this is a logged rest day rather than a workout.
  final bool isRestDay = false,

  /// Users who liked it.
  final List<String> likedByUserIds = const [],

  /// The author's weekly streak as of finishing it.
  final int? weekStreakCount,

  /// Time spent paused, in seconds.
  final double? pausedSeconds,

  /// The Strava activity it was uploaded as.
  final int? stravaActivityId,

  /// The gym it was done in.
  final String? gymProfileId,

  /// Whether it was a deload week's session.
  final bool? isDeload,

  /// Set by report moderation; the feed then shows it only to its author.
  final bool? hidden,
}) {
  /// Creates a [WorkoutSessionModel].
  this;

  /// Decodes as Swift's synthesized decoder does, strictly:
  /// `is_rest_day` and `liked_by_user_ids` are required, and a missing
  /// field, a wrong type or an unreadable exercise throws. Unknown keys are
  /// ignored, and a null optional reads as absent.
  factory fromFirestore(Map<String, Object?> data) => WorkoutSessionModel(
    id: data[WorkoutSessionModelKeys.id]! as String,
    authorId: data[WorkoutSessionModelKeys.authorId]! as String,
    name: data[WorkoutSessionModelKeys.name]! as String,
    workoutTemplateId:
        data[WorkoutSessionModelKeys.workoutTemplateId] as String?,
    mesocycleId: data[WorkoutSessionModelKeys.mesocycleId] as String?,
    dateCreated: data[WorkoutSessionModelKeys.dateCreated]! as DateTime,
    dateModified: data[WorkoutSessionModelKeys.dateModified]! as DateTime,
    endedAt: data[WorkoutSessionModelKeys.endedAt] as DateTime?,
    notes: data[WorkoutSessionModelKeys.notes] as String?,
    exercises: [
      for (final exercise
          in data[WorkoutSessionModelKeys.exercises]! as List<Object?>)
        WorkoutExerciseModel.fromFirestore(readMap(exercise)),
    ],
    deletedAt: data[WorkoutSessionModelKeys.deletedAt] as DateTime?,
    isRestDay: data[WorkoutSessionModelKeys.isRestDay]! as bool,
    likedByUserIds: readStringList(
      data[WorkoutSessionModelKeys.likedByUserIds],
    ),
    weekStreakCount: readOptionalInt(
      data[WorkoutSessionModelKeys.weekStreakCount],
    ),
    pausedSeconds: readOptionalDouble(
      data[WorkoutSessionModelKeys.pausedSeconds],
    ),
    stravaActivityId: readOptionalInt(
      data[WorkoutSessionModelKeys.stravaActivityId],
    ),
    gymProfileId: data[WorkoutSessionModelKeys.gymProfileId] as String?,
    isDeload: data[WorkoutSessionModelKeys.isDeload] as bool?,
    hidden: data[WorkoutSessionModelKeys.hidden] as bool?,
  );

  /// The Firestore-shaped map Swift writes: a null field is left out.
  Map<String, Object?> toFirestore() => {
    WorkoutSessionModelKeys.id: id,
    WorkoutSessionModelKeys.authorId: authorId,
    WorkoutSessionModelKeys.name: name,
    WorkoutSessionModelKeys.workoutTemplateId: ?workoutTemplateId,
    WorkoutSessionModelKeys.mesocycleId: ?mesocycleId,
    WorkoutSessionModelKeys.dateCreated: dateCreated,
    WorkoutSessionModelKeys.dateModified: dateModified,
    WorkoutSessionModelKeys.endedAt: ?endedAt,
    WorkoutSessionModelKeys.notes: ?notes,
    WorkoutSessionModelKeys.exercises: [
      for (final exercise in exercises) exercise.toFirestore(),
    ],
    WorkoutSessionModelKeys.deletedAt: ?deletedAt,
    WorkoutSessionModelKeys.isRestDay: isRestDay,
    WorkoutSessionModelKeys.likedByUserIds: likedByUserIds,
    WorkoutSessionModelKeys.weekStreakCount: ?weekStreakCount,
    WorkoutSessionModelKeys.pausedSeconds: ?pausedSeconds,
    WorkoutSessionModelKeys.stravaActivityId: ?stravaActivityId,
    WorkoutSessionModelKeys.gymProfileId: ?gymProfileId,
    WorkoutSessionModelKeys.isDeload: ?isDeload,
    WorkoutSessionModelKeys.hidden: ?hidden,
  };
}
