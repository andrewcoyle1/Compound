import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/training_library/models/training_library.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show EquipmentScope;

/// What the equipment sheet opens on: the exercise, the library and gyms
/// that name its equipment, and the workout's gym.
final class const EquipmentSheetSetup({
  required final WorkoutExerciseModel exercise,
  required final List<ExerciseModel> library,
  required final List<GymProfileModel> gyms,
  required final GymProfileModel? gym,
});

/// One variation as the sheet lists it (`VariationDisplayItem`). A name is
/// `null` for equipment no gym or catalogue lists any more, which the sheet
/// calls removed.
final class const VariationItem({
  required final String id,

  /// Its place in the list, from 1: "Variation 2".
  required final int number,
  required final List<String?> resistance,
  required final List<String?> support,

  /// Its equipment, for the gym editor to show alone.
  required final EquipmentScope equipment,

  /// Whether the workout's gym has every item it needs switched on.
  final bool isAvailable = true,
}) extends Equatable {
  @override
  List<Object?> get props => [
    id,
    number,
    resistance,
    support,
    equipment,
    isAvailable,
  ];
}

final class const EquipmentSheetState({
  required final String exerciseId,
  required final String exerciseName,
  final List<VariationItem> items = const [],
  final String? chosenId,

  /// The exercise defines no variations ("No Equipment").
  final bool hasNoVariations = false,

  /// The workout's gym, as last saved from here; equipment can be edited
  /// only in it.
  final GymProfileModel? gym,
}) extends Equatable {
  EquipmentSheetState copyWith({
    List<VariationItem>? items,
    String? chosenId,
    bool? hasNoVariations,
    GymProfileModel? gym,
  }) => EquipmentSheetState(
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    items: items ?? this.items,
    chosenId: chosenId ?? this.chosenId,
    hasNoVariations: hasNoVariations ?? this.hasNoVariations,
    gym: gym ?? this.gym,
  );

  @override
  List<Object?> get props => [
    exerciseId,
    exerciseName,
    items,
    chosenId,
    hasNoVariations,
    gym,
  ];
}

/// The exercise's equipment variations, one to pick, each editable in the
/// workout's gym (`WorkoutExerciseEquipmentSheetPresenter`).
class EquipmentSheetCubit extends Cubit<EquipmentSheetState> {
  new(EquipmentSheetSetup setup, {required this._analytics})
    : _setup = setup,
      super(
        EquipmentSheetState(
          exerciseId: setup.exercise.id,
          exerciseName: setup.exercise.name,
          gym: setup.gym,
        ),
      ) {
    _analytics.appear(_screen);
    _load();
  }

  static const _screen = 'WorkoutExerciseEquipmentSheetView';

  final EquipmentSheetSetup _setup;
  final AnalyticsRepository _analytics;
  List<EquipmentVariation> _variations = const [];

  void _load() {
    _analytics.analytic('${_screen}_LoadVariations_Start');
    final exercise = _setup.exercise;
    // The session's own variations, else the library's for an old session
    // (a stale template id is matched by name).
    var variations = exercise.equipmentVariations;
    if (variations.isEmpty) {
      final name = exercise.name.toLowerCase();
      final library = _setup.library;
      final template =
          library.where((e) => e.id == exercise.templateId).firstOrNull ??
          library.where((e) => e.name.toLowerCase() == name).firstOrNull;
      variations = template?.equipmentVariations ?? const [];
    }
    if (variations.isEmpty) {
      _analytics.severe(
        '${_screen}_LoadVariations_Fail',
        'No equipment variations defined for this exercise.',
      );
      return emit(state.copyWith(hasNoVariations: true));
    }
    _variations = variations;
    emit(
      state.copyWith(
        items: _items(state.gym),
        chosenId: exercise.chosenVariationId ?? variations.first.id,
      ),
    );
    _analytics.analytic('${_screen}_LoadVariations_Success');
  }

  List<VariationItem> _items(GymProfileModel? gym) {
    final names = TrainingLibrary(gymProfiles: _setup.gyms);
    final available = gym == null
        ? null
        : TrainingLibrary(gymProfiles: [gym]).availableEquipment(gym.id);
    String? name(EquipmentRef ref) =>
        names.equipmentName(ref) ??
        (_uuid.hasMatch(ref.equipmentId) ? null : ref.equipmentId);
    return [
      for (final (index, variation) in _variations.indexed)
        VariationItem(
          id: variation.id,
          number: index + 1,
          resistance: variation.resistanceEquipment.map(name).toList(),
          support: variation.supportEquipment.map(name).toList(),
          equipment: {
            for (final ref in [
              ...variation.resistanceEquipment,
              ...variation.supportEquipment,
            ])
              (ref.kind, ref.equipmentId),
          },
          isAvailable:
              available == null ||
              [
                ...variation.resistanceEquipment,
                ...variation.supportEquipment,
              ].every((ref) => available.contains((ref.kind, ref.equipmentId))),
        ),
    ];
  }

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// A tap on a row chooses it.
  void selected(String id) => emit(state.copyWith(chosenId: id));

  /// A row's ⋯ opened its equipment in the workout's gym.
  void editPressed() => _analytics.analytic('${_screen}_EditVariation_Pressed');

  /// The gym was saved from a variation's editor: "Not in this gym"
  /// follows it.
  void gymSaved(GymProfileModel gym) =>
      emit(state.copyWith(gym: gym, items: _items(gym)));

  @override
  Future<void> close() {
    _analytics.disappear(_screen);
    return super.close();
  }
}
