import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:social_repository/src/sample_social.dart';
import 'package:social_repository/src/social_repository.dart';
import 'package:user_repository/user_repository.dart';

/// A [SocialRepository] for the staging flavor: the real repository over an
/// in-memory Firestore seeded with [sampleSocial], so every query, write and
/// listener behaves as it does against Firestore, other users' documents
/// included. The signed-in user's own profile stays in [users].
///
/// The two callables are played by [stagingCallFunction] for [signedInUid].
Future<SocialRepository> inMemorySocialRepository({
  required UserRepository users,
  required DateTime now,
  String signedInUid = sampleUserId,
}) async {
  final firestore = FakeFirebaseFirestore();
  for (final MapEntry(key: path, value: data) in sampleSocial(
    uid: signedInUid,
    now: now,
  ).entries) {
    await firestore.doc(path).set(_stored(data)! as Map<String, Object?>);
  }
  return SocialRepository(
    firestore: firestore,
    callFunction: stagingCallFunction(firestore, signedInUid),
    users: users,
  );
}

/// The `acceptInvite` and `removeFollower` functions over [firestore], for
/// [callerId], as the Swift app's mock services play them.
///
/// - `acceptInvite` refuses as the function does (`not-found`, your own
///   invite as `failed-precondition`, a used-up one as
///   `resource-exhausted`), counts the use and answers that both now
///   follow each other, writing no follows (`MockInviteService`).
/// - `removeFollower` takes [callerId] out of the follower's
///   `following_ids` and deletes their follow notification, as the function
///   does.
CallFunction stagingCallFunction(
  FirebaseFirestore firestore,
  String callerId,
) => (name, data) async {
  switch (name) {
    case 'acceptInvite':
      final invite = firestore
          .collection('invites')
          .doc(data['code']! as String);
      final stored = (await invite.get()).data();
      if (stored == null) throw _refused('not-found');
      if (stored[InviteModelKeys.inviterId] == callerId) {
        throw _refused('failed-precondition');
      }
      if ((stored[InviteModelKeys.uses]! as int) >=
          (stored[InviteModelKeys.maxUses]! as int)) {
        throw _refused('resource-exhausted');
      }
      await invite.update({InviteModelKeys.uses: FieldValue.increment(1)});
      return {
        'inviter_id': stored[InviteModelKeys.inviterId],
        'you_follow': 'following',
        'they_follow': 'following',
      };
    case 'removeFollower':
      final followerId = data['followerId']! as String;
      await firestore.collection('users').doc(followerId).update({
        UserModelKeys.followingIds: FieldValue.arrayRemove([callerId]),
      });
      await firestore
          .doc('users/$callerId/notifications/follow_$followerId')
          .delete();
      return {'removed': followerId};
  }
  throw _refused('not-found');
};

FirebaseFunctionsException _refused(String code) =>
    FirebaseFunctionsException(message: code, code: code);

/// A model's map with its dates as Timestamps, as Firestore stores them.
Object? _stored(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => map.map(
    (key, value) => MapEntry(key, _stored(value)),
  ),
  final List<Object?> list => list.map(_stored).toList(),
  _ => value,
};
