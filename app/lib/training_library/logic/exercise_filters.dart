import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show ValueGetter;

/// A piece of equipment by kind and catalogue type, which is what an
/// exercise names and what a gym has (Swift `EquipmentRef`, as a key).
typedef EquipmentKey = (EquipmentKind kind, String typeId);

/// Which library an exercise comes from (Swift
/// `ExerciseFilters.LibraryScope`).
enum ExerciseLibraryScope {
  /// Every exercise.
  all,

  /// The user's own.
  mine,

  /// The bundled system exercises.
  official,
}

/// The exercise list's filter bar (Swift `ExerciseFilters`): one value every
/// list on the screen runs through.
final class const ExerciseFilters({
  final Set<ExerciseType> types = const {},
  final Set<Laterality> lateralities = const {},
  final Set<EquipmentKind> resistanceKinds = const {},
  final Set<EquipmentKind> supportKinds = const {},

  /// A floor on the 1–5 range-of-motion rating.
  final int? minimumRangeOfMotion,

  /// A floor on the 1–5 stability rating.
  final int? minimumStability,
  final ExerciseLibraryScope library = ExerciseLibraryScope.all,

  /// The gym whose equipment an exercise must be performable with, or null
  /// for any equipment.
  final String? gymProfileId,
}) extends Equatable {
  /// Whether anything narrows the list.
  bool get isActive => this != const ExerciseFilters();

  ExerciseFilters copyWith({
    Set<ExerciseType>? types,
    Set<Laterality>? lateralities,
    Set<EquipmentKind>? resistanceKinds,
    Set<EquipmentKind>? supportKinds,
    ValueGetter<int?>? minimumRangeOfMotion,
    ValueGetter<int?>? minimumStability,
    ExerciseLibraryScope? library,
    ValueGetter<String?>? gymProfileId,
  }) => ExerciseFilters(
    types: types ?? this.types,
    lateralities: lateralities ?? this.lateralities,
    resistanceKinds: resistanceKinds ?? this.resistanceKinds,
    supportKinds: supportKinds ?? this.supportKinds,
    minimumRangeOfMotion: minimumRangeOfMotion != null
        ? minimumRangeOfMotion()
        : this.minimumRangeOfMotion,
    minimumStability: minimumStability != null
        ? minimumStability()
        : this.minimumStability,
    library: library ?? this.library,
    gymProfileId: gymProfileId != null ? gymProfileId() : this.gymProfileId,
  );

  /// Whether [exercise] passes every filter. [availableEquipment] is the
  /// chosen gym's active equipment; with a gym chosen, an empty set is a gym
  /// with nothing in it, which matches only exercises needing no equipment.
  bool matches(ExerciseModel exercise, Set<EquipmentKey> availableEquipment) {
    if (types.isNotEmpty && !types.contains(exercise.type)) return false;
    if (lateralities.isNotEmpty &&
        !lateralities.contains(exercise.laterality)) {
      return false;
    }
    // Variations are alternatives, so one using a chosen kind is enough.
    final variations = exercise.equipmentVariations;
    if (resistanceKinds.isNotEmpty &&
        !variations
            .expand((variation) => variation.resistanceEquipment)
            .any((ref) => resistanceKinds.contains(ref.kind))) {
      return false;
    }
    if (supportKinds.isNotEmpty &&
        !variations
            .expand((variation) => variation.supportEquipment)
            .any((ref) => supportKinds.contains(ref.kind))) {
      return false;
    }
    if (exercise.rangeOfMotion < (minimumRangeOfMotion ?? 0)) return false;
    if (exercise.stability < (minimumStability ?? 0)) return false;
    final libraryMatches = switch (library) {
      ExerciseLibraryScope.all => true,
      ExerciseLibraryScope.mine => !exercise.isSystemExercise,
      ExerciseLibraryScope.official => exercise.isSystemExercise,
    };
    if (!libraryMatches) return false;
    return gymProfileId == null ||
        isPerformable(exercise, available: availableEquipment);
  }

  /// Performable when the exercise needs no equipment, or when one of its
  /// variations can be put together entirely from [available]: half a variation
  /// is no way to do it.
  static bool isPerformable(
    ExerciseModel exercise, {
    required Set<EquipmentKey> available,
  }) =>
      exercise.equipmentVariations.isEmpty ||
      exercise.equipmentVariations.any(
        (variation) => [
          ...variation.resistanceEquipment,
          ...variation.supportEquipment,
        ].every((ref) => available.contains((ref.kind, ref.equipmentId))),
      );

  @override
  List<Object?> get props => [
    types,
    lateralities,
    resistanceKinds,
    supportKinds,
    minimumRangeOfMotion,
    minimumStability,
    library,
    gymProfileId,
  ];
}
