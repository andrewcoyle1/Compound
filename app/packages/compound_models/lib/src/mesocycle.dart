import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/training_enums.dart';
import 'package:compound_models/src/workout_template_model.dart';

/// Field names of a [Mesocycle], exactly as the Swift `CodingKeys` spell
/// them.
abstract final class MesocycleKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `name`.
  static const name = 'name';

  /// `icon`.
  static const icon = 'icon';

  /// `colour`.
  static const colour = 'colour';

  /// `num_microcycles`.
  static const numMicrocycles = 'num_microcycles';

  /// `deload`.
  static const deload = 'deload';

  /// `periodisation`.
  static const periodisation = 'periodisation';

  /// `workout_templates`.
  static const workoutTemplates = 'workout_templates';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `date_modified`.
  static const dateModified = 'date_modified';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    name,
    icon,
    colour,
    numMicrocycles,
    deload,
    periodisation,
    workoutTemplates,
    dateCreated,
    dateModified,
  ];
}

/// A program of day plans run for a number of microcycles, at
/// `users/{uid}/mesocycles/{id}`, the payload of a mesocycle share, or one
/// of the bundled templates (Swift `Mesocycle`).
class const Mesocycle({
  /// The mesocycle's id.
  required final String id,

  /// Who made it: a user id, or `official` for a bundled template.
  required final String authorId,

  /// Its name.
  required final String name,

  /// An SF Symbol name.
  required final String icon,

  /// Its colour, as `#RRGGBB`.
  required final String colour,

  /// The day plans of one microcycle, in order. A plan with no exercises
  /// is a rest day.
  required final List<WorkoutTemplateModel> workoutTemplates,

  /// When it was made.
  required final DateTime dateCreated,

  /// When it was last changed.
  required final DateTime dateModified,

  /// How many microcycles it runs for.
  final int numMicrocycles = 8,

  /// Where its deload microcycle falls.
  final DeloadType deload = DeloadType.none,

  /// Whether its microcycles move through periodisation phases.
  final bool periodisation = false,
}) {
  /// Creates a [Mesocycle].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does: every field is
  /// required, and a field an older build wrote (`day_plans`) is ignored.
  factory fromFirestore(Map<String, Object?> data) => Mesocycle(
    id: data[MesocycleKeys.id]! as String,
    authorId: data[MesocycleKeys.authorId]! as String,
    name: data[MesocycleKeys.name]! as String,
    icon: data[MesocycleKeys.icon]! as String,
    colour: data[MesocycleKeys.colour]! as String,
    numMicrocycles: readInt(data[MesocycleKeys.numMicrocycles]),
    deload: enumFromValue(
      DeloadType.values,
      data[MesocycleKeys.deload]! as String,
    ),
    periodisation: data[MesocycleKeys.periodisation]! as bool,
    workoutTemplates: [
      for (final template
          in data[MesocycleKeys.workoutTemplates]! as List<Object?>)
        WorkoutTemplateModel.fromFirestore(readMap(template)),
    ],
    dateCreated: data[MesocycleKeys.dateCreated]! as DateTime,
    dateModified: data[MesocycleKeys.dateModified]! as DateTime,
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    MesocycleKeys.id: id,
    MesocycleKeys.authorId: authorId,
    MesocycleKeys.name: name,
    MesocycleKeys.icon: icon,
    MesocycleKeys.colour: colour,
    MesocycleKeys.numMicrocycles: numMicrocycles,
    MesocycleKeys.deload: deload.value,
    MesocycleKeys.periodisation: periodisation,
    MesocycleKeys.workoutTemplates: [
      for (final template in workoutTemplates) template.toFirestore(),
    ],
    MesocycleKeys.dateCreated: dateCreated,
    MesocycleKeys.dateModified: dateModified,
  };
}
