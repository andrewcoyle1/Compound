import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  late AuthRepository authRepository;

  setUp(() => authRepository = MockAuthRepository());

  group(SignInCubit, () {
    test('starts idle', () {
      expect(
        SignInCubit(authRepository: authRepository).state,
        SignInStatus.idle,
      );
    });

    final methods = <String, Future<void> Function(AuthRepository)>{
      'Google': (repository) => repository.signInWithGoogle(),
      'Apple': (repository) => repository.signInWithApple(),
      'anonymously': (repository) => repository.signInAnonymously(),
    };
    final calls = <String, Future<void> Function(SignInCubit)>{
      'Google': (cubit) => cubit.signInWithGoogle(),
      'Apple': (cubit) => cubit.signInWithApple(),
      'anonymously': (cubit) => cubit.signInAnonymously(),
    };

    for (final MapEntry(key: name, value: method) in methods.entries) {
      group('signs in with $name', () {
        blocTest<SignInCubit, SignInStatus>(
          'and returns to idle',
          setUp: () =>
              when(() => method(authRepository)).thenAnswer((_) async {}),
          build: () => SignInCubit(authRepository: authRepository),
          act: (cubit) => calls[name]!(cubit),
          expect: () => [SignInStatus.inProgress, SignInStatus.idle],
          verify: (_) => verify(() => method(authRepository)).called(1),
        );

        blocTest<SignInCubit, SignInStatus>(
          'and returns to idle when cancelled',
          setUp: () =>
              when(() => method(authRepository))
                  .thenThrow(const SignInCancelled()),
          build: () => SignInCubit(authRepository: authRepository),
          act: (cubit) => calls[name]!(cubit),
          expect: () => [SignInStatus.inProgress, SignInStatus.idle],
        );

        blocTest<SignInCubit, SignInStatus>(
          'and reports a failure',
          setUp: () =>
              when(() => method(authRepository)).thenThrow(const AuthFailure()),
          build: () => SignInCubit(authRepository: authRepository),
          act: (cubit) => calls[name]!(cubit),
          expect: () => [SignInStatus.inProgress, SignInStatus.failure],
          errors: () => [isA<AuthFailure>()],
        );
      });
    }
  });
}
