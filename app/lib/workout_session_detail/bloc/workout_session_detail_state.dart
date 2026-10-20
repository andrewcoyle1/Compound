part of 'workout_session_detail_bloc.dart';

sealed class WorkoutSessionDetailState extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Reading the workout.
final class WorkoutSessionDetailLoading extends WorkoutSessionDetailState {
  const new();
}

/// The workout, and the profile's units, null where unset.
final class const WorkoutSessionDetailLoaded({
  required final WorkoutSessionModel session,
  final WeightUnitPreference? weightUnit,
  final DistanceUnitPreference? distanceUnit,
}) extends WorkoutSessionDetailState {
  @override
  List<Object?> get props => [session, weightUnit, distanceUnit];
}

/// There is no such workout.
final class WorkoutSessionDetailNotFound extends WorkoutSessionDetailState {
  const new();
}

/// The workout could not be read.
final class WorkoutSessionDetailFailure extends WorkoutSessionDetailState {
  const new();
}
