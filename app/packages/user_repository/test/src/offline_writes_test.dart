import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The repository's writes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy).
void main() {
  group('FirestoreUserRepository offline', () {
    late OfflineFirestore firestore;
    late List<(String, String)> refused;
    late FirestoreUserRepository subject;

    setUp(() {
      firestore = OfflineFirestore();
      refused = [];
      subject = FirestoreUserRepository(
        firestore: firestore,
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
      );
    });

    test('the writes complete offline; a refusal is reported', () async {
      final user = UserModel.fromFirestore(modelFixture('user_model', 'full'));
      final settings = PrivateUserSettings.fromFirestore(
        modelFixture('private_user_settings', 'full'),
      );
      await subject.createUser(user);
      await subject.mergePrivateSettings('u', settings);
      expect(firestore.writes, [
        'users/${user.userId}',
        'users/u/private/settings',
      ]);
      expect(refused, isEmpty);

      firestore.refuse('permission-denied');
      await pumpEventQueue();

      expect(refused, [
        for (final path in ['users/${user.userId}', 'users/u/private/settings'])
          (path, 'permission-denied'),
      ]);
    });

    test('updateUserFields completes offline; not-found is reported', () async {
      await subject.updateUserFields('u', [UserField.weeklySessionGoal(3)]);
      expect(refused, isEmpty);

      firestore.refuse('not-found');
      await pumpEventQueue();

      expect(refused, [('users/u', 'not-found')]);
    });
  });
}
