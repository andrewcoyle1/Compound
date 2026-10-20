part of 'exercise_history_bloc.dart';

sealed class ExerciseHistoryEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Start following the sessions, or try again after a failure.
final class ExerciseHistorySubscriptionRequested extends ExerciseHistoryEvent {
  const new();
}
