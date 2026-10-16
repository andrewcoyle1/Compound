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

  /// Whether `users/{uid}` exists, read from the server and never from the
  /// cache: a cache with no copy of the profile, or one with a copy that
  /// does not decode, must never pass for a new account. Throws when the
  /// server cannot be reached.
  ///
  /// The AppBloc asks before [createUser]: Swift creates the profile only
  /// for an account Firebase reports as new (`UserManager.swift:56-60`),
  /// which a stream of signed-in users cannot tell, and a [createUser] over
  /// an existing profile would reset `did_complete_onboarding`.
  Future<bool> userExists(String uid);

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
  /// (`CoachManager.swift:75`). A field that must go is named in
  /// [clearing] (a `PrivateUserSettingsKeys` constant) and deleted in the
  /// same write.
  Future<void> mergePrivateSettings(
    String uid,
    PrivateUserSettings settings, {
    Set<String> clearing = const {},
  });

  /// Deletes the profile at `users/{uid}`, as `UserManager.deleteCurrentUser`
  /// does inside account deletion (`CoreInteractor.swift:240-262`). The
  /// `onUserDeleted` Cloud Function then deletes everything else the account
  /// owns. Only the profile: its subcollections are the function's.
  ///
  /// Unlike every other write here this waits for the server, and fails
  /// offline: the Auth user is deleted next, after which the rules refuse
  /// this user, so a delete still queued on the device would never land
  /// and the account's data would never be cleaned up.
  Future<void> deleteUser(String uid);
}
