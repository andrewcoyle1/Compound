part of 'inbox_bloc.dart';

/// A failure to tell the user about, each with Swift's alert.
enum InboxNotice {
  /// `Unable to Delete Notification`.
  deleteFailed,

  /// `Unable to Follow User`.
  followBackFailed,

  /// `Unable to Answer Request`.
  answerFailed,

  /// `Unable to Open`: it may have been deleted.
  openFailed,

  /// `Unable to Load More`.
  loadMoreFailed,
}

/// Where a tapped notification goes.
sealed class InboxDestination extends Equatable {
  const new();
}

/// Someone's profile: a follow, an accepted request or a nudge.
final class const InboxProfileDestination(final UserModel user)
    extends InboxDestination {
  @override
  List<Object?> get props => [user];
}

/// A workout: a like opens it; a comment or mention opens its thread on
/// top ([openComments]).
final class const InboxSessionDestination(
  final WorkoutSessionModel session, {
  required final bool openComments,
}) extends InboxDestination {
  @override
  List<Object?> get props => [session, openComments];
}

/// A shared template or mesocycle, and who sent it.
final class const InboxShareDestination(
  final ShareModel share, {
  required final String senderName,
}) extends InboxDestination {
  @override
  List<Object?> get props => [share.id, senderName];
}

/// A challenge's standings: a finished challenge.
final class const InboxChallengeDestination(final ChallengeModel challenge)
    extends InboxDestination {
  @override
  List<Object?> get props => [challenge];
}

/// The signed-in user's activity, app-wide (Swift's
/// `ActivityNotificationManager` and `incomingFollowRequests`, with the
/// inbox screen's own state).
final class const InboxState({
  /// The signed-in user's profile, live.
  final UserModel? viewer,

  /// The notifications held: the pages read and those arriving since,
  /// newest first.
  final List<ActivityNotificationModel> notifications = const [],

  /// Whether the last page came back full, so another may exist.
  final bool hasMore = false,

  /// Pending requests to follow the viewer's private profile.
  final List<FollowRequestModel> requests = const [],

  /// The inbox has loaded once, so a reload keeps the list on screen.
  final bool hasLoadedOnce = false,

  /// A first load is under way.
  final bool isLoading = false,

  /// The last load failed.
  final bool loadFailed = false,

  /// The row being opened, which shows a spinner.
  final String? openingId,

  /// Where to go, bumped by [destinationId].
  final InboxDestination? destination,
  final int destinationId = 0,

  /// The actor to follow back, handed to the circle's follow button, bumped
  /// by [followBackId].
  final UserModel? followBack,
  final int followBackId = 0,

  /// The last failure, bumped by [noticeId].
  final InboxNotice? notice,
  final int noticeId = 0,

  /// A notification that just arrived, shown over the app until it is
  /// dismissed or times out (`AppPresenter.activityBanner`).
  final ActivityNotificationModel? banner,
}) extends Equatable {
  /// Nothing a blocked account did reaches the viewer: not the list, not
  /// the badges.
  List<ActivityNotificationModel> get visible => [
    for (final notification in notifications)
      if (!hasBlocked(viewer, notification.actorId)) notification,
  ];

  /// The rows.
  List<NotificationGroup> get groups => groupNotifications(visible);

  /// The Social bell's badge: unread rows plus requests waiting on an
  /// answer (`SocialPresenter.bellBadgeCount`).
  int get bellBadgeCount => unreadGroupCount(visible) + requests.length;

  /// The Social tab's badge: unread comments and mentions (a grouped row
  /// counts once) plus requests; likes and follows wait in the inbox
  /// (`TabBarPresenter.unreadActivityCount`).
  int get tabBadgeCount =>
      unreadGroupCount(
        visible.where(
          (notification) =>
              notification.type == ActivityType.comment ||
              notification.type == ActivityType.mention,
        ),
      ) +
      requests.length;

  /// Only a follow row offers a follow back, and never for the viewer.
  bool showsFollowBack(ActivityNotificationModel notification) =>
      notification.type == ActivityType.follow &&
      notification.actorId != viewer?.userId;

  InboxState copyWith({
    UserModel? Function()? viewer,
    List<ActivityNotificationModel>? notifications,
    bool? hasMore,
    List<FollowRequestModel>? requests,
    bool? hasLoadedOnce,
    bool? isLoading,
    bool? loadFailed,
    String? Function()? openingId,
    InboxDestination? destination,
    UserModel? followBack,
    InboxNotice? notice,
    ActivityNotificationModel? Function()? banner,
  }) => InboxState(
    viewer: viewer == null ? this.viewer : viewer(),
    notifications: notifications ?? this.notifications,
    hasMore: hasMore ?? this.hasMore,
    requests: requests ?? this.requests,
    hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    isLoading: isLoading ?? this.isLoading,
    loadFailed: loadFailed ?? this.loadFailed,
    openingId: openingId == null ? this.openingId : openingId(),
    destination: destination ?? this.destination,
    destinationId: destination == null ? destinationId : destinationId + 1,
    followBack: followBack ?? this.followBack,
    followBackId: followBack == null ? followBackId : followBackId + 1,
    notice: notice ?? this.notice,
    noticeId: notice == null ? noticeId : noticeId + 1,
    banner: banner == null ? this.banner : banner(),
  );

  @override
  List<Object?> get props => [
    viewer,
    notifications,
    hasMore,
    requests,
    hasLoadedOnce,
    isLoading,
    loadFailed,
    openingId,
    destination,
    destinationId,
    followBack,
    followBackId,
    notice,
    noticeId,
    banner,
  ];
}
