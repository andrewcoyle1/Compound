import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/app/app.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound_models/compound_models.dart' show UserModelKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository;

void main() {
  const user = AuthUser(uid: 'uid', isAnonymous: false, email: 'a@b.com');
  final now = DateTime.utc(2026, 10, 15, 9);
  const profile = UserModel(userId: 'uid');
  late AuthRepository authRepository;
  late UserRepository userRepository;
  late AnalyticsRepository analyticsRepository;

  setUpAll(() {
    registerFallbackValue(const AnalyticsEvent(''));
    registerFallbackValue(const UserModel(userId: ''));
  });

  setUp(() {
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    analyticsRepository = _MockAnalyticsRepository();
    when(() => authRepository.currentUser).thenReturn(null);
    when(() => authRepository.user).thenAnswer((_) => const Stream.empty());
    when(() => userRepository.watchUser(any()))
        .thenAnswer((_) => Stream.value(profile));
  });

  AppBloc build() => AppBloc(
    authRepository: authRepository,
    userRepository: userRepository,
    now: () => now,
  );

  AppAuthenticated ready(AuthUser user) => AppAuthenticated(
    user,
    profile: profile,
    profileStatus: AppProfileStatus.ready,
  );

  group(AppBloc, () {
    test('starts from the current user', () {
      expect(build().state, const AppUnauthenticated());
      when(() => authRepository.currentUser).thenReturn(user);
      expect(build().state, const AppAuthenticated(user));
    });

    blocTest<AppBloc, AppState>(
      'follows the signed-in user',
      setUp: () =>
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.fromIterable([user, null])),
      build: build,
      act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
      expect: () => const [AppAuthenticated(user), AppUnauthenticated()],
    );

    blocTest<AppBloc, AppState>(
      'emits the profile once it is read, writing nothing',
      setUp: () =>
          when(() => authRepository.user).thenAnswer((_) => Stream.value(user)),
      build: build,
      act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
      expect: () => [const AppAuthenticated(user), ready(user)],
      verify: (_) => verifyNever(() => userRepository.createUser(any())),
    );

    group('a missing profile', () {
      late StreamController<UserModel?> profiles;

      setUp(() {
        profiles = StreamController<UserModel?>();
        when(() => authRepository.user).thenAnswer((_) => Stream.value(user));
        when(() => userRepository.watchUser('uid'))
            .thenAnswer((_) => profiles.stream);
      });

      tearDown(() => profiles.close());

      Future<void> subscribeThenRead(
        AppBloc bloc,
        List<UserModel?> reads,
      ) async {
        bloc.add(const AppUserSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        for (final read in reads) {
          profiles.add(read);
          await Future<void>.delayed(Duration.zero);
        }
      }

      blocTest<AppBloc, AppState>(
        'is created from the account when the server has none, as '
        'UserManager.signIn does for a new user',
        setUp: () {
          when(() => userRepository.userExists('uid'))
              .thenAnswer((_) async => false);
          when(() => userRepository.createUser(any())).thenAnswer((_) async {
            profiles.add(profile);
          });
        },
        build: build,
        act: (bloc) => subscribeThenRead(bloc, [null]),
        expect: () => [const AppAuthenticated(user), ready(user)],
        verify: (_) {
          final created =
              verify(() => userRepository.createUser(captureAny()))
                      .captured
                      .single
                  as UserModel;
          expect(created.toFirestore(), {
            UserModelKeys.userId: 'uid',
            UserModelKeys.email: 'a@b.com',
            UserModelKeys.isAnonymous: false,
            UserModelKeys.creationDate: now,
            UserModelKeys.lastSignInDate: now,
            UserModelKeys.didCompleteOnboarding: false,
          });
        },
      );

      blocTest<AppBloc, AppState>(
        'is created once, however many empty reads arrive meanwhile',
        setUp: () {
          final exists = Completer<bool>();
          when(() => userRepository.userExists('uid'))
              .thenAnswer((_) => exists.future);
          when(() => userRepository.createUser(any())).thenAnswer((_) async {});
          unawaited(
            Future<void>.delayed(const Duration(milliseconds: 10))
                .then((_) => exists.complete(false)),
          );
        },
        build: build,
        act: (bloc) async {
          await subscribeThenRead(bloc, [null, null]);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        },
        verify: (_) => verify(() => userRepository.createUser(any())).called(1),
      );

      blocTest<AppBloc, AppState>(
        'is never written over when the server has one that does not decode',
        setUp: () =>
            when(() => userRepository.userExists('uid'))
                .thenAnswer((_) async => true),
        build: build,
        act: (bloc) => subscribeThenRead(bloc, [null]),
        expect: () => const [
          AppAuthenticated(user),
          AppAuthenticated(user, profileStatus: AppProfileStatus.failure),
        ],
        verify: (_) => verifyNever(() => userRepository.createUser(any())),
      );

      final offline = Exception('offline');
      blocTest<AppBloc, AppState>(
        'fails, writing nothing, when the server cannot be asked',
        setUp: () =>
            when(() => userRepository.userExists('uid')).thenThrow(offline),
        build: build,
        act: (bloc) => subscribeThenRead(bloc, [null]),
        expect: () => const [
          AppAuthenticated(user),
          AppAuthenticated(user, profileStatus: AppProfileStatus.failure),
        ],
        errors: () => [offline],
        verify: (_) => verifyNever(() => userRepository.createUser(any())),
      );

      blocTest<AppBloc, AppState>(
        'that was read before is never recreated',
        build: build,
        act: (bloc) => subscribeThenRead(bloc, [profile, null]),
        expect: () => [
          const AppAuthenticated(user),
          ready(user),
          const AppAuthenticated(user, profileStatus: AppProfileStatus.failure),
        ],
        verify: (_) {
          verifyNever(() => userRepository.userExists(any()));
          verifyNever(() => userRepository.createUser(any()));
        },
      );
    });

    final readError = Exception('read');
    blocTest<AppBloc, AppState>(
      'fails when the profile stream fails, and reads again on retry',
      setUp: () {
        var calls = 0;
        when(() => authRepository.user).thenAnswer((_) => Stream.value(user));
        when(() => userRepository.watchUser('uid')).thenAnswer(
          (_) => calls++ == 0 ? Stream.error(readError) : Stream.value(profile),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const AppUserSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AppProfileRetryRequested());
      },
      expect: () => [
        const AppAuthenticated(user),
        const AppAuthenticated(user, profileStatus: AppProfileStatus.failure),
        const AppAuthenticated(user),
        ready(user),
      ],
      errors: () => [readError],
    );

    blocTest<AppBloc, AppState>(
      'retry does nothing while signed out',
      build: build,
      act: (bloc) => bloc.add(const AppProfileRetryRequested()),
      expect: () => const <AppState>[],
    );

    const linked = AuthUser(uid: 'uid', isAnonymous: false, email: 'new@b.com');
    blocTest<AppBloc, AppState>(
      'keeps the profile when the same account comes again, as after linking',
      setUp: () {
        final users = StreamController<AuthUser?>();
        when(() => authRepository.user).thenAnswer((_) => users.stream);
        users.add(user);
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 5))
              .then((_) => users.add(linked)),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const AppUserSubscriptionRequested());
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      expect: () => [const AppAuthenticated(user), ready(user), ready(linked)],
      verify: (_) => verify(() => userRepository.watchUser('uid')).called(1),
    );

    blocTest<AppBloc, AppState>(
      'ignores a profile read for someone who has since signed out',
      setUp: () {
        final profiles = StreamController<UserModel?>.broadcast();
        when(() => authRepository.user)
            .thenAnswer((_) => Stream.fromIterable([user, null]));
        when(() => userRepository.watchUser('uid'))
            .thenAnswer((_) => profiles.stream);
      },
      build: build,
      act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
      expect: () => const [AppAuthenticated(user), AppUnauthenticated()],
    );

    test('onboardingStep is null until the profile is read, and once '
        'onboarding is done', () {
      expect(const AppAuthenticated(user).onboardingStep, isNull);
      expect(
        const AppAuthenticated(user, profile: profile).onboardingStep,
        OnboardingStep.completeAccountSetup,
      );
      expect(
        const AppAuthenticated(
          user,
          profile: UserModel(userId: 'uid', didCompleteOnboarding: true),
        ).onboardingStep,
        isNull,
      );
    });

    blocTest<AppBloc, AppState>(
      'tells analytics who is signed in, as the Swift auth listener does',
      setUp: () =>
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.fromIterable([user, null])),
      build: () => AppBloc(
        authRepository: authRepository,
        userRepository: userRepository,
        analyticsRepository: analyticsRepository,
      ),
      act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
      verify: (_) {
        const parameters = {
          'uauth_user_id': 'uid',
          'uauth_is_anonymous': false,
        };
        verify(
          () =>
              analyticsRepository.identifyUser(userId: 'uid', email: 'a@b.com'),
        ).called(1);
        verify(
          () => analyticsRepository.addUserProperties(
            parameters,
            isHighPriority: true,
          ),
        ).called(1);
        final events = verify(
          () => analyticsRepository.trackEvent(captureAny()),
        ).captured.cast<LoggableEvent>();
        expect(events.map((event) => event.eventName), [
          'Auth_Listener_Success',
          'Auth_Listener_Empty',
        ]);
        expect(events.first.parameters, parameters);
        expect(events.first.type, LogType.info);
        expect(events.last.parameters, isNull);
        expect(events.last.type, LogType.warning);
      },
    );

    final streamError = Exception('stream');
    blocTest<AppBloc, AppState>(
      'reports errors from the user stream',
      setUp: () =>
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.error(streamError)),
      build: build,
      act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
      expect: () => const <AppState>[],
      errors: () => [streamError],
    );

    blocTest<AppBloc, AppState>(
      'signs out',
      setUp: () => when(authRepository.signOut).thenAnswer((_) async {}),
      build: build,
      act: (bloc) => bloc.add(const AppSignOutPressed()),
      verify: (_) => verify(authRepository.signOut).called(1),
    );

    blocTest<AppBloc, AppState>(
      'reports a failed sign-out',
      setUp: () => when(authRepository.signOut).thenThrow(const AuthFailure()),
      build: build,
      act: (bloc) => bloc.add(const AppSignOutPressed()),
      errors: () => [isA<AuthFailure>()],
    );
  });
}
