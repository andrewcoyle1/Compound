import 'package:compound_models/compound_models.dart';

final _date = DateTime.utc(2026, 9);

/// A library exercise, a user's own unless [system].
ExerciseModel fixtureLibraryExercise(
  String id, {
  String? name,
  String? description,
  Map<Muscles, MuscleTargetType> muscles = const {
    Muscles.chest: MuscleTargetType.primary,
  },
  List<String> alternateNames = const [],
  ExerciseType? type = ExerciseType.compoundUpper,
  Laterality? laterality = Laterality.bilateral,
  List<EquipmentVariation> variations = const [],
  int rangeOfMotion = 4,
  int stability = 3,
  bool system = false,
  String? imageUrl,
}) => ExerciseModel(
  id: id,
  authorId: system ? 'official' : 'friend',
  name: name ?? id,
  description: description,
  imageUrl: imageUrl,
  trackableMetrics: const [
    TrackableExerciseMetric.weight,
    TrackableExerciseMetric.reps,
  ],
  type: type,
  laterality: laterality,
  muscleGroups: muscles,
  isBodyweight: false,
  equipmentVariations: variations,
  rangeOfMotion: rangeOfMotion,
  stability: stability,
  bodyWeightContribution: 0,
  alternateNames: alternateNames,
  isSystemExercise: system,
  dateCreated: _date,
  dateModified: _date,
);

/// A template slot for [exercise] with [sets] targets of 8–12 reps.
WorkoutTemplateExercise fixtureSlot(
  ExerciseModel exercise, {
  int sets = 3,
  String? supersetGroupId,
  List<String> substitutes = const [],
  String? id,
}) => WorkoutTemplateExercise(
  id: id ?? 'slot-${exercise.id}',
  exercise: exercise,
  setTargets: [
    for (var number = 1; number <= sets; number++)
      SetTarget(
        id: '${exercise.id}-$number',
        setNumber: number,
        minReps: 8,
        maxReps: 12,
      ),
  ],
  setRestTimers: false,
  supersetGroupId: supersetGroupId,
  substituteExerciseIds: substitutes,
);

/// A user's workout template.
WorkoutTemplateModel fixtureTemplate(
  String id, {
  String? name,
  String? description,
  List<WorkoutTemplateExercise> exercises = const [],
}) => WorkoutTemplateModel(
  workoutId: id,
  authorId: 'friend',
  name: name ?? id,
  description: description,
  dateCreated: _date,
  dateModified: _date,
  exercises: exercises,
);

/// A user's mesocycle of [days].
Mesocycle fixtureMesocycle(
  String id,
  List<WorkoutTemplateModel> days, {
  String? name,
}) => Mesocycle(
  id: id,
  authorId: 'friend',
  name: name ?? id,
  icon: 'flag',
  colour: '#FF0000',
  workoutTemplates: days,
  dateCreated: _date,
  dateModified: _date,
);
