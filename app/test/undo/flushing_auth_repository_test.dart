import 'package:auth_repository/auth_repository.dart';
import 'package:compound/undo/flushing_auth_repository.dart';
import 'package:compound/undo/pending_deletes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

void main() {
  group(FlushingAuthRepository, () {
    late _MockAuthRepository auth;
    late PendingDeletes pending;
    late FlushingAuthRepository repository;
    late List<String> calls;

    setUp(() {
      auth = _MockAuthRepository();
      pending = PendingDeletes();
      repository = FlushingAuthRepository(auth, pending);
      calls = [];
    });

    test('writes the waiting deletes before signing out', () async {
      pending.schedule('gyms/a', () async => calls.add('delete'));
      when(auth.signOut).thenAnswer((_) async => calls.add('signOut'));
      await repository.signOut();
      expect(calls, ['delete', 'signOut']);
      expect(pending.keys, isEmpty);
    });

    test('drops the waiting deletes when deleting the account', () async {
      pending.schedule('gyms/a', () async => calls.add('delete'));
      when(
        () => auth.deleteAccount(beforeDelete: any(named: 'beforeDelete')),
      ).thenAnswer((invocation) async {
        final before =
            invocation.namedArguments[#beforeDelete] as Future<void> Function();
        await before();
        calls.add('deleted');
      });
      await repository.deleteAccount(
        beforeDelete: () async => calls.add('before'),
      );
      expect(calls, ['before', 'deleted']);
      expect(pending.keys, isEmpty);
    });

    test('passes everything else straight through', () async {
      const user = AuthUser(uid: 'me', isAnonymous: false);
      when(() => auth.user).thenAnswer((_) => Stream.value(user));
      when(() => auth.currentUser).thenReturn(user);
      when(auth.signInWithGoogle).thenAnswer((_) async {});
      when(auth.signInWithApple).thenAnswer((_) async {});
      when(auth.signInAnonymously).thenAnswer((_) async {});

      expect(await repository.user.first, user);
      expect(repository.currentUser, user);
      await repository.signInWithGoogle();
      await repository.signInWithApple();
      await repository.signInAnonymously();
      verify(auth.signInWithGoogle).called(1);
      verify(auth.signInWithApple).called(1);
      verify(auth.signInAnonymously).called(1);
    });
  });
}
