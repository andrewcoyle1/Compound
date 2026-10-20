import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// The people list's state: followers removed here, and a failed removal.
final class const PeopleListState({
  final Set<String> removedIds = const {},
  final bool removing = false,
  final int failureId = 0,
}) extends Equatable {
  @override
  List<Object> get props => [removedIds, removing, failureId];
}

/// A list of people (`FollowersListPresenter`): the reader's own followers
/// can be removed, through the `removeFollower` function.
class PeopleListCubit extends Cubit<PeopleListState> {
  new({
    required this._social,
    required this._analytics,
    required this._connectivity,
  }) : super(const PeopleListState());

  final SocialRepository _social;
  final AnalyticsRepository _analytics;

  /// Removing calls a function, so it does not start offline.
  final ConnectivityRepository _connectivity;

  void appeared() => _analytics.trackScreenView(
    const AnalyticsEvent('FollowersListView_Appear'),
  );

  void disappeared() => _analytics.trackEvent(
    const AnalyticsEvent('FollowersListView_Disappear'),
  );

  /// Removes [followerId], dropping them from the list once the function
  /// answers.
  Future<void> removeConfirmed(String followerId) async {
    if (!_connectivity.ensureOnline()) return;
    _analytics
      ..trackEvent(const AnalyticsEvent('FollowersListView_RemoveFollower'))
      ..trackEvent(
        const AnalyticsEvent('FollowersListView_RemoveFollower_Start'),
      );
    emit(
      PeopleListState(
        removedIds: state.removedIds,
        removing: true,
        failureId: state.failureId,
      ),
    );
    try {
      await _social.removeFollower(followerId);
      _analytics.trackEvent(
        const AnalyticsEvent('FollowersListView_RemoveFollower_Success'),
      );
      emit(
        PeopleListState(
          removedIds: {...state.removedIds, followerId},
          failureId: state.failureId,
        ),
      );
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'FollowersListView_RemoveFollower_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(
        PeopleListState(
          removedIds: state.removedIds,
          failureId: state.failureId + 1,
        ),
      );
    }
  }
}
