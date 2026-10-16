import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/training_library/logic/exercise_filters.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// The exercise list's search text and filters.
final class const ExerciseListState({
  final String query = '',
  final ExerciseFilters filters = const ExerciseFilters(),
}) extends Equatable {
  ExerciseListState copyWith({String? query, ExerciseFilters? filters}) =>
      ExerciseListState(
        query: query ?? this.query,
        filters: filters ?? this.filters,
      );

  @override
  List<Object> get props => [query, filters];
}

/// The exercise list's search and filter bar, shared by the library and the
/// picker (`ExerciseListBuilderPresenter`), with its analytics.
class ExerciseListCubit extends Cubit<ExerciseListState> {
  new({required this._analytics}) : super(const ExerciseListState());

  final AnalyticsRepository _analytics;

  /// `<screen>_Appear`: `ExercisesView` or `ExercisesPickerView`.
  void appeared(String screen) =>
      _analytics.trackScreenView(AnalyticsEvent('${screen}_Appear'));

  void queryChanged(String query) => emit(state.copyWith(query: query));

  /// [filters] replace the current ones; [name] says which chip changed.
  void filtersChanged(ExerciseFilters filters, String name) {
    _analytics.trackEvent(
      AnalyticsEvent(
        'ExercisesView_Filter_Changed',
        parameters: {'filter': name},
      ),
    );
    emit(state.copyWith(filters: filters));
  }

  /// Clears every filter; nothing happens when none is set.
  void filtersReset() {
    if (!state.filters.isActive) return;
    _analytics.trackEvent(const AnalyticsEvent('ExercisesView_Filters_Reset'));
    emit(state.copyWith(filters: const ExerciseFilters()));
  }

  /// Create Exercise was opened from the list.
  void addExercisePressed() => _analytics.trackEvent(
    const AnalyticsEvent('ExercisesView_AddExercisePressed'),
  );

  /// Picking an exercise is what the list is for, so it is counted.
  void exerciseSelected(ExerciseModel exercise) => _analytics.trackEvent(
    AnalyticsEvent(
      'ExercisesView_Exercise_Selected',
      parameters: {'exercise_id': exercise.id, 'exercise_name': exercise.name},
    ),
  );
}
