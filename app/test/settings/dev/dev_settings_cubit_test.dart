import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/settings/dev/dev_settings_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

class _MockSessions extends Mock implements WorkoutSessionRepository;

class _MockPurchases extends Mock implements PurchasesRepository;

// DevToolsPresenterTests, for what Flutter has: the session lookup, forcing
// a fresh user, the parameter dumps and the lifecycle; and Simulate
// Premium. The seeding and A/B test cases have nothing to port.
void main() {
  const uid = 'uid';
  late AnalyticsRecorder analytics;
  late _MockAuthRepository auth;
  late _MockSessions sessions;
  final session = fixtureSession('session-1', author: uid);

  setUp(() {
    analytics = AnalyticsRecorder();
    auth = _MockAuthRepository();
    sessions = _MockSessions();
  });

  DevSettingsCubit build({
    PurchasesRepository? purchases,
    TrainingLibraryRepository? library,
  }) => DevSettingsCubit(
    auth: auth,
    purchases: purchases ?? FakePurchasesRepository(),
    sessions: sessions,
    library: library ?? InMemoryTrainingLibraryRepository(),
    analytics: analytics,
    uid: uid,
  );

  group('fetching a session', () {
    blocTest<DevSettingsCubit, DevSettingsState>(
      'by id shows what came back',
      setUp: () =>
          when(() => sessions.session(uid, 'session-1'))
              .thenAnswer((_) async => session),
      build: build,
      act: (cubit) => cubit.fetchSession(' session-1 '),
      expect: () => [
        const DevSettingsState(simulatePremium: true, isFetchingSession: true),
        DevSettingsState(simulatePremium: true, fetchedSession: session),
      ],
    );

    blocTest<DevSettingsCubit, DevSettingsState>(
      'a failed lookup shows the reason, not an empty result',
      setUp: () =>
          when(() => sessions.session(uid, 'x'))
              .thenThrow(StateError('offline')),
      build: build,
      act: (cubit) => cubit.fetchSession('x'),
      skip: 1,
      expect: () => [
        const DevSettingsState(
          simulatePremium: true,
          fetchError: 'Bad state: offline',
        ),
      ],
      verify: (_) =>
          expect(analytics.names, ['DevSettingsView_FetchSession_Fail']),
    );

    blocTest<DevSettingsCubit, DevSettingsState>(
      'a second lookup does not keep the first result',
      setUp: () {
        when(() => sessions.session(uid, 'session-1'))
            .thenAnswer((_) async => session);
        when(() => sessions.session(uid, 'gone')).thenAnswer((_) async => null);
      },
      build: build,
      act: (cubit) async {
        await cubit.fetchSession('session-1');
        await cubit.fetchSession('gone');
      },
      skip: 2,
      expect: () => [
        const DevSettingsState(simulatePremium: true, isFetchingSession: true),
        const DevSettingsState(
          simulatePremium: true,
          fetchError: DevSettingsState.notFound,
        ),
      ],
    );
  });

  group('forcing a fresh user', () {
    test('signs out', () async {
      when(auth.signOut).thenAnswer((_) async {});
      expect(await build().signOutPressed(), isTrue);
      expect(analytics.names, [
        'DevSettingsView_ForceSignOut_Start',
        'DevSettingsView_ForceSignOut_Success',
      ]);
    });

    test('a failed sign out says so', () async {
      when(auth.signOut).thenThrow(const AuthFailure('offline'));
      expect(await build().signOutPressed(), isFalse);
      expect(analytics.names, [
        'DevSettingsView_ForceSignOut_Start',
        'DevSettingsView_ForceSignOut_Fail',
      ]);
    });
  });

  test('the parameter dumps are sorted and empty when absent', () {
    expect(devAuthParameters(null), isEmpty);
    expect(devUserParameters(null), isEmpty);
    expect(
      devAuthParameters(
        const AuthUser(
          uid: uid,
          isAnonymous: false,
          email: 'ada@example.com',
          providers: {SignInProvider.google},
        ),
      ),
      [
        ('uauth_email', 'ada@example.com'),
        ('uauth_is_anonymous', 'false'),
        ('uauth_providers', 'google'),
        ('uauth_user_id', uid),
      ],
    );
    expect(
      devUserParameters(
        const UserModel(userId: uid, isAnonymous: true, email: 'a@b.c'),
      ),
      [
        ('did_complete_onboarding', 'false'),
        ('email', 'a@b.c'),
        ('is_anonymous', 'true'),
        ('user_id', uid),
      ],
    );
  });

  group('Simulate Premium', () {
    test('follows the simulated store, and switches it', () {
      final purchases = FakePurchasesRepository(premium: false);
      final cubit = build(purchases: purchases);
      expect(cubit.state.simulatePremium, isFalse);
      cubit.simulatePremiumChanged(value: true);
      expect(purchases.premium, isTrue);
      expect(cubit.state.simulatePremium, isTrue);
    });

    test('is not offered over a real store', () {
      final cubit = build(purchases: _MockPurchases())
        ..simulatePremiumChanged(value: true);
      expect(cubit.state.simulatePremium, isNull);
    });
  });

  test('tracks its own lifecycle and counts the library', () async {
    final library = InMemoryTrainingLibraryRepository(
      workoutTemplates: [
        WorkoutTemplateModel(
          workoutId: 'template-1',
          authorId: uid,
          name: 'Push',
          dateCreated: session.dateCreated,
          dateModified: session.dateCreated,
          exercises: const [],
        ),
      ],
    );
    final cubit = build(library: library)..appeared();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.userWorkoutTemplates, 1);
    expect(cubit.state.userExercises, 0);
    cubit.disappeared();
    await cubit.close();
    expect(analytics.names, [
      'DevSettingsView_Appear',
      'DevSettingsView_Disappear',
    ]);
  });
}
