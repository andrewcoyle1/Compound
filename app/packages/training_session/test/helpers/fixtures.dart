// Builders for the stored models, in the shapes the Swift tests build them.
import 'package:compound_models/compound_models.dart' as m;
import 'package:training_session/training_session.dart';

const author = 'author-1';

/// `Date(timeIntervalSince1970: 1_000_000)`, the Swift tests' start.
final start = DateTime.fromMillisecondsSinceEpoch(1000000000, isUtc: true);

/// A clock the test moves by hand.
class FakeClock {
  new([DateTime? now]) : now = now ?? start;

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

/// Ids "id-1", "id-2"…
class Ids {
  var _next = 0;

  String call() => 'id-${++_next}';
}

m.WorkoutSetModel set(
  String id, {
  int index = 1,
  int? reps = 8,
  double? weightKg = 80,
  bool warmup = false,
  DateTime? doneAt,
  bool done = false,
  String? side,
  String? kind,
  String? parent,
  double? rpe,
  int? durationSec,
}) => m.WorkoutSetModel(
  id: id,
  authorId: author,
  index: index,
  isWarmup: warmup,
  dateCreated: start,
  reps: reps,
  weightKg: weightKg,
  rpe: rpe,
  durationSec: durationSec,
  sideRawValue: side,
  kindRawValue: kind,
  parentSetId: parent,
  completedAt: doneAt ?? (done ? start : null),
);

m.WorkoutExerciseModel exercise(
  String id, {
  List<m.WorkoutSetModel> sets = const [],
  int index = 1,
  String? templateId,
  String? name,
  String? group,
  List<m.SetTarget> targets = const [],
  m.TrackingMode mode = m.TrackingMode.weightReps,
  List<m.EquipmentVariation> variations = const [],
  String? chosenVariationId,
  int? restSeconds,
  m.ExerciseWeightUnit? weightUnit,
}) => m.WorkoutExerciseModel(
  id: id,
  authorId: author,
  templateId: templateId ?? 'template-$id',
  name: name ?? 'Bench Press',
  trackingMode: mode,
  index: index,
  sets: sets,
  setTargets: targets,
  supersetGroupId: group,
  equipmentVariations: variations,
  chosenVariationId: chosenVariationId,
  restSeconds: restSeconds,
  weightUnit: weightUnit,
);

m.WorkoutSessionModel session(
  List<m.WorkoutExerciseModel> exercises, {
  String id = 'session-1',
  String? templateId,
  String? mesocycleId,
  DateTime? created,
  DateTime? ended,
  bool isRestDay = false,
  bool? isDeload,
  String? gymProfileId,
  String authorId = author,
}) => m.WorkoutSessionModel(
  id: id,
  authorId: authorId,
  name: 'Push Day',
  workoutTemplateId: templateId,
  mesocycleId: mesocycleId,
  dateCreated: created ?? start,
  dateModified: created ?? start,
  endedAt: ended,
  exercises: exercises,
  isRestDay: isRestDay,
  isDeload: isDeload,
  gymProfileId: gymProfileId,
);

m.SetTarget target(
  int number, {
  int? min,
  int? max,
  int? rir,
  m.SetTargetSetType type = m.SetTargetSetType.standard,
  int? dropCount,
  int? dropStepPercent,
  int? dropReps,
  int? miniSetCount,
  int? amrapTargetReps,
  int? partialReps,
  int? holdSeconds,
}) => m.SetTarget(
  id: 'target-$number',
  setNumber: number,
  minReps: min,
  maxReps: max,
  rirTarget: rir,
  setType: type,
  dropCount: dropCount,
  dropStepPercent: dropStepPercent,
  dropReps: dropReps,
  miniSetCount: miniSetCount,
  amrapTargetReps: amrapTargetReps,
  partialReps: partialReps,
  holdSeconds: holdSeconds,
);

m.EquipmentRef ref(m.EquipmentKind kind, String id) =>
    m.EquipmentRef(kind: kind, equipmentId: id);

m.EquipmentVariation variation(
  String id,
  List<m.EquipmentRef> resistance, {
  List<m.EquipmentRef> support = const [],
}) => m.EquipmentVariation(
  id: id,
  resistanceEquipment: resistance,
  supportEquipment: support,
);

m.ExerciseModel library(
  String id, {
  String name = 'Lift',
  List<m.TrackableExerciseMetric> metrics = const [
    m.TrackableExerciseMetric.weight,
    m.TrackableExerciseMetric.reps,
  ],
  m.ExerciseType? type,
  List<m.EquipmentVariation> variations = const [],
  bool isBodyweight = false,
  String? imageUrl,
}) => m.ExerciseModel(
  id: id,
  authorId: author,
  name: name,
  trackableMetrics: metrics,
  muscleGroups: const {},
  isBodyweight: isBodyweight,
  rangeOfMotion: 3,
  stability: 3,
  bodyWeightContribution: 0,
  alternateNames: const [],
  isSystemExercise: false,
  dateCreated: start,
  dateModified: start,
  type: type,
  equipmentVariations: variations,
  imageUrl: imageUrl,
);

m.GymProfileModel gym({
  String id = 'gym-1',
  List<m.FreeWeights> freeWeights = const [],
  List<m.LoadableBars> loadableBars = const [],
  List<m.FixedWeightBars> fixedWeightBars = const [],
  List<m.Bands> bands = const [],
  List<m.BodyWeights> bodyWeights = const [],
  List<m.PlainEquipment> supportEquipment = const [],
  List<m.StackMachine> cableMachines = const [],
  List<m.PlateLoadedMachine> plateLoadedMachines = const [],
  List<m.StackMachine> pinLoadedMachines = const [],
}) => m.GymProfileModel(
  id: id,
  authorId: author,
  name: 'Gym',
  icon: 'dumbbell',
  dateCreated: start,
  dateModified: start,
  freeWeights: freeWeights,
  loadableBars: loadableBars,
  fixedWeightBars: fixedWeightBars,
  bands: bands,
  bodyWeights: bodyWeights,
  supportEquipment: supportEquipment,
  accessoryEquipment: const [],
  loadableAccessoryEquipment: const [],
  cableMachines: cableMachines,
  plateLoadedMachines: plateLoadedMachines,
  pinLoadedMachines: pinLoadedMachines,
);

m.FreeWeights plates(
  List<double> weights, {
  String id = 'weight_plates',
  m.ExerciseWeightUnit unit = m.ExerciseWeightUnit.kilograms,
  List<int?>? counts,
  bool isPlates = true,
}) => m.FreeWeights(
  id: id,
  typeId: id,
  name: id,
  needsColour: false,
  isPlates: isPlates,
  isActive: true,
  range: [
    for (final (i, weight) in weights.indexed)
      m.FreeWeightsAvailable(
        id: '$id-$i',
        availableWeights: weight,
        unit: unit,
        isActive: true,
        count: counts?[i],
      ),
  ],
);

m.WorkoutSettings settings({
  bool propagateChanges = true,
  bool supersetAutoScroll = true,
  bool exerciseAutoNext = true,
  bool rirTracking = false,
  bool smartProgressionApplyInSession = false,
  bool addSmartWarmUps = true,
  int? supersetTransitionRestSeconds,
  bool useRestTimers = true,
  bool? setPlanning,
  m.InitialLogFillOption fill = m.InitialLogFillOption.previousValues,
  m.PreviousWorkoutReferenceOption reference =
      m.PreviousWorkoutReferenceOption.sameWorkout,
}) => m.WorkoutSettings(
  authorId: author,
  propagateChanges: propagateChanges,
  supersetAutoScroll: supersetAutoScroll,
  exerciseAutoNext: exerciseAutoNext,
  rirTracking: rirTracking,
  smartProgressionApplyInSession: smartProgressionApplyInSession,
  addSmartWarmUps: addSmartWarmUps,
  supersetTransitionRestSeconds: supersetTransitionRestSeconds,
  useRestTimers: useRestTimers,
  setPlanning: setPlanning,
  smartProgressionInitialLogFill: fill,
  previousWorkoutReference: reference,
);

/// A controller over [workout] with an in-memory store.
ActiveSessionController controller(
  m.WorkoutSessionModel workout, {
  m.WorkoutSettings? workoutSettings,
  ActiveSessionStore? store,
  FakeClock? clock,
  List<m.ExerciseModel> libraryExercises = const [],
  m.GymProfileModel? workoutGym,
  List<m.WorkoutSessionModel> history = const [],
  Map<String, int> restOverrides = const {},
  Ids? ids,
}) => ActiveSessionController(
  state: ActiveSessionState(session: workout),
  environment: TrackerEnvironment(
    authorId: author,
    settings: workoutSettings ?? settings(),
    library: libraryExercises,
    gym: workoutGym,
    history: SessionHistory(history),
    restOverrides: restOverrides,
  ),
  store: store ?? InMemoryActiveSessionStore(),
  clock: (clock ?? FakeClock()).call,
  newId: (ids ?? Ids()).call,
);

/// The weights of the first exercise's sets.
List<double?> weights(ActiveSessionController c) => [
  for (final s in c.session.exercises.first.sets) s.weightKg,
];
