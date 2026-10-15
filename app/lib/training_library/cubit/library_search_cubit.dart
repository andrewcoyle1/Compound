import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound_models/compound_models.dart';

/// A library screen's search text (Training's search, the workouts list),
/// with the screen's analytics.
class LibrarySearchCubit extends Cubit<String> {
  new({required this._analytics}) : super('');

  final AnalyticsRepository _analytics;

  /// `<screen>_Appear`, such as `WorkoutsView`.
  void appeared(String screen) =>
      _analytics.trackScreenView(AnalyticsEvent('${screen}_Appear'));

  void queryChanged(String query) => emit(query);

  /// A workout picked from the list (`WorkoutsView_Workout_Selected`);
  /// [isMesocycleDay] when it is a day of one of the user's mesocycles.
  void workoutSelected(
    WorkoutTemplateModel workout, {
    required bool isMesocycleDay,
  }) => _analytics.trackEvent(
    AnalyticsEvent(
      'WorkoutsView_Workout_Selected',
      parameters: {
        'workout_id': workout.workoutId,
        'workout_name': workout.name,
        'is_mesocycle_day': isMesocycleDay,
      },
    ),
  );
}
