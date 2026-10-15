import 'package:bloc/bloc.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// The exercises ticked in the picker so far.
final class const ExercisePickerState({
  /// Ticked here, in the order they were ticked.
  final List<ExerciseModel> picked = const [],

  /// Already in the caller's list: shown ticked, never added again.
  final Set<String> committedIds = const {},

  /// Not offered, such as the exercise whose substitutes are being chosen.
  final Set<String> excludedIds = const {},
}) extends Equatable {
  /// Something new is ticked, which closing would lose.
  bool get hasUnsavedChanges => picked.isNotEmpty;

  /// Confirming with nothing new ticked would add nothing.
  bool get canSave => picked.isNotEmpty;

  /// Whether [id] shows ticked.
  bool isSelected(String id) =>
      committedIds.contains(id) || picked.any((exercise) => exercise.id == id);

  @override
  List<Object> get props => [picked, committedIds, excludedIds];
}

/// The exercise picker's selection (`ExercisesPickerPresenter`).
class ExercisePickerCubit extends Cubit<ExercisePickerState> {
  new({Set<String> committedIds = const {}, Set<String> excludedIds = const {}})
    : super(
        ExercisePickerState(
          committedIds: committedIds,
          excludedIds: excludedIds,
        ),
      );

  /// Ticks or unticks [exercise]. One already in the caller's list stays
  /// ticked, and an excluded one can't be ticked.
  void toggled(ExerciseModel exercise) {
    if (state.excludedIds.contains(exercise.id) ||
        state.committedIds.contains(exercise.id)) {
      return;
    }
    final picked = state.picked.any((other) => other.id == exercise.id)
        ? [
            for (final other in state.picked)
              if (other.id != exercise.id) other,
          ]
        : [...state.picked, exercise];
    emit(
      ExercisePickerState(
        picked: picked,
        committedIds: state.committedIds,
        excludedIds: state.excludedIds,
      ),
    );
  }
}
