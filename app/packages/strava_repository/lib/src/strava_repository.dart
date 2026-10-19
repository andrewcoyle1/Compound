import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:strava_repository/src/strava_account_store.dart';
import 'package:strava_repository/src/strava_api.dart';
import 'package:strava_repository/src/strava_authorizer.dart';
import 'package:strava_repository/src/strava_models.dart';
import 'package:strava_repository/src/strava_strength_file.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// What an upload needs beyond the session: the exercise library, for the
/// Strava type of a custom exercise, and the user's units, for the
/// description.
typedef StravaUploadContext = ({
  List<ExerciseModel> library,
  WeightUnitPreference weightUnit,
  DistanceUnitPreference distanceUnit,
});

/// Called with an analytics event the queue raises
/// (`strava_upload_rejected`, `strava_upload_error`), as Swift tracks them
/// at the warning level.
typedef StravaEventReporter = void Function(
  String name,
  Map<String, Object> parameters,
);

/// The default [StravaEventReporter]: `dart:developer`'s log.
void logStravaEvent(String name, Map<String, Object> parameters) =>
    developer.log('$name $parameters', name: 'strava_repository', level: 900);

/// Called with an imported activity's path when it cannot be decoded and is
/// skipped.
typedef StravaDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// What sending one session came to (Swift `UploadOutcome`).
sealed class StravaUploadOutcome {
  const new();
}

/// Strava made the activity.
@immutable
final class StravaLinked extends StravaUploadOutcome {
  /// Creates a [StravaLinked].
  const new(this.activityId);

  /// The activity's id.
  final int activityId;

  @override
  bool operator ==(Object other) =>
      other is StravaLinked && other.activityId == activityId;

  @override
  int get hashCode => activityId.hashCode;

  @override
  String toString() => 'StravaLinked($activityId)';
}

/// Nothing Strava can take: no completed set it can place.
final class StravaNothingToSend extends StravaUploadOutcome {
  /// Creates a [StravaNothingToSend].
  const new();
}

/// Strava had not finished after the wait. Sending again answers the same
/// activity as a duplicate, so the session stays queued to pick up its id.
final class StravaProcessing extends StravaUploadOutcome {
  /// Creates a [StravaProcessing].
  const new();
}

/// The connection to Strava, workout uploads and the imported activities
/// (Swift `StravaManager`).
///
/// The tokens live on the server (`strava_connections/{uid}`, behind the
/// `strava*` callables), so the connection belongs to the Compound account
/// rather than the device: signing out keeps it, and signing in on another
/// phone finds it. This holds only a short-lived access token, in memory.
///
/// Finished workouts go up through a queue kept per account on the device
/// ([StravaAccountStore]), sent at [signIn] and after each [queueUpload],
/// like a sync engine's pending writes. Strava's rate limits are per app,
/// shared by every user, which is why a long backfill finishes over later
/// syncs rather than at once.
///
/// One instance serves the signed-in account: call [signIn] once its
/// sessions can be read, and [signOut] when it signs out.
class StravaRepository {
  /// Creates a [StravaRepository]. `firestore` is read for the imported
  /// activities only; `sessions` is read for queued sessions and stamped
  /// with each activity id. `clientId` is Strava's for this app.
  new({
    required this._firestore,
    required this._api,
    required this._sessions,
    required this._store,
    required this._clientId,
    required this._uploadContext,
    DateTime Function()? now,
    String Function()? newId,
    this._pollInterval = const Duration(seconds: 1),
    this._pollAttempts = 10,
    this._onEvent = logStravaEvent,
    this._onDecodeError = _logDecodeError,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? newDocumentId;

  final FirebaseFirestore _firestore;
  final StravaApi _api;
  final WorkoutSessionRepository _sessions;
  final StravaAccountStore _store;
  final String _clientId;
  final Future<StravaUploadContext> Function(String uid) _uploadContext;
  final DateTime Function() _now;
  final String Function() _newId;
  final Duration _pollInterval;
  final int _pollAttempts;
  final StravaEventReporter _onEvent;
  final StravaDecodeErrorHandler _onDecodeError;

  String? _uid;
  StravaAccountState _state = const StravaAccountState();
  StravaAccessToken? _cachedToken;
  bool _isSyncingUploads = false;
  final _athleteChanges = StreamController<StravaAthlete?>.broadcast(
    sync: true,
  );

  /// The signed-in account, `null` before [signIn] and after [signOut].
  String? get userId => _uid;

  /// The Strava account this Compound account is connected to, `null` when
  /// it is not. Remembered per account so a launch knows at once, and
  /// refreshed from the server at sign-in and by [refreshConnection].
  StravaAthlete? get athlete => _state.athlete;

  /// Whether this account is connected to Strava.
  bool get isConnected => athlete != null;

  /// Sessions waiting to go to Strava, oldest first.
  List<String> get pendingSessionIds =>
      List.unmodifiable(_state.pendingSessionIds);

  /// Whether the queue is being sent.
  bool get isSyncingUploads => _isSyncingUploads;

  /// Whether the athlete has answered the offer to connect
  /// (`shouldOfferStrava`).
  bool get offerAnswered => _state.offerAnswered;

  /// [athlete] now and on every change, a disconnect found by an upload
  /// included.
  Stream<StravaAthlete?> watchAthlete() => Stream.multi((listener) {
    listener.add(athlete);
    final subscription = _athleteChanges.stream.listen(listener.add);
    listener.onCancel = () => unawaited(subscription.cancel());
  });

  // MARK: - Lifecycle

  /// Loads [uid]'s state on this device, asks the server whether it is
  /// connected, and sends its queue. A failure to reach the server leaves
  /// the remembered connection as it was.
  Future<void> signIn(String uid) async {
    _uid = uid;
    _cachedToken = null;
    final state = await _store.load(uid);
    if (_uid != uid) return;
    _state = state;
    _athleteChanges.add(athlete);
    try {
      await refreshConnection();
    } on StravaException {
      // Offline, most likely: the remembered connection stands.
    }
    await syncPendingUploads();
  }

  /// Forgets this account's state here. The connection itself stays with
  /// the account, and the queue on the device for its next sign-in.
  void signOut() {
    _uid = null;
    _state = const StravaAccountState();
    _cachedToken = null;
    _athleteChanges.add(null);
  }

  /// Asks the server whether this account is connected, and to whom.
  Future<void> refreshConnection() async {
    await _setAthlete(await _api.connection());
  }

  // MARK: - Connecting

  /// Connects through Strava's consent page, opened by [authorizer]. Throws
  /// what the authorizer throws when the athlete cancels, and a
  /// [StravaException] when Strava or the server refuses: a grant without
  /// the upload permission is
  /// [StravaFailure.missingUploadPermission].
  Future<void> connect(StravaAuthorizer authorizer) async {
    final redirect = await authorizer.authorize(
      stravaAuthorizationUri(_clientId),
      stravaCallbackScheme,
    );
    final result = await _api.connect(
      clientId: _clientId,
      code: stravaAuthorizationCode(redirect),
    );
    _cachedToken = result.token;
    await _setAthlete(result.athlete);
  }

  /// Revokes Compound at Strava and deletes the connection and the imported
  /// activities on the server. Nothing changes here unless that worked, so
  /// a failure leaves the account connected rather than claiming otherwise.
  Future<void> disconnect() async {
    await _api.disconnect();
    await _setState(
      _state.copyWith(clearAthlete: true, pendingSessionIds: const []),
    );
  }

  /// Remembers that the athlete answered the offer to connect, whichever
  /// way.
  Future<void> answerOffer() => _setState(_state.copyWith(offerAnswered: true));

  // MARK: - Tokens

  /// Runs [body] with a current access token. A 401 gets one fresh token
  /// and one retry. If Strava still refuses, or the server has no
  /// connection, the account is not connected: this throws
  /// [StravaFailure.notConnected] and [athlete] becomes `null`.
  Future<T> withAccessToken<T>(Future<T> Function(String token) body) async {
    try {
      try {
        return await body(await _validAccessToken());
      } on StravaException catch (error) {
        if (error.failure != StravaFailure.authorizationRevoked) rethrow;
        _cachedToken = null;
        return await body(await _validAccessToken());
      }
    } on StravaException catch (error) {
      if (error.failure != StravaFailure.authorizationRevoked &&
          error.failure != StravaFailure.notConnected) {
        rethrow;
      }
      await _setState(_state.copyWith(clearAthlete: true));
      throw StravaException(StravaFailure.notConnected, cause: error);
    }
  }

  Future<String> _validAccessToken() async {
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    if (_cachedToken case final token? when token.expiresAt > nowSeconds + 60) {
      return token.accessToken;
    }
    final token = await _api.accessToken();
    _cachedToken = token;
    return token.accessToken;
  }

  // MARK: - The queue

  /// Queues a finished workout and sends the queue. [session] is the one
  /// just saved, which the stored copy may not have caught up with yet.
  /// Nothing happens unless signed in and connected.
  Future<void> queueUpload(WorkoutSessionModel session) async {
    if (!isConnected || _uid == null) return;
    if (!_state.pendingSessionIds.contains(session.id)) {
      await _setState(
        _state.copyWith(
          pendingSessionIds: [..._state.pendingSessionIds, session.id],
        ),
      );
    }
    await syncPendingUploads(including: session);
  }

  /// The account's finished workouts that are not on Strava yet and are not
  /// queued, oldest first: own, not rest days, not deleted, with something
  /// Strava can take.
  Future<List<WorkoutSessionModel>> backfillCandidates() async {
    final uid = _uid;
    if (uid == null) return const [];
    final sessions = await _sessions.watchSessions(uid).first;
    final context = await _uploadContext(uid);
    return [
      for (final session in sessions)
        if (session.authorId == uid &&
            session.endedAt != null &&
            !session.isRestDay &&
            session.deletedAt == null &&
            session.stravaActivityId == null &&
            !_state.pendingSessionIds.contains(session.id) &&
            StravaStrengthFile.from(session, context.library) != null)
          session,
    ]..sort((a, b) => a.dateCreated.compareTo(b.dateCreated));
  }

  /// Queues every past workout not on Strava yet, and answers how many.
  /// Sending is the caller's to start ([syncPendingUploads]): a long
  /// backlog runs into Strava's request limit and finishes over later syncs.
  Future<int> queueBackfill() async {
    final candidates = [
      for (final session in await backfillCandidates()) session.id,
    ];
    if (candidates.isNotEmpty) {
      await _setState(
        _state.copyWith(
          pendingSessionIds: [..._state.pendingSessionIds, ...candidates],
        ),
      );
    }
    return candidates.length;
  }

  /// Sends the queue in order. Stops at the first failure that would fail
  /// the rest too (offline, over Strava's limit, no longer connected) and
  /// drops an entry Strava will never take. A session that cannot be read
  /// yet stays for the next sync. [including] is a session just saved.
  Future<void> syncPendingUploads({WorkoutSessionModel? including}) async {
    final uid = _uid;
    if (!isConnected || uid == null || _isSyncingUploads) return;
    _isSyncingUploads = true;
    try {
      StravaUploadContext? context;
      for (final sessionId in List.of(_state.pendingSessionIds)) {
        if (_uid != uid) return;
        final session = including?.id == sessionId
            ? including
            : await _storedSession(uid, sessionId);
        if (session == null) continue;
        if (session.deletedAt != null || session.stravaActivityId != null) {
          await _dequeue(sessionId);
          continue;
        }
        try {
          context ??= await _uploadContext(uid);
          final outcome = await _upload(session, context);
          // Signed out meanwhile: the entry stays in that account's queue,
          // and its next sync links the activity through Strava's
          // duplicate answer.
          if (_uid != uid) return;
          switch (outcome) {
            case StravaLinked(:final activityId):
              await _dequeue(sessionId);
              await _stamp(uid, sessionId, activityId);
            case StravaNothingToSend():
              await _dequeue(sessionId);
            case StravaProcessing():
              continue;
          }
        } on StravaException catch (error) {
          if (error.failure == StravaFailure.processingFailed) {
            _onEvent('strava_upload_rejected', {'reason': error.reason ?? ''});
            await _dequeue(sessionId);
          } else if (error.failure == StravaFailure.uploadFailed &&
              error.status! >= 400 &&
              error.status! < 500) {
            _onEvent('strava_upload_rejected', {'status': error.status!});
            await _dequeue(sessionId);
          } else {
            _onEvent('strava_upload_error', {'error': error.failure.name});
            return;
          }
        } on Object catch (error) {
          _onEvent('strava_upload_error', {'error': '$error'});
          return;
        }
      }
    } finally {
      _isSyncingUploads = false;
    }
  }

  Future<WorkoutSessionModel?> _storedSession(String uid, String id) async {
    try {
      return await _sessions.session(uid, id);
    } on Object {
      // Not readable yet (offline and not cached): it stays queued.
      return null;
    }
  }

  /// Swift `try?`: the activity exists either way, and a refusal by the
  /// server reaches the session repository's `onWriteError`.
  Future<void> _stamp(String uid, String sessionId, int activityId) async {
    try {
      await _sessions.updateStravaActivityId(uid, sessionId, activityId);
    } on Object {
      // The link is lost; the activity is not.
    }
  }

  Future<void> _dequeue(String sessionId) => _setState(
    _state.copyWith(
      pendingSessionIds: [
        for (final id in _state.pendingSessionIds)
          if (id != sessionId) id,
      ],
    ),
  );

  // MARK: - Sending

  /// Uploads a finished workout with its sets. A workout sent twice (a
  /// retry, or two finishes racing) is one activity, because Strava refuses
  /// the second as a duplicate of the first.
  Future<StravaUploadOutcome> upload(WorkoutSessionModel session) async =>
      await _upload(session, await _uploadContext(_signedIn()));

  Future<StravaUploadOutcome> _upload(
    WorkoutSessionModel session,
    StravaUploadContext context,
  ) async {
    final file = StravaStrengthFile.from(session, context.library);
    if (file == null) return const StravaNothingToSend();
    final activityId = await _send(
      StravaUpload(
        name: session.name,
        description: _description(session, context),
        externalId: 'compound-${session.id}',
        file: file,
      ),
    );
    return activityId == null
        ? const StravaProcessing()
        : StravaLinked(activityId);
  }

  /// Sends a session's name and description to the activity it was
  /// uploaded as.
  Future<void> updateActivity(
    int activityId,
    WorkoutSessionModel session,
  ) async {
    final description = _description(
      session,
      await _uploadContext(_signedIn()),
    );
    await withAccessToken(
      (token) => _api.updateActivity(
        activityId,
        name: session.name,
        description: description,
        accessToken: token,
      ),
    );
  }

  /// After [session] was edited and saved: sends it to its activity when
  /// connected and the stored session is on Strava (the edited copy may not
  /// carry the id yet), and answers whether it did. Best-effort for the
  /// caller: the edit is saved in Compound either way.
  Future<bool> pushEdit(WorkoutSessionModel session) async {
    if (!isConnected) return false;
    final stored = await _storedSession(_signedIn(), session.id);
    final activityId = stored?.stravaActivityId ?? session.stravaActivityId;
    if (activityId == null) return false;
    await updateActivity(activityId, session);
    return true;
  }

  /// Uploads a one-set test workout, to check the connection from
  /// Integrations. Each is a new activity the athlete may delete.
  Future<void> uploadTestActivity() async {
    final end = _now().toUtc();
    final start = end.subtract(const Duration(minutes: 30));
    final session = WorkoutSessionModel(
      id: 'test',
      authorId: '',
      name: 'Compound Test Upload',
      dateCreated: start,
      dateModified: end,
      endedAt: end,
      notes: 'Test upload from Compound — safe to delete.',
      exercises: [
        WorkoutExerciseModel(
          id: 'test',
          authorId: '',
          templateId: 'system-barbell-bench-press',
          name: 'Barbell Bench Press',
          trackingMode: TrackingMode.weightReps,
          index: 0,
          sets: [
            WorkoutSetModel(
              id: 'test',
              authorId: '',
              index: 0,
              reps: 10,
              weightKg: 60,
              isWarmup: false,
              completedAt: end,
              dateCreated: start,
            ),
          ],
        ),
      ],
    );
    await _send(
      StravaUpload(
        name: session.name,
        description: _description(session, await _uploadContext(_signedIn())),
        externalId: 'compound-test-${_newId()}',
        file: StravaStrengthFile.from(session, const [])!,
      ),
    );
  }

  String? _description(
    WorkoutSessionModel session,
    StravaUploadContext context,
  ) => stravaDescription(
    session,
    weightUnit: context.weightUnit,
    distanceUnit: context.distanceUnit,
  );

  /// The activity id, or `null` if Strava was still processing after the
  /// wait. Strava processes an upload in under two seconds on average and
  /// asks to be polled no more than once a second.
  Future<int?> _send(StravaUpload upload) async {
    var status = await withAccessToken((token) => _api.upload(upload, token));
    for (var attempt = 0; attempt <= _pollAttempts; attempt++) {
      if (status.activityId ?? status.duplicateActivityId case final id?) {
        return id;
      }
      if (status.error case final reason?) {
        throw StravaException(StravaFailure.processingFailed, reason: reason);
      }
      if (attempt == _pollAttempts) break;
      await Future<void>.delayed(_pollInterval);
      final uploadId = status.id;
      status = await withAccessToken(
        (token) => _api.uploadStatus(uploadId, token),
      );
    }
    return null;
  }

  // MARK: - Imported activities

  /// Runs and rides from [uid]'s Strava account, newest first, re-emitted on
  /// every change. Strava's terms allow showing these to the athlete only:
  /// pass the signed-in user's own uid, and show them only on their own
  /// screens, never anywhere followers see. (The rules let no one else read
  /// them.) An activity that does not decode is skipped and reported.
  Stream<List<StravaImportedActivity>> watchImportedActivities(String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('strava_activities')
          .snapshots()
          .map(
            (snapshot) =>
                [for (final document in snapshot.docs) ?_decode(document)]
                  ..sort((a, b) => b.startDate.compareTo(a.startDate)),
          );

  StravaImportedActivity? _decode(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    try {
      return StravaImportedActivity.fromFirestore(
        document.data().map(
          (key, value) => MapEntry(
            key,
            value is Timestamp ? value.toDate().toUtc() : value,
          ),
        ),
      );
    } on Object catch (error, stackTrace) {
      _onDecodeError(document.reference.path, error, stackTrace);
      return null;
    }
  }

  // MARK: - State

  String _signedIn() =>
      _uid ?? (throw StateError('StravaRepository: no one is signed in'));

  Future<void> _setAthlete(StravaAthlete? athlete) => _setState(
    athlete == null
        ? _state.copyWith(clearAthlete: true)
        : _state.copyWith(athlete: athlete),
  );

  Future<void> _setState(StravaAccountState state) async {
    final athleteChanged = state.athlete != _state.athlete;
    _state = state;
    if (state.athlete == null) _cachedToken = null;
    if (athleteChanged) _athleteChanges.add(state.athlete);
    if (_uid case final uid?) await _store.save(uid, state);
  }

  static void _logDecodeError(
    String path,
    Object error,
    StackTrace stackTrace,
  ) => developer.log(
    'Skipped $path: it does not decode',
    name: 'strava_repository',
    error: error,
    stackTrace: stackTrace,
  );
}
