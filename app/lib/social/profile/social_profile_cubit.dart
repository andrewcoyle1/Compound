import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// The profile's two tabs.
enum SocialProfileTab { progress, activities }

/// A write or read that failed, for the alert that says so.
enum SocialProfileNotice { blockFailed, unblockFailed, followingFailed }

final class const SocialProfileState({
  /// The profile as opened; null until read when only its id was known.
  final UserModel? user,

  /// The profile opened by id could not be read: gone, blocked, or the
  /// read failed.
  final bool notFound = false,
  final List<UserModel> followers = const [],

  /// Someone else's newest sessions; the reader's own come from the circle.
  final List<WorkoutSessionModel> sessions = const [],
  final bool isLoadingSessions = false,
  final bool loadSessionsFailed = false,
  final SocialProfileTab tab = SocialProfileTab.progress,
  final SocialProfileNotice? notice,
  final int noticeId = 0,

  /// The following list, read on request, for the screen to open.
  final List<UserModel>? following,
  final int followingId = 0,
}) extends Equatable {
  SocialProfileState copyWith({
    UserModel? user,
    bool? notFound,
    List<UserModel>? followers,
    List<WorkoutSessionModel>? sessions,
    bool? isLoadingSessions,
    bool? loadSessionsFailed,
    SocialProfileTab? tab,
    SocialProfileNotice? notice,
    List<UserModel>? following,
  }) => SocialProfileState(
    user: user ?? this.user,
    notFound: notFound ?? this.notFound,
    followers: followers ?? this.followers,
    sessions: sessions ?? this.sessions,
    isLoadingSessions: isLoadingSessions ?? this.isLoadingSessions,
    loadSessionsFailed: loadSessionsFailed ?? this.loadSessionsFailed,
    tab: tab ?? this.tab,
    notice: notice ?? this.notice,
    noticeId: notice == null ? noticeId : noticeId + 1,
    following: following ?? this.following,
    followingId: following == null ? followingId : followingId + 1,
  );

  @override
  List<Object?> get props => [
    user,
    notFound,
    followers,
    sessions,
    isLoadingSessions,
    loadSessionsFailed,
    tab,
    notice,
    noticeId,
    following,
    followingId,
  ];
}

/// Someone's profile, or the reader's own (`SocialProfilePresenter`): its
/// followers, their workouts, blocking, and the following list. Who the
/// reader follows, and so whether a private profile is locked, is the
/// circle's.
class SocialProfileCubit extends Cubit<SocialProfileState> {
  new({
    required this._social,
    required this._analytics,
    required this._userId,
    UserModel? user,
  }) : super(SocialProfileState(user: user));

  final SocialRepository _social;
  final AnalyticsRepository _analytics;
  final String _userId;

  void _track(String name, {Object? error, LogType? type}) =>
      _analytics.trackEvent(
        AnalyticsEvent(
          'SocialProfileView_$name',
          parameters: error == null ? null : {'error_description': '$error'},
          type: type ?? LogType.analytic,
        ),
      );

  /// Opens the profile for [viewer]: its followers, and someone else's
  /// workouts unless the profile is locked to them.
  Future<void> appeared(UserModel viewer) async {
    _analytics.trackScreenView(
      const AnalyticsEvent('SocialProfileView_Appear'),
    );
    // The reader's own profile is the viewer: no read, and none to fail.
    var user = state.user ?? (_userId == viewer.userId ? viewer : null);
    if (user == null) {
      try {
        user = (await _social.users([_userId], viewer: viewer)).firstOrNull;
      } on Object {
        user = null;
      }
      if (user == null) {
        emit(state.copyWith(notFound: true));
        return;
      }
    }
    if (state.user == null) emit(state.copyWith(user: user));
    final isOwn = user.userId == viewer.userId;
    final locked =
        (user.isPrivate ?? false) &&
        !isOwn &&
        !(viewer.followingIds?.contains(user.userId) ?? false);
    await Future.wait([
      _loadFollowers(viewer),
      if (!isOwn && !locked) loadSessions(),
    ]);
  }

  void disappeared() => _track('Disappear');

  Future<void> _loadFollowers(UserModel viewer) async {
    try {
      emit(
        state.copyWith(
          followers: await _social.followersOf(_userId, viewer: viewer),
        ),
      );
    } on Object catch (error) {
      _track('LoadFollowers_Fail', error: error, type: LogType.warning);
    }
  }

  /// Reads someone else's newest 30 workouts.
  Future<void> loadSessions() async {
    emit(state.copyWith(isLoadingSessions: true, loadSessionsFailed: false));
    try {
      final sessions = await _social.sessionsByAuthor(_userId, limit: 30);
      emit(state.copyWith(sessions: sessions, isLoadingSessions: false));
    } on Object catch (error) {
      _track('LoadSessions_Fail', error: error, type: LogType.severe);
      emit(state.copyWith(isLoadingSessions: false, loadSessionsFailed: true));
    }
  }

  void tabChanged(SocialProfileTab tab) => emit(state.copyWith(tab: tab));

  /// Reads the profile's following list for the screen to open.
  Future<void> followingPressed(UserModel viewer) async {
    final user = state.user;
    if (user == null) return;
    try {
      emit(
        state.copyWith(
          following: await _social.users(
            user.followingIds ?? const [],
            viewer: viewer,
          ),
        ),
      );
    } on Object catch (error) {
      _track('LoadFollowing_Fail', error: error, type: LogType.severe);
      emit(state.copyWith(notice: SocialProfileNotice.followingFailed));
    }
  }

  /// Tracks what the follow button is about to do; the circle does it.
  void followPressed({required bool following, required bool requested}) =>
      _track(
        following
            ? 'Unfollow_Pressed'
            : requested
            ? 'CancelRequest_Pressed'
            : 'Follow_Pressed',
      );

  /// Blocks the profile, which also unfollows it.
  Future<void> blockConfirmed(UserModel viewer) async {
    _track('Block_Confirmed');
    _track('Block_Start');
    try {
      await _social.block(_userId, viewer: viewer);
      _track('Block_Success');
    } on Object catch (error) {
      _track('Block_Fail', error: error, type: LogType.severe);
      emit(state.copyWith(notice: SocialProfileNotice.blockFailed));
    }
  }

  Future<void> unblockPressed(UserModel viewer) async {
    _track('Unblock_Pressed');
    _track('Unblock_Start');
    try {
      await _social.unblock(_userId, viewer: viewer);
      _track('Unblock_Success');
    } on Object catch (error) {
      _track('Unblock_Fail', error: error, type: LogType.severe);
      emit(state.copyWith(notice: SocialProfileNotice.unblockFailed));
    }
  }

  void settingsPressed() => _track('Settings_Pressed');

  void editProfilePressed() => _track('EditProfile_Pressed');

  void weeklyGoalPressed() => _track('WeeklyGoal_Pressed');
}
