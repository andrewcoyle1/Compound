part of 'training_library_bloc.dart';

sealed class TrainingLibraryEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Start following the library, or try again after a failure.
final class TrainingLibrarySubscriptionRequested extends TrainingLibraryEvent {
  const new();
}
