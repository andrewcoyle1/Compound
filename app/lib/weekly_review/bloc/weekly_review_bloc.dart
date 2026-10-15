import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/training_analytics/logic/training_analytics.dart';
import 'package:compound/weekly_review/logic/weekly_review.dart';
import 'package:compound/workout_history/models/workout_session_highlights.dart';
import 'package:compound_maths/compound_maths.dart' show weeklySessionGoal;
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'weekly_review_event.dart';
part 'weekly_review_state.dart';

/// The Weekly Review (Swift `WeeklyReviewPresenter`): the user's sessions,
/// meals, weigh-ins, diet plan, exercises and profile, followed live, and
/// the week on screen. It opens on last week on the first day of a week,
/// when this week has barely started, and on this week otherwise.
class WeeklyReviewBloc extends Bloc<WeeklyReviewEvent, WeeklyReviewState> {
  new({
    required this._workoutSessionRepository,
    required this._nutritionRepository,
    required this._bodyRepository,
    required this._trainingLibraryRepository,
    required this._userRepository,
    required this._analyticsRepository,
    required this._uid,
    required int firstDayOfWeek,
    DateTime Function() now = DateTime.now,
  }) : super(_initial(_uid, now(), firstDayOfWeek)) {
    on<WeeklyReviewSubscriptionRequested>(_onSubscriptionRequested);
    on<WeeklyReviewPreviousWeekPressed>(
      (event, emit) => emit(state.copyWith(weekStart: _shift(-7))),
    );
    on<WeeklyReviewNextWeekPressed>((event, emit) {
      if (state.canShowNextWeek) emit(state.copyWith(weekStart: _shift(7)));
    });
  }

  static WeeklyReviewState _initial(String uid, DateTime now, int first) {
    final thisWeek = WorkoutSessionHighlights.weekStart(now, first);
    final isFirstDay = thisWeek == DateTime(now.year, now.month, now.day);
    return WeeklyReviewState(
      uid: uid,
      now: now,
      firstDayOfWeek: first,
      weekStart: isFirstDay
          ? DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7)
          : thisWeek,
    );
  }

  DateTime _shift(int days) {
    final start = state.weekStart;
    return DateTime(start.year, start.month, start.day + days);
  }

  final WorkoutSessionRepository _workoutSessionRepository;
  final NutritionRepository _nutritionRepository;
  final BodyRepository _bodyRepository;
  final TrainingLibraryRepository _trainingLibraryRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final String _uid;

  /// The screen's analytics name.
  static const screen = 'WeeklyReviewView';

  Future<void> _onSubscriptionRequested(
    WeeklyReviewSubscriptionRequested event,
    Emitter<WeeklyReviewState> emit,
  ) {
    _analyticsRepository.appear(screen);
    WeeklyReviewState failed(Object _, StackTrace _) =>
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
      // The rest are niceties: without them, no adherence, the system
      // exercises, the default goal and kilograms.
      emit.forEach(
        _nutritionRepository.watchDietPlan(_uid),
        onData: (plan) => state.copyWith(dietPlan: () => plan),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _trainingLibraryRepository.watchUserExercises(_uid),
        onData: (exercises) => state.copyWith(userExercises: exercises),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _userRepository.watchUser(_uid),
        onData: (user) => state.copyWith(user: () => user),
        onError: (_, _) => state,
      ),
    ]);
  }
}
