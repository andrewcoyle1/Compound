import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// Whether the reader likes one workout, and how many do.
final class const SessionLikeState({
  required final bool isLiked,
  required final int count,
}) extends Equatable {
  @override
  List<Object> get props => [isLiked, count];
}

/// The like button on one feed card (`WorkoutSessionRowPresenter`): it
/// flips at once and writes in the background, flipping back if the write
/// fails.
class SessionLikeCubit extends Cubit<SessionLikeState> {
  new({
    required this._social,
    required this._analytics,
    required this._session,
    required String? viewerId,
  }) : super(
         SessionLikeState(
           isLiked: _session.likedByUserIds.contains(viewerId),
           count: _session.likedByUserIds.length,
         ),
       );

  final SocialRepository _social;
  final AnalyticsRepository _analytics;
  final WorkoutSessionModel _session;

  /// Likes or unlikes as [viewer]. False when the write failed and the
  /// button went back.
  Future<bool> toggled(UserModel viewer) async {
    final before = state;
    final liking = !before.isLiked;
    final name = liking ? 'Like' : 'Unlike';
    emit(
      SessionLikeState(
        isLiked: liking,
        count: before.count + (liking ? 1 : -1),
      ),
    );
    _analytics.trackEvent(AnalyticsEvent('WorkoutSessionRow_${name}_Start'));
    try {
      if (liking) {
        await _social.likeSession(
          _session.id,
          authorId: _session.authorId,
          viewer: viewer,
        );
      } else {
        await _social.unlikeSession(
          _session.id,
          authorId: _session.authorId,
          viewer: viewer,
        );
      }
      _analytics.trackEvent(
        AnalyticsEvent('WorkoutSessionRow_${name}_Success'),
      );
      return true;
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'WorkoutSessionRow_${name}_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(before);
      return false;
    }
  }
}
