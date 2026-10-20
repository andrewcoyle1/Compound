import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/training_library/logic/exercise_detail_stats.dart';
import 'package:equatable/equatable.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'exercise_history_event.dart';
part 'exercise_history_state.dart';

/// One exercise's logged history, following the signed-in user's sessions
/// (`ExerciseModelDetailPresenter.onViewAppear`, which Swift rebuilt on
/// appear; here it follows every change).
class ExerciseHistoryBloc
    extends Bloc<ExerciseHistoryEvent, ExerciseHistoryState> {
  new({
    required this._repository,
    required this._uid,
    required this._exerciseId,
    required this._analytics,
  }) : super(const ExerciseHistoryLoading()) {
    on<ExerciseHistorySubscriptionRequested>(_onSubscriptionRequested);
  }

  final WorkoutSessionRepository _repository;
  final String _uid;
  final String _exerciseId;
  final AnalyticsRepository _analytics;

  Future<void> _onSubscriptionRequested(
    ExerciseHistorySubscriptionRequested event,
    Emitter<ExerciseHistoryState> emit,
  ) async {
    _analytics.trackScreenView(
      AnalyticsEvent(
        'ExerciseModelDetailView_Appear',
        parameters: {'exercise_id': _exerciseId},
      ),
    );
    emit(const ExerciseHistoryLoading());
    await emit.forEach(
      _repository.watchSessions(_uid),
      onData: (sessions) => ExerciseHistoryLoaded(
        ExerciseDetailStats.make(sessions, _exerciseId),
      ),
      onError: (_, _) => const ExerciseHistoryFailure(),
    );
  }
}
