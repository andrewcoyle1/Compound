import 'package:user_repository/user_repository.dart';

/// One new value for every [UserField], each different from the
/// `user_model/full` fixture's, and [taggedUpdates]: how each is stored, as
/// tagged JSON.
final everyFieldUpdate = <UserFieldValue>[
  UserField.submittedFirstName('Grace'),
  UserField.submittedLastName('Hopper'),
  UserField.submittedEmail('grace@example.com'),
  UserField.submittedProfileImage('https://example.com/grace.jpg'),
  UserField.submittedGender(Gender.female),
  UserField.submittedDateOfBirth(DateTime.utc(1985, 6, 7)),
  UserField.submittedHeightCentimeters(180.5),
  UserField.submittedWeightKilograms(70.75),
  UserField.submittedLengthUnitPreference(LengthUnitPreference.centimeters),
  UserField.submittedWeightUnitPreference(WeightUnitPreference.kilograms),
  UserField.submittedDistanceUnitPreference(DistanceUnitPreference.kilometers),
  UserField.submittedExerciseFrequency(ExerciseFrequency.fiveToSix),
  UserField.submittedDailyActivityLevel(ActivityLevel.moderate),
  UserField.submittedCardioFitnessLevel(CardioFitnessLevel.advanced),
  UserField.submittedActiveMesocycleId('mesocycle_2'),
  UserField.submittedFavouriteGymProfileId('gym_2'),
  UserField.submittedCurrentGoalId('goal_2'),
  UserField.didCompleteOnboarding(false),
  UserField.acceptedHealthDisclaimerVersion('2026.10.01'),
  UserField.acceptedHealthDisclaimerDate(
    DateTime.utc(2026, 10, 15, 9, 30, 0, 125),
  ),
  UserField.acceptedHealthPrivacyPolicyVersion('2026.10.02'),
  UserField.acceptedHealthPrivacyPolicyDate(
    DateTime.utc(2026, 10, 15, 9, 31, 0, 250),
  ),
  UserField.isPrivate(false),
  UserField.blockedUserIds(['user_x', 'user_y']),
  UserField.followingIds([]),
  UserField.username('grace'),
  UserField.weeklySessionGoal(5),
  UserField.isAnonymous(false),
  UserField.email('grace@example.com'),
  UserField.authProviders(['google']),
];

/// [everyFieldUpdate] as Firestore stores it, as tagged JSON.
const taggedUpdates = <String, Object?>{
  'submitted_first_name': 'Grace',
  'submitted_last_name': 'Hopper',
  'submitted_email': 'grace@example.com',
  'submitted_profile_image': 'https://example.com/grace.jpg',
  'submitted_gender': 'female',
  'submitted_date_of_birth': {r'$timestamp': '1985-06-07T00:00:00.000Z'},
  'submitted_height_centimeters': 180.5,
  'submitted_weight_kilograms': 70.75,
  'submitted_length_unit_preference': 'centimeters',
  'submitted_weight_unit_preference': 'kilograms',
  'submitted_distance_unit_preference': 'kilometers',
  'submitted_exercise_frequency': '5-6',
  'submitted_daily_activity_level': 'moderate',
  'submitted_cardio_fitness_level': 'advanced',
  'submitted_active_mesocycle_id': 'mesocycle_2',
  'submitted_favourite_gym_profile_id': 'gym_2',
  'submitted_current_goal_id': 'goal_2',
  'did_complete_onboarding': false,
  'accepted_health_disclaimer_version': '2026.10.01',
  'accepted_health_disclaimer_date': {
    r'$timestamp': '2026-10-15T09:30:00.125Z',
  },
  'accepted_health_privacy_policy_version': '2026.10.02',
  'accepted_health_privacy_policy_date': {
    r'$timestamp': '2026-10-15T09:31:00.250Z',
  },
  'is_private': false,
  'blocked_user_ids': ['user_x', 'user_y'],
  'following_ids': <Object?>[],
  'username': 'grace',
  'weekly_session_goal': 5,
  'is_anonymous': false,
  'email': 'grace@example.com',
  'auth_providers': ['google'],
};
