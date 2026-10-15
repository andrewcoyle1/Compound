import 'dart:convert';

import 'package:compound_models/compound_models.dart';
import 'package:training_library_repository/src/prebuilt_exercises_json.dart';
import 'package:training_library_repository/src/prebuilt_workouts_json.dart';

/// The system exercises and workouts the Swift app bundles
/// (`PrebuiltExercises.json`, `PrebuiltWorkouts.json`) and seeds into local
/// storage at sign-in. They are never written to Firestore.
///
/// The JSON is embedded byte for byte (`tool/embed_json.dart` in
/// compound_models); a test fails when the Swift app's files change.
final class PrebuiltCatalogue {
  new _(this.exercises, this.workoutTemplates);

  /// Decodes the bundled JSON as `ExerciseModelManager` and
  /// `WorkoutTemplateManager` do.
  factory decode() {
    final exercises = [
      for (final exercise in _list(prebuiltExercisesJson, 'exercises'))
        ExerciseModel.fromFirestore(_withDates(exercise)),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return PrebuiltCatalogue._(
      List.unmodifiable(exercises),
      List.unmodifiable([
        for (final workout in _list(prebuiltWorkoutsJson, 'workouts'))
          ?_workout(workout, exercises),
      ]),
    );
  }

  /// The catalogue, decoded once.
  static final instance = PrebuiltCatalogue.decode();

  /// The system exercises, by name, as Swift's `systemExercises`.
  final List<ExerciseModel> exercises;

  /// The system workouts in the file's order, each exercise resolved
  /// against [exercises].
  final List<WorkoutTemplateModel> workoutTemplates;

  static List<Map<String, Object?>> _list(String json, String key) => [
    for (final item
        in (jsonDecode(json) as Map<String, Object?>)[key]! as List<Object?>)
      item! as Map<String, Object?>,
  ];

  /// Swift's `JSONDecoder` reads a date as seconds since 1 January 2001.
  static Map<String, Object?> _withDates(Map<String, Object?> exercise) => {
    ...exercise,
    for (final key in [
      ExerciseModelKeys.dateCreated,
      ExerciseModelKeys.dateModified,
    ])
      if (exercise[key] case final num seconds)
        key: _referenceDate.add(
          Duration(microseconds: (seconds * 1000000).round()),
        ),
  };

  static final _referenceDate = DateTime.utc(2001);

  /// `PrebuiltWorkoutDTO.toModel`: exercises it cannot find are left out,
  /// and a workout left with none is dropped. Each exercise starts as one
  /// standard set of 8 to 12 reps with rest timers off.
  ///
  /// Swift gives each slot and set target a random id and stamps the
  /// workout with the time it was seeded; here they are derived from the
  /// workout, and the dates are the exercises', so the catalogue is the
  /// same on every launch. The ids are only ever read within the template.
  static WorkoutTemplateModel? _workout(
    Map<String, Object?> workout,
    List<ExerciseModel> exercises,
  ) {
    final workoutId = workout['workoutId']! as String;
    final resolved = [
      for (final id in workout['exerciseIds']! as List<Object?>)
        ?exercises.where((exercise) => exercise.id == id).firstOrNull,
    ];
    if (resolved.isEmpty) return null;
    final seeded = resolved.first.dateCreated;
    return WorkoutTemplateModel(
      workoutId: workoutId,
      authorId: 'official',
      name: workout['name']! as String,
      description: workout['description'] as String?,
      dateCreated: seeded,
      dateModified: seeded,
      exercises: [
        for (final (index, exercise) in resolved.indexed)
          WorkoutTemplateExercise(
            id: '${workoutId}_${index + 1}',
            exercise: exercise,
            setTargets: [
              SetTarget(
                id: '${workoutId}_${index + 1}_set_1',
                setNumber: 1,
                minReps: 8,
                maxReps: 12,
              ),
            ],
            setRestTimers: false,
          ),
      ],
    );
  }
}
