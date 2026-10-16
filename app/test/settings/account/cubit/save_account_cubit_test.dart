import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/settings/account/cubit/save_account_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../../helpers/helpers.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

class _MockUserRepository extends Mock implements UserRepository;

// SettingsPresenterTests' "saving an anonymous account opens sign in", with
// AuthPresenter's events, and the profile update Swift lacks.
void main() {
  const anonymous = InMemoryAuthRepository.anonymousUser;
  late AnalyticsRecorder analytics;
  late InMemoryAuthRepository auth;
  late InMemoryUserRepository users;

  setUpAll(() => registerFallbackValue(<UserFieldValue>[]));

  setUp(() {
    analytics = AnalyticsRecorder();
    auth = InMemoryAuthRepository(user: anonymous);
    users = InMemoryUserRepository(
      users: {
        anonymous.uid: UserModel(userId: anonymous.uid, isAnonymous: true),
      },
    );
  });

  SaveAccountCubit build({AuthRepository? authRepository}) => SaveAccountCubit(
    auth: authRepository ?? auth,
    users: users,
    analytics: analytics,
  );

  blocTest<SaveAccountCubit, SaveAccountStatus>(
    'linking Google keeps the account and tells the profile, field by field',
    build: build,
    act: (cubit) => cubit.googlePressed(),
    expect: () => [SaveAccountStatus.inProgress, SaveAccountStatus.saved],
    verify: (_) async {
      expect(auth.currentUser?.uid, anonymous.uid);
      final profile = await users.watchUser(anonymous.uid).first;
      expect(profile?.isAnonymous, isFalse);
      expect(profile?.email, InMemoryAuthRepository.sampleUser.email);
      expect(profile?.authProviders, ['google']);
      expect(analytics.names, [
        'Auth_GoogleAuth_Start',
        'Auth_GoogleAuth_Success',
      ]);
    },
  );

  blocTest<SaveAccountCubit, SaveAccountStatus>(
    'linking Apple records "apple"',
    build: build,
    act: (cubit) => cubit.applePressed(),
    expect: () => [SaveAccountStatus.inProgress, SaveAccountStatus.saved],
    verify: (_) async {
      final profile = await users.watchUser(anonymous.uid).first;
      expect(profile?.authProviders, ['apple']);
      expect(analytics.names, [
        'Auth_AppleAuth_Start',
        'Auth_AppleAuth_Success',
      ]);
    },
  );

  group('with a mocked sign-in', () {
    late _MockAuthRepository mockAuth;

    setUp(() {
      mockAuth = _MockAuthRepository();
      when(() => mockAuth.currentUser).thenReturn(anonymous);
    });

    blocTest<SaveAccountCubit, SaveAccountStatus>(
      'a cancelled sheet changes nothing',
      setUp: () =>
          when(mockAuth.signInWithGoogle).thenThrow(const SignInCancelled()),
      build: () => build(authRepository: mockAuth),
      act: (cubit) => cubit.googlePressed(),
      expect: () => [SaveAccountStatus.inProgress, SaveAccountStatus.idle],
      verify: (_) => expect(analytics.names, ['Auth_GoogleAuth_Start']),
    );

    blocTest<SaveAccountCubit, SaveAccountStatus>(
      'a failure says so and leaves the account anonymous',
      setUp: () =>
          when(mockAuth.signInWithApple)
              .thenThrow(const AuthFailure('offline')),
      build: () => build(authRepository: mockAuth),
      act: (cubit) => cubit.applePressed(),
      expect: () => [SaveAccountStatus.inProgress, SaveAccountStatus.failure],
      verify: (_) async {
        expect(analytics.names, [
          'Auth_AppleAuth_Start',
          'Auth_AppleAuth_Fail',
        ]);
        final profile = await users.watchUser(anonymous.uid).first;
        expect(profile?.isAnonymous, isTrue);
      },
    );

    blocTest<SaveAccountCubit, SaveAccountStatus>(
      'Google already on another account signs in to that one, and writes '
      'nothing to it',
      setUp: () {
        var signedIn = false;
        when(() => mockAuth.currentUser).thenAnswer(
          (_) => signedIn ? InMemoryAuthRepository.sampleUser : anonymous,
        );
        when(mockAuth.signInWithGoogle)
            .thenAnswer((_) async => signedIn = true);
      },
      build: () => build(authRepository: mockAuth),
      act: (cubit) => cubit.googlePressed(),
      expect: () => [SaveAccountStatus.inProgress, SaveAccountStatus.saved],
      verify: (_) async {
        final profile = await users.watchUser(anonymous.uid).first;
        expect(profile?.isAnonymous, isTrue);
        expect(
          await users.watchUser(InMemoryAuthRepository.sampleUser.uid).first,
          isNull,
        );
      },
    );

    blocTest<SaveAccountCubit, SaveAccountStatus>(
      'a second press while linking does nothing',
      setUp: () => when(mockAuth.signInWithGoogle).thenAnswer((_) async {}),
      build: () => build(authRepository: mockAuth),
      seed: () => SaveAccountStatus.inProgress,
      act: (cubit) => cubit.googlePressed(),
      expect: () => <SaveAccountStatus>[],
      verify: (_) => verifyNever(mockAuth.signInWithGoogle),
    );
  });

  blocTest<SaveAccountCubit, SaveAccountStatus>(
    'a profile update that fails still counts as saved',
    build: () {
      final failing = _MockUserRepository();
      when(() => failing.updateUserFields(any(), any()))
          .thenThrow(StateError('offline'));
      return SaveAccountCubit(auth: auth, users: failing, analytics: analytics);
    },
    act: (cubit) => cubit.googlePressed(),
    expect: () => [SaveAccountStatus.inProgress, SaveAccountStatus.saved],
    verify: (_) => expect(analytics.names.last, 'Auth_UserLogin_Fail'),
  );

  test('tracks its screen as AuthView', () {
    build()
      ..appeared()
      ..disappeared();
    expect(analytics.names, ['AuthView_Appear', 'AuthView_Disappear']);
  });
}
