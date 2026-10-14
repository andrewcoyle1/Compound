import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository;

void main() {
  const user = AuthUser(uid: 'uid', isAnonymous: false, email: 'a@b.com');
  late AuthRepository authRepository;
  late AnalyticsRepository analyticsRepository;

  setUpAll(() => registerFallbackValue(const AnalyticsEvent('')));

  setUp(() {
    authRepository = MockAuthRepository();
    analyticsRepository = _MockAnalyticsRepository();
    when(() => authRepository.currentUser).thenReturn(null);
    when(() => authRepository.user).thenAnswer((_) => const Stream.empty());
  });

  group(AppBloc, () {
    test('starts from the current user', () {
      expect(
        AppBloc(authRepository: authRepository).state,
        const AppUnauthenticated(),
      );
      when(() => authRepository.currentUser).thenReturn(user);
      expect(
        AppBloc(authRepository: authRepository).state,
        const AppAuthenticated(user),
      );
    });

    blocTest<AppBloc, AppState>(
      'follows the signed-in user',
      setUp: () =>
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.fromIterable([user, null])),
      build: () => AppBloc(authRepository: authRepository),
      act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
      expect: () => const [AppAuthenticated(user), AppUnauthenticated()],
    );

    blocTest<AppBloc, AppState>(
      'tells analytics who is signed in, as the Swift auth listener does',
      setUp: () =>
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.fromIterable([user, null])),
      build: () => AppBloc(
        authRepository: authRepository,
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
      build: () => AppBloc(authRepository: authRepository),
      act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
      expect: () => const <AppState>[],
      errors: () => [streamError],
    );

    blocTest<AppBloc, AppState>(
      'signs out',
      setUp: () => when(authRepository.signOut).thenAnswer((_) async {}),
      build: () => AppBloc(authRepository: authRepository),
      act: (bloc) => bloc.add(const AppSignOutPressed()),
      verify: (_) => verify(authRepository.signOut).called(1),
    );

    blocTest<AppBloc, AppState>(
      'reports a failed sign-out',
      setUp: () => when(authRepository.signOut).thenThrow(const AuthFailure()),
      build: () => AppBloc(authRepository: authRepository),
      act: (bloc) => bloc.add(const AppSignOutPressed()),
      errors: () => [isA<AuthFailure>()],
    );
  });
}
