import 'package:compound_models/compound_models.dart';
import 'package:user_repository/src/user_repository.dart';

/// [UserRepository] over fixed documents, for the staging flavor and tests.
/// Seed it with `sampleUser` and `sampleUserSettings`.
class InMemoryUserRepository implements UserRepository {
  /// Creates an [InMemoryUserRepository] holding [users] and [settings],
  /// each keyed by uid.
  new({
    Map<String, UserModel> users = const {},
    Map<String, PrivateUserSettings> settings = const {},
  }) : _users = Map.unmodifiable(users),
       _settings = Map.unmodifiable(settings);

  final Map<String, UserModel> _users;
  final Map<String, PrivateUserSettings> _settings;

  @override
  Stream<UserModel?> watchUser(String uid) => Stream.value(_users[uid]);

  @override
  Stream<PrivateUserSettings?> watchPrivateSettings(String uid) =>
      Stream.value(_settings[uid]);
}
