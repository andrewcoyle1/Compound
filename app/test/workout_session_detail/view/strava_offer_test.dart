import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

/// The summary of a first workout offers Strava once (Swift `StravaOffer`
/// over `WorkoutSessionDetailView`).
void main() {
  const uid = 'friend';

  testWidgets('offers Strava over the first summary, and connects', (
    tester,
  ) async {
    final appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
    final users = InMemoryUserRepository(
      users: {uid: const UserModel(userId: uid)},
    );
    final finished = fixtureSession('s');
    final sessions = InMemoryWorkoutSessionRepository(sessions: [finished]);
    final firestore = FakeFirebaseFirestore();
    final api = FakeStravaApi(firestore: firestore, uid: uid);
    final strava = StravaRepository(
      firestore: firestore,
      api: api,
      sessions: sessions,
      store: InMemoryStravaAccountStore(),
      clientId: 'client',
      uploadContext: (_) async => (
        library: const <ExerciseModel>[],
        weightUnit: WeightUnitPreference.kilograms,
        distanceUnit: DistanceUnitPreference.kilometers,
      ),
      pollInterval: Duration.zero,
    );
    final analytics = AnalyticsRecorder();
    final cubit = StravaCubit(
      strava: strava,
      authorizer: FakeStravaAuthorizer(),
      analytics: analytics,
    );
    await tester.runAsync(() => cubit.userChanged(uid));

    await tester.pumpApp(
      WorkoutSessionDetailPage(
        sessionId: 's',
        session: finished,
        isWorkoutSummary: true,
      ),
      appBloc: appBloc,
      userRepository: users,
      workoutSessionRepository: sessions,
      stravaRepository: strava,
      stravaCubit: cubit,
      analyticsRepository: analytics,
    );
    await tester.pumpAndSettle();

    expect(find.text('Upload Workouts to Strava?'), findsOneWidget);
    await tester.tap(find.text('Connect Strava'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(strava.offerAnswered, isTrue);
    expect(cubit.state.isConnected, isTrue);
    expect(analytics.names, contains('strava_offer_accepted'));
  });
}
