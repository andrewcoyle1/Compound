import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound_maths/compound_maths.dart'
    hide CheckInState, LoggingBreak;
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'today_event.dart';
part 'today_state.dart';

/// The Today tab: the user's sessions, meals, diet plan, weigh-ins, steps,
/// step goal, profile and weight goal, each followed live, so logging
/// anything elsewhere shows here at once (Swift `TodayPresenter`).
class TodayBloc extends Bloc<TodayEvent, TodayState> {
  new({
    required this._workoutSessionRepository,
    required this._nutritionRepository,
    required this._bodyRepository,
    required this._userRepository,
    required this._analyticsRepository,
    required this._checkInRepository,
    required this._uid,
    required int firstWeekday,
    DateTime Function() now = DateTime.now,
  }) : super(TodayState(uid: _uid, now: now(), firstWeekday: firstWeekday)) {
    on<TodaySubscriptionRequested>(_onSubscriptionRequested);
    on<_TodayGoalChanged>(
      (event, emit) => emit(state.copyWith(goal: () => event.goal)),
    );
    on<TodayCheckInStarted>(
      (event, emit) => _analyticsRepository.trackEvent(
        const AnalyticsEvent('TodayView_CheckIn_Start'),
      ),
    );
    on<TodayCheckInSkipped>(_onCheckInSkipped);
  }

  final WorkoutSessionRepository _workoutSessionRepository;
  final NutritionRepository _nutritionRepository;
  final BodyRepository _bodyRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final CheckInRepository _checkInRepository;
  final String _uid;

  StreamSubscription<WeightGoal?>? _goalSubscription;
  String? _goalId;

  Future<void> _onSubscriptionRequested(
    TodaySubscriptionRequested event,
    Emitter<TodayState> emit,
  ) {
    _analyticsRepository.trackScreenView(
      const AnalyticsEvent('TodayView_Appear'),
    );
    _watchGoal(null);
    TodayState failed(Object _, StackTrace _) => state.copyWith(failed: true);
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
      // The rest are niceties: without them, no target, no steps item, the
      // default step goal, kilograms and no goal pace.
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
      // The check-in card's: without them, no card.
      emit.forEach(
        _checkInRepository.watchStrategySettings(_uid),
        onData: (settings) => state.copyWith(strategySettings: settings),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _checkInRepository.watchCheckInRecord(_uid),
        onData: (record) => state.copyWith(checkInRecord: () => record),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _checkInRepository.watchLoggingBreak(_uid),
        onData: (loggingBreak) =>
            state.copyWith(loggingBreak: () => loggingBreak),
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

  /// Optimistic, and puts the card back if the write does not land: a card
  /// that vanished on a failed write would look like a week dealt with.
  /// `TodayView_CheckIn_Skip` is the write's Start.
  Future<void> _onCheckInSkipped(
    TodayCheckInSkipped event,
    Emitter<TodayState> emit,
  ) async {
    final weekStart = state.dueCheckInWeekStart;
    if (weekStart == null) return;
    _analyticsRepository.trackEvent(
      const AnalyticsEvent('TodayView_CheckIn_Skip'),
    );
    emit(state.copyWith(checkInSkipped: true));
    try {
      await _checkInRepository.markCheckInSkipped(_uid, weekStart);
      _analyticsRepository.trackEvent(
        const AnalyticsEvent('TodayView_CheckIn_Skip_Success'),
      );
    } on Object catch (error) {
      _analyticsRepository.trackEvent(
        AnalyticsEvent(
          'TodayView_CheckIn_Skip_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(
        state.copyWith(
          checkInSkipped: false,
          skipFailures: state.skipFailures + 1,
        ),
      );
    }
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
          (goal) => add(_TodayGoalChanged(goal)),
          onError: (Object _) => add(const _TodayGoalChanged(null)),
        );
  }

  @override
  Future<void> close() async {
    await _goalSubscription?.cancel();
    await super.close();
  }
}
