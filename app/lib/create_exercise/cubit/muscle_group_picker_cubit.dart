import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// The muscles chosen so far, and how much each is worked.
final class const MuscleGroupPickerState({
  final Map<Muscles, MuscleTargetType> selected = const {},
}) extends Equatable {
  int get primaryCount =>
      selected.values.where((t) => t == MuscleTargetType.primary).length;

  int get secondaryCount =>
      selected.values.where((t) => t == MuscleTargetType.secondary).length;

  @override
  List<Object> get props => [selected];
}

/// The second step (Swift `MuscleGroupPickerPresenter`). It can be skipped.
class MuscleGroupPickerCubit extends Cubit<MuscleGroupPickerState> {
  new({required this._draft, required this._analytics})
    : super(MuscleGroupPickerState(selected: _draft.muscleGroups));

  static const _screen = 'MuscleGroupPickerView';

  final ExerciseDraft _draft;
  final AnalyticsRepository _analytics;

  void appeared() => _analytics.appear(_screen);

  void disappeared() => _analytics.disappear(_screen);

  /// Cycles [muscle] from off to primary to secondary and off again.
  void pressed(Muscles muscle) {
    final selected = {...state.selected};
    switch (selected[muscle]) {
      case null:
        selected[muscle] = MuscleTargetType.primary;
      case MuscleTargetType.primary:
        selected[muscle] = MuscleTargetType.secondary;
      case MuscleTargetType.secondary:
        selected.remove(muscle);
    }
    emit(MuscleGroupPickerState(selected: selected));
  }

  void reset() => emit(const MuscleGroupPickerState());

  /// The draft the equipment step opens with.
  ExerciseDraft get next => _draft.copyWith(muscleGroups: state.selected);
}
