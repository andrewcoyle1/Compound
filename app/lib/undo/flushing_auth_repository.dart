import 'package:auth_repository/auth_repository.dart';
import 'package:compound/undo/pending_deletes.dart';

/// The app's [AuthRepository], which first writes the deletes still waiting
/// on an Undo when the user signs out, while the security rules still let
/// the account write its own documents. Everything else goes straight to
/// [auth].
class FlushingAuthRepository implements AuthRepository {
  /// Wraps [auth], flushing [pending] before a sign-out.
  const new(this.auth, this.pending);

  /// The repository that signs in and out.
  final AuthRepository auth;

  /// The deletes to write first.
  final PendingDeletes pending;

  @override
  Stream<AuthUser?> get user => auth.user;

  @override
  AuthUser? get currentUser => auth.currentUser;

  @override
  Future<void> signInWithGoogle() => auth.signInWithGoogle();

  @override
  Future<void> signInWithApple() => auth.signInWithApple();

  @override
  Future<void> signInAnonymously() => auth.signInAnonymously();

  @override
  Future<void> signOut() async {
    await pending.flushAll();
    await auth.signOut();
  }

  /// Deleting the account removes everything, so the waiting deletes are
  /// dropped rather than written after it has gone.
  @override
  Future<void> deleteAccount({required Future<void> Function() beforeDelete}) =>
      auth.deleteAccount(
        beforeDelete: () async {
          pending.keys.forEach(pending.undo);
          await beforeDelete();
        },
      );
}
