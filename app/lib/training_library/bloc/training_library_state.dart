part of 'training_library_bloc.dart';

sealed class TrainingLibraryState extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Waiting for the first read of every list.
final class TrainingLibraryLoading extends TrainingLibraryState {
  const new();
}

/// The library as last read.
final class const TrainingLibraryLoaded(final TrainingLibrary library)
    extends TrainingLibraryState {
  @override
  List<Object> get props => [library];
}

/// Part of the library could not be read.
final class TrainingLibraryFailure extends TrainingLibraryState {
  const new();
}
