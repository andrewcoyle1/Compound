import 'package:auth_repository/auth_repository.dart';

/// {@template auth_failure}
/// Signing in or out failed. [error] is the underlying SDK error.
/// {@endtemplate}
class const AuthFailure([final Object? error]) implements Exception {
  /// {@macro auth_failure}
  this;
}

/// {@template sign_in_cancelled}
/// The user dismissed the sign-in sheet: nothing to report.
/// {@endtemplate}
class const SignInCancelled() extends AuthFailure {
  /// {@macro sign_in_cancelled}
  this;
}

/// Signs users in and out, and reports who is signed in.
///
/// Every method throws [AuthFailure] on failure, or [SignInCancelled] when
/// the user backs out of a provider's sheet.
abstract interface class AuthRepository {
  /// The signed-in user, or `null` once signed out. Emits the current value
  /// on listen, and again when the account changes (such as linking an
  /// anonymous account to Google).
  Stream<AuthUser?> get user;

  /// The signed-in user right now, or `null`.
  AuthUser? get currentUser;

  /// Signs in with Google, linking it to an anonymous account if one is
  /// signed in.
  Future<void> signInWithGoogle();

  /// Signs in with Apple, linking it to an anonymous account if one is
  /// signed in.
  Future<void> signInWithApple();

  /// Signs in with a new anonymous account.
  Future<void> signInAnonymously();

  /// Signs out.
  Future<void> signOut();
}
