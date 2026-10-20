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

  /// Deletes the signed-in account, as SwiftfulAuthenticating's
  /// `deleteAccountWithReauthentication` does for `CoreInteractor
  /// .deleteAccount`:
  ///
  /// 1. signs in again with the account's provider, Apple before Google,
  ///    which Firebase requires before deleting; an anonymous account has
  ///    nothing to sign in with and skips this. Signing in as a different
  ///    account fails;
  /// 2. runs [beforeDelete] while the account still exists, so the rules
  ///    still let it delete its own profile;
  /// 3. deletes the Firebase Auth user, which signs it out.
  ///
  /// Throws [SignInCancelled] when the sign-in sheet is dismissed (nothing is
  /// deleted), and [AuthFailure] otherwise; an error from [beforeDelete]
  /// propagates as it is, and the account is kept.
  Future<void> deleteAccount({required Future<void> Function() beforeDelete});
}
