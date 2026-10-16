import 'package:compound/training_library/logic/exercise_filters.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// The rules a user's exercise must keep (Swift `ExerciseDefinitionRules`),
/// and the create flow's other fixed values.
abstract final class ExerciseDefinitionRules {
  /// What the contribution starts at when Bodyweight Exercise is on.
  static const bodyweightContributionPreset = 75;

  /// The most characters the alternate names field takes.
  static const alternateNamesLimit = 300;

  /// Metrics that record external load. Assistance is not one: an assisted
  /// machine is bodyweight minus assistance, so it stays bodyweight.
  static const Set<TrackableExerciseMetric> loadedMetrics = {
    TrackableExerciseMetric.weight,
    TrackableExerciseMetric.weightPerSide,
    TrackableExerciseMetric.weightPerSidePersistent,
  };

  /// The upper body's muscles, in Swift's order (`Muscles.bodyRegion`).
  static final List<Muscles> upperMuscles = Muscles.values.sublist(0, 15);

  /// The lower body's muscles.
  static final List<Muscles> lowerMuscles = Muscles.values.sublist(15);

  /// Whether [contribution] is a percentage.
  static bool isValidContribution(int contribution) =>
      contribution >= 0 && contribution <= 100;

  /// A bodyweight exercise cannot be loaded, so tracking a load on it
  /// contradicts the flag.
  static bool bodyweightConflict({
    required bool isBodyweight,
    required Iterable<TrackableExerciseMetric> metrics,
  }) => isBodyweight && metrics.any(loadedMetrics.contains);

  /// Equipment that assists rather than loads, offered under Support; the
  /// rest goes under Resistance.
  static bool isSupport(EquipmentKind kind) =>
      kind == EquipmentKind.supportEquipment ||
      kind == EquipmentKind.accessoryEquipment;

  /// The alternate names typed as one comma-separated line, each trimmed,
  /// blanks dropped.
  static List<String> splitAlternateNames(String text) => [
    for (final name in text.split(','))
      if (name.trim().isNotEmpty) name.trim(),
  ];
}

/// One way of doing the exercise being made: what loads it and what
/// supports it (Swift `EquipmentVariationDraft`).
final class const VariationDraft({
  required final String id,
  final List<EquipmentKey> resistance = const [],
  final List<EquipmentKey> support = const [],
}) extends Equatable {
  /// Whether nothing at all is chosen.
  bool get isEmpty => resistance.isEmpty && support.isEmpty;

  VariationDraft copyWith({
    List<EquipmentKey>? resistance,
    List<EquipmentKey>? support,
  }) => VariationDraft(
    id: id,
    resistance: resistance ?? this.resistance,
    support: support ?? this.support,
  );

  /// The stored variation.
  EquipmentVariation toModel() => EquipmentVariation(
    id: id,
    resistanceEquipment: [
      for (final (kind, id) in resistance)
        EquipmentRef(kind: kind, equipmentId: id),
    ],
    supportEquipment: [
      for (final (kind, id) in support)
        EquipmentRef(kind: kind, equipmentId: id),
    ],
  );

  @override
  List<Object> get props => [id, resistance, support];
}

/// Everything the create-exercise flow has collected, handed from each step
/// to the next (Swift's `MuscleGroupPickerDelegate` through
/// `ExerciseSaveDelegate`).
final class const ExerciseDraft({
  required final String name,
  required final TrackableExerciseMetric metricA,
  final TrackableExerciseMetric? metricB,
  final ExerciseType? type,
  final Laterality? laterality,
  final Map<Muscles, MuscleTargetType> muscleGroups = const {},
  final bool isBodyweight = false,
  final List<VariationDraft> variations = const [],
  final int rangeOfMotion = 0,
  final int stability = 0,
  final int bodyweightContribution = 0,
  final List<String> alternateNames = const [],
  final String description = '',
}) extends Equatable {
  /// The metrics in the order chosen, without a gap.
  List<TrackableExerciseMetric> get metrics => [metricA, ?metricB];

  ExerciseDraft copyWith({
    Map<Muscles, MuscleTargetType>? muscleGroups,
    bool? isBodyweight,
    List<VariationDraft>? variations,
    int? rangeOfMotion,
    int? stability,
    int? bodyweightContribution,
    List<String>? alternateNames,
    String? description,
  }) => ExerciseDraft(
    name: name,
    metricA: metricA,
    metricB: metricB,
    type: type,
    laterality: laterality,
    muscleGroups: muscleGroups ?? this.muscleGroups,
    isBodyweight: isBodyweight ?? this.isBodyweight,
    variations: variations ?? this.variations,
    rangeOfMotion: rangeOfMotion ?? this.rangeOfMotion,
    stability: stability ?? this.stability,
    bodyweightContribution:
        bodyweightContribution ?? this.bodyweightContribution,
    alternateNames: alternateNames ?? this.alternateNames,
    description: description ?? this.description,
  );

  /// The exercise as stored, [authorId]'s own (Swift
  /// `ExerciseModel(from:authorId:)`).
  ExerciseModel toModel({
    required String id,
    required String authorId,
    required DateTime now,
  }) => ExerciseModel(
    id: id,
    authorId: authorId,
    name: name,
    description: description,
    trackableMetrics: metrics,
    type: type,
    laterality: laterality,
    muscleGroups: muscleGroups,
    isBodyweight: isBodyweight,
    equipmentVariations: [
      for (final variation in variations) variation.toModel(),
    ],
    rangeOfMotion: rangeOfMotion,
    stability: stability,
    bodyWeightContribution: bodyweightContribution,
    alternateNames: alternateNames,
    isSystemExercise: false,
    dateCreated: now,
    dateModified: now,
    clickCount: 0,
    bookmarkCount: 0,
    favouriteCount: 0,
  );

  @override
  List<Object?> get props => [
    name,
    metricA,
    metricB,
    type,
    laterality,
    muscleGroups,
    isBodyweight,
    variations,
    rangeOfMotion,
    stability,
    bodyweightContribution,
    alternateNames,
    description,
  ];
}
