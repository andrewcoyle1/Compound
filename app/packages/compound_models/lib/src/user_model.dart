import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/user_enums.dart';

/// Field names of `users/{uid}`, exactly as the Swift `CodingKeys`
/// spell them.
///
/// Partial updates take their field names only from here.
abstract final class UserModelKeys {
  /// `user_id`.
  static const userId = 'user_id';

  /// `email`.
  static const email = 'email';

  /// `is_anonymous`.
  static const isAnonymous = 'is_anonymous';

  /// `auth_providers`.
  static const authProviders = 'auth_providers';

  /// `display_name`.
  static const displayName = 'display_name';

  /// `first_name`.
  static const firstName = 'first_name';

  /// `last_name`.
  static const lastName = 'last_name';

  /// `phone_number`.
  static const phoneNumber = 'phone_number';

  /// `photo_url`.
  static const photoUrl = 'photo_url';

  /// `creation_date`.
  static const creationDate = 'creation_date';

  /// `creation_version`.
  static const creationVersion = 'creation_version';

  /// `last_sign_in_date`.
  static const lastSignInDate = 'last_sign_in_date';

  /// `submitted_email`.
  static const submittedEmail = 'submitted_email';

  /// `submitted_first_name`.
  static const submittedFirstName = 'submitted_first_name';

  /// `submitted_last_name`.
  static const submittedLastName = 'submitted_last_name';

  /// `submitted_profile_image`.
  static const submittedProfileImage = 'submitted_profile_image';

  /// `submitted_date_of_birth`.
  static const submittedDateOfBirth = 'submitted_date_of_birth';

  /// `submitted_gender`.
  static const submittedGender = 'submitted_gender';

  /// `submitted_height_centimeters`.
  static const submittedHeightCentimeters = 'submitted_height_centimeters';

  /// `submitted_weight_kilograms`.
  static const submittedWeightKilograms = 'submitted_weight_kilograms';

  /// `submitted_exercise_frequency`.
  static const submittedExerciseFrequency = 'submitted_exercise_frequency';

  /// `submitted_daily_activity_level`.
  static const submittedDailyActivityLevel = 'submitted_daily_activity_level';

  /// `submitted_cardio_fitness_level`.
  static const submittedCardioFitnessLevel = 'submitted_cardio_fitness_level';

  /// `submitted_length_unit_preference`.
  static const submittedLengthUnitPreference =
      'submitted_length_unit_preference';

  /// `submitted_weight_unit_preference`.
  static const submittedWeightUnitPreference =
      'submitted_weight_unit_preference';

  /// `submitted_distance_unit_preference`.
  static const submittedDistanceUnitPreference =
      'submitted_distance_unit_preference';

  /// `submitted_current_goal_id`.
  static const submittedCurrentGoalId = 'submitted_current_goal_id';

  /// `submitted_active_mesocycle_id`.
  static const submittedActiveMesocycleId = 'submitted_active_mesocycle_id';

  /// `submitted_favourite_gym_profile_id`.
  static const submittedFavouriteGymProfileId =
      'submitted_favourite_gym_profile_id';

  /// `did_complete_onboarding`.
  static const didCompleteOnboarding = 'did_complete_onboarding';

  /// `blocked_user_ids`.
  static const blockedUserIds = 'blocked_user_ids';

  /// `following_ids`.
  static const followingIds = 'following_ids';

  /// `is_private`.
  static const isPrivate = 'is_private';

  /// `social_push_likes`.
  static const socialPushLikes = 'social_push_likes';

  /// `social_push_comments`.
  static const socialPushComments = 'social_push_comments';

  /// `social_push_follows`.
  static const socialPushFollows = 'social_push_follows';

  /// `social_push_nudges`.
  static const socialPushNudges = 'social_push_nudges';

  /// `social_push_mentions`.
  static const socialPushMentions = 'social_push_mentions';

  /// `fcm_token`.
  static const fcmToken = 'fcm_token';

  /// `accepted_health_disclaimer_version`.
  static const acceptedHealthDisclaimerVersion =
      'accepted_health_disclaimer_version';

  /// `accepted_health_disclaimer_date`.
  static const acceptedHealthDisclaimerDate = 'accepted_health_disclaimer_date';

  /// `accepted_health_privacy_policy_version`.
  static const acceptedHealthPrivacyPolicyVersion =
      'accepted_health_privacy_policy_version';

  /// `accepted_health_privacy_policy_date`.
  static const acceptedHealthPrivacyPolicyDate =
      'accepted_health_privacy_policy_date';

  /// `username`.
  static const username = 'username';

  /// `weekly_session_goal`.
  static const weeklySessionGoal = 'weekly_session_goal';

  /// Every field, in declaration order.
  static const List<String> all = [
    userId,
    email,
    isAnonymous,
    authProviders,
    displayName,
    firstName,
    lastName,
    phoneNumber,
    photoUrl,
    creationDate,
    creationVersion,
    lastSignInDate,
    submittedEmail,
    submittedFirstName,
    submittedLastName,
    submittedProfileImage,
    submittedDateOfBirth,
    submittedGender,
    submittedHeightCentimeters,
    submittedWeightKilograms,
    submittedExerciseFrequency,
    submittedDailyActivityLevel,
    submittedCardioFitnessLevel,
    submittedLengthUnitPreference,
    submittedWeightUnitPreference,
    submittedDistanceUnitPreference,
    submittedCurrentGoalId,
    submittedActiveMesocycleId,
    submittedFavouriteGymProfileId,
    didCompleteOnboarding,
    blockedUserIds,
    followingIds,
    isPrivate,
    socialPushLikes,
    socialPushComments,
    socialPushFollows,
    socialPushNudges,
    socialPushMentions,
    fcmToken,
    acceptedHealthDisclaimerVersion,
    acceptedHealthDisclaimerDate,
    acceptedHealthPrivacyPolicyVersion,
    acceptedHealthPrivacyPolicyDate,
    username,
    weeklySessionGoal,
  ];
}

/// The public profile at `users/{uid}`, readable by every signed-in user.
///
/// Mirrors the Swift `UserModel` (`Compound/Managers/User/Models/`).
class const UserModel({
  /// The Firebase Auth uid, and the document id.
  required final String userId,

  /// Email from the auth provider.
  final String? email,

  /// Whether the account is anonymous.
  final bool? isAnonymous,

  /// Auth provider ids, such as `google.com`.
  final List<String>? authProviders,

  /// Display name from the auth provider.
  final String? displayName,

  /// First name from the auth provider.
  final String? firstName,

  /// Last name from the auth provider.
  final String? lastName,

  /// Phone number from the auth provider.
  final String? phoneNumber,

  /// Photo URL from the auth provider.
  final String? photoUrl,

  /// When the account was created.
  final DateTime? creationDate,

  /// The app version that created the account.
  final String? creationVersion,

  /// When the user last signed in.
  final DateTime? lastSignInDate,

  /// Email the user entered.
  final String? submittedEmail,

  /// First name the user entered.
  final String? submittedFirstName,

  /// Last name the user entered.
  final String? submittedLastName,

  /// URL of the profile image the user uploaded.
  final String? submittedProfileImage,

  /// Date of birth.
  final DateTime? submittedDateOfBirth,

  /// Sex for the calorie estimate.
  final Gender? submittedGender,

  /// Height in centimeters.
  final double? submittedHeightCentimeters,

  /// Weight in kilograms.
  final double? submittedWeightKilograms,

  /// How often the user exercises.
  final ExerciseFrequency? submittedExerciseFrequency,

  /// Daily activity outside exercise.
  final ActivityLevel? submittedDailyActivityLevel,

  /// Cardio fitness; no longer asked in onboarding.
  final CardioFitnessLevel? submittedCardioFitnessLevel,

  /// Unit for height and body measurements.
  final LengthUnitPreference? submittedLengthUnitPreference,

  /// Unit for weights.
  final WeightUnitPreference? submittedWeightUnitPreference,

  /// Unit for distances.
  final DistanceUnitPreference? submittedDistanceUnitPreference,

  /// Id of the running goal in `users/{uid}/goals`.
  final String? submittedCurrentGoalId,

  /// Id of the active mesocycle.
  final String? submittedActiveMesocycleId,

  /// Id of the favourite gym profile.
  final String? submittedFavouriteGymProfileId,

  /// Whether onboarding is finished. Required by the Swift decoder.
  final bool didCompleteOnboarding = false,

  /// Users this user has blocked.
  final List<String>? blockedUserIds,

  /// Users this user follows.
  final List<String>? followingIds,

  /// Whether follows need approval.
  final bool? isPrivate,

  /// Legacy opt-out; now in `PrivateUserSettings`.
  final bool? socialPushLikes,

  /// Legacy opt-out; now in `PrivateUserSettings`.
  final bool? socialPushComments,

  /// Legacy opt-out; now in `PrivateUserSettings`.
  final bool? socialPushFollows,

  /// Legacy opt-out; now in `PrivateUserSettings`.
  final bool? socialPushNudges,

  /// Legacy opt-out; now in `PrivateUserSettings`.
  final bool? socialPushMentions,

  /// Legacy push token; now in `PrivateUserSettings`.
  final String? fcmToken,

  /// Health disclaimer version accepted.
  final String? acceptedHealthDisclaimerVersion,

  /// When the health disclaimer was accepted.
  final DateTime? acceptedHealthDisclaimerDate,

  /// Health privacy policy version accepted.
  final String? acceptedHealthPrivacyPolicyVersion,

  /// When the health privacy policy was accepted.
  final DateTime? acceptedHealthPrivacyPolicyDate,

  /// The unique handle, reserved in `usernames/{handle}`.
  final String? username,

  /// Finished sessions a week the user aims for, 1 to 7.
  final int? weeklySessionGoal,
}) {
  /// Creates a [UserModel].
  this;

  /// Decodes a Firestore-shaped map as strictly as the Swift decoder:
  /// a missing required field, a wrong type or an unknown enum value
  /// throws. Unknown keys are ignored, and a null reads as absent.
  factory fromFirestore(Map<String, Object?> data) => UserModel(
    userId: data[UserModelKeys.userId]! as String,
    email: data[UserModelKeys.email] as String?,
    isAnonymous: data[UserModelKeys.isAnonymous] as bool?,
    authProviders: switch (data[UserModelKeys.authProviders]) {
      null => null,
      final Object list => List<String>.from(list as List<Object?>),
    },
    displayName: data[UserModelKeys.displayName] as String?,
    firstName: data[UserModelKeys.firstName] as String?,
    lastName: data[UserModelKeys.lastName] as String?,
    phoneNumber: data[UserModelKeys.phoneNumber] as String?,
    photoUrl: data[UserModelKeys.photoUrl] as String?,
    creationDate: data[UserModelKeys.creationDate] as DateTime?,
    creationVersion: data[UserModelKeys.creationVersion] as String?,
    lastSignInDate: data[UserModelKeys.lastSignInDate] as DateTime?,
    submittedEmail: data[UserModelKeys.submittedEmail] as String?,
    submittedFirstName: data[UserModelKeys.submittedFirstName] as String?,
    submittedLastName: data[UserModelKeys.submittedLastName] as String?,
    submittedProfileImage: data[UserModelKeys.submittedProfileImage] as String?,
    submittedDateOfBirth: data[UserModelKeys.submittedDateOfBirth] as DateTime?,
    submittedGender: switch (data[UserModelKeys.submittedGender]) {
      null => null,
      final Object raw => enumFromValue(Gender.values, raw as String),
    },
    submittedHeightCentimeters:
        (data[UserModelKeys.submittedHeightCentimeters] as num?)?.toDouble(),
    submittedWeightKilograms:
        (data[UserModelKeys.submittedWeightKilograms] as num?)?.toDouble(),
    submittedExerciseFrequency:
        switch (data[UserModelKeys.submittedExerciseFrequency]) {
          null => null,
          final Object raw => enumFromValue(
            ExerciseFrequency.values,
            raw as String,
          ),
        },
    submittedDailyActivityLevel: switch (data[UserModelKeys
        .submittedDailyActivityLevel]) {
      null => null,
      final Object raw => enumFromValue(ActivityLevel.values, raw as String),
    },
    submittedCardioFitnessLevel:
        switch (data[UserModelKeys.submittedCardioFitnessLevel]) {
          null => null,
          final Object raw => enumFromValue(
            CardioFitnessLevel.values,
            raw as String,
          ),
        },
    submittedLengthUnitPreference:
        switch (data[UserModelKeys.submittedLengthUnitPreference]) {
          null => null,
          final Object raw => enumFromValue(
            LengthUnitPreference.values,
            raw as String,
          ),
        },
    submittedWeightUnitPreference:
        switch (data[UserModelKeys.submittedWeightUnitPreference]) {
          null => null,
          final Object raw => enumFromValue(
            WeightUnitPreference.values,
            raw as String,
          ),
        },
    submittedDistanceUnitPreference:
        switch (data[UserModelKeys.submittedDistanceUnitPreference]) {
          null => null,
          final Object raw => enumFromValue(
            DistanceUnitPreference.values,
            raw as String,
          ),
        },
    submittedCurrentGoalId:
        data[UserModelKeys.submittedCurrentGoalId] as String?,
    submittedActiveMesocycleId:
        data[UserModelKeys.submittedActiveMesocycleId] as String?,
    submittedFavouriteGymProfileId:
        data[UserModelKeys.submittedFavouriteGymProfileId] as String?,
    didCompleteOnboarding: data[UserModelKeys.didCompleteOnboarding]! as bool,
    blockedUserIds: switch (data[UserModelKeys.blockedUserIds]) {
      null => null,
      final Object list => List<String>.from(list as List<Object?>),
    },
    followingIds: switch (data[UserModelKeys.followingIds]) {
      null => null,
      final Object list => List<String>.from(list as List<Object?>),
    },
    isPrivate: data[UserModelKeys.isPrivate] as bool?,
    socialPushLikes: data[UserModelKeys.socialPushLikes] as bool?,
    socialPushComments: data[UserModelKeys.socialPushComments] as bool?,
    socialPushFollows: data[UserModelKeys.socialPushFollows] as bool?,
    socialPushNudges: data[UserModelKeys.socialPushNudges] as bool?,
    socialPushMentions: data[UserModelKeys.socialPushMentions] as bool?,
    fcmToken: data[UserModelKeys.fcmToken] as String?,
    acceptedHealthDisclaimerVersion:
        data[UserModelKeys.acceptedHealthDisclaimerVersion] as String?,
    acceptedHealthDisclaimerDate:
        data[UserModelKeys.acceptedHealthDisclaimerDate] as DateTime?,
    acceptedHealthPrivacyPolicyVersion:
        data[UserModelKeys.acceptedHealthPrivacyPolicyVersion] as String?,
    acceptedHealthPrivacyPolicyDate:
        data[UserModelKeys.acceptedHealthPrivacyPolicyDate] as DateTime?,
    username: data[UserModelKeys.username] as String?,
    weeklySessionGoal: data[UserModelKeys.weeklySessionGoal] as int?,
  );

  /// The Firestore-shaped map Swift writes: a null field is left out,
  /// never written as null.
  Map<String, Object?> toFirestore() => {
    UserModelKeys.userId: userId,
    UserModelKeys.email: ?email,
    UserModelKeys.isAnonymous: ?isAnonymous,
    UserModelKeys.authProviders: ?authProviders,
    UserModelKeys.displayName: ?displayName,
    UserModelKeys.firstName: ?firstName,
    UserModelKeys.lastName: ?lastName,
    UserModelKeys.phoneNumber: ?phoneNumber,
    UserModelKeys.photoUrl: ?photoUrl,
    UserModelKeys.creationDate: ?creationDate,
    UserModelKeys.creationVersion: ?creationVersion,
    UserModelKeys.lastSignInDate: ?lastSignInDate,
    UserModelKeys.submittedEmail: ?submittedEmail,
    UserModelKeys.submittedFirstName: ?submittedFirstName,
    UserModelKeys.submittedLastName: ?submittedLastName,
    UserModelKeys.submittedProfileImage: ?submittedProfileImage,
    UserModelKeys.submittedDateOfBirth: ?submittedDateOfBirth,
    UserModelKeys.submittedGender: ?submittedGender?.value,
    UserModelKeys.submittedHeightCentimeters: ?submittedHeightCentimeters,
    UserModelKeys.submittedWeightKilograms: ?submittedWeightKilograms,
    UserModelKeys.submittedExerciseFrequency:
        ?submittedExerciseFrequency?.value,
    UserModelKeys.submittedDailyActivityLevel:
        ?submittedDailyActivityLevel?.value,
    UserModelKeys.submittedCardioFitnessLevel:
        ?submittedCardioFitnessLevel?.value,
    UserModelKeys.submittedLengthUnitPreference:
        ?submittedLengthUnitPreference?.value,
    UserModelKeys.submittedWeightUnitPreference:
        ?submittedWeightUnitPreference?.value,
    UserModelKeys.submittedDistanceUnitPreference:
        ?submittedDistanceUnitPreference?.value,
    UserModelKeys.submittedCurrentGoalId: ?submittedCurrentGoalId,
    UserModelKeys.submittedActiveMesocycleId: ?submittedActiveMesocycleId,
    UserModelKeys.submittedFavouriteGymProfileId:
        ?submittedFavouriteGymProfileId,
    UserModelKeys.didCompleteOnboarding: didCompleteOnboarding,
    UserModelKeys.blockedUserIds: ?blockedUserIds,
    UserModelKeys.followingIds: ?followingIds,
    UserModelKeys.isPrivate: ?isPrivate,
    UserModelKeys.socialPushLikes: ?socialPushLikes,
    UserModelKeys.socialPushComments: ?socialPushComments,
    UserModelKeys.socialPushFollows: ?socialPushFollows,
    UserModelKeys.socialPushNudges: ?socialPushNudges,
    UserModelKeys.socialPushMentions: ?socialPushMentions,
    UserModelKeys.fcmToken: ?fcmToken,
    UserModelKeys.acceptedHealthDisclaimerVersion:
        ?acceptedHealthDisclaimerVersion,
    UserModelKeys.acceptedHealthDisclaimerDate: ?acceptedHealthDisclaimerDate,
    UserModelKeys.acceptedHealthPrivacyPolicyVersion:
        ?acceptedHealthPrivacyPolicyVersion,
    UserModelKeys.acceptedHealthPrivacyPolicyDate:
        ?acceptedHealthPrivacyPolicyDate,
    UserModelKeys.username: ?username,
    UserModelKeys.weeklySessionGoal: ?weeklySessionGoal,
  };
}
