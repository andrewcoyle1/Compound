part of 'expenditure_metric_bloc.dart';

sealed class ExpenditureMetricEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// The screen opened: follow the engine's inputs.
final class ExpenditureMetricSubscriptionRequested
    extends ExpenditureMetricEvent {
  const new();
}

/// The chart's range picker.
final class const ExpenditureMetricRangeSelected(final MetricRange range)
    extends ExpenditureMetricEvent {
  @override
  List<Object?> get props => [range];
}
