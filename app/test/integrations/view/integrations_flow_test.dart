import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/profile/profile.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:health_repository/health_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

/// The integrations end to end on the staging flavor's in-memory data, as
/// `main_staging.dart` wires them: connect Strava (fake), see the imported
/// activities on your own profile, disconnect; connect Health (fake) from
/// Today, and log a weigh-in that goes to Health.
void main() {
  final now = DateTime.now();
  // Mid-year, so "Strava This Year" holds them whatever today is.
  final activities = sampleStravaActivities(DateTime(now.year, 6, 15));

  late InMemoryUserRepository users;
  late InMemoryWorkoutSessionRepository sessions;
  late InMemoryBodyRepository body;
  late InMemoryNutritionRepository nutrition;
  late InMemoryTrainingLibraryRepository library;
  late FakeHealthPlatform health;
  late LinkRecorder links;

  Widget app() {
    final firestore = FakeFirebaseFirestore();
    return App(
      socialRepository: emptySocialRepository(),
      coachRepository: silentCoachRepository(),
      purchasesRepository: FakePurchasesRepository(),
      programRepository: InMemoryProgramRepository(),
      trainingLibraryRepository: library,
      authRepository: InMemoryAuthRepository(
        user: InMemoryAuthRepository.sampleUser,
      ),
      userRepository: users,
      workoutSessionRepository: sessions,
      nutritionRepository: nutrition,
      bodyRepository: body,
      healthRepository: HealthRepository(
        platform: health,
        body: body,
        nutrition: nutrition,
      ),
      stravaRepository: StravaRepository(
        firestore: firestore,
        api: FakeStravaApi(
          firestore: firestore,
          uid: sampleUserId,
          activities: activities,
        ),
        sessions: sessions,
        store: InMemoryStravaAccountStore(),
        clientId: 'staging',
        uploadContext: stravaUploadContext(users: users, library: library),
        pollInterval: Duration.zero,
      ),
      stravaAuthorizer: FakeStravaAuthorizer(),
      linkOpener: links,
    );
  }

  setUp(() {
    users = InMemoryUserRepository(
      users: {sampleUserId: sampleUser(now: now)},
      settings: {sampleUserId: sampleUserSettings(now: now)},
    );
    sessions = InMemoryWorkoutSessionRepository(
      sessions: sampleWorkoutSessions(uid: sampleUserId, now: now),
    );
    body = InMemoryBodyRepository();
    nutrition = InMemoryNutritionRepository();
    library = InMemoryTrainingLibraryRepository();
    health = sampleHealthPlatform(now);
    links = LinkRecorder();
  });

  /// Lets the fakes' futures and streams run, then draws.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
  }

  void go(WidgetTester tester, String location) =>
      GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);

  testWidgets('connects Strava, shows its activities on your own profile, '
      'then disconnects', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    go(tester, '/profile/settings/integrations');
    await settle(tester);
    expect(find.text('Not connected'), findsOneWidget);

    await tester.tap(find.text('Connect'));
    await settle(tester);
    expect(find.text('Connected as Alex Runner'), findsOneWidget);
    // The sample workouts are offered; not now.
    await tester.tap(find.text('Not Now'));
    await settle(tester);
    expect(find.text('Upload Past Workouts'), findsOneWidget);

    // Your own profile shows the year's runs and rides.
    go(tester, '/today');
    await settle(tester);
    await tester.tap(find.byType(ProfileButton));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Strava This Year'), 200);
    await settle(tester);
    expect(find.text('Morning Run'), findsOneWidget);
    expect(find.text('Evening Ride'), findsOneWidget);
    await tester.tap(find.text('Morning Run'));
    expect(links.opened, [Uri.parse('https://www.strava.com/activities/1001')]);

    go(tester, '/profile/settings/integrations');
    await settle(tester);
    await tester.tap(find.text('Disconnect Strava'));
    await settle(tester);
    await tester.tap(find.text('Disconnect'));
    await settle(tester);
    expect(find.text('Not connected'), findsOneWidget);
  });

  testWidgets('connects Health from Today, and a weigh-in goes to Health', (
    tester,
  ) async {
    // Nothing imported yet: as a phone that has never been asked.
    health.steps.clear();
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('Connect Apple Health'), findsNothing);
    // Android words on the test's platform.
    expect(find.text('Connect Health Connect'), findsOneWidget);
    expect(find.text('Connect Strava'), findsOneWidget);

    health.steps.add((date: now, steps: 4321));
    await tester.tap(find.text('Connect Health Connect'));
    await settle(tester);
    expect(health.requested, contains(HealthScope.steps));
    expect(find.text('Connect Health Connect'), findsNothing);
    expect(await tester.runAsync(() => body.watchSteps(sampleUserId).first), [
      isA<StepsModel>().having((s) => s.number, 'number', 4321),
    ]);

    go(tester, '/log-weight');
    await settle(tester);
    await tester.tap(find.byTooltip('Save'));
    await settle(tester);
    expect(health.writtenWeights, hasLength(1));
  });
}
