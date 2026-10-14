import 'package:auth_repository/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth;

class _MockUser extends Mock implements User;

class _MockUserCredential extends Mock implements UserCredential;

class _MockGoogleSignIn extends Mock implements GoogleSignIn;

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount;

void main() {
  late FirebaseAuth firebaseAuth;
  late GoogleSignIn googleSignIn;
  late User user;
  late UserCredential userCredential;
  late FirebaseAuthRepository repository;

  final hasGoogleIdToken = isA<OAuthCredential>().having(
    (credential) => credential.idToken,
    'idToken',
    'google-id-token',
  );

  setUpAll(() {
    registerFallbackValue(AppleAuthProvider());
    registerFallbackValue(GoogleAuthProvider.credential(idToken: 'fallback'));
  });

  setUp(() {
    firebaseAuth = _MockFirebaseAuth();
    googleSignIn = _MockGoogleSignIn();
    user = _MockUser();
    userCredential = _MockUserCredential();
    repository = FirebaseAuthRepository(
      firebaseAuth: firebaseAuth,
      googleSignIn: googleSignIn,
      googleClientId: 'ios-client-id',
    );

    when(() => user.uid).thenReturn('uid');
    when(() => user.isAnonymous).thenReturn(false);
    when(() => user.email).thenReturn('a@b.com');
    when(() => user.displayName).thenReturn('Ann');

    final account = _MockGoogleSignInAccount();
    when(
      () => account.authentication,
    ).thenReturn(const GoogleSignInAuthentication(idToken: 'google-id-token'));
    when(() => googleSignIn.initialize(clientId: any(named: 'clientId')))
        .thenAnswer((_) async {});
    when(googleSignIn.authenticate).thenAnswer((_) async => account);
    when(googleSignIn.signOut).thenAnswer((_) async {});

    when(() => firebaseAuth.signInWithCredential(any()))
        .thenAnswer((_) async => userCredential);
    when(() => firebaseAuth.signInWithProvider(any()))
        .thenAnswer((_) async => userCredential);
    when(firebaseAuth.signInAnonymously)
        .thenAnswer((_) async => userCredential);
    when(firebaseAuth.signOut).thenAnswer((_) async {});
  });

  const authUser = AuthUser(
    uid: 'uid',
    isAnonymous: false,
    email: 'a@b.com',
    displayName: 'Ann',
  );

  /// Makes [user] the anonymous account currently signed in.
  void signInAnonymousUser() {
    when(() => user.isAnonymous).thenReturn(true);
    when(() => firebaseAuth.currentUser).thenReturn(user);
  }

  group('user', () {
    test(
      'maps Firebase users, sign-outs and profile changes such as linking',
      () {
        when(firebaseAuth.userChanges)
            .thenAnswer((_) => Stream.fromIterable([user, null]));
        expect(repository.user, emitsInOrder([authUser, null]));
      },
    );
  });

  group('currentUser', () {
    test('is null when signed out', () {
      expect(repository.currentUser, isNull);
    });

    test('maps the Firebase user', () {
      when(() => firebaseAuth.currentUser).thenReturn(user);
      expect(repository.currentUser, authUser);
    });
  });

  group('signInWithGoogle', () {
    test('initialises Google once and signs in with its id token', () async {
      await repository.signInWithGoogle();
      await repository.signInWithGoogle();

      verify(() => googleSignIn.initialize(clientId: 'ios-client-id'))
          .called(1);
      verify(
        () => firebaseAuth.signInWithCredential(any(that: hasGoogleIdToken)),
      ).called(2);
    });

    test('signs in when the current user is not anonymous', () async {
      when(() => firebaseAuth.currentUser).thenReturn(user);
      await repository.signInWithGoogle();
      verify(
        () => firebaseAuth.signInWithCredential(any(that: hasGoogleIdToken)),
      ).called(1);
      verifyNever(() => user.linkWithCredential(any()));
    });

    test('links Google to an anonymous account', () async {
      signInAnonymousUser();
      when(() => user.linkWithCredential(any()))
          .thenAnswer((_) async => userCredential);

      await repository.signInWithGoogle();

      verify(() => user.linkWithCredential(any(that: hasGoogleIdToken)));
      verifyNever(() => firebaseAuth.signInWithCredential(any()));
    });

    test('signs in to the account that already owns the Google credential, '
        'using the credential Firebase returns', () async {
      signInAnonymousUser();
      final existing = GoogleAuthProvider.credential(idToken: 'existing');
      when(() => user.linkWithCredential(any())).thenThrow(
        FirebaseAuthException(
          code: 'credential-already-in-use',
          credential: existing,
        ),
      );

      await repository.signInWithGoogle();

      verify(() => firebaseAuth.signInWithCredential(existing)).called(1);
    });

    test('throws AuthFailure when linking fails otherwise', () async {
      signInAnonymousUser();
      when(() => user.linkWithCredential(any()))
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          isA<AuthFailure>()
              .having((f) => f.error, 'error', isA<FirebaseAuthException>())
              .having((f) => f, 'type', isNot(isA<SignInCancelled>())),
        ),
      );
    });

    test('throws SignInCancelled when the user cancels', () async {
      when(googleSignIn.authenticate).thenThrow(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );
      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<SignInCancelled>()),
      );
    });

    test('throws AuthFailure when Google fails', () async {
      when(googleSignIn.authenticate).thenThrow(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
        ),
      );
      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.error,
            'error',
            isA<GoogleSignInException>(),
          ),
        ),
      );
    });
  });

  group('signInWithApple', () {
    test('signs in with the Apple provider', () async {
      await repository.signInWithApple();
      verify(
        () => firebaseAuth.signInWithProvider(
          any(
            that: isA<AppleAuthProvider>().having((p) => p.scopes, 'scopes', [
              'email',
              'name',
            ]),
          ),
        ),
      ).called(1);
    });

    test('links Apple to an anonymous account', () async {
      signInAnonymousUser();
      when(() => user.linkWithProvider(any()))
          .thenAnswer((_) async => userCredential);

      await repository.signInWithApple();

      verify(() => user.linkWithProvider(any()));
      verifyNever(() => firebaseAuth.signInWithProvider(any()));
    });

    test('signs in again when the Apple account is taken and Firebase '
        'returns no credential', () async {
      signInAnonymousUser();
      when(() => user.linkWithProvider(any()))
          .thenThrow(FirebaseAuthException(code: 'credential-already-in-use'));

      await repository.signInWithApple();

      verify(() => firebaseAuth.signInWithProvider(any())).called(1);
    });

    for (final code in ['canceled', 'web-context-canceled']) {
      test('throws SignInCancelled on $code', () async {
        when(() => firebaseAuth.signInWithProvider(any()))
            .thenThrow(FirebaseAuthException(code: code));
        await expectLater(
          repository.signInWithApple(),
          throwsA(isA<SignInCancelled>()),
        );
      });
    }
  });

  group('signInAnonymously', () {
    test('signs in anonymously', () async {
      await repository.signInAnonymously();
      verify(firebaseAuth.signInAnonymously).called(1);
    });

    test('throws AuthFailure on any other error', () async {
      final error = Exception('oops');
      when(firebaseAuth.signInAnonymously).thenThrow(error);
      await expectLater(
        repository.signInAnonymously(),
        throwsA(isA<AuthFailure>().having((f) => f.error, 'error', error)),
      );
    });
  });

  group('signOut', () {
    test('signs out of Firebase only when Google was never used', () async {
      await repository.signOut();
      verify(firebaseAuth.signOut).called(1);
      verifyNever(googleSignIn.signOut);
    });

    test('also signs out of Google after a Google sign-in', () async {
      await repository.signInWithGoogle();
      await repository.signOut();
      verify(firebaseAuth.signOut).called(1);
      verify(googleSignIn.signOut).called(1);
    });
  });
}
