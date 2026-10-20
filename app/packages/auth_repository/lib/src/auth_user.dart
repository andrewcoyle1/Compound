import 'package:equatable/equatable.dart';

/// A sign-in provider linked to an account (Swift `AuthProviderOption`).
enum SignInProvider {
  /// Sign in with Apple (`apple.com`).
  apple,

  /// Google (`google.com`).
  google,
}

/// {@template auth_user}
/// The signed-in Firebase Auth account.
/// {@endtemplate}
class const AuthUser({
  required final String uid,
  required final bool isAnonymous,
  final String? email,
  final String? displayName,

  /// The Apple and Google sign-ins linked to the account; empty for an
  /// anonymous one.
  final Set<SignInProvider> providers = const {},
}) extends Equatable {
  /// {@macro auth_user}
  this;

  @override
  List<Object?> get props => [uid, isAnonymous, email, displayName, providers];
}
