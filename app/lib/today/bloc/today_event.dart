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

/// Start on the check-in card; the view opens the check-in.
final class TodayCheckInStarted extends TodayEvent {
  const new();
}

/// Skip This Week on the check-in card.
final class TodayCheckInSkipped extends TodayEvent {
  const new();
}

/// A checklist item was tapped; the view opens what is behind it.
final class const TodayChecklistItemPressed(final ChecklistItem item)
    extends TodayEvent {
  @override
  List<Object?> get props => [item];
}

/// The checklist showed every item done, with [itemCount] items.
final class const TodayDayCompleted(final int itemCount) extends TodayEvent {
  @override
  List<Object?> get props => [itemCount];
}

/// A step goal was chosen on the Steps item.
final class const TodayStepGoalSelected(final int goal) extends TodayEvent {
  @override
  List<Object?> get props => [goal];
}

/// The friends-trained-today row was tapped; the view opens Social.
final class TodaySocialPulsePressed extends TodayEvent {
  const new();
}
