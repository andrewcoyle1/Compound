import 'package:compound_models/src/equipment_variation.dart';
import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/library_enums.dart';

/// Field names of an [ExerciseModel], exactly as the Swift `CodingKeys`
/// spell them. Partial updates and queries take their field names only from
/// here.
abstract final class ExerciseModelKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `name`.
  static const name = 'name';

  /// `description`.
  static const description = 'description';

  /// `image_url`.
  static const imageUrl = 'image_url';

  /// `trackable_metrics`.
  static const trackableMetrics = 'trackable_metrics';

  /// `type`.
  static const type = 'type';

  /// `laterality`.
  static const laterality = 'laterality';

  /// `muscle_groups`.
  static const muscleGroups = 'muscle_groups';

  /// `is_bodyweight`.
  static const isBodyweight = 'is_bodyweight';

  /// `equipment_variations`.
  static const equipmentVariations = 'equipment_variations';

  /// `range_of_motion`.
  static const rangeOfMotion = 'range_of_motion';

  /// `stability`.
  static const stability = 'stability';

  /// `body_weight_contribution`.
  static const bodyWeightContribution = 'body_weight_contribution';

  /// `alternate_names`.
  static const alternateNames = 'alternate_names';

  /// `is_system_exercise`.
  static const isSystemExercise = 'is_system_exercise';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `date_modified`.
  static const dateModified = 'date_modified';

  /// `click_count`.
  static const clickCount = 'click_count';

  /// `bookmark_count`.
  static const bookmarkCount = 'bookmark_count';

  /// `favourite_count`.
  static const favouriteCount = 'favourite_count';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    name,
    description,
    imageUrl,
    trackableMetrics,
    type,
    laterality,
    muscleGroups,
    isBodyweight,
    equipmentVariations,
    rangeOfMotion,
    stability,
    bodyWeightContribution,
    alternateNames,
    isSystemExercise,
    dateCreated,
    dateModified,
    clickCount,
    bookmarkCount,
    favouriteCount,
  ];
}

/// An exercise in the library (Swift `ExerciseModel`): a user's own at
/// `exercise_templates/{id}`, one of the bundled system exercises, or the
/// copy stored inside each workout template that uses it.
class const ExerciseModel({
  /// The exercise's id; `system-…` for the bundled ones.
  required final String id,

  /// Who made it: a user id, or `official` for a system exercise. Empty
  /// when the stored document has none.
  required final String authorId,

  /// The exercise's name.
  required final String name,

  /// What its sets can record.
  required final List<TrackableExerciseMetric> trackableMetrics,

  /// The muscles it works, and how much.
  required final Map<Muscles, MuscleTargetType> muscleGroups,

  /// Whether the lifter's own weight is the load.
  required final bool isBodyweight,

  /// How far the joints move, from 1.
  required final int rangeOfMotion,

  /// How much the exercise is braced, from 1.
  required final int stability,

  /// The percentage of body weight that counts as load.
  required final int bodyWeightContribution,

  /// Other names it is searched by.
  required final List<String> alternateNames,

  /// Whether it is one of the bundled system exercises.
  required final bool isSystemExercise,

  /// When it was made.
  required final DateTime dateCreated,

  /// When it was last changed.
  required final DateTime dateModified,

  /// How it is described.
  final String? description,

  /// Its picture: a URL, or an asset name for a system exercise.
  final String? imageUrl,

  /// Its movement class.
  final ExerciseType? type,

  /// Whether it works one side at a time.
  final Laterality? laterality,

  /// The ways of doing it.
  final List<EquipmentVariation> equipmentVariations = const [],

  /// How often it has been opened.
  final int? clickCount,

  /// How often it has been bookmarked.
  final int? bookmarkCount,

  /// How often it has been made a favourite.
  final int? favouriteCount,
}) {
  /// Creates an [ExerciseModel].
  this;

  /// Decodes as Swift's tolerant decoder does: only `id` and `name` are
  /// required. Any other field that is missing or cannot be read takes its
  /// default, an unreadable metric or variation is skipped, and
  /// `muscle_groups` reads as empty unless every muscle and target in it is
  /// known. A missing `date_created` is 1970, and a missing
  /// `date_modified` is `date_created`.
  factory fromFirestore(Map<String, Object?> data) {
    final dateCreated =
        lenientDate(data[ExerciseModelKeys.dateCreated]) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return ExerciseModel(
      id: data[ExerciseModelKeys.id]! as String,
      authorId: lenientString(data[ExerciseModelKeys.authorId]) ?? '',
      name: data[ExerciseModelKeys.name]! as String,
      description: lenientString(data[ExerciseModelKeys.description]),
      imageUrl: lenientString(data[ExerciseModelKeys.imageUrl]),
      trackableMetrics:
          lossyList(
            data[ExerciseModelKeys.trackableMetrics],
            (metric) => enumFromValue(
              TrackableExerciseMetric.values,
              metric! as String,
            ),
          ) ??
          const [],
      type: enumFromValueOrNull(
        ExerciseType.values,
        data[ExerciseModelKeys.type],
      ),
      laterality: enumFromValueOrNull(
        Laterality.values,
        data[ExerciseModelKeys.laterality],
      ),
      muscleGroups: _muscleGroups(data[ExerciseModelKeys.muscleGroups]),
      isBodyweight: lenientBool(data[ExerciseModelKeys.isBodyweight]) ?? false,
      equipmentVariations:
          lossyList(
            data[ExerciseModelKeys.equipmentVariations],
            (variation) => EquipmentVariation.fromFirestore(readMap(variation)),
          ) ??
          const [],
      rangeOfMotion: lenientInt(data[ExerciseModelKeys.rangeOfMotion]) ?? 0,
      stability: lenientInt(data[ExerciseModelKeys.stability]) ?? 0,
      bodyWeightContribution:
          lenientInt(data[ExerciseModelKeys.bodyWeightContribution]) ?? 0,
      alternateNames:
          lenientStringList(data[ExerciseModelKeys.alternateNames]) ?? const [],
      isSystemExercise:
          lenientBool(data[ExerciseModelKeys.isSystemExercise]) ?? false,
      dateCreated: dateCreated,
      dateModified:
          lenientDate(data[ExerciseModelKeys.dateModified]) ?? dateCreated,
      clickCount: lenientInt(data[ExerciseModelKeys.clickCount]),
      bookmarkCount: lenientInt(data[ExerciseModelKeys.bookmarkCount]),
      favouriteCount: lenientInt(data[ExerciseModelKeys.favouriteCount]),
    );
  }

  /// Swift decodes the whole map or none of it.
  static Map<Muscles, MuscleTargetType> _muscleGroups(Object? stored) {
    if (stored is! Map<String, Object?>) return const {};
    final muscles = <Muscles, MuscleTargetType>{};
    for (final MapEntry(:key, :value) in stored.entries) {
      final muscle = enumFromValueOrNull(Muscles.values, key);
      final target = enumFromValueOrNull(MuscleTargetType.values, value);
      if (muscle == null || target == null) return const {};
      muscles[muscle] = target;
    }
    return muscles;
  }

  /// The Firestore-shaped map Swift writes, a null field left out.
  Map<String, Object?> toFirestore() => {
    ExerciseModelKeys.id: id,
    ExerciseModelKeys.authorId: authorId,
    ExerciseModelKeys.name: name,
    ExerciseModelKeys.description: ?description,
    ExerciseModelKeys.imageUrl: ?imageUrl,
    ExerciseModelKeys.trackableMetrics: [
      for (final metric in trackableMetrics) metric.value,
    ],
    ExerciseModelKeys.type: ?type?.value,
    ExerciseModelKeys.laterality: ?laterality?.value,
    ExerciseModelKeys.muscleGroups: {
      for (final MapEntry(:key, :value) in muscleGroups.entries)
        key.value: value.value,
    },
    ExerciseModelKeys.isBodyweight: isBodyweight,
    ExerciseModelKeys.equipmentVariations: [
      for (final variation in equipmentVariations) variation.toFirestore(),
    ],
    ExerciseModelKeys.rangeOfMotion: rangeOfMotion,
    ExerciseModelKeys.stability: stability,
    ExerciseModelKeys.bodyWeightContribution: bodyWeightContribution,
    ExerciseModelKeys.alternateNames: alternateNames,
    ExerciseModelKeys.isSystemExercise: isSystemExercise,
    ExerciseModelKeys.dateCreated: dateCreated,
    ExerciseModelKeys.dateModified: dateModified,
    ExerciseModelKeys.clickCount: ?clickCount,
    ExerciseModelKeys.bookmarkCount: ?bookmarkCount,
    ExerciseModelKeys.favouriteCount: ?favouriteCount,
  };
}
