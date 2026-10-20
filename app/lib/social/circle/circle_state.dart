part of 'circle_bloc.dart';

/// What a follow or nudge that failed was, for the message that says so.
enum CircleNotice {
  /// Following failed (`Unable to follow user`).
  followFailed,

  /// Unfollowing failed.
  unfollowFailed,

  /// Cancelling a follow request failed.
  cancelRequestFailed,

  /// A nudge failed; [CircleState.noticeName] names who.
  nudgeFailed,
}

/// The signed-in user's circle: who they follow, their sessions and their
/// own, the follow requests they have sent, and who they nudged today. The
/// app-wide social state Swift keeps in `UserManager` and
/// `WorkoutSessionManager`.
final class const CircleState({
  /// The signed-in user's profile, live.
  final UserModel? viewer,

  /// The profiles of the first 30 people [viewer] follows.
  final List<UserModel> followingUsers = const [],

  /// Their newest sessions.
  final List<WorkoutSessionModel> followingSessions = const [],

  /// The viewer's own sessions.
  final List<WorkoutSessionModel> ownSessions = const [],

  /// Whether the following sessions have answered once: until then an
  /// empty feed only means "not loaded".
  final bool hasLoadedFollowingSessions = false,

  /// Private profiles with a request from [viewer] still pending.
  final Set<String> sentRequestIds = const {},

  /// Who was nudged on [nudgedDay].
  final Set<String> nudgedIds = const {},

  /// The local day [nudgedIds] belong to, `yyyy-MM-dd`.
  final String? nudgedDay,

  /// The username banner was closed.
  final bool usernameBannerDismissed = false,

  /// The week whose Monday recap was closed.
  final DateTime? dismissedSummaryWeek,

  /// The invite card was tapped or closed.
  final bool inviteCardDismissed = false,

  /// The last failure to tell the user about.
  final CircleNotice? notice,

  /// Who [notice] is about, for a nudge.
  final String? noticeName,

  /// Bumped with each [notice], so the same failure twice is shown twice.
  final int noticeId = 0,
}) extends Equatable {
  /// Everything known: [ownSessions] and [followingSessions].
  List<WorkoutSessionModel> get sessions => [
    ...ownSessions,
    ...followingSessions,
  ];

  /// The follow button for [userId].
  FollowState followState(String userId) =>
      followStateOf(viewer, sentRequestIds, userId);

  /// Who was nudged on [now]'s day.
  Set<String> nudgedOn(DateTime now) =>
      nudgedDay == dayKey(now) ? nudgedIds : const {};

  /// The people [viewer] follows, less anyone they blocked.
  List<UserModel> get visibleFollowing => [
    for (final user in followingUsers)
      if (!hasBlocked(viewer, user.userId)) user,
  ];

  /// The one-time invite card: from the fifth counted workout of the
  /// viewer's own until it is tapped or closed
  /// (`ReviewPromptPolicy.showsInviteCard`). A workout counts when it is
  /// not a rest day and has a set done (`ReviewPromptPolicy.counts`).
  bool get showsInviteCard =>
      viewer != null &&
      !inviteCardDismissed &&
      ownSessions
              .where(
                (session) =>
                    !session.isRestDay &&
                    session.exercises.any(
                      (exercise) =>
                          exercise.sets.any((set) => set.completedAt != null),
                    ),
              )
              .length >=
          5;

  /// The session's author, when it is [viewer] or someone they follow.
  UserModel? authorOf(WorkoutSessionModel session) {
    final viewer = this.viewer;
    if (viewer != null && session.authorId == viewer.userId) return viewer;
    return followingUsers
        .where((user) => user.userId == session.authorId)
        .firstOrNull;
  }

  /// The feed: finished, non-rest workouts by someone attributable, less
  /// blocked authors and moderated sessions, newest first
  /// (`SocialPresenter.feedSessions`).
  List<WorkoutSessionModel> get feed {
    final viewerId = viewer?.userId;
    return [
      for (final session in sessions)
        if (session.endedAt != null &&
            !session.isRestDay &&
            authorOf(session) != null &&
            !hasBlocked(viewer, session.authorId) &&
            !(session.hidden == true && viewerId != session.authorId))
          session,
    ]..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
  }

  /// A spinner rather than the empty feed until the following feed has
  /// answered once.
  bool get isFeedLoading => feed.isEmpty && !hasLoadedFollowingSessions;

  /// The strip's faces; empty when [viewer] follows nobody.
  List<CircleMember> members({
    required DateTime now,
    required int firstDayOfWeek,
  }) {
    final viewer = this.viewer;
    if (viewer == null) return const [];
    return CircleWeek.members(
      viewer: viewer,
      following: followingUsers,
      sessions: sessions,
      nudged: nudgedOn(now),
      now: now,
      firstDayOfWeek: firstDayOfWeek,
    );
  }

  /// The local day of [date], `yyyy-MM-dd`.
  static String dayKey(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  CircleState copyWith({
    UserModel? Function()? viewer,
    List<UserModel>? followingUsers,
    List<WorkoutSessionModel>? followingSessions,
    List<WorkoutSessionModel>? ownSessions,
    bool? hasLoadedFollowingSessions,
    Set<String>? sentRequestIds,
    Set<String>? nudgedIds,
    String? nudgedDay,
    bool? usernameBannerDismissed,
    DateTime? dismissedSummaryWeek,
    bool? inviteCardDismissed,
    CircleNotice? notice,
    String? noticeName,
  }) => CircleState(
    viewer: viewer == null ? this.viewer : viewer(),
    followingUsers: followingUsers ?? this.followingUsers,
    followingSessions: followingSessions ?? this.followingSessions,
    ownSessions: ownSessions ?? this.ownSessions,
    hasLoadedFollowingSessions:
        hasLoadedFollowingSessions ?? this.hasLoadedFollowingSessions,
    sentRequestIds: sentRequestIds ?? this.sentRequestIds,
    nudgedIds: nudgedIds ?? this.nudgedIds,
    nudgedDay: nudgedDay ?? this.nudgedDay,
    usernameBannerDismissed:
        usernameBannerDismissed ?? this.usernameBannerDismissed,
    dismissedSummaryWeek: dismissedSummaryWeek ?? this.dismissedSummaryWeek,
    inviteCardDismissed: inviteCardDismissed ?? this.inviteCardDismissed,
    notice: notice ?? this.notice,
    noticeName: notice == null ? this.noticeName : noticeName,
    noticeId: notice == null ? noticeId : noticeId + 1,
  );

  @override
  List<Object?> get props => [
    viewer,
    followingUsers,
    followingSessions,
    ownSessions,
    hasLoadedFollowingSessions,
    sentRequestIds,
    nudgedIds,
    nudgedDay,
    usernameBannerDismissed,
    dismissedSummaryWeek,
    inviteCardDismissed,
    notice,
    noticeName,
    noticeId,
  ];
}
