part of 'workout_history_bloc.dart';

sealed class WorkoutHistoryEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Start following the sessions, or try again after a failure.
final class WorkoutHistorySubscriptionRequested extends WorkoutHistoryEvent {
  const new();
}
