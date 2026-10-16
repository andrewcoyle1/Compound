part of 'inbox_bloc.dart';

sealed class InboxEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// The signed-in user's profile changed, or they signed in or out (null).
final class const InboxViewerChanged(final UserModel? viewer)
    extends InboxEvent {
  @override
  List<Object?> get props => [viewer];
}

/// Restarts the listeners for [viewer].
final class const _InboxSubscribed(final UserModel? viewer) extends InboxEvent {
  @override
  List<Object?> get props => [viewer];
}

/// Social appeared: the badge's silent refresh
/// (`SocialPresenter.loadNotifications`).
final class InboxBadgeRefreshRequested extends InboxEvent {
  const new();
}

/// The inbox opened: `NotificationsView_Appear`, then a load.
final class InboxAppeared extends InboxEvent {
  const new();
}

/// The inbox closed: `NotificationsView_Disappear`.
final class InboxDisappeared extends InboxEvent {
  const new();
}

/// Try Again was pressed, or the inbox was pulled to refresh:
/// read the first page, then mark everything read
/// (`NotificationsPresenter.loadNotifications`). The follow requests are a
/// live listener, so a refresh has nothing to re-read for them.
final class InboxLoadRequested extends InboxEvent {
  const new();
}

/// Load more, at the foot of the list.
final class InboxLoadMorePressed extends InboxEvent {
  const new();
}

/// A row was tapped: its unread members are marked read and what it is
/// about opens.
final class const InboxGroupPressed(final NotificationGroup group)
    extends InboxEvent {
  @override
  List<Object?> get props => [group.members];
}

/// A row was swiped away: every notification in it is deleted.
final class const InboxGroupDeleted(final NotificationGroup group)
    extends InboxEvent {
  @override
  List<Object?> get props => [group.members];
}

/// Follow back beside a follow row.
final class const InboxFollowBackPressed(
  final ActivityNotificationModel notification,
) extends InboxEvent {
  @override
  List<Object?> get props => [notification];
}

/// Accept or Decline on a follow request.
final class const InboxRequestAnswered(
  final FollowRequestModel request, {
  required final bool accept,
}) extends InboxEvent {
  @override
  List<Object?> get props => [request, accept];
}
