import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:compound_models/compound_models.dart';
import 'package:user_repository/src/user_field.dart';
import 'package:user_repository/src/user_repository.dart';

/// [UserRepository] in memory, for the staging flavor and tests. Seed it
/// with `sampleUser` and `sampleUserSettings`.
///
/// Writes behave as Firestore's do, so staging behaves as the real app:
/// saves merge over the stored document field by field, an update of a
/// missing profile fails with `not-found`, and every watcher sees the
/// change.
class InMemoryUserRepository implements UserRepository {
  /// Creates an [InMemoryUserRepository] holding [users] and [settings],
  /// each keyed by uid.
  new({
    Map<String, UserModel> users = const {},
    Map<String, PrivateUserSettings> settings = const {},
  }) : _users = Map.of(users),
       _settings = Map.of(settings);

  final Map<String, UserModel> _users;
  final Map<String, PrivateUserSettings> _settings;
  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<UserModel?> watchUser(String uid) => _watch(() => _users[uid]);

  @override
  Stream<PrivateUserSettings?> watchPrivateSettings(String uid) =>
      _watch(() => _settings[uid]);

  @override
  Future<bool> userExists(String uid) async => _users.containsKey(uid);

  @override
  Future<void> createUser(UserModel user) async {
    _users[user.userId] = UserModel.fromFirestore({
      ...?_users[user.userId]?.toFirestore(),
      ...user.toFirestore(),
    });
    _changes.add(null);
  }

  @override
  Future<void> updateUserFields(String uid, List<UserFieldValue> fields) async {
    final user = _users[uid];
    if (user == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'No document to update: users/$uid',
      );
    }
    _users[uid] = UserModel.fromFirestore(
      {
        ...user.toFirestore(),
        for (final field in fields) field.key: field.value,
      }..removeWhere((_, value) => value == null),
    );
    _changes.add(null);
  }

  @override
  Future<void> mergePrivateSettings(
    String uid,
    PrivateUserSettings settings,
  ) async {
    _settings[uid] = PrivateUserSettings.fromFirestore({
      ...?_settings[uid]?.toFirestore(),
      ...settings.toFirestore(),
    });
    _changes.add(null);
  }

  @override
  Future<void> deleteUser(String uid) async {
    _users.remove(uid);
    _changes.add(null);
  }

  /// [read] now and after every write, as a Firestore listener emits.
  Stream<T> _watch<T>(T Function() read) => Stream.multi((listener) {
    listener.add(read());
    final subscription = _changes.stream.listen((_) => listener.add(read()));
    // Not `subscription.cancel` itself: `first` would wait on the Future
    // that returns, which never completes under a widget test's fake clock.
    listener.onCancel = () => unawaited(subscription.cancel());
  });
}
