part of 'weekly_review_bloc.dart';

sealed class WeeklyReviewEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Start following everything the review is built from.
final class WeeklyReviewSubscriptionRequested extends WeeklyReviewEvent {
  const new();
}

/// The user asked for the week before.
final class WeeklyReviewPreviousWeekPressed extends WeeklyReviewEvent {
  const new();
}

/// The user asked for the week after, up to this one.
final class WeeklyReviewNextWeekPressed extends WeeklyReviewEvent {
  const new();
}

/// The user shared the week as an image (`WeeklyReviewView_Share_Pressed`).
final class WeeklyReviewSharePressed extends WeeklyReviewEvent {
  const new();
}
