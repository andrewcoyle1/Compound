import 'package:compound/integrations/integrations.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show PrebuiltCatalogue;
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

const _uid = 'user-1';

void main() {
  late AnalyticsRecorder analytics;

  Future<StravaCubit> cubit({
    StravaAthlete? connectedAs,
    List<WorkoutSessionModel> sessions = const [],
  }) async {
    final firestore = FakeFirebaseFirestore();
    final cubit = StravaCubit(
      strava: StravaRepository(
        firestore: firestore,
        api: FakeStravaApi(
          firestore: firestore,
          uid: _uid,
          athlete: connectedAs,
          activities: sampleStravaActivities(DateTime.now()),
        ),
        sessions: InMemoryWorkoutSessionRepository(sessions: sessions),
        store: InMemoryStravaAccountStore(),
        clientId: 'client',
        uploadContext: (_) async => (
          library: PrebuiltCatalogue.instance.exercises,
          weightUnit: WeightUnitPreference.kilograms,
          distanceUnit: DistanceUnitPreference.kilometers,
        ),
        pollInterval: Duration.zero,
      ),
      authorizer: FakeStravaAuthorizer(),
      analytics: analytics,
    );
    await cubit.userChanged(_uid);
    return cubit;
  }

  setUp(() => analytics = AnalyticsRecorder());

  group(IntegrationsPage, () {
    testWidgets('a build without Strava says so and offers nothing', (
      tester,
    ) async {
      await tester.pumpApp(const IntegrationsPage());
      await tester.pumpAndSettle();
      expect(find.text('STRAVA'), findsOneWidget);
      expect(find.text('Not available in this build'), findsOneWidget);
      expect(find.text('Connect'), findsNothing);
    });

    testWidgets('connects, then offers the past workouts', (tester) async {
      final strava = await tester.runAsync(
        () => cubit(
          sessions: sampleWorkoutSessions(uid: _uid, now: DateTime.now()),
        ),
      );
      await tester.pumpApp(
        const IntegrationsPage(),
        stravaCubit: strava,
        analyticsRepository: analytics,
      );
      await tester.pumpAndSettle();
      expect(find.text('Not connected'), findsOneWidget);

      await tester.tap(find.text('Connect'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Connected as Alex Runner'), findsOneWidget);
      expect(find.textContaining('past workouts to Strava?'), findsOneWidget);
      await tester.tap(find.text('Upload Past Workouts').last);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.textContaining('queued for Strava'), findsOneWidget);
      expect(analytics.names, contains('IntegrationsView_StravaBackfill'));
      expect(analytics.names.first, 'IntegrationsView_Appear');
    });

    testWidgets('disconnecting asks first', (tester) async {
      final strava = await tester.runAsync(
        () => cubit(connectedAs: FakeStravaApi.stagingAthlete),
      );
      await tester.pumpApp(const IntegrationsPage(), stravaCubit: strava);
      await tester.pumpAndSettle();
      expect(find.text('Connected as Alex Runner'), findsOneWidget);
      expect(find.text('Test Upload'), findsNWidgets(2));

      await tester.tap(find.text('Disconnect Strava'));
      await tester.pumpAndSettle();
      expect(find.text('Disconnect Strava?'), findsOneWidget);
      await tester.tap(find.text('Disconnect'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Not connected'), findsOneWidget);
    });

    testWidgets('a test upload says it was sent', (tester) async {
      final strava = await tester.runAsync(
        () => cubit(connectedAs: FakeStravaApi.stagingAthlete),
      );
      await tester.pumpApp(const IntegrationsPage(), stravaCubit: strava);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Upload').last);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Test upload sent to Strava'), findsOneWidget);
    });
  });

  group('showStravaNotice', () {
    testWidgets('a refused connection and a failed disconnect alert', (
      tester,
    ) async {
      final strava = StravaCubit(
        strava: null,
        authorizer: FakeStravaAuthorizer(),
        analytics: analytics,
      );
      await tester.pumpApp(const IntegrationsPage(), stravaCubit: strava);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(IntegrationsView));

      for (final (state, title, message) in [
        (
          const StravaState().telling(
            StravaNotice.connectFailed,
            failure: StravaFailure.missingUploadPermission,
          ),
          'Unable to Connect Strava',
          'Allow Compound to upload your activities to connect Strava.',
        ),
        (
          const StravaState().telling(StravaNotice.disconnectFailed),
          'Unable to Disconnect Strava',
          'Check your internet connection and try again.',
        ),
        (
          const StravaState().telling(
            StravaNotice.testUploadFailed,
            failure: StravaFailure.rateLimited,
          ),
          'Upload Failed',
          'Strava is busy. Your workouts will upload later.',
        ),
      ]) {
        showStravaNotice(context, state);
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
    });
  });
}
