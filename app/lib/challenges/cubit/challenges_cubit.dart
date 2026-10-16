import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// The signed-in user's challenges and their standings.
final class const ChallengesState({
  /// Whose challenges these are, so a previous account's never show.
  final String? uid,

  /// Every challenge [uid] is in, soonest ending first.
  final List<ChallengeModel> challenges = const [],

  /// Sessions per member id, keyed by challenge id.
  final Map<String, Map<String, int>> progress = const {},
}) extends Equatable {
  /// [uid]'s challenge [id], when held.
  ChallengeModel? challenge(String id) =>
      challenges.where((challenge) => challenge.id == id).firstOrNull;

  @override
  List<Object?> get props => [uid, challenges, progress];
}

/// The signed-in user's challenges, app-wide, as Swift's `ChallengeManager`:
/// read when Social appears rather than listened to, since the query is by
/// membership. Social's section and the detail screen read it; creating
/// and leaving update it in place.
class ChallengesCubit extends Cubit<ChallengesState> {
  new({required this._social, required this._analytics})
    : super(const ChallengesState());

  final SocialRepository _social;
  final AnalyticsRepository _analytics;

  /// Someone else signed in, or out: their challenges start empty.
  void viewerChanged(String? uid) {
    if (uid != state.uid) emit(ChallengesState(uid: uid));
  }

  /// Reads the challenges and each one's standings. Silent: the section
  /// keeps what it had (`SocialPresenter.loadChallenges`).
  Future<void> refresh() async {
    final uid = state.uid;
    if (uid == null) return;
    try {
      final challenges = await _social.challenges(uid);
      final progress = {
        for (final challenge in challenges)
          challenge.id: await _social.challengeProgress(challenge.id),
      };
      if (isClosed || state.uid != uid) return;
      emit(
        ChallengesState(uid: uid, challenges: challenges, progress: progress),
      );
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'SocialView_LoadChallenges_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.warning,
        ),
      );
    }
  }

  /// [challenge] was just created.
  void added(ChallengeModel challenge) => emit(
    ChallengesState(
      uid: state.uid,
      challenges: [...state.challenges, challenge]
        ..sort((a, b) => a.endsAt.compareTo(b.endsAt)),
      progress: {...state.progress, challenge.id: const {}},
    ),
  );

  /// The viewer left challenge [id].
  void left(String id) => emit(
    ChallengesState(
      uid: state.uid,
      challenges: [
        for (final challenge in state.challenges)
          if (challenge.id != id) challenge,
      ],
      progress: {...state.progress}..remove(id),
    ),
  );

  /// The detail screen read challenge [id]'s standings afresh.
  void progressRead(String id, Map<String, int> progress) => emit(
    ChallengesState(
      uid: state.uid,
      challenges: state.challenges,
      progress: {...state.progress, id: progress},
    ),
  );
}
