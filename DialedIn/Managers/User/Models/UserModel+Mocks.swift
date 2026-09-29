//
//  UserModel+Mocks.swift
//  DialedIn
//
//  Mock roster for previews, unit tests and the `.mock` build configuration.
//  Split out of UserModel.swift to keep that file under the 750-line limit.
//
import Foundation

extension UserModel {
    
    static var mock: Self {
        mocks[0]
    }

    /// A complete, fully-onboarded user whose userId matches `UserAuthInfo.mock().uid`.
    /// Use this in mock scenarios where an existing authenticated user is required.
    static var mockExisting: Self {
        UserModel(
            userId: "mock_user_123",
            email: "alice@example.com",
            isAnonymous: false,
            firstName: "Alice",
            lastName: "Cooper",
            creationDate: Date().addingTimeInterval(-30 * 86400),
            creationVersion: "1.0.0",
            lastSignInDate: Date(),
            submittedProfileImage: "https://picsum.photos/200",
            submittedDateOfBirth: Calendar.current.date(from: DateComponents(year: 2000, month: 11, day: 13)),
            submittedGender: .male,
            submittedHeightCentimeters: 175.0,
            submittedWeightKilograms: 70.0,
            submittedExerciseFrequency: .daily,
            submittedDailyActivityLevel: .active,
            submittedCardioFitnessLevel: .intermediate,
            submittedCurrentGoalId: "goal1",
            submittedActiveTrainingProgramId: TrainingProgram.mock.id,
            submittedFavouriteGymProfileId: GymProfileModel.mock.id,
            // The same circle as `mocks[0]`, so the signed-in mock scenario has a feed and a strip.
            followingIds: ["user1", "user3", "user4", "user5"],
            didCompleteOnboarding: true,
            acceptedHealthDisclaimerVersion: "2025.10.05"
        ).withUsername("alice.cooper")
    }

    static func mockWithStep(_ step: OnboardingStep) -> Self {
        let now = Date()
        let hasProfile = step.orderIndex >= OnboardingStep.completeAccountSetup.orderIndex
        let hasDisclaimer = step.orderIndex >= OnboardingStep.healthDisclaimer.orderIndex
        let hasGoal = step.orderIndex >= OnboardingStep.goalSetting.orderIndex
        return UserModel(
            userId: "mockUser",
            email: "mock@example.com",
            isAnonymous: false,
            firstName: "Mock",
            lastName: "User",
            creationDate: now,
            creationVersion: "1.0.0",
            lastSignInDate: now,
            submittedDateOfBirth: hasProfile ? Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1)) : nil,
            submittedGender: hasProfile ? .male : nil,
            submittedHeightCentimeters: hasProfile ? 175.0 : nil,
            submittedWeightKilograms: hasProfile ? 70.0 : nil,
            submittedExerciseFrequency: hasProfile ? .fiveToSix : nil,
            submittedDailyActivityLevel: hasProfile ? .active : nil,
            submittedCardioFitnessLevel: hasProfile ? .intermediate : nil,
            submittedCurrentGoalId: hasGoal ? "mock_goal_id" : nil,
            didCompleteOnboarding: step == .complete,
            acceptedHealthDisclaimerVersion: hasDisclaimer ? "2025.10.05" : nil
        )
    }

    static var mocks: [Self] {
        let now = Date()
        let day: TimeInterval = 86400

        func birthday(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date? {
            Calendar.current.date(from: DateComponents(year: year, month: month, day: dayOfMonth))
        }

        /// Distinct avatar per user so lists and feeds do not render six identical images.
        func avatar(_ seed: String) -> String {
            "https://picsum.photos/seed/\(seed)/200"
        }

        return [
            // The signed-in mock user. Follows most of the roster so the social feed has
            // content, and blocks one user so the block path is still exercised.
            UserModel(
                userId: "mock_user_123",
                email: "andrew.coyle@example.com",
                isAnonymous: false,
                authProviders: ["apple"],
                displayName: "Andrew Coyle",
                firstName: "Andrew",
                lastName: "Coyle",
                phoneNumber: "+44 7700 900123",
                photoUrl: avatar("andrew"),
                creationDate: now.addingTimeInterval(-420 * day),
                creationVersion: "1.0.0",
                lastSignInDate: now,
                submittedEmail: "andrew.coyle@example.com",
                submittedFirstName: "Andrew",
                submittedLastName: "Coyle",
                submittedProfileImage: avatar("andrew"),
                submittedDateOfBirth: birthday(2000, 11, 13),
                submittedGender: .male,
                submittedHeightCentimeters: 178,
                submittedWeightKilograms: 82.4,
                submittedExerciseFrequency: .fiveToSix,
                submittedDailyActivityLevel: .active,
                submittedCardioFitnessLevel: .advanced,
                submittedLengthUnitPreference: .centimeters,
                submittedWeightUnitPreference: .kilograms,
                submittedCurrentGoalId: WeightGoal.mocks.first!.id,
                submittedActiveTrainingProgramId: TrainingProgram.mock.id,
                submittedFavouriteGymProfileId: GymProfileModel.mock.id,
                blockedUserIds: ["user6"],
                // Bob is private and not followed, so his profile shows the request flow.
                followingIds: ["user1", "user3", "user4", "user5"],
                fcmToken: "mock_fcm_token_andrew",
                didCompleteOnboarding: true,
                acceptedHealthDisclaimerVersion: "2025.10.05",
                acceptedHealthDisclaimerDate: now.addingTimeInterval(-420 * day),
                acceptedHealthPrivacyPolicyVersion: "2025.10.05",
                acceptedHealthPrivacyPolicyDate: now.addingTimeInterval(-420 * day)
            ),
            // Long-time powerlifter on imperial units.
            UserModel(
                userId: "user1",
                email: "alice.cooper@example.com",
                isAnonymous: false,
                authProviders: ["google"],
                displayName: "Alice Cooper",
                firstName: "Alice",
                lastName: "Cooper",
                photoUrl: avatar("alice"),
                creationDate: now.addingTimeInterval(-365 * day),
                creationVersion: "1.0.0",
                lastSignInDate: now.addingTimeInterval(-2 * 3600),
                submittedProfileImage: avatar("alice"),
                submittedDateOfBirth: birthday(1991, 4, 2),
                submittedGender: .female,
                submittedHeightCentimeters: 168,
                submittedWeightKilograms: 64.5,
                submittedExerciseFrequency: .fiveToSix,
                submittedDailyActivityLevel: .veryActive,
                submittedCardioFitnessLevel: .elite,
                submittedLengthUnitPreference: .inches,
                submittedWeightUnitPreference: .pounds,
                followingIds: ["mock_user_123", "user3"],
                didCompleteOnboarding: true,
                acceptedHealthDisclaimerVersion: "2025.10.05",
                acceptedHealthDisclaimerDate: now.addingTimeInterval(-365 * day)
            ),
            // Returning after a layoff — modest numbers, lighter training.
            UserModel(
                userId: "user2",
                email: "bob.martinez@example.com",
                isAnonymous: false,
                authProviders: ["apple"],
                displayName: "Bob Martinez",
                firstName: "Bob",
                lastName: "Martinez",
                photoUrl: avatar("bob"),
                creationDate: now.addingTimeInterval(-96 * day),
                creationVersion: "1.0.0",
                lastSignInDate: now.addingTimeInterval(-26 * 3600),
                submittedProfileImage: avatar("bob"),
                submittedDateOfBirth: birthday(1978, 8, 19),
                submittedGender: .male,
                submittedHeightCentimeters: 183,
                submittedWeightKilograms: 96.2,
                submittedExerciseFrequency: .oneToTwo,
                submittedDailyActivityLevel: .sedentary,
                submittedCardioFitnessLevel: .beginner,
                submittedLengthUnitPreference: .inches,
                submittedWeightUnitPreference: .pounds,
                followingIds: ["mock_user_123"],
                isPrivate: true,
                didCompleteOnboarding: true,
                acceptedHealthDisclaimerVersion: "2025.10.05",
                acceptedHealthDisclaimerDate: now.addingTimeInterval(-96 * day)
            ),
            // Endurance-leaning, tracks in metric, mid-cut.
            UserModel(
                userId: "user3",
                email: "charlie.nguyen@example.com",
                isAnonymous: false,
                authProviders: ["google"],
                displayName: "Charlie Nguyen",
                firstName: "Charlie",
                lastName: "Nguyen",
                photoUrl: avatar("charlie"),
                creationDate: now.addingTimeInterval(-210 * day),
                creationVersion: "1.0.0",
                lastSignInDate: now.addingTimeInterval(-5 * 3600),
                submittedProfileImage: avatar("charlie"),
                submittedDateOfBirth: birthday(1985, 6, 15),
                submittedGender: .female,
                submittedHeightCentimeters: 165,
                submittedWeightKilograms: 59.8,
                submittedExerciseFrequency: .threeToFour,
                submittedDailyActivityLevel: .moderate,
                submittedCardioFitnessLevel: .intermediate,
                submittedLengthUnitPreference: .centimeters,
                submittedWeightUnitPreference: .kilograms,
                followingIds: ["mock_user_123", "user1"],
                didCompleteOnboarding: true,
                acceptedHealthDisclaimerVersion: "2025.10.05",
                acceptedHealthDisclaimerDate: now.addingTimeInterval(-210 * day)
            ),
            // Newest member of the roster, still light on profile detail.
            UserModel(
                userId: "user4",
                email: "priya.shah@example.com",
                isAnonymous: false,
                authProviders: ["apple"],
                displayName: "Priya Shah",
                firstName: "Priya",
                lastName: "Shah",
                photoUrl: avatar("priya"),
                creationDate: now.addingTimeInterval(-9 * day),
                creationVersion: "1.0.0",
                lastSignInDate: now.addingTimeInterval(-40 * 60),
                submittedProfileImage: avatar("priya"),
                submittedDateOfBirth: birthday(1999, 2, 27),
                submittedGender: .female,
                submittedHeightCentimeters: 160,
                submittedWeightKilograms: 55.1,
                submittedExerciseFrequency: .threeToFour,
                submittedDailyActivityLevel: .light,
                submittedCardioFitnessLevel: .novice,
                submittedLengthUnitPreference: .centimeters,
                submittedWeightUnitPreference: .kilograms,
                followingIds: ["mock_user_123"],
                didCompleteOnboarding: true,
                acceptedHealthDisclaimerVersion: "2025.10.05",
                acceptedHealthDisclaimerDate: now.addingTimeInterval(-9 * day)
            ),
            // Daily trainer at the heavier end of the range.
            UserModel(
                userId: "user5",
                email: "dev.patel@example.com",
                isAnonymous: false,
                authProviders: ["google"],
                displayName: "Dev Patel",
                firstName: "Dev",
                lastName: "Patel",
                photoUrl: avatar("dev"),
                creationDate: now.addingTimeInterval(-150 * day),
                creationVersion: "1.0.0",
                lastSignInDate: now.addingTimeInterval(-9 * 3600),
                submittedProfileImage: avatar("dev"),
                submittedDateOfBirth: birthday(1995, 3, 22),
                submittedGender: .male,
                submittedHeightCentimeters: 180,
                submittedWeightKilograms: 88.7,
                submittedExerciseFrequency: .daily,
                submittedDailyActivityLevel: .veryActive,
                submittedCardioFitnessLevel: .advanced,
                submittedLengthUnitPreference: .centimeters,
                submittedWeightUnitPreference: .kilograms,
                followingIds: ["mock_user_123", "user1", "user3"],
                didCompleteOnboarding: true,
                acceptedHealthDisclaimerVersion: "2025.10.05",
                acceptedHealthDisclaimerDate: now.addingTimeInterval(-150 * day)
            ),
            // Blocked by the signed-in user — keeps the block-filtering path covered.
            UserModel(
                userId: "user6",
                email: "david.blocked@example.com",
                isAnonymous: false,
                authProviders: ["apple"],
                displayName: "David Kerr",
                firstName: "David",
                lastName: "Kerr",
                photoUrl: avatar("david"),
                creationDate: now.addingTimeInterval(-45 * day),
                creationVersion: "1.0.0",
                lastSignInDate: now.addingTimeInterval(-4 * 3600),
                submittedProfileImage: avatar("david"),
                submittedDateOfBirth: birthday(1992, 9, 8),
                submittedGender: .male,
                submittedHeightCentimeters: 176,
                submittedWeightKilograms: 74.3,
                submittedExerciseFrequency: .oneToTwo,
                submittedDailyActivityLevel: .light,
                submittedCardioFitnessLevel: .beginner,
                blockedUserIds: ["mock_user_123"],
                didCompleteOnboarding: true,
                acceptedHealthDisclaimerVersion: "2025.10.05"
            ),
            // Mid-onboarding, anonymous — exercises the partial-profile UI.
            UserModel(
                userId: "user7",
                isAnonymous: true,
                authProviders: ["anonymous"],
                creationDate: now.addingTimeInterval(-2 * 3600),
                creationVersion: "1.0.0",
                lastSignInDate: now.addingTimeInterval(-15 * 60),
                submittedFirstName: "Sam",
                submittedDateOfBirth: birthday(2003, 12, 1),
                submittedGender: .female,
                submittedHeightCentimeters: 171,
                submittedWeightKilograms: 67.0,
                didCompleteOnboarding: false
            )
        ].map { $0.withUsername(mockUsernames[$0.userId]) }
    }

}

// MARK: - Usernames

extension UserModel {

    /// Handles for the mock roster, by user id. `user7` is left without one, so the unset state is
    /// exercised too. `MockUserQueryService` seeds its reservations from this and `mockExisting`.
    static let mockUsernames: [String: String] = [
        "mock_user_123": "andrew",
        "user1": "alice",
        "user2": "bob_lifts",
        "user3": "charlie.c",
        "user4": "priya_runs",
        "user5": "dev.patel",
        "user6": "david_s"
    ]

    func withUsername(_ username: String?) -> Self {
        var copy = self
        copy.username = username
        return copy
    }
}
