import 'package:compound_models/compound_models.dart';

/// The signed-in user's profile and private settings, read-only.
abstract interface class UserRepository {
  /// The profile at `users/{uid}`, re-emitted on every change. Null when
  /// there is no document or it cannot be read.
  Stream<UserModel?> watchUser(String uid);

  /// The settings at `users/{uid}/private/settings`, re-emitted on every
  /// change. Null when there is no document or it cannot be read.
  Stream<PrivateUserSettings?> watchPrivateSettings(String uid);
}
