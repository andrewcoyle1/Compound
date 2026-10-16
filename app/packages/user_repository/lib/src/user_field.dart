import 'package:compound_models/compound_models.dart';

/// A field of `users/{uid}` that the Swift app updates on its own, typed by
/// its value. These are the only fields a [UserFieldValue] can carry, so a
/// partial update can name no other field and no value of the wrong type.
///
/// The list is Swift's partial updates: `UserManager.swift:119-365`
/// (names, image, gender, date of birth, height, weight, units, exercise
/// frequency, activity and cardio levels, active mesocycle, favourite gym,
/// onboarding, current goal, health consents, privacy, blocking, following),
/// `EditProfilePresenter.swift:160`, `ExpenditurePresenter.swift:188`
/// (account setup), `UserManager+Username.swift:43` and
/// `CoreInteractor+CircleGoals.swift:12` (weekly goal). Two of the fields
/// `FirestoreContractTests.userModelNamedFields` lists are left out because
/// Swift only queries them (`creation_date`, `user_id`), and one by choice:
/// `fcm_token`, Swift's legacy public copy of the push token, which Flutter
/// writes only to the private settings.
///
/// Three are Flutter's own: `is_anonymous`, `email` and `auth_providers`,
/// written when Settings' Save Account links an anonymous account, which
/// Swift never updates (`swift-findings.md`).
enum UserField<T extends Object> {
  /// `submitted_first_name`.
  submittedFirstName<String>(UserModelKeys.submittedFirstName),

  /// `submitted_last_name`.
  submittedLastName<String>(UserModelKeys.submittedLastName),

  /// `submitted_email`.
  submittedEmail<String>(UserModelKeys.submittedEmail),

  /// `submitted_profile_image`: the uploaded image's URL.
  submittedProfileImage<String>(UserModelKeys.submittedProfileImage),

  /// `submitted_gender`.
  submittedGender<Gender>(UserModelKeys.submittedGender),

  /// `submitted_date_of_birth`.
  submittedDateOfBirth<DateTime>(UserModelKeys.submittedDateOfBirth),

  /// `submitted_height_centimeters`.
  submittedHeightCentimeters<double>(UserModelKeys.submittedHeightCentimeters),

  /// `submitted_weight_kilograms`.
  submittedWeightKilograms<double>(UserModelKeys.submittedWeightKilograms),

  /// `submitted_length_unit_preference`.
  submittedLengthUnitPreference<LengthUnitPreference>(
    UserModelKeys.submittedLengthUnitPreference,
  ),

  /// `submitted_weight_unit_preference`.
  submittedWeightUnitPreference<WeightUnitPreference>(
    UserModelKeys.submittedWeightUnitPreference,
  ),

  /// `submitted_distance_unit_preference`.
  submittedDistanceUnitPreference<DistanceUnitPreference>(
    UserModelKeys.submittedDistanceUnitPreference,
  ),

  /// `submitted_exercise_frequency`.
  submittedExerciseFrequency<ExerciseFrequency>(
    UserModelKeys.submittedExerciseFrequency,
  ),

  /// `submitted_daily_activity_level`.
  submittedDailyActivityLevel<ActivityLevel>(
    UserModelKeys.submittedDailyActivityLevel,
  ),

  /// `submitted_cardio_fitness_level`.
  submittedCardioFitnessLevel<CardioFitnessLevel>(
    UserModelKeys.submittedCardioFitnessLevel,
  ),

  /// `submitted_active_mesocycle_id`.
  submittedActiveMesocycleId<String>(UserModelKeys.submittedActiveMesocycleId),

  /// `submitted_favourite_gym_profile_id`.
  submittedFavouriteGymProfileId<String>(
    UserModelKeys.submittedFavouriteGymProfileId,
  ),

  /// `submitted_current_goal_id`.
  submittedCurrentGoalId<String>(UserModelKeys.submittedCurrentGoalId),

  /// `did_complete_onboarding`.
  didCompleteOnboarding<bool>(UserModelKeys.didCompleteOnboarding),

  /// `accepted_health_disclaimer_version`.
  acceptedHealthDisclaimerVersion<String>(
    UserModelKeys.acceptedHealthDisclaimerVersion,
  ),

  /// `accepted_health_disclaimer_date`.
  acceptedHealthDisclaimerDate<DateTime>(
    UserModelKeys.acceptedHealthDisclaimerDate,
  ),

  /// `accepted_health_privacy_policy_version`.
  acceptedHealthPrivacyPolicyVersion<String>(
    UserModelKeys.acceptedHealthPrivacyPolicyVersion,
  ),

  /// `accepted_health_privacy_policy_date`.
  acceptedHealthPrivacyPolicyDate<DateTime>(
    UserModelKeys.acceptedHealthPrivacyPolicyDate,
  ),

  /// `is_private`.
  isPrivate<bool>(UserModelKeys.isPrivate),

  /// `blocked_user_ids`: the whole list, as Swift writes it.
  blockedUserIds<List<String>>(UserModelKeys.blockedUserIds),

  /// `following_ids`: the whole list, as Swift writes it.
  followingIds<List<String>>(UserModelKeys.followingIds),

  /// `username`. The rules accept only a handle whose `usernames/{handle}`
  /// reservation the writer already holds (`UserManager+Username.swift`).
  username<String>(UserModelKeys.username),

  /// `weekly_session_goal`, 1 to 7.
  weeklySessionGoal<int>(UserModelKeys.weeklySessionGoal),

  /// `is_anonymous`: false once Save Account links the account.
  isAnonymous<bool>(UserModelKeys.isAnonymous),

  /// `email`: the linked provider's address.
  email<String>(UserModelKeys.email),

  /// `auth_providers`: the whole list of linked providers, as Swift's
  /// `AuthProviderOption` raw values ("apple", "google").
  authProviders<List<String>>(UserModelKeys.authProviders);

  new(this.key);

  /// The stored field name, from [UserModelKeys].
  final String key;

  /// This field set to [value]. An enum is stored as its raw value, as
  /// Swift's updates write `rawValue`.
  UserFieldValue call(T value) => UserFieldValue._(key, switch (value) {
    final FirestoreEnum raw => raw.value,
    _ => value,
  });

  /// This field removed from the profile, as Firestore's
  /// `FieldValue.delete()`: an update can clear a field, where Swift's
  /// merge save cannot.
  UserFieldValue get cleared => UserFieldValue._(key, null);
}

/// One field of a partial update to `users/{uid}`, made by calling a
/// [UserField]: `UserField.submittedGender(Gender.female)`.
final class UserFieldValue {
  const new _(this.key, this.value);

  /// The stored field name.
  final String key;

  /// The value as the model's `toFirestore` writes it: enums as raw values,
  /// dates still [DateTime] (the repository stores them as Timestamps).
  /// Null removes the field ([UserField.cleared]).
  final Object? value;
}
