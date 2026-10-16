import 'package:compound/training_library/logic/exercise_filters.dart';
import 'package:compound/training_library/logic/search_match.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Everything the library screens read: the user's exercises, workout
/// templates, mesocycles and gyms, beside the bundled system exercises and
/// workouts ([PrebuiltCatalogue]).
final class const TrainingLibrary({
  /// The user's own exercises.
  final List<ExerciseModel> userExercises = const [],

  /// The user's own workout templates.
  final List<WorkoutTemplateModel> userWorkoutTemplates = const [],

  /// The user's mesocycles.
  final List<Mesocycle> mesocycles = const [],

  /// The user's gyms, deleted ones included.
  final List<GymProfileModel> gymProfiles = const [],
}) extends Equatable {
  /// The bundled exercises, by name.
  List<ExerciseModel> get systemExercises =>
      PrebuiltCatalogue.instance.exercises;

  /// The bundled workouts.
  List<WorkoutTemplateModel> get systemWorkoutTemplates =>
      PrebuiltCatalogue.instance.workoutTemplates;

  /// The user's exercises, then the bundled ones.
  List<ExerciseModel> get allExercises => [
    ...userExercises,
    ...systemExercises,
  ];

  /// The gyms that haven't been deleted.
  List<GymProfileModel> get gyms => [
    for (final gym in gymProfiles)
      if (gym.deletedAt == null) gym,
  ];

  /// The exercise with [id], the user's own first.
  ExerciseModel? exercise(String id) =>
      allExercises.where((exercise) => exercise.id == id).firstOrNull;

  /// [exercises] that pass [filters], by name (`ExerciseListBuilderPresenter`).
  List<ExerciseModel> filtered(
    Iterable<ExerciseModel> exercises,
    ExerciseFilters filters,
  ) {
    final equipment = availableEquipment(filters.gymProfileId);
    return byName([
      for (final exercise in exercises)
        if (filters.matches(exercise, equipment)) exercise,
    ], (exercise) => exercise.name);
  }

  /// Every exercise matching [query] on its name, description, muscles or
  /// other names, by name. Empty for a blank query.
  List<ExerciseModel> searchExercises(String query) => byName([
    for (final exercise in allExercises)
      if (exerciseMatches(exercise, query)) exercise,
  ], (exercise) => exercise.name);

  /// Every workout template, the user's and the bundled ones, matching
  /// [query] on its name, description or exercises, by name.
  List<WorkoutTemplateModel> searchWorkoutTemplates(String query) => byName([
    for (final template in [...userWorkoutTemplates, ...systemWorkoutTemplates])
      if (templateMatches(template, query)) template,
  ], (template) => template.name);

  /// The mesocycles with a workout day left after [query], by name, each
  /// with those days in its own order (`WorkoutListPresenterBuilder`). Rest
  /// days are left out, and a blank query keeps every day.
  List<(Mesocycle, List<WorkoutTemplateModel>)> mesocycleDays(String query) {
    final searching = SearchMatch.isSearching(query);
    return [
      for (final mesocycle in byName(mesocycles, (mesocycle) => mesocycle.name))
        if ([
              for (final day in mesocycle.workoutTemplates)
                if (day.exercises.isNotEmpty &&
                    (!searching || templateMatches(day, query)))
                  day,
            ]
            case final days when days.isNotEmpty)
          (mesocycle, days),
    ];
  }

  /// The template with [id]: a user's own, a mesocycle's day (with its
  /// mesocycle), or a bundled one.
  (WorkoutTemplateModel, Mesocycle?)? template(String id) {
    for (final template in userWorkoutTemplates) {
      if (template.workoutId == id) return (template, null);
    }
    for (final mesocycle in mesocycles) {
      for (final day in mesocycle.workoutTemplates) {
        if (day.workoutId == id) return (day, mesocycle);
      }
    }
    for (final template in systemWorkoutTemplates) {
      if (template.workoutId == id) return (template, null);
    }
    return null;
  }

  /// The active equipment of the gym with [gymProfileId], by type: a
  /// duplicate machine switched on makes its type available. Empty with no
  /// gym.
  Set<EquipmentKey> availableEquipment(String? gymProfileId) {
    final gym = gyms.where((gym) => gym.id == gymProfileId).firstOrNull;
    if (gym == null) return const {};
    return {
      for (final (kind, item) in _equipment(gym))
        if (item.isActive) (kind, item.typeId),
    };
  }

  /// Every type of equipment an exercise can name, with its name: the
  /// catalogue's, then those the user's gyms add, once each (Swift
  /// `GymProfileModel.equipmentTypes(including:)`).
  List<(EquipmentKey, String)> get equipmentTypes {
    final seen = <EquipmentKey>{};
    return [
      for (final gym in [_catalogue, ...gymProfiles])
        for (final (kind, item) in _equipment(gym))
          if (seen.add((kind, item.typeId)))
            (
              (kind, item.typeId),
              item.toFirestore()[GymEquipmentKeys.name] as String? ??
                  item.typeId,
            ),
    ];
  }

  /// What [ref] is called: the first catalogue item of its type, else the
  /// first in the user's gyms (a machine they added). Null when nothing
  /// names it any more.
  String? equipmentName(EquipmentRef ref) {
    for (final gym in [_catalogue, ...gymProfiles]) {
      for (final (kind, item) in _equipment(gym)) {
        if (kind == ref.kind && item.typeId == ref.equipmentId) {
          return item.toFirestore()[GymEquipmentKeys.name] as String?;
        }
      }
    }
    return null;
  }

  /// How many pieces of [gym]'s equipment are switched on
  /// (`GymProfileModel.activeEquipmentCount`).
  static int activeEquipmentCount(GymProfileModel gym) => [
    for (final (_, item) in _equipment(gym))
      if (item.isActive) item,
  ].length;

  /// A profile decoded from nothing holds the whole catalogue.
  static final _catalogue = GymProfileModel.fromFirestore(const {
    GymProfileModelKeys.id: 'catalogue',
    GymProfileModelKeys.authorId: '',
  });

  static List<(EquipmentKind, GymEquipmentItem)> _equipment(
    GymProfileModel gym,
  ) => [
    for (final (kind, items) in <(EquipmentKind, List<GymEquipmentItem>)>[
      (EquipmentKind.freeWeight, gym.freeWeights),
      (EquipmentKind.loadableBar, gym.loadableBars),
      (EquipmentKind.fixedWeightBar, gym.fixedWeightBars),
      (EquipmentKind.bands, gym.bands),
      (EquipmentKind.bodyWeight, gym.bodyWeights),
      (EquipmentKind.supportEquipment, gym.supportEquipment),
      (EquipmentKind.accessoryEquipment, gym.accessoryEquipment),
      (
        EquipmentKind.loadableAccessoryEquipment,
        gym.loadableAccessoryEquipment,
      ),
      (EquipmentKind.cableMachine, gym.cableMachines),
      (EquipmentKind.plateLoadedMachine, gym.plateLoadedMachines),
      (EquipmentKind.pinLoadedMachine, gym.pinLoadedMachines),
    ])
      for (final item in items) (kind, item),
  ];

  /// Whether [exercise] matches [query] (Training's search and the exercise
  /// list's): name, description, muscles and other names.
  static bool exerciseMatches(ExerciseModel exercise, String query) =>
      SearchMatch.matches(query, [
        exercise.name,
        exercise.description,
        for (final muscle in exercise.muscleGroups.keys) muscle.value,
        ...exercise.alternateNames,
      ]);

  /// Whether [template] matches [query]: name, description and exercises.
  static bool templateMatches(WorkoutTemplateModel template, String query) =>
      SearchMatch.matches(query, [
        template.name,
        template.description,
        for (final exercise in template.exercises) exercise.exercise.name,
      ]);

  /// [items] sorted by [name], as Swift's `sortedByKeyPath(\.name)`.
  static List<T> byName<T>(Iterable<T> items, String Function(T) name) =>
      items.toList()..sort((a, b) => name(a).compareTo(name(b)));

  @override
  List<Object> get props => [
    userExercises,
    userWorkoutTemplates,
    mesocycles,
    gymProfiles,
  ];
}
