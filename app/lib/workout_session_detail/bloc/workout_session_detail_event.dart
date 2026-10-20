part of 'workout_session_detail_bloc.dart';

sealed class WorkoutSessionDetailEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Read the workout, or try again after a failure.
final class WorkoutSessionDetailRequested extends WorkoutSessionDetailEvent {
  const new();
}
