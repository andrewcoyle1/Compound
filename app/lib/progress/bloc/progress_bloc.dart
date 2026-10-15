import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart' show AppFormat, AppWeightUnit;
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/progress/logic/progress_overview.dart';
import 'package:compound/today/logic/today_checklist.dart' show countedSessions;
import 'package:compound/training_analytics/logic/training_analytics.dart';
import 'package:compound/weight_metric/models/weight_metric.dart';
import 'package:compound_maths/compound_maths.dart'
    hide CheckInState, LoggingBreak, Muscle;
import 'package:compound_models/compound_models.dart' show WorkoutSessionStats;
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'progress_event.dart';
part 'progress_state.dart';

/// The Progress tab's overview (Swift `AnalyticsPresenter`): the user's
/// sessions, meals, diet plan, weigh-ins, steps, section settings, profile
/// and weight goal, each followed live, so the cards move as soon as
/// anything is logged.
///
/// The screens behind the tab (Insights & Analytics, Habits, Nutrition,
/// Body Metrics and every metric under them) read the same data, so each
/// takes one of these too, named by `screen` for its `_Appear` event.
class ProgressBloc extends Bloc<ProgressEvent, ProgressState> {
  new({
    required this._workoutSessionRepository,
    required this._nutritionRepository,
    required this._bodyRepository,
    required this._userRepository,
    required this._analyticsRepository,
    required this._trainingLibraryRepository,
    required this._checkInRepository,
    required this._uid,
    required int firstWeekday,
    this._screen = 'AnalyticsView',
    this._parameters,
    DateTime Function() now = DateTime.now,
  }) : super(
         ProgressState(
           uid: _uid,
           now: now(),
           firstWeekday: firstWeekday,
           // The weekly target grid opens on today's column.
           targetDay: (now().weekday - firstWeekday + 7) % 7,
         ),
       ) {
    on<ProgressSubscriptionRequested>(_onSubscriptionRequested);
    on<ProgressRangeSelected>(
      (event, emit) => emit(state.copyWith(range: event.range)),
    );
    on<ProgressMeasurementCleared>(_onMeasurementCleared);
    on<ProgressTargetDayPressed>(_onTargetDayPressed);
    on<_ProgressGoalChanged>(
      (event, emit) => emit(state.copyWith(goal: () => event.goal)),
    );
  }

  final WorkoutSessionRepository _workoutSessionRepository;
  final NutritionRepository _nutritionRepository;
  final BodyRepository _bodyRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final TrainingLibraryRepository _trainingLibraryRepository;
  final CheckInRepository _checkInRepository;
  final String _uid;
  final String _screen;
  final Map<String, Object?>? _parameters;

  StreamSubscription<WeightGoal?>? _goalSubscription;
  String? _goalId;

  Future<void> _onSubscriptionRequested(
    ProgressSubscriptionRequested event,
    Emitter<ProgressState> emit,
  ) {
    _analyticsRepository.appear(_screen, _parameters);
    _watchGoal(null);
    ProgressState failed(Object _, StackTrace _) =>
        state.copyWith(failed: true);
    return Future.wait([
      emit.forEach(
        _workoutSessionRepository.watchSessions(_uid),
        onData: (sessions) => state.copyWith(sessions: sessions),
        onError: failed,
      ),
      emit.forEach(
        _nutritionRepository.watchMeals(_uid),
        onData: (meals) => state.copyWith(meals: meals),
        onError: failed,
      ),
      emit.forEach(
        _bodyRepository.watchMeasurements(_uid),
        onData: (measurements) => state.copyWith(measurements: measurements),
        onError: failed,
      ),
      // The rest are niceties: without them, no protein target, no steps,
      // every section, the system exercises only, kilograms and no goal.
      emit.forEach(
        _nutritionRepository.watchDietPlan(_uid),
        onData: (plan) => state.copyWith(dietPlan: () => plan),
        onError: (_, _) => state.copyWith(dietPlan: () => null),
      ),
      emit.forEach(
        _bodyRepository.watchSteps(_uid),
        onData: (steps) => state.copyWith(steps: steps),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _bodyRepository.watchAnalyticsSettings(_uid),
        onData: (settings) => state.copyWith(analyticsSettings: () => settings),
        onError: (_, _) => state,
      ),
      // The expenditure engine's: without them, Swift's default settings,
      // no annotations and no break.
      emit.forEach(
        _checkInRepository.watchStrategySettings(_uid),
        onData: (settings) => state.copyWith(strategySettings: settings),
        onError: (_, _) => state.copyWith(
          strategySettings: NutritionStrategySettings(authorId: _uid),
        ),
      ),
      emit.forEach(
        _checkInRepository.watchDayAnnotations(_uid),
        onData: (annotations) => state.copyWith(annotations: annotations),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _checkInRepository.watchLoggingBreak(_uid),
        onData: (loggingBreak) =>
            state.copyWith(loggingBreak: () => loggingBreak),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _trainingLibraryRepository.watchUserExercises(_uid),
        onData: (exercises) => state.copyWith(userExercises: exercises),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _userRepository.watchUser(_uid),
        onData: (user) {
          _watchGoal(user?.submittedCurrentGoalId);
          return state.copyWith(user: () => user);
        },
        onError: (_, _) => state,
      ),
    ]);
  }

  /// Removes [ProgressMeasurementCleared.fields] from the entry, with a
  /// delete rather than Swift's merge (which loses the clear; see
  /// `swift-findings.md`), logging `<screen>_DeleteEntry_*` as Swift's
  /// presenters do. A failure counts in [ProgressState.deleteFailures], for
  /// the screen's alert; the row stays, as the entry never changed.
  Future<void> _onMeasurementCleared(
    ProgressMeasurementCleared event,
    Emitter<ProgressState> emit,
  ) async {
    _analyticsRepository.analytic('${_screen}_DeleteEntry_Start', _parameters);
    try {
      await _bodyRepository.clearMeasurementFields(
        _uid,
        event.entryId,
        event.fields,
      );
      _analyticsRepository.analytic(
        '${_screen}_DeleteEntry_Success',
        _parameters,
      );
    } on Object catch (error) {
      _analyticsRepository.severe(
        '${_screen}_DeleteEntry_Fail',
        error,
        _parameters,
      );
      emit(state.copyWith(deleteFailures: state.deleteFailures + 1));
    }
  }

  /// Shows the pressed day on the weekly target grid's last column, or the
  /// week when it was already shown (`NutritionTargetChartPresenter
  /// .onDayPressed`).
  void _onTargetDayPressed(
    ProgressTargetDayPressed event,
    Emitter<ProgressState> emit,
  ) {
    final day = state.targetDay == event.day ? null : event.day;
    _analyticsRepository.analytic('NutritionTargetChart_Day_Pressed', {
      'is_week': day == null,
    });
    emit(state.copyWith(targetDay: () => day));
  }

  /// Follows the goal named by [goalId] (the uid's, without one), dropping
  /// the previous goal's stream when the id changes, as `GoalManager` does.
  void _watchGoal(String? goalId) {
    if (_goalSubscription != null && goalId == _goalId) return;
    _goalId = goalId;
    unawaited(_goalSubscription?.cancel());
    _goalSubscription = _bodyRepository
        .watchCurrentGoal(_uid, currentGoalId: goalId)
        .listen(
          (goal) => add(_ProgressGoalChanged(goal)),
          onError: (Object _) => add(const _ProgressGoalChanged(null)),
        );
  }

  @override
  Future<void> close() async {
    await _goalSubscription?.cancel();
    await super.close();
  }
}
