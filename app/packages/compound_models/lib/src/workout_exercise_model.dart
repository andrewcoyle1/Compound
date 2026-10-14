import 'package:compound_models/src/equipment_variation.dart';
import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/set_target.dart';
import 'package:compound_models/src/training_enums.dart';
import 'package:compound_models/src/workout_set_model.dart';

/// Field names of a [WorkoutExerciseModel], exactly as the Swift
/// `CodingKeys` spell them.
abstract final class WorkoutExerciseModelKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `template_id`.
  static const templateId = 'template_id';

  /// `name`.
  static const name = 'name';

  /// `tracking_mode`.
  static const trackingMode = 'tracking_mode';

  /// `index`.
  static const index = 'index';

  /// `notes`.
  static const notes = 'notes';

  /// `image_name`.
  static const imageName = 'image_name';

  /// `sets`.
  static const sets = 'sets';

  /// `set_targets`.
  static const setTargets = 'set_targets';

  /// `chosen_variation_id`.
  static const chosenVariationId = 'chosen_variation_id';

  /// `equipment_variations`.
  static const equipmentVariations = 'equipment_variations';

  /// `superset_group_id`.
  static const supersetGroupId = 'superset_group_id';

  /// `plan_notes`.
  static const planNotes = 'plan_notes';

  /// `plan_slot_id`.
  static const planSlotId = 'plan_slot_id';

  /// `rest_seconds`.
  static const restSeconds = 'rest_seconds';

  /// `link_url`.
  static const linkUrl = 'link_url';

  /// `substitute_exercise_ids`.
  static const substituteExerciseIds = 'substitute_exercise_ids';

  /// `weight_unit`.
  static const weightUnit = 'weight_unit';

  /// `loads_per_set`.
  static const loadsPerSet = 'loads_per_set';

  /// `machine_base_kg`.
  static const machineBaseKg = 'machine_base_kg';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    templateId,
    name,
    trackingMode,
    index,
    notes,
    imageName,
    sets,
    setTargets,
    chosenVariationId,
    equipmentVariations,
    supersetGroupId,
    planNotes,
    planSlotId,
    restSeconds,
    linkUrl,
    substituteExerciseIds,
    weightUnit,
    loadsPerSet,
    machineBaseKg,
  ];
}

/// One exercise of a session, with its sets (Swift `WorkoutExerciseModel`).
class const WorkoutExerciseModel({
  /// The exercise's id within the session.
  required final String id,

  /// The session's author.
  required final String authorId,

  /// The library exercise it was made from.
  required final String templateId,

  /// The exercise's name.
  required final String name,

  /// What its sets record.
  required final TrackingMode trackingMode,

  /// Its place in the session, from 1.
  required final int index,

  /// Its sets, warm-ups first.
  required final List<WorkoutSetModel> sets,

  /// The user's notes.
  final String? notes,

  /// The image stored with the session.
  final String? imageName,

  /// What the plan asked of each set.
  final List<SetTarget> setTargets = const [],

  /// The variation the session is on.
  final String? chosenVariationId,

  /// The ways of doing the exercise.
  final List<EquipmentVariation> equipmentVariations = const [],

  /// Exercises sharing a superset group are done back to back.
  final String? supersetGroupId,

  /// The plan's notes for this exercise.
  final String? planNotes,

  /// The plan's exercise this one was started from.
  final String? planSlotId,

  /// The plan's rest for this exercise, in seconds.
  final int? restSeconds,

  /// The plan's video or reference link.
  final String? linkUrl,

  /// Exercise ids the plan offers in this one's place.
  final List<String> substituteExerciseIds = const [],

  /// The unit its weights are entered in for the session.
  final ExerciseWeightUnit? weightUnit,

  /// How many of the weight one set lifts.
  final int? loadsPerSet,

  /// The machine base its weights are entered without, in kg.
  final double? machineBaseKg,
}) {
  /// Creates a [WorkoutExerciseModel].
  this;

  /// Decodes as Swift's hand-written decoder does: strictly, except that
  /// `set_targets` and `substitute_exercise_ids` default to empty,
  /// `equipment_variations` is read variation by variation (skipping one
  /// that cannot be read), and `weight_unit`, `loads_per_set` and
  /// `machine_base_kg` read as absent when they cannot be read. An unknown
  /// `weight_unit` is dropped here, unlike a set's, which is kept.
  factory fromFirestore(Map<String, Object?> data) => WorkoutExerciseModel(
    id: data[WorkoutExerciseModelKeys.id]! as String,
    authorId: data[WorkoutExerciseModelKeys.authorId]! as String,
    templateId: data[WorkoutExerciseModelKeys.templateId]! as String,
    name: data[WorkoutExerciseModelKeys.name]! as String,
    trackingMode: enumFromValue(
      TrackingMode.values,
      data[WorkoutExerciseModelKeys.trackingMode]! as String,
    ),
    index: readInt(data[WorkoutExerciseModelKeys.index]),
    notes: data[WorkoutExerciseModelKeys.notes] as String?,
    imageName: data[WorkoutExerciseModelKeys.imageName] as String?,
    sets: [
      for (final set in data[WorkoutExerciseModelKeys.sets]! as List<Object?>)
        WorkoutSetModel.fromFirestore(readMap(set)),
    ],
    setTargets: [
      for (final target
          in data[WorkoutExerciseModelKeys.setTargets] as List<Object?>? ??
              const [])
        SetTarget.fromFirestore(readMap(target)),
    ],
    chosenVariationId:
        data[WorkoutExerciseModelKeys.chosenVariationId] as String?,
    equipmentVariations:
        lossyList(
          data[WorkoutExerciseModelKeys.equipmentVariations],
          (variation) => EquipmentVariation.fromFirestore(readMap(variation)),
        ) ??
        const [],
    supersetGroupId: data[WorkoutExerciseModelKeys.supersetGroupId] as String?,
    planNotes: data[WorkoutExerciseModelKeys.planNotes] as String?,
    planSlotId: data[WorkoutExerciseModelKeys.planSlotId] as String?,
    restSeconds: readOptionalInt(data[WorkoutExerciseModelKeys.restSeconds]),
    linkUrl: data[WorkoutExerciseModelKeys.linkUrl] as String?,
    substituteExerciseIds:
        switch (data[WorkoutExerciseModelKeys.substituteExerciseIds]) {
          null => const [],
          final Object ids => readStringList(ids),
        },
    weightUnit: enumFromValueOrNull(
      ExerciseWeightUnit.values,
      data[WorkoutExerciseModelKeys.weightUnit],
    ),
    loadsPerSet: lenientInt(data[WorkoutExerciseModelKeys.loadsPerSet]),
    machineBaseKg: lenientDouble(data[WorkoutExerciseModelKeys.machineBaseKg]),
  );

  /// The Firestore-shaped map Swift writes: `set_targets` and
  /// `equipment_variations` always, `substitute_exercise_ids` only when
  /// there are some, and a null field left out.
  Map<String, Object?> toFirestore() => {
    WorkoutExerciseModelKeys.id: id,
    WorkoutExerciseModelKeys.authorId: authorId,
    WorkoutExerciseModelKeys.templateId: templateId,
    WorkoutExerciseModelKeys.name: name,
    WorkoutExerciseModelKeys.trackingMode: trackingMode.value,
    WorkoutExerciseModelKeys.index: index,
    WorkoutExerciseModelKeys.notes: ?notes,
    WorkoutExerciseModelKeys.imageName: ?imageName,
    WorkoutExerciseModelKeys.sets: [for (final set in sets) set.toFirestore()],
    WorkoutExerciseModelKeys.setTargets: [
      for (final target in setTargets) target.toFirestore(),
    ],
    WorkoutExerciseModelKeys.chosenVariationId: ?chosenVariationId,
    WorkoutExerciseModelKeys.equipmentVariations: [
      for (final variation in equipmentVariations) variation.toFirestore(),
    ],
    WorkoutExerciseModelKeys.supersetGroupId: ?supersetGroupId,
    WorkoutExerciseModelKeys.planNotes: ?planNotes,
    WorkoutExerciseModelKeys.planSlotId: ?planSlotId,
    WorkoutExerciseModelKeys.restSeconds: ?restSeconds,
    WorkoutExerciseModelKeys.linkUrl: ?linkUrl,
    if (substituteExerciseIds.isNotEmpty)
      WorkoutExerciseModelKeys.substituteExerciseIds: substituteExerciseIds,
    WorkoutExerciseModelKeys.weightUnit: ?weightUnit?.value,
    WorkoutExerciseModelKeys.loadsPerSet: ?loadsPerSet,
    WorkoutExerciseModelKeys.machineBaseKg: ?machineBaseKg,
  };
}
