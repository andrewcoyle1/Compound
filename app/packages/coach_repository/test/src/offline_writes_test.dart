import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The coach's deletes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy).
void main() {
  test('deletes complete offline; a refusal is reported', () async {
    const uid = 'user-1';
    final firestore = OfflineFirestore();
    final refused = <(String, String)>[];
    final users = InMemoryUserRepository();
    final subject = CoachRepository(
      firestore: firestore,
      users: users,
      coachChat: (_, {chatId, context}) => const Stream.empty(),
      onWriteError: (path, error, _) =>
          refused.add((path, (error as FirebaseException).code)),
    );
    firestore.cached['users/$uid/coach_chats/a'] = {'id': 'a'};
    firestore.cached['users/$uid/coach_chats/b'] = {'id': 'b'};
    firestore.cached['users/$uid/coach_chats/b/nested/x'] = {'id': 'x'};

    await subject.deleteChat(uid, 'c');
    await subject.withdrawConsent(uid);
    firestore.refuse('permission-denied');
    await pumpEventQueue();

    final paths = [
      'users/$uid/coach_chats/c',
      'users/$uid/coach_chats/a',
      'users/$uid/coach_chats/b',
    ];
    expect(firestore.writes, paths);
    expect(refused, [for (final path in paths) (path, 'permission-denied')]);
    expect(
      (await users.watchPrivateSettings(uid).first)?.coachConsent,
      isFalse,
    );
  });
}
