import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/notifications/inbox/notification_grouping.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound/social/logic/restartable.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

part 'inbox_event.dart';
part 'inbox_state.dart';

/// The signed-in user's activity notifications and incoming follow
/// requests, app-wide, and the inbox that shows them (Swift
/// `ActivityNotificationManager`, `UserManager.incomingFollowRequests` and
/// `NotificationsPresenter`). The app tells it who is signed in
/// ([InboxViewerChanged]); the Social tab and the inbox read it. Events keep
/// Swift's `NotificationsView_` names.
class InboxBloc extends Bloc<InboxEvent, InboxState> {
  new({required this._social, required this._analytics})
    : super(const InboxState()) {
    on<InboxViewerChanged>(_onViewerChanged);
    on<_InboxSubscribed>(_onSubscribed, transformer: restartable());
    on<InboxBadgeRefreshRequested>(_onBadgeRefreshRequested);
    on<InboxAppeared>((event, emit) async {
      _analytics.appear('NotificationsView');
      await _onLoadRequested(const InboxLoadRequested(), emit);
    });
    on<InboxDisappeared>(
      (event, emit) => _analytics.disappear('NotificationsView'),
    );
    on<InboxLoadRequested>(_onLoadRequested);
    on<InboxLoadMorePressed>(_onLoadMorePressed);
    on<InboxGroupPressed>(_onGroupPressed);
    on<InboxGroupDeleted>(_onGroupDeleted);
    on<InboxFollowBackPressed>(_onFollowBackPressed);
    on<InboxRequestAnswered>(_onRequestAnswered);
  }

  final SocialRepository _social;
  final AnalyticsRepository _analytics;

  /// What the listeners were started for: a change restarts them.
  Object? _subscriptionKey;

  void _onViewerChanged(InboxViewerChanged event, Emitter<InboxState> emit) {
    final viewer = event.viewer;
    // The requests listener drops blocked requesters, so a block restarts it.
    final key = viewer == null
        ? null
        : (viewer.userId, (viewer.blockedUserIds ?? const []).join());
    // Someone else's activity starts empty.
    emit(
      viewer?.userId == state.viewer?.userId
          ? state.copyWith(viewer: () => viewer)
          : InboxState(viewer: viewer),
    );
    if (key == _subscriptionKey) return;
    _subscriptionKey = key;
    add(_InboxSubscribed(viewer));
  }

  Future<void> _onSubscribed(
    _InboxSubscribed event,
    Emitter<InboxState> emit,
  ) async {
    final viewer = event.viewer;
    if (viewer == null) return;
    await Future.wait([
      _refreshBadge(emit),
      emit.forEach(
        _social.watchIncomingFollowRequests(viewer),
        onData: (requests) => state.copyWith(requests: requests),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _social.watchNewNotifications(viewer.userId),
        onData: (notification) =>
            state.notifications.any((held) => held.id == notification.id)
            ? state
            : state.copyWith(
                notifications: [notification, ...state.notifications],
              ),
        onError: (_, _) => state,
      ),
    ]);
  }

  Future<void> _onBadgeRefreshRequested(
    InboxBadgeRefreshRequested event,
    Emitter<InboxState> emit,
  ) => _refreshBadge(emit);

  /// The first page, silently: a stale badge is the fallback.
  Future<void> _refreshBadge(Emitter<InboxState> emit) async {
    final uid = state.viewer?.userId;
    if (uid == null) return;
    try {
      final page = await _social.notifications(uid);
      if (emit.isDone || uid != state.viewer?.userId) return;
      emit(state.copyWith(notifications: page, hasMore: _isFull(page)));
    } on Object catch (error) {
      _analytics.severe('SocialView_LoadNotifications_Fail', error);
    }
  }

  static bool _isFull(List<ActivityNotificationModel> page) =>
      page.length >= SocialRepository.notificationPageSize;

  Future<void> _onLoadRequested(
    InboxLoadRequested event,
    Emitter<InboxState> emit,
  ) async {
    final uid = state.viewer?.userId;
    if (uid == null) return;
    emit(state.copyWith(isLoading: !state.hasLoadedOnce));
    try {
      final page = await _social.notifications(uid);
      emit(
        state.copyWith(
          notifications: page,
          hasMore: _isFull(page),
          loadFailed: false,
        ),
      );
    } on Object catch (error) {
      // A failure must not read as an empty inbox.
      _analytics.severe('NotificationsView_LoadNotifications_Fail', error);
      emit(state.copyWith(loadFailed: true));
    }
    // Silent: a stale unread badge is the fallback, not an alert.
    try {
      await _social.markAllNotificationsRead(uid);
      emit(
        state.copyWith(
          notifications: [
            for (final notification in state.notifications) _read(notification),
          ],
        ),
      );
    } on Object catch (error) {
      _warning('NotificationsView_MarkRead_Fail', error);
    }
    emit(state.copyWith(isLoading: false, hasLoadedOnce: true));
  }

  Future<void> _onLoadMorePressed(
    InboxLoadMorePressed event,
    Emitter<InboxState> emit,
  ) async {
    _analytics.analytic('NotificationsView_LoadMore_Pressed');
    final uid = state.viewer?.userId;
    final held = state.notifications;
    if (uid == null || held.isEmpty) return;
    final oldest = held
        .map((notification) => notification.dateCreated)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    try {
      final page = await _social.notifications(uid, before: oldest);
      final ids = {
        for (final notification in state.notifications) notification.id,
      };
      emit(
        state.copyWith(
          notifications: [
            ...state.notifications,
            for (final notification in page)
              if (!ids.contains(notification.id)) notification,
          ],
          hasMore: _isFull(page),
        ),
      );
    } on Object catch (error) {
      _analytics.severe('NotificationsView_LoadMore_Fail', error);
      emit(state.copyWith(notice: InboxNotice.loadMoreFailed));
    }
  }

  /// Marks every unread member read and opens what the group is about;
  /// members share a type and a session, so the newest stands for all.
  Future<void> _onGroupPressed(
    InboxGroupPressed event,
    Emitter<InboxState> emit,
  ) async {
    final viewer = state.viewer;
    final notification = event.group.newest;
    if (viewer == null) return;
    final unread = event.group.unreadIds;
    if (unread.isNotEmpty) {
      // Silent: a row left looking unread is the fallback.
      try {
        await _social.markNotificationsRead(viewer.userId, unread);
        emit(
          state.copyWith(
            notifications: [
              for (final held in state.notifications)
                if (unread.contains(held.id)) _read(held) else held,
            ],
          ),
        );
      } on Object catch (error) {
        _warning('NotificationsView_MarkRead_Fail', error);
      }
    }
    _analytics.analytic('NotificationsView_Notification_Pressed', {
      'type': notification.type.value,
    });
    emit(state.copyWith(openingId: () => notification.id));
    try {
      final destination = switch (notification.type) {
        ActivityType.follow ||
        ActivityType.followAccepted ||
        ActivityType.nudge => await _profile(notification.actorId, viewer),
        ActivityType.like ||
        ActivityType.comment ||
        ActivityType.mention => await _session(notification),
        ActivityType.challengeComplete => await _challenge(notification),
        // Social part 2b: the shared item.
        ActivityType.share => null,
      };
      if (destination != null) emit(state.copyWith(destination: destination));
    } on Object catch (error) {
      _analytics.severe('NotificationsView_OpenNotification_Fail', error, {
        'type': notification.type.value,
      });
      emit(state.copyWith(notice: InboxNotice.openFailed));
    }
    emit(state.copyWith(openingId: () => null));
  }

  Future<InboxDestination> _profile(String userId, UserModel viewer) async {
    final user = (await _social.users([userId], viewer: viewer)).firstOrNull;
    if (user == null) throw StateError('No profile for $userId');
    return InboxProfileDestination(user);
  }

  Future<InboxDestination> _challenge(
    ActivityNotificationModel notification,
  ) async {
    final id = notification.challengeId ?? '';
    final challenge = await _social.challenge(id);
    if (challenge == null) throw StateError('No challenge $id');
    return InboxChallengeDestination(challenge);
  }

  Future<InboxDestination> _session(
    ActivityNotificationModel notification,
  ) async {
    final session = await _social.sessionById(
      notification.sessionId,
      authorId: notification.sessionAuthorId,
    );
    if (session == null) {
      throw StateError('No session ${notification.sessionId}');
    }
    return InboxSessionDestination(
      session,
      openComments: notification.type != ActivityType.like,
    );
  }

  Future<void> _onGroupDeleted(
    InboxGroupDeleted event,
    Emitter<InboxState> emit,
  ) async {
    final uid = state.viewer?.userId;
    if (uid == null) return;
    var failed = false;
    for (final notification in event.group.members) {
      _analytics.analytic('NotificationsView_DeleteNotification_Start');
      try {
        await _social.deleteNotification(uid, notification.id);
        _analytics.analytic('NotificationsView_DeleteNotification_Success');
        emit(
          state.copyWith(
            notifications: [
              for (final held in state.notifications)
                if (held.id != notification.id) held,
            ],
          ),
        );
      } on Object catch (error) {
        _analytics.severe('NotificationsView_DeleteNotification_Fail', error);
        failed = true;
      }
    }
    // One alert for the row, however many of its members failed.
    if (failed) emit(state.copyWith(notice: InboxNotice.deleteFailed));
  }

  /// The notification does not carry the actor's privacy, so the profile is
  /// read now: whether it follows or requests depends on the account as it
  /// is, not as it was when they followed.
  Future<void> _onFollowBackPressed(
    InboxFollowBackPressed event,
    Emitter<InboxState> emit,
  ) async {
    final viewer = state.viewer;
    if (viewer == null) return;
    _analytics.analytic('NotificationsView_FollowBack_Pressed');
    try {
      final actor = (await _social.users([
        event.notification.actorId,
      ], viewer: viewer)).firstOrNull;
      if (actor == null) {
        throw StateError('No profile for ${event.notification.actorId}');
      }
      emit(state.copyWith(followBack: actor));
    } on Object catch (error) {
      _analytics.severe('NotificationsView_FollowBack_Fail', error);
      emit(state.copyWith(notice: InboxNotice.followBackFailed));
    }
  }

  Future<void> _onRequestAnswered(
    InboxRequestAnswered event,
    Emitter<InboxState> emit,
  ) async {
    final viewer = state.viewer;
    if (viewer == null) return;
    final parameters = {'accept': event.accept};
    _analytics
      ..analytic('NotificationsView_FollowRequest_Answered', parameters)
      ..analytic('NotificationsView_RespondToFollowRequest_Start', parameters);
    try {
      await _social.answerFollowRequest(
        event.request.requesterId,
        targetId: viewer.userId,
        accept: event.accept,
      );
      _analytics.analytic(
        'NotificationsView_RespondToFollowRequest_Success',
        parameters,
      );
    } on Object catch (error) {
      _analytics.severe('NotificationsView_RespondToFollowRequest_Fail', error);
      emit(state.copyWith(notice: InboxNotice.answerFailed));
    }
  }

  static ActivityNotificationModel _read(ActivityNotificationModel n) =>
      ActivityNotificationModel(
        id: n.id,
        type: n.type,
        actorId: n.actorId,
        actorName: n.actorName,
        sessionId: n.sessionId,
        sessionAuthorId: n.sessionAuthorId,
        dateCreated: n.dateCreated,
        isRead: true,
        isReply: n.isReply,
        actorImageUrl: n.actorImageUrl,
        commentText: n.commentText,
        shareId: n.shareId,
        challengeId: n.challengeId,
      );

  void _warning(String name, Object error) => _analytics.trackEvent(
    AnalyticsEvent(
      name,
      parameters: {'error_description': '$error'},
      type: LogType.warning,
    ),
  );
}
