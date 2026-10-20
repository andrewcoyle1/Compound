part of 'exercise_history_bloc.dart';

sealed class ExerciseHistoryState extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Waiting for the first read.
final class ExerciseHistoryLoading extends ExerciseHistoryState {
  const new();
}

/// The exercise's performances.
final class const ExerciseHistoryLoaded(final ExerciseDetailStats stats)
    extends ExerciseHistoryState {
  @override
  List<Object> get props => [stats];
}

/// The sessions could not be read.
final class ExerciseHistoryFailure extends ExerciseHistoryState {
  const new();
}
