import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show PrebuiltCatalogue;
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/analytics_recorder.dart';

const _uid = 'user-1';

/// Strava and its server on the device, failing where a test says.
class _Api extends FakeStravaApi {
  new({required super.firestore, super.athlete})
    : super(uid: _uid, activities: sampleStravaActivities(DateTime(2026, 10)));

  Exception? connectError;
  Exception? disconnectError;
  Exception? uploadError;

  @override
  Future<StravaConnectResult> connect({
    required String clientId,
    String? code,
    String? refreshToken,
  }) async {
    if (connectError case final error?) throw error;
    return await super.connect(clientId: clientId, code: code);
  }

  @override
  Future<void> disconnect() async {
    if (disconnectError case final error?) throw error;
    await super.disconnect();
  }

  @override
  Future<StravaUploadStatus> upload(
    StravaUpload upload,
    String accessToken,
  ) async {
    if (uploadError case final error?) throw error;
    return await super.upload(upload, accessToken);
  }
}

/// Closes Strava's page without answering.
class _CancellingAuthorizer implements StravaAuthorizer {
  @override
  Future<Uri> authorize(Uri authorizationUri, String callbackScheme) =>
      throw const StravaAuthorizationCancelled();
}

/// A finished workout of [_uid]'s, [daysAgo] days back, Strava can take.
WorkoutSessionModel _workout(String id, int daysAgo) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day - daysAgo, 9);
  final end = start.add(const Duration(minutes: 45));
  return WorkoutSessionModel(
    id: id,
    authorId: _uid,
    name: 'Push',
    dateCreated: start,
    dateModified: end,
    endedAt: end,
    exercises: [
      WorkoutExerciseModel(
        id: '$id-e',
        authorId: _uid,
        templateId: 'system-barbell-bench-press',
        name: 'Barbell Bench Press',
        trackingMode: TrackingMode.weightReps,
        index: 0,
        sets: [
          WorkoutSetModel(
            id: '$id-s',
            authorId: _uid,
            index: 0,
            reps: 8,
            weightKg: 60,
            isWarmup: false,
            completedAt: end,
            dateCreated: start,
          ),
        ],
      ),
    ],
  );
}

/// Ported from Swift's `GeneralSettingsIntegrationsTests`: connecting is a
/// round trip out to another app, so the screen shows something is
/// happening and says plainly when it did not work.
void main() {
  late FakeFirebaseFirestore firestore;
  late _Api api;
  late InMemoryWorkoutSessionRepository sessions;
  late AnalyticsRecorder analytics;

  StravaCubit build({
    StravaAuthorizer? authorizer,
    List<WorkoutSessionModel> workouts = const [],
    StravaAthlete? connectedAs,
  }) {
    api = _Api(firestore: firestore, athlete: connectedAs);
    sessions = InMemoryWorkoutSessionRepository(sessions: workouts);
    return StravaCubit(
      strava: StravaRepository(
        firestore: firestore,
        api: api,
        sessions: sessions,
        store: InMemoryStravaAccountStore(),
        clientId: 'client',
        uploadContext: (_) async => (
          library: PrebuiltCatalogue.instance.exercises,
          weightUnit: WeightUnitPreference.kilograms,
          distanceUnit: DistanceUnitPreference.kilometers,
        ),
        pollInterval: Duration.zero,
      ),
      authorizer: authorizer ?? FakeStravaAuthorizer(),
      analytics: analytics,
    );
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    analytics = AnalyticsRecorder();
  });

  group(StravaCubit, () {
    test(
      'without a client id, Strava is unavailable and does nothing',
      () async {
        final cubit = StravaCubit(
          strava: null,
          authorizer: FakeStravaAuthorizer(),
          analytics: analytics,
        );
        await cubit.userChanged(_uid);
        await cubit.connect();
        expect(cubit.state, const StravaState());
        expect(analytics.names, isEmpty);
        await cubit.close();
      },
    );

    test('connecting reports the connection', () async {
      final cubit = build();
      await cubit.userChanged(_uid);

      await cubit.connect();

      expect(cubit.state.isConnecting, isFalse);
      expect(cubit.state.isConnected, isTrue);
      expect(cubit.state.athlete!.name, 'Alex Runner');
      expect(cubit.state.notice, isNull);
      expect(analytics.names, [
        'IntegrationsView_StravaConnect_Start',
        'IntegrationsView_StravaConnect_Success',
      ]);
      // The server imports the athlete's runs and rides.
      await pumpEventQueue();
      expect(cubit.state.activities.map((a) => a.name), [
        'Morning Run',
        'Evening Ride',
      ]);
      await cubit.close();
    });

    test(
      'connecting offers to upload past workouts when there are some',
      () async {
        final none = build();
        await none.userChanged(_uid);
        await none.connect();
        expect(none.state.notice, isNull);
        await none.close();

        final some = build(workouts: [_workout('a', 2), _workout('b', 1)]);
        await some.userChanged(_uid);
        await some.connect();
        expect(some.state.notice, StravaNotice.backfillOffered);
        expect(some.state.noticeCount, 2);
        await some.close();
      },
    );

    test('uploading past workouts queues them and starts sending', () async {
      final cubit = build(
        workouts: [_workout('a', 3), _workout('b', 2), _workout('c', 1)],
        connectedAs: FakeStravaApi.stagingAthlete,
      );
      await cubit.userChanged(_uid);
      expect(cubit.state.backfillCount, 3);

      await cubit.backfill();

      expect(cubit.state.notice, StravaNotice.backfillQueued);
      expect(cubit.state.noticeCount, 3);
      expect(analytics.parameters('IntegrationsView_StravaBackfill'), {
        'count': 3,
      });
      await pumpEventQueue();
      expect(api.uploads, hasLength(3));
      expect(cubit.state.pendingCount, 0);
      expect(cubit.state.backfillCount, 0);
      expect((await sessions.session(_uid, 'a'))!.stravaActivityId, isNotNull);
      await cubit.close();
    });

    test('nothing to upload queues nothing and says nothing', () async {
      final cubit = build(connectedAs: FakeStravaApi.stagingAthlete);
      await cubit.userChanged(_uid);
      await cubit.backfill();
      expect(cubit.state.notice, isNull);
      expect(analytics.parameters('IntegrationsView_StravaBackfill'), {
        'count': 0,
      });
      await cubit.close();
    });

    test('pending uploads are counted', () async {
      final cubit = build(
        workouts: [_workout('a', 2), _workout('b', 1)],
        connectedAs: FakeStravaApi.stagingAthlete,
      );
      await cubit.userChanged(_uid);
      expect(cubit.state.pendingCount, 0);
      api.uploadError = const StravaException(StravaFailure.unavailable);

      await cubit.backfill();
      await pumpEventQueue();

      expect(cubit.state.pendingCount, 2);
      await cubit.close();
    });

    test('appearing refreshes the connection', () async {
      final cubit = build();
      await cubit.userChanged(_uid);
      expect(cubit.state.isConnected, isFalse);
      // Connected meanwhile on another phone.
      await api.connect(clientId: 'client');

      await cubit.appeared();
      cubit.disappeared();

      expect(cubit.state.isConnected, isTrue);
      expect(analytics.names, [
        'IntegrationsView_Appear',
        'IntegrationsView_Disappear',
      ]);
      await cubit.close();
    });

    test(
      'a failed connection is reported and leaves Strava disconnected',
      () async {
        final cubit = build();
        await cubit.userChanged(_uid);
        api.connectError = const StravaException(StravaFailure.unavailable);

        await cubit.connect();

        expect(cubit.state.notice, StravaNotice.connectFailed);
        expect(cubit.state.noticeFailure, isNull);
        expect(cubit.state.isConnected, isFalse);
        expect(cubit.state.isConnecting, isFalse);
        final fail = analytics.events.last;
        expect(fail.eventName, 'IntegrationsView_StravaConnect_Fail');
        expect(fail.type, LogType.severe);
        await cubit.close();
      },
    );

    test('a grant without upload permission says what to allow', () async {
      final cubit = build(authorizer: FakeStravaAuthorizer(scope: 'read'));
      await cubit.userChanged(_uid);

      await cubit.connect();

      expect(cubit.state.notice, StravaNotice.connectFailed);
      expect(cubit.state.noticeFailure, StravaFailure.missingUploadPermission);
      expect(cubit.state.isConnected, isFalse);
      await cubit.close();
    });

    test('cancelling the Strava sign in says nothing', () async {
      final cubit = build(authorizer: _CancellingAuthorizer());
      await cubit.userChanged(_uid);

      await cubit.connect();

      expect(cubit.state.notice, isNull);
      expect(cubit.state.isConnected, isFalse);
      expect(cubit.state.isConnecting, isFalse);
      expect(analytics.names.last, 'IntegrationsView_StravaConnect_Cancelled');
      await cubit.close();
    });

    test('disconnecting drops the connection and its activities', () async {
      final cubit = build(connectedAs: FakeStravaApi.stagingAthlete);
      await cubit.userChanged(_uid);
      await pumpEventQueue();
      expect(cubit.state.activities, hasLength(2));

      await cubit.disconnect();
      await pumpEventQueue();

      expect(cubit.state.isConnected, isFalse);
      expect(cubit.state.isDisconnecting, isFalse);
      expect(cubit.state.activities, isEmpty);
      expect(analytics.names, ['IntegrationsView_StravaDisconnect']);
      await cubit.close();
    });

    test('a failed disconnect is reported and stays connected', () async {
      final cubit = build(connectedAs: FakeStravaApi.stagingAthlete);
      await cubit.userChanged(_uid);
      api.disconnectError = const StravaException(StravaFailure.unavailable);

      await cubit.disconnect();

      expect(cubit.state.notice, StravaNotice.disconnectFailed);
      expect(cubit.state.isConnected, isTrue);
      expect(cubit.state.isDisconnecting, isFalse);
      expect(analytics.names.last, 'IntegrationsView_StravaDisconnect_Fail');
      await cubit.close();
    });

    test('both test upload outcomes are reported', () async {
      final cubit = build(connectedAs: FakeStravaApi.stagingAthlete);
      await cubit.userChanged(_uid);

      await cubit.testUpload();
      expect(cubit.state.notice, StravaNotice.testUploadSent);
      expect(cubit.state.isTestingUpload, isFalse);
      expect(api.uploads.single.name, 'Compound Test Upload');

      api.uploadError = const StravaException(StravaFailure.rateLimited);
      await cubit.testUpload();
      expect(cubit.state.notice, StravaNotice.testUploadFailed);
      expect(cubit.state.noticeFailure, StravaFailure.rateLimited);
      expect(cubit.state.isTestingUpload, isFalse);
      expect(analytics.names, [
        'IntegrationsView_StravaTestUpload_Start',
        'IntegrationsView_StravaTestUpload_Success',
        'IntegrationsView_StravaTestUpload_Start',
        'IntegrationsView_StravaTestUpload_Fail',
      ]);
      await cubit.close();
    });

    test('connecting from the offer queues the workouts at once', () async {
      final cubit = build(workouts: [_workout('a', 1)]);
      await cubit.userChanged(_uid);

      await cubit.connect(fromOffer: true);
      await pumpEventQueue();

      expect(cubit.state.isConnected, isTrue);
      expect(cubit.state.notice, isNull);
      expect(api.uploads, hasLength(1));
      // The offer has its own events (`strava_offer_*`).
      expect(analytics.names, isEmpty);
      await cubit.close();
    });

    test('a failed connection from the offer is still reported', () async {
      final cubit = build();
      await cubit.userChanged(_uid);
      api.connectError = Exception('offline');

      await cubit.connect(fromOffer: true);

      expect(cubit.state.notice, StravaNotice.connectFailed);
      expect(analytics.names, isEmpty);
      await cubit.close();
    });

    test('signing out forgets the account here', () async {
      final cubit = build(connectedAs: FakeStravaApi.stagingAthlete);
      await cubit.userChanged(_uid);
      expect(cubit.state.isConnected, isTrue);

      await cubit.userChanged(null);

      expect(cubit.state, const StravaState(available: true));
      await cubit.close();
    });
  });
}
