import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/social/logic/circle_week.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound/social/logic/restartable.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'circle_event.dart';
part 'circle_state.dart';

/// The signed-in user's circle, app-wide: the people they follow and their
/// sessions, the viewer's own sessions, the follow button and the nudge.
/// The app tells it who is signed in ([CircleViewerChanged]); every social
/// screen reads it.
class CircleBloc extends Bloc<CircleEvent, CircleState> {
  new({
    required this._social,
    required this._sessions,
    required this._analytics,
    this._now = DateTime.now,
  }) : super(const CircleState()) {
    on<CircleViewerChanged>(_onViewerChanged);
    on<_CircleSubscribed>(_onSubscribed, transformer: restartable());
    on<CircleFollowPressed>(_onFollowPressed);
    on<CircleNudgePressed>(_onNudgePressed);
    on<CircleUsernameBannerDismissed>(
      (event, emit) => emit(state.copyWith(usernameBannerDismissed: true)),
    );
    on<CircleWeeklySummaryDismissed>(_onWeeklySummaryDismissed);
  }

  final SocialRepository _social;
  final WorkoutSessionRepository _sessions;
  final AnalyticsRepository _analytics;
  final DateTime Function() _now;

  /// What the listeners were started for: a change restarts them.
  Object? _subscriptionKey;

  void _onViewerChanged(CircleViewerChanged event, Emitter<CircleState> emit) {
    final viewer = event.viewer;
    final key = viewer == null
        ? null
        : (
            viewer.userId,
            FollowingQueries.cappedIds(viewer.followingIds ?? const []).join(),
            (viewer.blockedUserIds ?? const []).join(),
          );
    // Someone else's circle starts empty.
    emit(
      viewer?.userId == state.viewer?.userId
          ? state.copyWith(viewer: () => viewer)
          : CircleState(viewer: viewer),
    );
    if (key == _subscriptionKey) return;
    _subscriptionKey = key;
    add(_CircleSubscribed(viewer));
  }

  Future<void> _onSubscribed(
    _CircleSubscribed event,
    Emitter<CircleState> emit,
  ) async {
    final viewer = event.viewer;
    if (viewer == null) return;
    await Future.wait([
      () async {
        // Silent: without them a pending request reads as Follow.
        try {
          final sent = await _social.sentFollowRequestTargetIds(viewer.userId);
          if (!emit.isDone) emit(state.copyWith(sentRequestIds: sent.toSet()));
        } on Object catch (_) {}
      }(),
      emit.forEach(
        _social.watchFollowingUsers(viewer),
        onData: (users) => state.copyWith(followingUsers: users),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _social.watchFollowingSessions(viewer.followingIds ?? const []),
        onData: (sessions) => state.copyWith(
          followingSessions: sessions,
          hasLoadedFollowingSessions: true,
        ),
        onError: (_, _) => state.copyWith(hasLoadedFollowingSessions: true),
      ),
      emit.forEach(
        _sessions.watchSessions(viewer.userId),
        onData: (sessions) => state.copyWith(ownSessions: sessions),
        onError: (_, _) => state,
      ),
    ]);
  }

  Future<void> _onFollowPressed(
    CircleFollowPressed event,
    Emitter<CircleState> emit,
  ) async {
    final viewer = state.viewer;
    if (viewer == null) return;
    final user = event.user;
    final followState = state.followState(user.userId);
    final isPrivate = user.isPrivate ?? false;
    final action = switch (followState) {
      FollowState.follow when isPrivate => 'RequestFollow',
      FollowState.follow => 'Follow',
      FollowState.following => 'Unfollow',
      FollowState.requested => 'CancelRequest',
    };
    _analytics.trackEvent(AnalyticsEvent('FollowFlow_${action}_Start'));
    try {
      switch (followState) {
        case FollowState.follow when isPrivate:
          await _social.sendFollowRequest(user.userId, viewer: viewer);
          emit(
            state.copyWith(
              sentRequestIds: {...state.sentRequestIds, user.userId},
            ),
          );
        case FollowState.follow:
          await _social.follow(user.userId, viewer: viewer);
        case FollowState.following:
          await _social.unfollow(user.userId, viewer: viewer);
        case FollowState.requested:
          await _social.cancelFollowRequest(
            user.userId,
            requesterId: viewer.userId,
          );
          emit(
            state.copyWith(
              sentRequestIds: {...state.sentRequestIds}..remove(user.userId),
            ),
          );
      }
      _analytics.trackEvent(AnalyticsEvent('FollowFlow_${action}_Success'));
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'FollowFlow_${action}_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(
        state.copyWith(
          notice: switch (followState) {
            FollowState.follow => CircleNotice.followFailed,
            FollowState.following => CircleNotice.unfollowFailed,
            FollowState.requested => CircleNotice.cancelRequestFailed,
          },
        ),
      );
    }
  }

  /// Greys the button out at once so a second tap cannot send a second
  /// nudge, and gives it back if the write fails.
  Future<void> _onNudgePressed(
    CircleNudgePressed event,
    Emitter<CircleState> emit,
  ) async {
    final viewer = state.viewer;
    final member = event.member;
    final userId = member.user.userId;
    final now = _now();
    if (viewer == null ||
        !member.canNudge ||
        state.nudgedOn(now).contains(userId)) {
      return;
    }
    _analytics
      ..trackEvent(const AnalyticsEvent('SocialView_Nudge_Press'))
      ..trackEvent(const AnalyticsEvent('SocialView_Nudge_Start'));
    final day = CircleState.dayKey(now);
    emit(
      state.copyWith(
        nudgedIds: {...state.nudgedOn(now), userId},
        nudgedDay: day,
      ),
    );
    try {
      await _social.nudge(userId, viewer: viewer);
      _analytics.trackEvent(const AnalyticsEvent('SocialView_Nudge_Success'));
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'SocialView_Nudge_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(
        state.copyWith(
          nudgedIds: {...state.nudgedOn(now)}..remove(userId),
          notice: CircleNotice.nudgeFailed,
          noticeName: commonNameOf(member.user),
        ),
      );
    }
  }

  void _onWeeklySummaryDismissed(
    CircleWeeklySummaryDismissed event,
    Emitter<CircleState> emit,
  ) {
    _analytics.trackEvent(
      const AnalyticsEvent('SocialView_WeeklySummary_Dismiss'),
    );
    emit(state.copyWith(dismissedSummaryWeek: event.weekStart));
  }
}
