part of 'weight_metric_bloc.dart';

sealed class WeightMetricEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Start following the user's weigh-ins and their weight unit.
final class WeightMetricSubscriptionRequested extends WeightMetricEvent {
  const new();
}

/// The user picked [range] on the chart's picker.
final class const WeightMetricRangeSelected(final MetricRange range)
    extends WeightMetricEvent {
  @override
  List<Object> get props => [range];
}
