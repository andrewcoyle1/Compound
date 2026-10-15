part of 'progress_bloc.dart';

sealed class ProgressEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Start following everything the cards are built from.
final class ProgressSubscriptionRequested extends ProgressEvent {
  const new();
}

/// The current weight goal changed, or the user's goal id did.
final class const _ProgressGoalChanged(final WeightGoal? goal)
    extends ProgressEvent {
  @override
  List<Object?> get props => [goal];
}
