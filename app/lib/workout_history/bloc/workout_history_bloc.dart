import 'package:bloc/bloc.dart';
import 'package:compound/workout_history/models/workout_session_highlights.dart';
import 'package:equatable/equatable.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'workout_history_event.dart';
part 'workout_history_state.dart';

/// The signed-in user's finished workouts, newest first, following
/// [WorkoutSessionRepository.watchSessions].
class WorkoutHistoryBloc
    extends Bloc<WorkoutHistoryEvent, WorkoutHistoryState> {
  /// `firstDayOfWeek` is 0 for Sunday, as `MaterialLocalizations` counts,
  /// and decides which sessions share a week.
  new({
    required this._repository,
    required this._uid,
    required this._firstDayOfWeek,
  }) : super(const WorkoutHistoryLoading()) {
    on<WorkoutHistorySubscriptionRequested>(_onSubscriptionRequested);
  }

  final WorkoutSessionRepository _repository;
  final String _uid;
  final int _firstDayOfWeek;

  Future<void> _onSubscriptionRequested(
    WorkoutHistorySubscriptionRequested event,
    Emitter<WorkoutHistoryState> emit,
  ) async {
    emit(const WorkoutHistoryLoading());
    await emit.forEach(
      _repository.watchSessions(_uid),
      onData: _loaded,
      onError: (_, _) => const WorkoutHistoryFailure(),
    );
  }

  /// Only finished workouts belong in the history: the stored sessions also
  /// hold the one in progress (no `endedAt`) and rest days.
  WorkoutHistoryLoaded _loaded(List<WorkoutSessionModel> sessions) {
    final finished = [
      for (final session in sessions)
        if (session.endedAt != null && !session.isRestDay) session,
    ]..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    return WorkoutHistoryLoaded([
      for (final session in finished)
        WorkoutHistoryEntry(
          session: session,
          personalRecords: WorkoutSessionHighlights.personalRecords(
            session,
            priorSessions: sessions,
          ),
          weeklyWorkoutNumber: WorkoutSessionHighlights.weeklyWorkoutNumber(
            session,
            history: sessions,
            firstDayOfWeek: _firstDayOfWeek,
          ),
        ),
    ]);
  }
}
