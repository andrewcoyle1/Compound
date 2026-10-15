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

/// The user opened last week's review from its card.
final class TodayWeeklyReviewOpened extends TodayEvent {
  const new();
}
