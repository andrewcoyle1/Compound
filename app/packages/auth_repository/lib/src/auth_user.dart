import 'package:equatable/equatable.dart';

/// {@template auth_user}
/// The signed-in Firebase Auth account.
/// {@endtemplate}
class const AuthUser({
  required final String uid,
  required final bool isAnonymous,
  final String? email,
  final String? displayName,
}) extends Equatable {
  /// {@macro auth_user}
  this;

  @override
  List<Object?> get props => [uid, isAnonymous, email, displayName];
}
