import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// A finished workout's Strava link, and the summary's one-time offer.
final class const SessionStravaState({
  /// The activity on Strava, for its author, once the stored session has
  /// one.
  final Uri? link,

  /// Moves when the offer to connect Strava should be shown.
  final int offerId = 0,
}) extends Equatable {
  @override
  List<Object?> get props => [link, offerId];
}

/// Strava on a workout's detail (Swift `WorkoutSessionDetailPresenter`'s
/// Strava section): "View on Strava" from the stored session, which gains
/// the activity id once Strava has made it, and, on the summary of a
/// workout just finished, the one-time offer to connect (`StravaOffer`),
/// made once the workout has saved. Swift gives up waiting for the save
/// after ten seconds; this waits as long as the summary is open.
class SessionStravaCubit extends Cubit<SessionStravaState> {
  new({
    required this._sessions,
    required this._analytics,
    required this._uid,
    required this._sessionId,
    required this._isWorkoutSummary,
    this._session,
    this._strava,
  }) : super(const SessionStravaState());

  final WorkoutSessionRepository _sessions;
  final AnalyticsRepository _analytics;
  final String _uid;
  final String _sessionId;
  final bool _isWorkoutSummary;
  final WorkoutSessionModel? _session;
  final StravaRepository? _strava;

  StreamSubscription<List<WorkoutSessionModel>>? _subscription;
  bool _offerChecked = false;

  static const _screen = 'WorkoutSessionDetailView';

  /// Follows the stored session.
  void started() {
    _subscription = _sessions
        .watchSessions(_uid)
        .listen(_sessionsChanged, onError: (Object _, StackTrace _) {});
  }

  void _sessionsChanged(List<WorkoutSessionModel> sessions) {
    final stored = sessions.where((s) => s.id == _sessionId).firstOrNull;
    final session = stored ?? _session;
    final link = session == null
        ? null
        : stravaActivityLink(session, viewerId: _uid);
    var offerId = state.offerId;
    final strava = _strava;
    if (_isWorkoutSummary &&
        !_offerChecked &&
        stored != null &&
        strava != null) {
      _offerChecked = true;
      if (shouldOfferStrava(
        finished: _session ?? stored,
        savedSessions: sessions,
        isStravaConnected: strava.isConnected,
        hasAnswered: strava.offerAnswered,
      )) {
        _analytics.analytic('strava_offer_shown');
        offerId++;
      }
    }
    emit(SessionStravaState(link: link, offerId: offerId));
  }

  /// The offer was answered; it is never made again for this account.
  /// Connecting is `StravaCubit.connect(fromOffer: true)`.
  Future<void> offerAnswered({required bool connect}) async {
    _analytics.analytic(
      connect ? 'strava_offer_accepted' : 'strava_offer_declined',
    );
    await _strava?.answerOffer();
  }

  /// "View on Strava" was tapped.
  void viewOnStravaPressed() => _analytics.analytic('${_screen}_ViewOnStrava', {
    'session_id': _sessionId,
  });

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
