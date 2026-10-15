import 'package:auth_repository/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// {@template firebase_auth_repository}
/// An [AuthRepository] on Firebase Auth.
///
/// `googleClientId` is the iOS OAuth client id (`iosClientId` in the
/// generated Firebase options); Android reads its server client id from
/// `google-services.json`.
/// {@endtemplate}
class FirebaseAuthRepository({
  required final FirebaseAuth _firebaseAuth,
  required final GoogleSignIn _googleSignIn,
  final String? _googleClientId,
}) implements AuthRepository {
  /// {@macro firebase_auth_repository}
  this;

  // google_sign_in 7 must be initialised exactly once, before any other call.
  Future<void>? _googleInitialization;
  Future<void> _initializeGoogle() => _googleInitialization ??= _googleSignIn
      .initialize(clientId: _googleClientId);

  @override
  Stream<AuthUser?> get user =>
      _firebaseAuth.userChanges().map((user) => user?.toAuthUser());

  @override
  AuthUser? get currentUser => _firebaseAuth.currentUser?.toAuthUser();

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    await _initializeGoogle();
    final account = await _googleSignIn.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    await _signInOrLink(
      link: (user) => user.linkWithCredential(credential),
      signIn: () => _firebaseAuth.signInWithCredential(credential),
    );
  });

  @override
  Future<void> signInWithApple() => _guard(() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    await _signInOrLink(
      link: (user) => user.linkWithProvider(provider),
      signIn: () => _firebaseAuth.signInWithProvider(provider),
    );
  });

  @override
  Future<void> signInAnonymously() => _guard(_firebaseAuth.signInAnonymously);

  @override
  Future<void> signOut() => _guard(() async {
    await _firebaseAuth.signOut();
    if (_googleInitialization != null) await _googleSignIn.signOut();
  });

  @override
  Future<void> deleteAccount({
    required Future<void> Function() beforeDelete,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthFailure('No signed-in user');
    final providers = user.toAuthUser().providers;
    // Signing in as another account fails with `user-mismatch`, Swift's
    // `changedAuthenticatedUser`.
    await _guard(() async {
      if (providers.contains(SignInProvider.apple)) {
        await user.reauthenticateWithProvider(AppleAuthProvider());
      } else if (providers.contains(SignInProvider.google)) {
        await _initializeGoogle();
        final account = await _googleSignIn.authenticate();
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(
            idToken: account.authentication.idToken,
          ),
        );
      }
    });
    await beforeDelete();
    await _guard(() async {
      await user.delete();
      if (_googleInitialization != null) await _googleSignIn.signOut();
    });
  }

  /// From an anonymous account, links the provider so the uid (and the data
  /// under it) carries over. If the provider already belongs to another
  /// account, signs in to that one instead and the anonymous account is
  /// left behind, as the Swift app does.
  Future<void> _signInOrLink({
    required Future<UserCredential> Function(User user) link,
    required Future<UserCredential> Function() signIn,
  }) async {
    final current = _firebaseAuth.currentUser;
    if (current == null || !current.isAnonymous) {
      await signIn();
      return;
    }
    try {
      await link(current);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'credential-already-in-use') rethrow;
      final credential = error.credential;
      if (credential != null) {
        await _firebaseAuth.signInWithCredential(credential);
      } else {
        await signIn();
      }
    }
  }

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      throw AuthFailure(error);
    } on FirebaseAuthException catch (error) {
      if (_cancelCodes.contains(error.code)) throw const SignInCancelled();
      throw AuthFailure(error);
    } on Object catch (error) {
      throw AuthFailure(error);
    }
  }

  // Apple's sheet on iOS reports `canceled`; the web flow on Android reports
  // `web-context-canceled`.
  static const _cancelCodes = {'canceled', 'web-context-canceled'};
}

extension on User {
  AuthUser toAuthUser() => AuthUser(
    uid: uid,
    isAnonymous: isAnonymous,
    email: email,
    displayName: displayName,
    providers: {
      for (final info in providerData)
        ?switch (info.providerId) {
          'apple.com' => SignInProvider.apple,
          'google.com' => SignInProvider.google,
          _ => null,
        },
    },
  );
}
