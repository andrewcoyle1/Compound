import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(InMemoryAuthRepository, () {
    test('starts signed out', () {
      final repository = InMemoryAuthRepository();
      expect(repository.currentUser, isNull);
      expect(repository.user, emits(null));
    });

    test('can start signed in', () {
      final repository = InMemoryAuthRepository(
        user: InMemoryAuthRepository.sampleUser,
      );
      expect(repository.currentUser, InMemoryAuthRepository.sampleUser);
    });

    test('signs in and out', () async {
      final repository = InMemoryAuthRepository();
      expect(
        repository.user,
        emitsInOrder([
          null,
          InMemoryAuthRepository.sampleUser,
          InMemoryAuthRepository.sampleUser,
          InMemoryAuthRepository.anonymousUser,
          null,
        ]),
      );
      await repository.signInWithGoogle();
      await repository.signInWithApple();
      await repository.signInAnonymously();
      expect(repository.currentUser, InMemoryAuthRepository.anonymousUser);
      await repository.signOut();
      expect(repository.currentUser, isNull);
    });

    test('deletes the account after beforeDelete, signing out', () async {
      final repository = InMemoryAuthRepository(
        user: InMemoryAuthRepository.sampleUser,
      );
      var ranBefore = false;
      await repository.deleteAccount(
        beforeDelete: () async => ranBefore = true,
      );
      expect(ranBefore, isTrue);
      expect(repository.currentUser, isNull);
    });

    test('deleting with no one signed in fails', () {
      expect(
        InMemoryAuthRepository().deleteAccount(beforeDelete: () async {}),
        throwsA(isA<AuthFailure>()),
      );
    });
  });
}
