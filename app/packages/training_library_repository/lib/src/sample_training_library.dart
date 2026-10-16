import 'package:compound_models/compound_models.dart';
import 'package:training_library_repository/src/prebuilt_catalogue.dart';

final _created = DateTime.utc(2026, 9, 1, 9);
final _modified = DateTime.utc(2026, 10, 10, 18, 30);

/// Exercises `mock_user_123` made, as Swift's `ExerciseModel.userMocks`.
final sampleUserExercises = [
  ExerciseModel(
    id: 'user-exercise-plank',
    authorId: 'mock_user_123',
    name: 'Plank',
    description:
        'An isometric core stability exercise emphasizing abdominal '
        'endurance.',
    trackableMetrics: const [TrackableExerciseMetric.duration],
    type: ExerciseType.core,
    laterality: Laterality.bilateral,
    muscleGroups: const {
      Muscles.abs: MuscleTargetType.primary,
      Muscles.frontDelts: MuscleTargetType.secondary,
    },
    isBodyweight: true,
    rangeOfMotion: 1,
    stability: 5,
    bodyWeightContribution: 100,
    alternateNames: const [],
    isSystemExercise: false,
    dateCreated: _created,
    dateModified: _created,
    clickCount: 0,
    bookmarkCount: 0,
    favouriteCount: 0,
  ),
  ExerciseModel(
    id: 'user-exercise-push-up',
    authorId: 'mock_user_123',
    name: 'Push Up',
    description:
        'A bodyweight pressing movement targeting the chest, triceps, and '
        'shoulders.',
    trackableMetrics: const [TrackableExerciseMetric.reps],
    type: ExerciseType.compoundUpper,
    laterality: Laterality.bilateral,
    muscleGroups: const {
      Muscles.chest: MuscleTargetType.primary,
      Muscles.triceps: MuscleTargetType.secondary,
      Muscles.frontDelts: MuscleTargetType.secondary,
    },
    isBodyweight: true,
    rangeOfMotion: 4,
    stability: 3,
    bodyWeightContribution: 100,
    alternateNames: const ['Press Up'],
    isSystemExercise: false,
    dateCreated: _created,
    dateModified: _created,
    clickCount: 0,
    bookmarkCount: 0,
    favouriteCount: 0,
  ),
];

/// Workouts `mock_user_123` built from system exercises, as Swift's
/// `WorkoutTemplateModel.userMocks`.
final List<WorkoutTemplateModel> sampleUserWorkoutTemplates = [
  _template(
    'user-workout-upper',
    'My Upper Body',
    'Chest and back, alternating.',
    [
      'system-barbell-bench-press',
      'system-cable-neutral-grip-lat-pulldown',
      'system-dumbbell-seated-shoulder-press',
      'system-single-arm-row',
      'system-cable-bicep-curl-straight-bar',
    ],
  ),
  _template(
    'user-workout-legs',
    'My Leg Day',
    'Squat focused, with posterior chain accessories.',
    [
      'system-barbell-squat',
      'system-barbell-romanian-deadlift',
      'system-lying-leg-curl',
      'system-seated-leg-extension',
      'system-calf-press-leg-press',
    ],
  ),
];

WorkoutTemplateModel _template(
  String id,
  String name,
  String description,
  List<String> exerciseIds,
) {
  final system = PrebuiltCatalogue.instance.exercises;
  return WorkoutTemplateModel(
    workoutId: id,
    authorId: 'mock_user_123',
    name: name,
    description: description,
    dateCreated: _created,
    dateModified: _modified,
    exercises: [
      for (final (index, exerciseId) in exerciseIds.indexed)
        WorkoutTemplateExercise(
          id: '${id}_${index + 1}',
          exercise: system.firstWhere((exercise) => exercise.id == exerciseId),
          setTargets: [
            SetTarget(
              id: '${id}_${index + 1}_set_1',
              setNumber: 1,
              minReps: 8,
              maxReps: 12,
            ),
          ],
          setRestTimers: true,
          restSeconds: 120,
        ),
    ],
  );
}

/// `mock_user_123`'s gym: the whole catalogue, as a new profile starts.
final List<GymProfileModel> sampleGymProfiles = [
  () {
    final catalogue = GymEquipmentCatalogue.instance;
    return GymProfileModel(
      id: 'sample-gym',
      authorId: 'mock_user_123',
      name: 'Platinum Gym Malahide',
      icon: 'dumbbell',
      dateCreated: _created,
      dateModified: _modified,
      freeWeights: catalogue.freeWeights,
      loadableBars: catalogue.loadableBars,
      fixedWeightBars: catalogue.fixedWeightBars,
      bands: catalogue.bands,
      bodyWeights: catalogue.bodyWeights,
      supportEquipment: catalogue.supportEquipment,
      accessoryEquipment: catalogue.accessoryEquipment,
      loadableAccessoryEquipment: catalogue.loadableAccessoryEquipment,
      cableMachines: catalogue.cableMachines,
      plateLoadedMachines: catalogue.plateLoadedMachines,
      pinLoadedMachines: catalogue.pinLoadedMachines,
    );
  }(),
];

/// A standing note and rest on the bench press for `mock_user_123`.
const sampleExerciseSettings = [
  ExerciseSettingsModel(
    id: 'system-barbell-bench-press',
    authorId: 'mock_user_123',
    note: 'Shoulder blades back and down',
    restDurationOverride: 180,
  ),
];

/// `mock_user_123`'s workout settings: Swift's defaults with RIR tracking
/// and the set plan on.
const sampleWorkoutSettings = [
  WorkoutSettings(
    authorId: 'mock_user_123',
    rirTracking: true,
    setPlanning: true,
  ),
];
