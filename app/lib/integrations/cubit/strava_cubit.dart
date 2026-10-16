import 'dart:async';
import 'dart:developer' as developer;

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/integrations/web_strava_authorizer.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:strava_repository/strava_repository.dart';

/// What a Strava screen tells the person once (Swift's alerts, toasts and
/// dialogs on `IntegrationsPresenter` and the summary's offer).
enum StravaNotice {
  /// Connected with past workouts to send: "Upload {count} past workouts
  /// to Strava?"
  backfillOffered,

  /// Past workouts queued: "{count} workouts queued for Strava".
  backfillQueued,

  /// "Unable to Connect Strava", for [StravaState.noticeFailure].
  connectFailed,

  /// "Unable to Disconnect Strava".
  disconnectFailed,

  /// "Test upload sent to Strava".
  testUploadSent,

  /// "Upload Failed", for [StravaState.noticeFailure].
  testUploadFailed,
}

/// The signed-in account's Strava, app-wide.
final class const StravaState({
  /// Whether this build can reach Strava: false without a client id.
  final bool available = false,

  /// Whose Strava this is.
  final String? uid,

  /// The Strava account connected, or null.
  final StravaAthlete? athlete,

  /// Workouts queued and not on Strava yet.
  final int pendingCount = 0,

  /// Past workouts not on Strava and not queued.
  final int backfillCount = 0,

  /// Runs and rides imported from Strava, newest first. The owner's own
  /// screens only, per Strava's terms.
  final List<StravaImportedActivity> activities = const [],
  final bool isConnecting = false,
  final bool isDisconnecting = false,
  final bool isTestingUpload = false,

  /// The last notice, told once per [noticeId].
  final StravaNotice? notice,
  final int noticeId = 0,

  /// The count a backfill notice is about.
  final int noticeCount = 0,

  /// Why a connection or test upload failed, when Strava said.
  final StravaFailure? noticeFailure,
}) extends Equatable {
  /// Whether this account is connected.
  bool get isConnected => athlete != null;

  StravaState copyWith({
    StravaAthlete? Function()? athlete,
    int? pendingCount,
    int? backfillCount,
    List<StravaImportedActivity>? activities,
    bool? isConnecting,
    bool? isDisconnecting,
    bool? isTestingUpload,
  }) => StravaState(
    available: available,
    uid: uid,
    athlete: athlete == null ? this.athlete : athlete(),
    pendingCount: pendingCount ?? this.pendingCount,
    backfillCount: backfillCount ?? this.backfillCount,
    activities: activities ?? this.activities,
    isConnecting: isConnecting ?? this.isConnecting,
    isDisconnecting: isDisconnecting ?? this.isDisconnecting,
    isTestingUpload: isTestingUpload ?? this.isTestingUpload,
    notice: notice,
    noticeId: noticeId,
    noticeCount: noticeCount,
    noticeFailure: noticeFailure,
  );

  /// This state telling [notice].
  StravaState telling(
    StravaNotice notice, {
    int count = 0,
    StravaFailure? failure,
  }) => StravaState(
    available: available,
    uid: uid,
    athlete: athlete,
    pendingCount: pendingCount,
    backfillCount: backfillCount,
    activities: activities,
    isConnecting: isConnecting,
    isDisconnecting: isDisconnecting,
    isTestingUpload: isTestingUpload,
    notice: notice,
    noticeId: noticeId + 1,
    noticeCount: count,
    noticeFailure: failure,
  );

  @override
  List<Object?> get props => [
    available,
    uid,
    athlete,
    pendingCount,
    backfillCount,
    activities,
    isConnecting,
    isDisconnecting,
    isTestingUpload,
    notice,
    noticeId,
    noticeCount,
    noticeFailure,
  ];
}

/// Strava for the signed-in account (Swift `StravaManager` as
/// `IntegrationsPresenter` drives it): follows the account, connects and
/// disconnects, queues past workouts and sends a test upload, with the
/// Swift screen's event names. Without a repository (no Strava client id
/// in this build) Strava is unavailable and nothing happens.
class StravaCubit extends Cubit<StravaState> {
  new({
    required StravaRepository? strava,
    required this._authorizer,
    required this._analytics,
  }) : _strava = strava,
       super(StravaState(available: strava != null));

  final StravaRepository? _strava;
  final StravaAuthorizer _authorizer;
  final AnalyticsRepository _analytics;

  static const _screen = 'IntegrationsView';

  StreamSubscription<StravaAthlete?>? _athleteSubscription;
  StreamSubscription<List<StravaImportedActivity>>? _activitiesSubscription;

  /// Someone else signed in, or out: loads their connection and queue,
  /// sends the queue, and follows their imported activities.
  Future<void> userChanged(String? uid) async {
    final strava = _strava;
    if (strava == null || uid == state.uid) return;
    await _athleteSubscription?.cancel();
    await _activitiesSubscription?.cancel();
    if (state.uid != null) strava.signOut();
    emit(StravaState(available: true, uid: uid));
    if (uid == null) return;
    _athleteSubscription = strava.watchAthlete().listen((athlete) {
      if (state.uid == uid) emit(state.copyWith(athlete: () => athlete));
    });
    _activitiesSubscription = strava.watchImportedActivities(uid).listen(
      (activities) {
        if (state.uid == uid) {
          emit(state.copyWith(activities: activities));
        }
      },
      onError: (Object error, StackTrace stack) =>
          _log('Imported activities could not be read', error, stack),
    );
    try {
      await strava.signIn(uid);
    } on Object catch (error, stack) {
      _log('Signing in to Strava failed', error, stack);
    }
    await _refreshCounts(uid);
  }

  /// Integrations opened: the connection can change elsewhere (another
  /// phone, or revoking Compound on strava.com), so the server is asked.
  Future<void> appeared() async {
    _analytics.appear(_screen);
    final strava = _strava;
    final uid = state.uid;
    if (strava == null || uid == null) return;
    try {
      await strava.refreshConnection();
    } on Object {
      // Offline: the last known state stands.
    }
    await _refreshCounts(uid);
  }

  void disappeared() => _analytics.disappear(_screen);

  /// Connects through Strava's consent page. From Integrations
  /// ([fromOffer] false) a success offers to upload past workouts; from the
  /// summary's offer, the workout that prompted it and any before it are
  /// queued straight away, as Swift's `connectStrava`. Closing the page
  /// says nothing.
  Future<void> connect({bool fromOffer = false}) async {
    final strava = _strava;
    final uid = state.uid;
    if (strava == null || uid == null || state.isConnecting) return;
    emit(state.copyWith(isConnecting: true));
    if (!fromOffer) _analytics.analytic('${_screen}_StravaConnect_Start');
    try {
      await strava.connect(_authorizer);
      if (fromOffer) {
        await strava.queueBackfill();
        unawaited(_send(uid));
      } else {
        _analytics.analytic('${_screen}_StravaConnect_Success');
      }
      await _refreshCounts(uid);
      if (!fromOffer && state.backfillCount > 0) {
        emit(
          state.telling(
            StravaNotice.backfillOffered,
            count: state.backfillCount,
          ),
        );
      }
    } on StravaAuthorizationCancelled {
      if (!fromOffer) _analytics.analytic('${_screen}_StravaConnect_Cancelled');
    } on Object catch (error) {
      if (!fromOffer) {
        _analytics.severe('${_screen}_StravaConnect_Fail', error);
      }
      emit(
        state.telling(
          StravaNotice.connectFailed,
          failure: switch (error) {
            StravaException(failure: StravaFailure.missingUploadPermission) =>
              StravaFailure.missingUploadPermission,
            _ => null,
          },
        ),
      );
    }
    emit(state.copyWith(isConnecting: false));
  }

  /// Queues every past workout not on Strava and starts sending them.
  Future<void> backfill() async {
    final strava = _strava;
    final uid = state.uid;
    if (strava == null || uid == null) return;
    final queued = await strava.queueBackfill();
    _analytics.analytic('${_screen}_StravaBackfill', {'count': queued});
    if (queued == 0) return;
    await _refreshCounts(uid);
    emit(state.telling(StravaNotice.backfillQueued, count: queued));
    unawaited(_send(uid));
  }

  /// Disconnects, once confirmed. A failure leaves the account connected
  /// and says so.
  Future<void> disconnect() async {
    final strava = _strava;
    final uid = state.uid;
    if (strava == null || uid == null || state.isDisconnecting) return;
    _analytics.analytic('${_screen}_StravaDisconnect');
    emit(state.copyWith(isDisconnecting: true));
    try {
      await strava.disconnect();
      await _refreshCounts(uid);
    } on Object catch (error) {
      _analytics.severe('${_screen}_StravaDisconnect_Fail', error);
      emit(state.telling(StravaNotice.disconnectFailed));
    }
    emit(state.copyWith(isDisconnecting: false));
  }

  /// Posts a one-set test activity, and says how it went either way.
  Future<void> testUpload() async {
    final strava = _strava;
    if (strava == null || state.uid == null || state.isTestingUpload) return;
    emit(state.copyWith(isTestingUpload: true));
    _analytics.analytic('${_screen}_StravaTestUpload_Start');
    try {
      await strava.uploadTestActivity();
      _analytics.analytic('${_screen}_StravaTestUpload_Success');
      emit(state.telling(StravaNotice.testUploadSent));
    } on Object catch (error) {
      _analytics.severe('${_screen}_StravaTestUpload_Fail', error);
      emit(
        state.telling(
          StravaNotice.testUploadFailed,
          failure: error is StravaException ? error.failure : null,
        ),
      );
    }
    emit(state.copyWith(isTestingUpload: false));
  }

  Future<void> _send(String uid) async {
    await _strava?.syncPendingUploads();
    await _refreshCounts(uid);
  }

  Future<void> _refreshCounts(String uid) async {
    final strava = _strava;
    if (strava == null) return;
    var backfill = 0;
    try {
      backfill = (await strava.backfillCandidates()).length;
    } on Object catch (error, stack) {
      _log('Past workouts could not be counted', error, stack);
    }
    if (isClosed || state.uid != uid) return;
    emit(
      state.copyWith(
        athlete: () => strava.athlete,
        pendingCount: strava.pendingSessionIds.length,
        backfillCount: backfill,
      ),
    );
  }

  static void _log(String message, Object error, StackTrace stack) =>
      developer.log(message, name: 'strava', error: error, stackTrace: stack);

  @override
  Future<void> close() async {
    await _athleteSubscription?.cancel();
    await _activitiesSubscription?.cancel();
    await super.close();
  }
}
