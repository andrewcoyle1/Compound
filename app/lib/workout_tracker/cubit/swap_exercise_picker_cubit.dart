import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// The library, the plan's alternatives for the exercise being swapped, and
/// the search typed.
final class const SwapExercisePickerState({
  required final List<ExerciseModel> library,
  required final List<String> alternativeIds,
  final String search = '',
}) extends Equatable {
  /// The plan's alternatives the library holds that the search matches,
  /// best first, else in the plan's order; an id it no longer holds is
  /// skipped.
  List<ExerciseModel> get plannedAlternatives => _search([
    for (final id in alternativeIds)
      ?library.where((e) => e.id == id).firstOrNull,
  ]);

  /// Every exercise the search matches, best first.
  List<ExerciseModel> get exercises => _search(library);

  List<ExerciseModel> _search(List<ExerciseModel> exercises) =>
      FuzzyMatch.search(
        exercises,
        search,
        (exercise) => [
          [exercise.name],
        ],
      );

  @override
  List<Object> get props => [library, alternativeIds, search];
}

/// Swap Exercise (Swift `SwapExercisePickerPresenter`): the plan's
/// alternatives first, then the library, searched by name.
class SwapExercisePickerCubit extends Cubit<SwapExercisePickerState> {
  new({
    required List<ExerciseModel> library,
    required List<String> alternativeIds,
    required this._analytics,
  }) : super(
         SwapExercisePickerState(
           library: library,
           alternativeIds: alternativeIds,
         ),
       );

  final AnalyticsRepository _analytics;

  void appeared() => _analytics.appear('SwapExercisePicker', {
    'planned_alternatives': state.alternativeIds.length,
  });

  void searchChanged(String search) => emit(
    SwapExercisePickerState(
      library: state.library,
      alternativeIds: state.alternativeIds,
      search: search,
    ),
  );

  /// [exercise] chosen; the page hands it back.
  void selected(ExerciseModel exercise) => _analytics.analytic(
    'SwapExercisePicker_Exercise_Selected',
    {'planned_alternative': state.alternativeIds.contains(exercise.id)},
  );
}
