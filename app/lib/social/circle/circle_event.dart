part of 'circle_bloc.dart';

sealed class CircleEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// The signed-in user's profile changed, or they signed in or out (null).
final class const CircleViewerChanged(final UserModel? viewer)
    extends CircleEvent {
  @override
  List<Object?> get props => [viewer];
}

/// Restarts the listeners for [viewer]'s circle.
final class const _CircleSubscribed(final UserModel? viewer)
    extends CircleEvent {
  @override
  List<Object?> get props => [viewer];
}

/// The follow button beside [user] was pressed: follow, request, unfollow
/// or cancel, whichever it offers (`FollowFlow.onButtonPressed`). [user]
/// must carry an up-to-date `isPrivate`.
final class const CircleFollowPressed(final UserModel user)
    extends CircleEvent {
  @override
  List<Object?> get props => [user];
}

/// Nudge under [member]'s face in the strip.
final class const CircleNudgePressed(final CircleMember member)
    extends CircleEvent {
  @override
  List<Object?> get props => [member];
}

/// The username banner was closed.
final class CircleUsernameBannerDismissed extends CircleEvent {
  const new();
}

/// The Monday recap was closed for [weekStart]'s week.
final class const CircleWeeklySummaryDismissed(final DateTime weekStart)
    extends CircleEvent {
  @override
  List<Object?> get props => [weekStart];
}
