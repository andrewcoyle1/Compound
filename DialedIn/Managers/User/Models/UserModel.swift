//
//  UserModel.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/9/24.
//
import Foundation
import SwiftUI

struct UserModel: DataSyncModelProtocol, Equatable {
    
    var id: String {
        userId
    }
    
    // These values come from the user's Auth info
    let userId: String
    let email: String?
    let isAnonymous: Bool?
    let authProviders: [String]?
    let displayName: String?
    let firstName: String?
    let lastName: String?
    let phoneNumber: String?
    let photoUrl: String?
    let creationDate: Date?
    let creationVersion: String?
    let lastSignInDate: Date?
    
    // These values are submitted by the user
    let submittedEmail: String?
    let submittedFirstName: String?
    let submittedLastName: String?
    let submittedProfileImage: String?
    let submittedDateOfBirth: Date?
    let submittedGender: Gender?
    let submittedHeightCentimeters: Double?
    let submittedWeightKilograms: Double?
    let submittedExerciseFrequency: ExerciseFrequency?
    let submittedDailyActivityLevel: ActivityLevel?
    let submittedCardioFitnessLevel: CardioFitnessLevel?
    let submittedLengthUnitPreference: LengthUnitPreference?
    let submittedWeightUnitPreference: WeightUnitPreference?
    let submittedDistanceUnitPreference: DistanceUnitPreference?
    let submittedCurrentGoalId: String?
    let submittedFavouriteGymProfileId: String?
    let submittedActiveTrainingProgramId: String?
    /// Legacy: the token now lives in `PrivateUserSettings`. Still written for one release so the
    /// deployed Cloud Function keeps finding it; kept decodable so old documents parse.
    let fcmToken: String?
    let blockedUserIds: [String]?
    let followingIds: [String]?
    /// A private profile must accept a follow request before anyone follows it, is left out of
    /// suggestions, and shows non-followers only its header and counts.
    let isPrivate: Bool?
    /// Legacy per-type opt-outs for social pushes. They now live in `PrivateUserSettings`, and the
    /// app no longer writes them here; kept decodable so old documents parse, and the Cloud Function
    /// falls back to them for users who have not written the private document yet.
    let socialPushLikes: Bool?
    let socialPushComments: Bool?
    let socialPushFollows: Bool?
    let socialPushNudges: Bool?
    let socialPushMentions: Bool?
    var didCompleteOnboarding: Bool
    let acceptedHealthDisclaimerVersion: String?
    let acceptedHealthDisclaimerDate: Date?
    let acceptedHealthPrivacyPolicyVersion: String?
    let acceptedHealthPrivacyPolicyDate: Date?
    // MARK: - CircleGoals
    /// Finished sessions a week the user is aiming for, 1–7. Nil until they pick one; read through
    /// `CircleWeek.goal(for:)`, which shows it as 3.
    let weeklySessionGoal: Int?

    /// The health notices the app currently presents, and the versions an acceptance is recorded
    /// against. `HealthDisclaimerPresenter` stamps these onto the profile when the user confirms.
    ///
    /// Bumping either string sends every user who accepted an earlier one back through the
    /// disclaimer on their next launch, which is the point: `inferredOnboardingStep` compares
    /// against these rather than checking that some version was accepted.
    static let currentHealthDisclaimerVersion = "2025.10.05"
    static let currentHealthPrivacyPolicyVersion = "2025.10.05"

    init(
        userId: String,
        email: String? = nil,
        isAnonymous: Bool? = nil,
        authProviders: [String]? = nil,
        displayName: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        phoneNumber: String? = nil,
        photoUrl: String? = nil,
        creationDate: Date? = nil,
        creationVersion: String? = nil,
        lastSignInDate: Date? = nil,
        submittedEmail: String? = nil,
        submittedFirstName: String? = nil,
        submittedLastName: String? = nil,
        submittedProfileImage: String? = nil,
        submittedDateOfBirth: Date? = nil,
        submittedGender: Gender? = nil,
        submittedHeightCentimeters: Double? = nil,
        submittedWeightKilograms: Double? = nil,
        submittedExerciseFrequency: ExerciseFrequency? = nil,
        submittedDailyActivityLevel: ActivityLevel? = nil,
        submittedCardioFitnessLevel: CardioFitnessLevel? = nil,
        submittedLengthUnitPreference: LengthUnitPreference? = nil,
        submittedWeightUnitPreference: WeightUnitPreference? = nil,
        submittedDistanceUnitPreference: DistanceUnitPreference? = nil,
        submittedCurrentGoalId: String? = nil,
        submittedActiveTrainingProgramId: String? = nil,
        submittedFavouriteGymProfileId: String? = nil,
        blockedUserIds: [String]? = nil,
        followingIds: [String]? = nil,
        isPrivate: Bool? = nil,
        socialPushLikes: Bool? = nil,
        socialPushComments: Bool? = nil,
        socialPushFollows: Bool? = nil,
        socialPushNudges: Bool? = nil,
        socialPushMentions: Bool? = nil,
        fcmToken: String? = nil,
        didCompleteOnboarding: Bool = false,
        acceptedHealthDisclaimerVersion: String? = nil,
        acceptedHealthDisclaimerDate: Date? = nil,
        acceptedHealthPrivacyPolicyVersion: String? = nil,
        acceptedHealthPrivacyPolicyDate: Date? = nil,
        weeklySessionGoal: Int? = nil
    ) {
        self.userId = userId
        self.email = email
        self.isAnonymous = isAnonymous
        self.authProviders = authProviders
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.photoUrl = photoUrl
        self.creationDate = creationDate
        self.creationVersion = creationVersion
        self.lastSignInDate = lastSignInDate
        self.submittedFirstName = submittedFirstName
        self.submittedLastName = submittedLastName
        self.submittedEmail = submittedEmail
        self.submittedProfileImage = submittedProfileImage
        self.submittedDateOfBirth = submittedDateOfBirth
        self.submittedGender = submittedGender
        self.submittedHeightCentimeters = submittedHeightCentimeters
        self.submittedWeightKilograms = submittedWeightKilograms
        self.submittedExerciseFrequency = submittedExerciseFrequency
        self.submittedDailyActivityLevel = submittedDailyActivityLevel
        self.submittedCardioFitnessLevel = submittedCardioFitnessLevel
        self.submittedLengthUnitPreference = submittedLengthUnitPreference
        self.submittedWeightUnitPreference = submittedWeightUnitPreference
        self.submittedDistanceUnitPreference = submittedDistanceUnitPreference
        self.submittedCurrentGoalId = submittedCurrentGoalId
        self.submittedActiveTrainingProgramId = submittedActiveTrainingProgramId
        self.submittedFavouriteGymProfileId = submittedFavouriteGymProfileId
        self.blockedUserIds = blockedUserIds
        self.followingIds = followingIds
        self.isPrivate = isPrivate
        self.socialPushLikes = socialPushLikes
        self.socialPushComments = socialPushComments
        self.socialPushFollows = socialPushFollows
        self.socialPushNudges = socialPushNudges
        self.socialPushMentions = socialPushMentions
        self.fcmToken = fcmToken
        self.didCompleteOnboarding = didCompleteOnboarding
        self.acceptedHealthDisclaimerVersion = acceptedHealthDisclaimerVersion
        self.acceptedHealthDisclaimerDate = acceptedHealthDisclaimerDate
        self.acceptedHealthPrivacyPolicyVersion = acceptedHealthPrivacyPolicyVersion
        self.acceptedHealthPrivacyPolicyDate = acceptedHealthPrivacyPolicyDate
        self.weeklySessionGoal = weeklySessionGoal
    }
    
    init(auth: UserAuthInfo, creationVersion: String?) {
        self.init(
            userId: auth.uid,
            email: auth.email,
            isAnonymous: auth.isAnonymous,
            authProviders: auth.authProviders.map({ $0.rawValue }),
            displayName: auth.displayName,
            firstName: auth.firstName,
            lastName: auth.lastName,
            phoneNumber: auth.phoneNumber,
            photoUrl: auth.photoURL?.absoluteString,
            creationDate: auth.creationDate,
            creationVersion: creationVersion,
            lastSignInDate: auth.lastSignInDate
        )
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case isAnonymous = "is_anonymous"
        case authProviders = "auth_providers"
        case displayName = "display_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case phoneNumber = "phone_number"
        case photoUrl = "photo_url"
        case creationDate = "creation_date"
        case creationVersion = "creation_version"
        case lastSignInDate = "last_sign_in_date"
        case submittedFirstName = "submitted_first_name"
        case submittedLastName = "submitted_last_name"
        case submittedEmail = "submitted_email"
        case submittedProfileImage = "submitted_profile_image"
        case submittedDateOfBirth = "submitted_date_of_birth"
        case submittedGender = "submitted_gender"
        case submittedHeightCentimeters = "submitted_height_centimeters"
        case submittedWeightKilograms = "submitted_weight_kilograms"
        case submittedExerciseFrequency = "submitted_exercise_frequency"
        case submittedDailyActivityLevel = "submitted_daily_activity_level"
        case submittedCardioFitnessLevel = "submitted_cardio_fitness_level"
        case submittedLengthUnitPreference = "submitted_length_unit_preference"
        case submittedWeightUnitPreference = "submitted_weight_unit_preference"
        case submittedDistanceUnitPreference = "submitted_distance_unit_preference"
        case submittedCurrentGoalId = "submitted_current_goal_id"
        case submittedActiveTrainingProgramId = "submitted_active_training_program_id"
        case submittedFavouriteGymProfileId = "submitted_favourite_gym_profile_id"
        case didCompleteOnboarding = "did_complete_onboarding"
        case blockedUserIds = "blocked_user_ids"
        case followingIds = "following_ids"
        case isPrivate = "is_private"
        case socialPushLikes = "social_push_likes"
        case socialPushComments = "social_push_comments"
        case socialPushFollows = "social_push_follows"
        case socialPushNudges = "social_push_nudges"
        case socialPushMentions = "social_push_mentions"
        case fcmToken = "fcm_token"
        case acceptedHealthDisclaimerVersion = "accepted_health_disclaimer_version"
        case acceptedHealthDisclaimerDate = "accepted_health_disclaimer_date"
        case acceptedHealthPrivacyPolicyVersion = "accepted_health_privacy_policy_version"
        case acceptedHealthPrivacyPolicyDate = "accepted_health_privacy_policy_date"
        // MARK: - Usernames
        case username
        case weeklySessionGoal = "weekly_session_goal"
    }
    
    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "user_\(CodingKeys.userId.rawValue)": userId,
            "user_\(CodingKeys.email.rawValue)": email,
            "user_\(CodingKeys.isAnonymous.rawValue)": isAnonymous,
            "user_\(CodingKeys.authProviders.rawValue)": authProviders?.sorted().joined(separator: ", "),
            "user_\(CodingKeys.displayName.rawValue)": displayNameCalculated,
            "user_\(CodingKeys.firstName.rawValue)": firstNameCalculated,
            "user_\(CodingKeys.lastName.rawValue)": lastNameCalculated,
            "user_common_name_calc": commonNameCalculated,
            "user_full_name_calc": fullNameCalculated,
            "user_\(CodingKeys.phoneNumber.rawValue)": phoneNumber,
            "user_\(CodingKeys.photoUrl.rawValue)": photoUrl,
            "user_\(CodingKeys.creationDate.rawValue)": creationDate,
            "user_\(CodingKeys.creationVersion.rawValue)": creationVersion,
            "user_\(CodingKeys.lastSignInDate.rawValue)": lastSignInDate,
            "user_\(CodingKeys.submittedFirstName.rawValue)": submittedFirstName,
            "user_\(CodingKeys.submittedLastName.rawValue)": submittedLastName,
            "user_\(CodingKeys.submittedEmail.rawValue)": submittedEmail,
            "user_\(CodingKeys.submittedProfileImage.rawValue)": submittedProfileImage,
            "user_\(CodingKeys.submittedDateOfBirth.rawValue)": submittedDateOfBirth,
            "user_\(CodingKeys.submittedGender.rawValue)": submittedGender?.description,
            "user_\(CodingKeys.submittedHeightCentimeters.rawValue)": submittedHeightCentimeters,
            "user_\(CodingKeys.submittedWeightKilograms.rawValue)": submittedWeightKilograms,
            "user_\(CodingKeys.submittedExerciseFrequency.rawValue)": submittedExerciseFrequency?.rawValue,
            "user_\(CodingKeys.submittedDailyActivityLevel.rawValue)": submittedDailyActivityLevel?.rawValue,
            "user_\(CodingKeys.submittedCardioFitnessLevel.rawValue)": submittedCardioFitnessLevel?.rawValue,
            "user_\(CodingKeys.submittedLengthUnitPreference.rawValue)": submittedLengthUnitPreference?.rawValue,
            "user_\(CodingKeys.submittedWeightUnitPreference.rawValue)": submittedWeightUnitPreference?.rawValue,
            "user_\(CodingKeys.submittedDistanceUnitPreference.rawValue)": submittedDistanceUnitPreference?.rawValue,
            "user_\(CodingKeys.submittedCurrentGoalId.rawValue)": submittedCurrentGoalId,
            "user_\(CodingKeys.submittedActiveTrainingProgramId.rawValue)": submittedActiveTrainingProgramId,
            "user_\(CodingKeys.submittedFavouriteGymProfileId.rawValue)": submittedFavouriteGymProfileId,
            "user_\(CodingKeys.blockedUserIds.rawValue)": blockedUserIds,
            "user_has_\(CodingKeys.fcmToken.rawValue)": (fcmToken?.count ?? 0) > 0,
            "user_\(CodingKeys.didCompleteOnboarding.rawValue)": didCompleteOnboarding,
            "user_\(CodingKeys.acceptedHealthDisclaimerVersion.rawValue)": acceptedHealthDisclaimerVersion,
            "user_\(CodingKeys.acceptedHealthDisclaimerDate.rawValue)": acceptedHealthDisclaimerDate,
            "user_\(CodingKeys.acceptedHealthPrivacyPolicyVersion.rawValue)": acceptedHealthPrivacyPolicyVersion,
            "user_\(CodingKeys.acceptedHealthPrivacyPolicyDate.rawValue)": acceptedHealthPrivacyPolicyDate
        ]
        return dict.compactMapValues({ $0 })
    }
    
    /// First name, per user's Auth info
    var firstNameCalculated: String? {
        if let submittedFirstName,
        !submittedFirstName.isEmpty {
            return submittedFirstName
        } else if let firstName,
        !firstName.isEmpty {
            return firstName
        } else {
            return nil
        }
    }
    
    /// Last name, per user's Auth info
    var lastNameCalculated: String? {
        if let submittedLastName,
        !submittedLastName.isEmpty {
            return submittedLastName
        } else if let lastName,
        !lastName.isEmpty {
            return lastName
        } else {
            return nil
        }
    }
    
    /// Display name, per user's Auth info
    var displayNameCalculated: String? {
        guard let displayName, !displayName.isEmpty else { return nil }
        return displayName
    }
    
    /// Whether this user has blocked `userId`. Every surface that shows another person's content
    /// asks this, so a block hides them everywhere at once.
    func hasBlocked(_ userId: String) -> Bool {
        blockedUserIds?.contains(userId) ?? false
    }

    /// Full name, per user's Auth info
    var fullNameCalculated: String? {
        if let firstNameCalculated, let lastNameCalculated {
            return firstNameCalculated + " " + lastNameCalculated
        } else if let firstNameCalculated {
            return firstNameCalculated
        } else if let lastNameCalculated {
            return lastNameCalculated
        }
        return nil
    }
    
    /// Try to get the "best" common name for the user (ie. their preferred first name). Use this most of the time.
    var commonNameCalculated: String? {
        if let displayNameCalculated {
            return displayNameCalculated
        } else if let firstNameCalculated {
            return firstNameCalculated
        }
        return nil
    }
    
    /// Try to get submitted profile image, otherwise user image from user's auth (if available).
    var profileImageNameCalculated: String? {
        if let submittedProfileImage {
            return submittedProfileImage
        } else if let photoUrl {
            return photoUrl
        }
        return nil
    }
    
    /// Try to get submitted email, otherwise user email from user's auth (if available).
    var emailCalculated: String? {
        if let submittedEmail {
            return submittedEmail
        } else if let email {
            return email
        }
        return nil
    }

    /// Infer the user's current onboarding step from which fields have been filled.
    var inferredOnboardingStep: OnboardingStep {
        guard submittedDateOfBirth != nil,
              submittedGender != nil,
              submittedHeightCentimeters != nil,
              submittedWeightKilograms != nil,
              submittedExerciseFrequency != nil,
              submittedDailyActivityLevel != nil,
              submittedCardioFitnessLevel != nil else {
            return .completeAccountSetup
        }
        // Compared against the current version, not merely checked for presence. A health notice
        // is only consent to the wording the user actually read, so a reissued disclaimer has to
        // be accepted again — accepting the 2025 text cannot stand in for agreeing to a later one.
        //
        // Only the disclaimer version is compared, because the one screen that records consent
        // stamps both it and the privacy policy together, so they cannot drift apart in practice.
        guard acceptedHealthDisclaimerVersion == Self.currentHealthDisclaimerVersion else {
            return .healthDisclaimer
        }
        guard submittedCurrentGoalId != nil else { return .goalSetting }
        guard submittedFavouriteGymProfileId != nil else { return .gymProfileSetup }
        guard submittedActiveTrainingProgramId != nil else { return .trainingProgramSetup }
        guard didCompleteOnboarding else { return .customiseProgram }
        return .complete
    }
    
    mutating func markDidCompleteOnboarding() {
        didCompleteOnboarding = true
    }

    // MARK: - Usernames

    /// The user's unique handle, lowercase and shown exactly as stored — see `Username`. Set only
    /// through `UserManager.claimUsername`, which reserves `usernames/{handle}` first. A `var` with
    /// a default so the memberwise init and every existing call site are untouched.
    var username: String?
}

enum Gender: String, Codable, Sendable {
    case male
    case female
    var description: String {
        switch self {
        case .male: return String(localized: "Male")
        case .female: return String(localized: "Female")
        }
    }
}

/// Governs height and every body measurement. The abbreviation and display name describe those
/// uses, not distance — see `DistanceUnitPreference` for how far you have travelled.
enum LengthUnitPreference: String, Codable, Sendable, CaseIterable {
    case centimeters
    case inches

    var abbreviation: String {
        switch self {
        case .centimeters: return "cm"
        case .inches: return "\""
        }
    }

    /// `abbreviation` gives `"` for inches, which reads as a stray quote mark in a card caption
    /// under a number. Body measurements use this instead.
    var measurementAbbreviation: String {
        switch self {
        case .centimeters: return "cm"
        case .inches: return "in"
        }
    }

    var displayName: String {
        switch self {
        case .centimeters: return String(localized: "Centimeters")
        case .inches: return String(localized: "Feet & Inches")
        }
    }

}

enum DistanceUnitPreference: String, Codable, Sendable, CaseIterable {
    case kilometers
    case miles

    var abbreviation: String {
        switch self {
        case .kilometers: return "km"
        case .miles: return "mi"
        }
    }

    var displayName: String {
        switch self {
        case .kilometers: return String(localized: "Kilometers & Metres")
        case .miles: return String(localized: "Miles & Yards")
        }
    }

}

enum WeightUnitPreference: String, Codable, Sendable {
    case kilograms
    case pounds
    
    var abbreviation: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lbs"
        }
    }
    
    var displayName: String {
        switch self {
        case .kilograms: return String(localized: "Kilograms")
        case .pounds: return String(localized: "Pounds")
        }
    }

}

/// Not yet wired to anything. The Units screen used to offer a 12/24-hour picker that persisted
/// nowhere and changed nothing; honouring it means routing every `.shortened` time format in the
/// app through a shared formatter, which is its own piece of work. Kept so that work has a type
/// to start from.
enum ClockUnitPreference: String, Codable, Sendable {
    case twelveHour
    case twentyFourHour
    
    var abbreviation: String {
        switch self {
        case .twelveHour: return "12hr"
        case .twentyFourHour: return "24hr"
        }
    }
    
    var displayName: String {
        switch self {
        case .twelveHour: return String(localized: "12 Hour")
        case .twentyFourHour: return String(localized: "24 Hour")
        }
    }

}

enum OnboardingStep: String, Codable, Sendable {
    case auth
    case subscription
    case completeAccountSetup
    case notifications
    case healthData
    case healthDisclaimer
    case goalSetting
    case gymProfileSetup
    case trainingProgramSetup
    case customiseProgram
    case complete
    
    var eventParameters: [String: Any] {
        let params: [String: Any] = [
            "onboarding_step": self
        ]

        return params
    }
}

extension OnboardingStep {
    var orderIndex: Int {
        switch self {
        case .auth: return 0
        case .subscription: return 1
        case .completeAccountSetup: return 2
        case .notifications: return 3
        case .healthData: return 4
        case .healthDisclaimer: return 5
        case .goalSetting: return 6
        case .trainingProgramSetup: return 7
        case .gymProfileSetup: return 8
        case .customiseProgram: return 9
        case .complete: return 10
        }
    }
}
