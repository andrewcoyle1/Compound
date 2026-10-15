part of 'training_analytics_bloc.dart';

sealed class TrainingAnalyticsEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Start following the user's sessions, exercises and profile.
final class TrainingAnalyticsSubscriptionRequested
    extends TrainingAnalyticsEvent {
  const new();
}

/// The user picked [range] on a chart's picker.
final class const TrainingAnalyticsRangeSelected(final MetricRange range)
    extends TrainingAnalyticsEvent {
  @override
  List<Object?> get props => [range];
}

/// The user tapped [muscle] on Muscle Balance: its trend shows, or hides
/// when it was showing.
final class const TrainingAnalyticsMuscleToggled(final Muscles muscle)
    extends TrainingAnalyticsEvent {
  @override
  List<Object?> get props => [muscle];
}
