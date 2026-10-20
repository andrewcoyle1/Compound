import 'package:compound_models/src/exercise_model.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/set_target.dart';

/// Field names of a [WorkoutTemplateModel], exactly as the Swift
/// `CodingKeys` spell them.
abstract final class WorkoutTemplateModelKeys {
  /// `workout_id`, the template's id.
  static const workoutId = 'workout_id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `name`.
  static const name = 'name';

  /// `description`.
  static const description = 'description';

  /// `gym_profile_id`.
  static const gymProfileId = 'gym_profile_id';

  /// `image_url`.
  static const imageUrl = 'image_url';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `date_modified`.
  static const dateModified = 'date_modified';

  /// `exercises`.
  static const exercises = 'exercises';

  /// Every field, in declaration order.
  static const List<String> all = [
    workoutId,
    authorId,
    name,
    description,
    gymProfileId,
    imageUrl,
    dateCreated,
    dateModified,
    exercises,
  ];
}

/// A workout to start sessions from, at
/// `users/{uid}/workout_templates/{workoutId}`, or one of the bundled
/// system workouts (Swift `WorkoutTemplateModel`).
class const WorkoutTemplateModel({
  /// The template's id, stored as `workout_id`.
  required final String workoutId,

  /// Who made it: a user id, or `official` for a system workout.
  required final String authorId,

  /// The workout's name.
  required final String name,

  /// When it was made.
  required final DateTime dateCreated,

  /// When it was last changed.
  required final DateTime dateModified,

  /// Its exercises, in order.
  required final List<WorkoutTemplateExercise> exercises,

  /// How it is described.
  final String? description,

  /// The gym it is planned for.
  final String? gymProfileId,

  /// Its picture.
  final String? imageUrl,
}) {
  /// Creates a [WorkoutTemplateModel].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does; a field an
  /// older build wrote and this one no longer has is ignored.
  factory fromFirestore(Map<String, Object?> data) => WorkoutTemplateModel(
    workoutId: data[WorkoutTemplateModelKeys.workoutId]! as String,
    authorId: data[WorkoutTemplateModelKeys.authorId]! as String,
    name: data[WorkoutTemplateModelKeys.name]! as String,
    description: data[WorkoutTemplateModelKeys.description] as String?,
    gymProfileId: data[WorkoutTemplateModelKeys.gymProfileId] as String?,
    imageUrl: data[WorkoutTemplateModelKeys.imageUrl] as String?,
    dateCreated: data[WorkoutTemplateModelKeys.dateCreated]! as DateTime,
    dateModified: data[WorkoutTemplateModelKeys.dateModified]! as DateTime,
    exercises: [
      for (final exercise
          in data[WorkoutTemplateModelKeys.exercises]! as List<Object?>)
        WorkoutTemplateExercise.fromFirestore(readMap(exercise)),
    ],
  );

  /// The Firestore-shaped map Swift writes, a null field left out.
  Map<String, Object?> toFirestore() => {
    WorkoutTemplateModelKeys.workoutId: workoutId,
    WorkoutTemplateModelKeys.authorId: authorId,
    WorkoutTemplateModelKeys.name: name,
    WorkoutTemplateModelKeys.description: ?description,
    WorkoutTemplateModelKeys.gymProfileId: ?gymProfileId,
    WorkoutTemplateModelKeys.imageUrl: ?imageUrl,
    WorkoutTemplateModelKeys.dateCreated: dateCreated,
    WorkoutTemplateModelKeys.dateModified: dateModified,
    WorkoutTemplateModelKeys.exercises: [
      for (final exercise in exercises) exercise.toFirestore(),
    ],
  };
}

/// Field names of a [WorkoutTemplateExercise], exactly as the Swift
/// `CodingKeys` spell them.
abstract final class WorkoutTemplateExerciseKeys {
  /// `id`.
  static const id = 'id';

  /// `exercise`.
  static const exercise = 'exercise';

  /// `set_targets`.
  static const setTargets = 'set_targets';

  /// `set_rest_timers`.
  static const setRestTimers = 'set_rest_timers';

  /// `notes`.
  static const notes = 'notes';

  /// `warmup_set_count`.
  static const warmupSetCount = 'warmup_set_count';

  /// `rest_seconds`.
  static const restSeconds = 'rest_seconds';

  /// `substitute_exercise_ids`.
  static const substituteExerciseIds = 'substitute_exercise_ids';

  /// `superset_group_id`.
  static const supersetGroupId = 'superset_group_id';

  /// `link_url`.
  static const linkUrl = 'link_url';

  /// `set_targets_by_microcycle`.
  static const setTargetsByMicrocycle = 'set_targets_by_microcycle';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    exercise,
    setTargets,
    setRestTimers,
    notes,
    warmupSetCount,
    restSeconds,
    substituteExerciseIds,
    supersetGroupId,
    linkUrl,
    setTargetsByMicrocycle,
  ];
}

/// One exercise of a workout template, with the plan for its sets (Swift
/// `WorkoutTemplateExercise`).
class const WorkoutTemplateExercise({
  /// The slot's id within the template.
  required final String id,

  /// The exercise, stored whole.
  required final ExerciseModel exercise,

  /// What each set aims at.
  required final List<SetTarget> setTargets,

  /// Whether rest timers run after its sets.
  required final bool setRestTimers,

  /// The plan's notes for it.
  final String? notes,

  /// How many warm-up sets to add; null leaves it to the weight rule.
  final int? warmupSetCount,

  /// The rest after its sets, in seconds.
  final int? restSeconds,

  /// Exercise ids the plan offers in its place.
  final List<String> substituteExerciseIds = const [],

  /// Exercises sharing a group run as a superset.
  final String? supersetGroupId,

  /// A demonstration video or other reference.
  final String? linkUrl,

  /// Targets that replace [setTargets] from a later microcycle on.
  final List<MicrocycleSetTargets> setTargetsByMicrocycle = const [],
}) {
  /// Creates a [WorkoutTemplateExercise].
  this;

  /// Decodes as Swift does: strictly, except that the plan's lists default
  /// to empty when absent. The exercise itself decodes tolerantly
  /// ([ExerciseModel.fromFirestore]).
  factory fromFirestore(Map<String, Object?> data) => WorkoutTemplateExercise(
    id: data[WorkoutTemplateExerciseKeys.id]! as String,
    exercise: ExerciseModel.fromFirestore(
      readMap(data[WorkoutTemplateExerciseKeys.exercise]),
    ),
    setTargets: [
      for (final target
          in data[WorkoutTemplateExerciseKeys.setTargets]! as List<Object?>)
        SetTarget.fromFirestore(readMap(target)),
    ],
    setRestTimers: data[WorkoutTemplateExerciseKeys.setRestTimers]! as bool,
    notes: data[WorkoutTemplateExerciseKeys.notes] as String?,
    warmupSetCount: readOptionalInt(
      data[WorkoutTemplateExerciseKeys.warmupSetCount],
    ),
    restSeconds: readOptionalInt(data[WorkoutTemplateExerciseKeys.restSeconds]),
    substituteExerciseIds:
        switch (data[WorkoutTemplateExerciseKeys.substituteExerciseIds]) {
          null => const [],
          final Object ids => readStringList(ids),
        },
    supersetGroupId:
        data[WorkoutTemplateExerciseKeys.supersetGroupId] as String?,
    linkUrl: data[WorkoutTemplateExerciseKeys.linkUrl] as String?,
    setTargetsByMicrocycle: [
      for (final targets
          in data[WorkoutTemplateExerciseKeys.setTargetsByMicrocycle]
                  as List<Object?>? ??
              const [])
        MicrocycleSetTargets.fromFirestore(readMap(targets)),
    ],
  );

  /// The Firestore-shaped map Swift writes: the two plan lists only when
  /// they hold something, and a null field left out.
  Map<String, Object?> toFirestore() => {
    WorkoutTemplateExerciseKeys.id: id,
    WorkoutTemplateExerciseKeys.exercise: exercise.toFirestore(),
    WorkoutTemplateExerciseKeys.setTargets: [
      for (final target in setTargets) target.toFirestore(),
    ],
    WorkoutTemplateExerciseKeys.setRestTimers: setRestTimers,
    WorkoutTemplateExerciseKeys.notes: ?notes,
    WorkoutTemplateExerciseKeys.warmupSetCount: ?warmupSetCount,
    WorkoutTemplateExerciseKeys.restSeconds: ?restSeconds,
    if (substituteExerciseIds.isNotEmpty)
      WorkoutTemplateExerciseKeys.substituteExerciseIds: substituteExerciseIds,
    WorkoutTemplateExerciseKeys.supersetGroupId: ?supersetGroupId,
    WorkoutTemplateExerciseKeys.linkUrl: ?linkUrl,
    if (setTargetsByMicrocycle.isNotEmpty)
      WorkoutTemplateExerciseKeys.setTargetsByMicrocycle: [
        for (final targets in setTargetsByMicrocycle) targets.toFirestore(),
      ],
  };
}

/// Field names of a [MicrocycleSetTargets], exactly as the Swift
/// `CodingKeys` spell them.
abstract final class MicrocycleSetTargetsKeys {
  /// `from_microcycle`.
  static const fromMicrocycle = 'from_microcycle';

  /// `set_targets`.
  static const setTargets = 'set_targets';
}

/// A template exercise's targets from one microcycle on (Swift
/// `MicrocycleSetTargets`).
class const MicrocycleSetTargets({
  /// The first microcycle they apply to, from 1.
  required final int fromMicrocycle,

  /// The targets.
  required final List<SetTarget> setTargets,
}) {
  /// Creates a [MicrocycleSetTargets].
  this;

  /// Decodes strictly, as Swift does.
  factory fromFirestore(Map<String, Object?> data) => MicrocycleSetTargets(
    fromMicrocycle: readInt(data[MicrocycleSetTargetsKeys.fromMicrocycle]),
    setTargets: [
      for (final target
          in data[MicrocycleSetTargetsKeys.setTargets]! as List<Object?>)
        SetTarget.fromFirestore(readMap(target)),
    ],
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    MicrocycleSetTargetsKeys.fromMicrocycle: fromMicrocycle,
    MicrocycleSetTargetsKeys.setTargets: [
      for (final target in setTargets) target.toFirestore(),
    ],
  };
}
