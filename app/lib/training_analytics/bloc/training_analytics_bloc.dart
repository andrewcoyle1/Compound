import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart' show AppFormat;
import 'package:bloc/bloc.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show dayKeyOf;
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/today/logic/today_checklist.dart' show countedSessions;
import 'package:compound/training_analytics/logic/training_analytics.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'training_analytics_event.dart';
part 'training_analytics_state.dart';

/// Which training analytics screen a [TrainingAnalyticsBloc] serves, with
/// its Swift view's analytics name.
enum TrainingAnalyticsScreen {
  /// Exercises (Swift `ExerciseAnalyticsView`).
  exercises('ExerciseAnalyticsView'),

  /// One exercise's estimated 1RM (Swift `ExerciseDetailView`).
  exerciseDetail('ExerciseDetailView'),

  /// Muscle Groups (Swift `MuscleGroupsView`).
  muscleGroups('MuscleGroupsView'),

  /// One muscle's sets (Swift `MuscleGroupDetailView`).
  muscleGroupDetail('MuscleGroupDetailView'),

  /// Muscle Balance (Swift `MuscleBalanceView`).
  muscleBalance('MuscleBalanceView'),

  /// Workouts (Swift `WorkoutView`).
  workouts('WorkoutView'),

  /// Workout consistency (Swift `WorkoutConsistencyView`).
  workoutConsistency('WorkoutConsistencyView');

  new(this.analyticsName);

  /// The `<name>_Appear` and `<name>_Disappear` prefix.
  final String analyticsName;
}

/// The training analytics screens (Swift `ExerciseAnalyticsPresenter`,
/// `ExerciseDetailPresenter`, `MuscleGroupsPresenter`,
/// `MuscleGroupDetailPresenter`, `MuscleBalancePresenter`,
/// `WorkoutPresenter`, `WorkoutConsistencyPresenter`): the user's sessions,
/// their own exercises and their profile, followed live. Every figure is
/// derived in [TrainingAnalyticsState].
class TrainingAnalyticsBloc
    extends Bloc<TrainingAnalyticsEvent, TrainingAnalyticsState> {
  new({
    required this._workoutSessionRepository,
    required this._trainingLibraryRepository,
    required this._userRepository,
    required this._analyticsRepository,
    required this._uid,
    required this._screen,
    this._parameters,
    DateTime Function() now = DateTime.now,
  }) : super(TrainingAnalyticsState(uid: _uid, now: now())) {
    on<TrainingAnalyticsSubscriptionRequested>(_onSubscriptionRequested);
    on<TrainingAnalyticsRangeSelected>(
      (event, emit) => emit(state.copyWith(range: event.range)),
    );
    on<TrainingAnalyticsMuscleToggled>(_onMuscleToggled);
  }

  final WorkoutSessionRepository _workoutSessionRepository;
  final TrainingLibraryRepository _trainingLibraryRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final String _uid;
  final TrainingAnalyticsScreen _screen;
  final Map<String, Object?>? _parameters;

  Future<void> _onSubscriptionRequested(
    TrainingAnalyticsSubscriptionRequested event,
    Emitter<TrainingAnalyticsState> emit,
  ) {
    _analyticsRepository.appear(_screen.analyticsName, _parameters);
    return Future.wait([
      emit.forEach(
        _workoutSessionRepository.watchSessions(_uid),
        onData: (sessions) => state.copyWith(sessions: sessions),
        onError: (_, _) => state.copyWith(failed: true),
      ),
      // The rest are niceties: without them, the system exercises only, no
      // age and kilograms.
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

  void _onMuscleToggled(
    TrainingAnalyticsMuscleToggled event,
    Emitter<TrainingAnalyticsState> emit,
  ) {
    _analyticsRepository.analytic('MuscleBalanceView_Muscle_Press', {
      'muscle': event.muscle.value,
    });
    final muscle = event.muscle;
    emit(
      state.copyWith(
        selectedMuscle: () => state.selectedMuscle == muscle ? null : muscle,
      ),
    );
  }
}
