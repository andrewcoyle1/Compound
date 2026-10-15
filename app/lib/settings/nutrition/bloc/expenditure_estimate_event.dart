part of 'expenditure_estimate_bloc.dart';

sealed class ExpenditureEstimateEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Start following the engine's inputs.
final class ExpenditureEstimateSubscriptionRequested
    extends ExpenditureEstimateEvent {
  const new();
}
