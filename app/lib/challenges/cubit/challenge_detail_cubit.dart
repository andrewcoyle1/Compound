import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/challenges/logic/challenge_standings.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// Where leaving is.
enum ChallengeLeaveStatus { idle, leaving, left, failed }

final class const ChallengeDetailState({
  /// The challenge, once known; null while it is read.
  final ChallengeModel? challenge,

  /// It could not be read: deleted, or the viewer is no longer in it.
  final bool notFound = false,

  /// Sessions per member id.
  final Map<String, int> progress = const {},

  /// Everyone who can be named: the viewer, the people they follow, and
  /// members fetched to fill the standings.
  final Map<String, UserModel> users = const {},
  final ChallengeLeaveStatus leaveStatus = ChallengeLeaveStatus.idle,

  /// Bumped with each failure to leave.
  final int failureId = 0,
}) extends Equatable {
  /// Every member ranked, for [challenge] (the held copy may be newer).
  List<ChallengeStanding> standings(ChallengeModel challenge) =>
      ChallengeStandings.entries(challenge, progress: progress, users: users);

  ChallengeDetailState copyWith({
    ChallengeModel? challenge,
    bool? notFound,
    Map<String, int>? progress,
    Map<String, UserModel>? users,
    ChallengeLeaveStatus? leaveStatus,
    int? failureId,
  }) => ChallengeDetailState(
    challenge: challenge ?? this.challenge,
    notFound: notFound ?? this.notFound,
    progress: progress ?? this.progress,
    users: users ?? this.users,
    leaveStatus: leaveStatus ?? this.leaveStatus,
    failureId: failureId ?? this.failureId,
  );

  @override
  List<Object?> get props => [
    challenge,
    notFound,
    progress,
    users,
    leaveStatus,
    failureId,
  ];
}

/// One challenge's standings (`ChallengeDetailPresenter`): the reader's
/// ring, every member ranked, and Leave for a member.
class ChallengeDetailCubit extends Cubit<ChallengeDetailState> {
  new({
    required this._social,
    required this._analytics,
    required this._viewer,
    required this._challengeId,
    required List<UserModel> following,
    ChallengeModel? challenge,
    Map<String, int> progress = const {},
  }) : super(
         ChallengeDetailState(
           challenge: challenge,
           progress: progress,
           users: {
             for (final user in following) user.userId: user,
             _viewer.userId: _viewer,
           },
         ),
       );

  final SocialRepository _social;
  final AnalyticsRepository _analytics;
  final UserModel _viewer;
  final String _challengeId;

  void appeared() => _analytics.trackScreenView(
    const AnalyticsEvent('ChallengeDetailView_Appear'),
  );

  void disappeared() => _analytics.trackEvent(
    const AnalyticsEvent('ChallengeDetailView_Disappear'),
  );

  /// Reads the challenge if it was opened by id, then its standings, then
  /// any member the reader cannot name yet. The refreshes are silent: what
  /// is on screen stays, and an unfetchable member stays "Member".
  Future<void> load() async {
    var challenge = state.challenge;
    if (challenge == null) {
      try {
        challenge = await _social.challenge(_challengeId);
      } on Object catch (_) {
        challenge = null;
      }
      if (challenge == null) {
        emit(state.copyWith(notFound: true));
        return;
      }
      emit(state.copyWith(challenge: challenge));
    }
    try {
      emit(
        state.copyWith(progress: await _social.challengeProgress(challenge.id)),
      );
    } on Object catch (error) {
      _warning('ChallengeDetailView_RefreshProgress_Fail', error);
    }
    final missing = [
      for (final id in challenge.memberIds)
        if (!state.users.containsKey(id)) id,
    ];
    if (missing.isEmpty) return;
    try {
      final fetched = await _social.users(missing, viewer: _viewer);
      emit(
        state.copyWith(
          users: {
            ...state.users,
            for (final user in fetched) user.userId: user,
          },
        ),
      );
    } on Object catch (error) {
      _warning('ChallengeDetailView_LoadMember_Fail', error);
    }
  }

  /// Takes the viewer out of the challenge, after the view has confirmed.
  Future<void> leave() async {
    if (state.leaveStatus == ChallengeLeaveStatus.leaving) return;
    _analytics.trackEvent(
      const AnalyticsEvent('ChallengeDetailView_Leave_Start'),
    );
    emit(state.copyWith(leaveStatus: ChallengeLeaveStatus.leaving));
    try {
      await _social.leaveChallenge(_challengeId, userId: _viewer.userId);
      _analytics.trackEvent(
        const AnalyticsEvent('ChallengeDetailView_Leave_Success'),
      );
      emit(state.copyWith(leaveStatus: ChallengeLeaveStatus.left));
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'ChallengeDetailView_Leave_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(
        state.copyWith(
          leaveStatus: ChallengeLeaveStatus.failed,
          failureId: state.failureId + 1,
        ),
      );
    }
  }

  void _warning(String name, Object error) => _analytics.trackEvent(
    AnalyticsEvent(
      name,
      parameters: {'error_description': '$error'},
      type: LogType.warning,
    ),
  );
}
