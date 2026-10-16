import 'dart:async';

import 'package:auth_repository/auth_repository.dart';

/// {@template in_memory_auth_repository}
/// An [AuthRepository] with no backend, for the staging (mock) flavor and
/// tests. Every sign-in succeeds at once; from an anonymous account, Apple
/// and Google link to it. Pass `user:` to start signed in.
/// {@endtemplate}
class InMemoryAuthRepository implements AuthRepository {
  /// {@macro in_memory_auth_repository}
  new({this._user});

  /// The seeded sample user: the one staging starts signed in as, and the
  /// one Google and Apple sign in as. Matches the Swift app's
  /// `UserModel.mockExisting` (`UserAuthInfo.mock()`'s uid), so sample data
  /// in other in-memory repositories can be keyed on [AuthUser.uid].
  static const sampleUser = AuthUser(
    uid: 'mock_user_123',
    isAnonymous: false,
    email: 'alice@example.com',
    displayName: 'Alice Cooper',
    providers: {SignInProvider.apple},
  );

  /// The user an anonymous sign-in creates.
  static const anonymousUser = AuthUser(
    uid: 'in-memory-anonymous',
    isAnonymous: true,
  );

  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get user => Stream.multi((listener) {
    listener.add(_user);
    final subscription = _controller.stream.listen(listener.add);
    listener.onCancel = subscription.cancel;
  });

  void _set(AuthUser? user) => _controller.add(_user = user);

  /// Signs in as [sampleUser]; from an anonymous account, links the
  /// provider instead, keeping the uid, as Firebase does.
  @override
  Future<void> signInWithGoogle() async => _signInOrLink(SignInProvider.google);

  /// As [signInWithGoogle], with Apple.
  @override
  Future<void> signInWithApple() async => _signInOrLink(SignInProvider.apple);

  void _signInOrLink(SignInProvider provider) {
    final current = _user;
    if (current == null || !current.isAnonymous) return _set(sampleUser);
    _set(
      AuthUser(
        uid: current.uid,
        isAnonymous: false,
        email: sampleUser.email,
        displayName: sampleUser.displayName,
        providers: {provider},
      ),
    );
  }

  @override
  Future<void> signInAnonymously() async => _set(anonymousUser);

  @override
  Future<void> signOut() async => _set(null);

  /// Runs [beforeDelete] and signs out; there is nothing to sign in again
  /// with.
  @override
  Future<void> deleteAccount({
    required Future<void> Function() beforeDelete,
  }) async {
    if (_user == null) throw const AuthFailure('No signed-in user');
    await beforeDelete();
    _set(null);
  }
}
