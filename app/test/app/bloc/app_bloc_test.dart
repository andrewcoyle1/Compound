import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  const user = AuthUser(uid: 'uid', isAnonymous: false, email: 'a@b.com');
  late AuthRepository authRepository;

  setUp(() {
    authRepository = MockAuthRepository();
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
