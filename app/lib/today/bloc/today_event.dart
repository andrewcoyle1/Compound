part of 'today_bloc.dart';

sealed class TodayEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Start following everything the day is built from.
final class TodaySubscriptionRequested extends TodayEvent {
  const new();
}

/// The current weight goal changed, or the user's goal id did.
final class const _TodayGoalChanged(final WeightGoal? goal) extends TodayEvent {
  @override
  List<Object?> get props => [goal];
}

/// Start on the check-in card; the view opens the check-in.
final class TodayCheckInStarted extends TodayEvent {
  const new();
}

/// Skip This Week on the check-in card.
final class TodayCheckInSkipped extends TodayEvent {
  const new();
}
