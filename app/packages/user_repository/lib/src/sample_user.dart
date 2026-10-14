import 'package:compound_models/compound_models.dart';

/// The uid of the staging flavor's signed-in user, matching
/// `InMemoryAuthRepository.sampleUser` and the Swift app's
/// `UserModel.mockExisting`.
const sampleUserId = 'mock_user_123';

/// The staging flavor's signed-in user, after the Swift app's
/// `UserModel.mockExisting`: Alice Cooper, onboarded a month before [now],
/// with metric units and a goal of three sessions a week.
UserModel sampleUser({required DateTime now}) => UserModel(
  userId: sampleUserId,
  email: 'alice@example.com',
  isAnonymous: false,
  authProviders: const ['google.com'],
  displayName: 'Alice Cooper',
  firstName: 'Alice',
  lastName: 'Cooper',
  photoUrl: 'https://picsum.photos/200',
  creationDate: now.subtract(const Duration(days: 30)),
  creationVersion: '1.0.0',
  lastSignInDate: now,
  submittedDateOfBirth: DateTime.utc(2000, 11, 13),
  submittedGender: Gender.male,
  submittedHeightCentimeters: 175,
  submittedWeightKilograms: 70,
  submittedExerciseFrequency: ExerciseFrequency.daily,
  submittedDailyActivityLevel: ActivityLevel.active,
  submittedCardioFitnessLevel: CardioFitnessLevel.intermediate,
  submittedLengthUnitPreference: LengthUnitPreference.centimeters,
  submittedWeightUnitPreference: WeightUnitPreference.kilograms,
  submittedDistanceUnitPreference: DistanceUnitPreference.kilometers,
  didCompleteOnboarding: true,
  followingIds: const ['user1', 'user3', 'user4', 'user5'],
  acceptedHealthDisclaimerVersion: '2025.10.05',
  username: 'alice.cooper',
  weeklySessionGoal: 3,
);

/// The sample user's private settings: social pushes on, a two-week streak
/// and two of three sessions done this week.
PrivateUserSettings sampleUserSettings({required DateTime now}) =>
    PrivateUserSettings(
      socialPushLikes: true,
      socialPushComments: true,
      socialPushFollows: true,
      socialPushStreakReminder: true,
      reminderHour: 18,
      timezone: 'Europe/London',
      weekStreak: 2,
      weekSessions: 2,
      weekGoal: 3,
      lastTrainedAt: now.subtract(const Duration(days: 1)),
      coachConsent: false,
    );
