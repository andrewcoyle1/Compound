import 'package:compound_models/compound_models.dart';
import 'package:user_repository/src/user_field.dart';

/// The signed-in user's profile and private settings.
abstract interface class UserRepository {
  /// The profile at `users/{uid}`, re-emitted on every change. Null when
  /// there is no document or it cannot be read.
  Stream<UserModel?> watchUser(String uid);

  /// The settings at `users/{uid}/private/settings`, re-emitted on every
  /// change. Null when there is no document or it cannot be read.
  Stream<PrivateUserSettings?> watchPrivateSettings(String uid);

  /// Writes a brand-new user's profile to `users/{user.userId}`, merged over
  /// anything there, as `UserManager.signIn` does for a new account
  /// (`UserManager.swift:56-60`; `saveDocument` is `setData(merge: true)`).
  ///
  /// Only for a new account: a merge still writes every non-null field,
  /// `did_complete_onboarding` included, so calling this for an existing
  /// user would reset what the model leaves at its default.
  Future<void> createUser(UserModel user);

  /// Sets [fields] on the existing profile at `users/{uid}` and nothing
  /// else, as Swift's `userSyncEngine.updateDocument` does
  /// (`UserManager.swift:119-365`). Fails, as Firestore's `update` does,
  /// when there is no profile yet.
  Future<void> updateUserFields(String uid, List<UserFieldValue> fields);

  /// Merges [settings] over `users/{uid}/private/settings`, creating it if
  /// needed, as `UserManager.updatePrivateSettings` and `saveUserFCMToken`
  /// do (`UserManager.swift:245`, `:700`).
  ///
  /// A null field is left out of the write, so it keeps its stored value
  /// rather than clearing it. To turn something off, write `false`: coach
  /// consent is withdrawn by writing `coachConsent: false`
  /// (`CoachManager.swift:75`).
  Future<void> mergePrivateSettings(String uid, PrivateUserSettings settings);
}
