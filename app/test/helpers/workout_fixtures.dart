import 'package:compound_models/compound_models.dart';

/// 1 to 31 March 2026, at noon local time. The 2nd is a Monday.
DateTime marchDay(int day) => DateTime(2026, 3, day, 12);

WorkoutSetModel fixtureSet({
  String? id,
  int? reps = 5,
  double? weightKg = 100,
  int? durationSec,
  double? distanceMeters,
  double? rpe,
  bool isWarmup = false,
  bool completed = true,
  String? side,
  String? kind,
  String? parentSetId,
  String? weightUnit,
}) => WorkoutSetModel(
  id: id ?? 'set-${_next++}',
  authorId: 'friend',
  index: 1,
  isWarmup: isWarmup,
  dateCreated: marchDay(2),
  completedAt: completed ? marchDay(2) : null,
  reps: reps,
  weightKg: weightKg,
  durationSec: durationSec,
  distanceMeters: distanceMeters,
  rpe: rpe,
  sideRawValue: side,
  kindRawValue: kind,
  parentSetId: parentSetId,
  weightUnitRawValue: weightUnit,
);

int _next = 0;

WorkoutExerciseModel fixtureExercise(
  String name, {
  required List<WorkoutSetModel> sets,
  TrackingMode mode = TrackingMode.weightReps,
  ExerciseWeightUnit? weightUnit,
  String? notes,
}) => WorkoutExerciseModel(
  id: 'exercise-$name',
  authorId: 'friend',
  templateId: name,
  name: name,
  trackingMode: mode,
  index: 1,
  sets: sets,
  weightUnit: weightUnit,
  notes: notes,
);

WorkoutSessionModel fixtureSession(
  String id, {
  int day = 2,
  String author = 'friend',
  bool finished = true,
  bool isRestDay = false,
  int minutes = 60,
  String? notes,
  int? weekStreakCount,
  String? mesocycleId,
  List<WorkoutExerciseModel> exercises = const [],
}) => WorkoutSessionModel(
  id: id,
  authorId: author,
  name: 'Session $id',
  dateCreated: marchDay(day),
  dateModified: marchDay(day),
  endedAt: finished ? marchDay(day).add(Duration(minutes: minutes)) : null,
  isRestDay: isRestDay,
  notes: notes,
  weekStreakCount: weekStreakCount,
  mesocycleId: mesocycleId,
  exercises: exercises,
);
