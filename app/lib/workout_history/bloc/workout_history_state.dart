part of 'workout_history_bloc.dart';

sealed class WorkoutHistoryState extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Waiting for the first read.
final class WorkoutHistoryLoading extends WorkoutHistoryState {
  const new();
}

/// The finished workouts, newest first. Empty when there are none.
final class const WorkoutHistoryLoaded(final List<WorkoutHistoryEntry> entries)
    extends WorkoutHistoryState {
  @override
  List<Object> get props => [entries];
}

/// The sessions could not be read.
final class WorkoutHistoryFailure extends WorkoutHistoryState {
  const new();
}

/// One finished workout with its highlights.
final class const WorkoutHistoryEntry({
  required final WorkoutSessionModel session,
  required final List<PersonalRecord> personalRecords,
  required final int weeklyWorkoutNumber,
}) extends Equatable {
  @override
  List<Object> get props => [session, personalRecords, weeklyWorkoutNumber];
}
