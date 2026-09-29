//
//  UserManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/14/24.
//

import SwiftUI
import SwiftfulAuthenticating

@Observable
@MainActor
class UserManager {

    let queryService: any UserQueryService
    private let userSyncEngine: DocumentSyncEngine<UserModel>
    private let followingUsersSyncEngine: CollectionSyncEngine<UserModel>
    private let privateSettingsSyncEngine: DocumentSyncEngine<PrivateUserSettings>

    var currentUser: UserModel? { userSyncEngine.currentDocument }

    /// The owner-only settings document. A user who has never written it reads as all defaults.
    var privateSettings: PrivateUserSettings { privateSettingsSyncEngine.currentDocument ?? PrivateUserSettings() }
    /// Private profiles the reader has asked to follow and is waiting on. Requests live under their
    /// target, so this is kept here: seeded at sign-in, then changed by send and cancel.
    private(set) var sentFollowRequestIds: Set<String> = []

    /// Pending requests to follow the reader, newest first.
    private(set) var incomingFollowRequests: [FollowRequestModel] = []

    /// Blocked accounts are left out even while their follow is still being taken back.
    var followingUsers: [UserModel] {
        followingUsersSyncEngine.currentCollection.filter { !isBlocked($0) }
    }

    private func isBlocked(_ user: UserModel) -> Bool {
        isBlocked(id: user.userId)
    }

    private func isBlocked(id: String) -> Bool {
        currentUser?.hasBlocked(id) ?? false
    }

    init(
        queryService: any UserQueryService,
        userSyncEngine: DocumentSyncEngine<UserModel>,
        followingUsersSyncEngine: CollectionSyncEngine<UserModel>,
        privateSettingsSyncEngine: DocumentSyncEngine<PrivateUserSettings>
    ) {
        self.queryService = queryService
        self.userSyncEngine = userSyncEngine
        self.followingUsersSyncEngine = followingUsersSyncEngine
        self.privateSettingsSyncEngine = privateSettingsSyncEngine
    }
    
    func signIn(auth: UserAuthInfo, isNewUser: Bool) async throws {
        if isNewUser {
            // New user: create their Firestore document from auth data.
            let user = UserModel(auth: auth, creationVersion: Utilities.appVersion)
            try await userSyncEngine.saveDocument(user)
        }
        try await userSyncEngine.startListening(documentId: auth.uid)
        try await privateSettingsSyncEngine.startListening(documentId: PrivateUserSettings.documentId)
        // Best effort: a failed read leaves the buttons on "Follow" and the list empty, which a
        // later fetch corrects.
        sentFollowRequestIds = Set((try? await queryService.fetchSentFollowRequestTargetIds(requesterId: auth.uid)) ?? [])
        startListeningToFollowRequests(userId: auth.uid)
    }
    
    /// `startListening` returns before the listener's first value lands, so straight after sign-in
    /// `currentUser` can still be nil on a fresh install. Anything that needs the profile at that
    /// moment — the following ids that drive the feed and the circle — reads it through this.
    func currentUserOrFetched(userId: String) async -> UserModel? {
        if let currentUser { return currentUser }
        return try? await userSyncEngine.getDocumentAsync(id: userId)
    }

    func signOut() {
        userSyncEngine.stopListening()
        followingUsersSyncEngine.stopListening()
        privateSettingsSyncEngine.stopListening()
        sentFollowRequestIds = []
        stopListeningToFollowRequests()
        incomingFollowRequests = []
    }

    func refreshFollowingUsers(followingIds: [String]) async {
        guard !followingIds.isEmpty else {
            followingUsersSyncEngine.stopListening()
            return
        }
        await followingUsersSyncEngine.startListening { query in
            FollowingQueries.users(query, followingIds: followingIds)
        }
    }
    
//    /// Log In
//    func logIn(auth: UserAuthInfo, isNewUser: Bool) async throws {
//        if isNewUser {
//            // New user: create their Firestore document from auth data.
//            let user = UserModel(auth: auth, creationVersion: Utilities.appVersion)
//            logManager?.trackEvent(event: Event.logInStart(user: user))
//            try await remote.saveUser(user: user)
//            logManager?.trackEvent(event: Event.logInSuccess(user: user))
//        } else {
//            // Returning user: fetch their existing document so currentUser is correct
//            // before any routing decisions are made. Writing an auth-only stub would
//            // overwrite non-optional fields like didCompleteOnboarding with defaults.
//            logManager?.trackEvent(event: Event.logInStart(user: currentUser))
//            let storedUser = try await remote.getUser(userId: auth.uid)
//            logManager?.trackEvent(event: Event.logInSuccess(user: storedUser))
//        }
//
//        addCurrentUserListener(userId: auth.uid)
//    }

    // MARK: - Personal Info
    
    func updateUser(data: [String: any DMCodableSendable]) async throws {
        try await userSyncEngine.updateDocument(data: data)
    }
    
    func updateUserName(firstName: String? = nil, lastName: String? = nil) async throws {
        var data: [String: any DMCodableSendable] = [:]
        if let firstName = firstName {
            data["submitted_first_name"] = firstName
        }
        if let lastName = lastName {
            data["submitted_last_name"] = lastName
        }
        try await userSyncEngine.updateDocument(data: data)
    }

    func updateUserEmail(email: String) async throws {
        try await userSyncEngine.updateDocument(data: ["submitted_email": email])
    }

    // MARK: - Image URL
    
    func updateProfileImage(image: PlatformImage) async throws {
        guard let userId = currentUser?.userId else {
            throw UserManagerError.noUserId
        }
        
        let path = "users/\(userId)/profile"
        let url = try await FirebaseImageUploadService().uploadImage(image: image, path: path)

        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.submittedProfileImage.rawValue: url.absoluteString
        ])
    }

    func updateGender(gender: Gender) async throws {
        try await userSyncEngine.updateDocument(data: [UserModel.CodingKeys.submittedGender.rawValue: gender.rawValue])
    }

    func updateDateOfBirth(dob: Date) async throws {
        try await userSyncEngine.updateDocument(data: [UserModel.CodingKeys.submittedDateOfBirth.rawValue: dob])
    }
    
    func updateUserHeight(heightInCentimeters: Double, lengthUnitPreference: LengthUnitPreference) async throws {
        try await userSyncEngine.updateDocument(
            data: [
                UserModel.CodingKeys.submittedHeightCentimeters.rawValue: heightInCentimeters,
                UserModel.CodingKeys.submittedLengthUnitPreference.rawValue: lengthUnitPreference.rawValue
            ]
        )
    }

    func updateUserWeight(weightInKilograms: Double, weightUnitPreference: WeightUnitPreference) async throws {
        try await userSyncEngine.updateDocument(
            data: [
                UserModel.CodingKeys.submittedWeightKilograms.rawValue: weightInKilograms,
                UserModel.CodingKeys.submittedWeightUnitPreference.rawValue: weightUnitPreference.rawValue
            ]
        )
    }
    
    /// Unit preferences on their own. The height and weight updates above each write a measurement
    /// alongside its unit, which the settings screen has no business changing.
    func updateUnitPreferences(
        length: LengthUnitPreference,
        weight: WeightUnitPreference,
        distance: DistanceUnitPreference
    ) async throws {
        try await userSyncEngine.updateDocument(
            data: [
                UserModel.CodingKeys.submittedLengthUnitPreference.rawValue: length.rawValue,
                UserModel.CodingKeys.submittedWeightUnitPreference.rawValue: weight.rawValue,
                UserModel.CodingKeys.submittedDistanceUnitPreference.rawValue: distance.rawValue
            ]
        )
    }

    func updateUserExerciseFrequency(exerciseFrequency: ExerciseFrequency) async throws {
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.submittedExerciseFrequency.rawValue: exerciseFrequency.rawValue
        ])
    }
    
    func updateUserDailyActivityLevel(activityLevel: ActivityLevel) async throws {
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.submittedDailyActivityLevel.rawValue: activityLevel.rawValue
        ])
    }

    func updateUserCardioFitnessLevel(cardioFitnessLevel: CardioFitnessLevel) async throws {
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.submittedCardioFitnessLevel.rawValue: cardioFitnessLevel.rawValue
        ])
    }
    
    func saveUserCompleteAccountSetup(input data: [String: any DMCodableSendable]) async throws {
        try await userSyncEngine.updateDocument(data: data)
    }
        
    // MARK: Update Active Training Program
    
    func updateActiveTrainingProgramId(programId: String?) async throws {
        guard let activeProgramId = programId else { return }
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.submittedActiveTrainingProgramId.rawValue: activeProgramId
        ])
    }

    // MARK: Update Favourite Gym Profile

    func updateFavouriteGymProfileId(profileId: String?) async throws {
        guard let favouriteGymProfileId = profileId else { return }
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.submittedFavouriteGymProfileId.rawValue: favouriteGymProfileId
        ])
    }
    
    func saveOnboardingCompleteForCurrentUser() async throws {
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.didCompleteOnboarding.rawValue: true
        ])
    }

    // User FCM Token
    
    /// Written to the owner-only private document, merged over what is there. `saveDocument` is a
    /// merge, so this cannot fail on a document that does not exist yet the way an update would.
    func saveUserFCMToken(token: String) async throws {
        var settings = privateSettings
        settings.fcmToken = token
        settings.timezone = TimeZone.current.identifier
        try await privateSettingsSyncEngine.saveDocument(settings)
        // ponytail: legacy public copy for the Cloud Function deployed before the private doc.
        // Drop this write one release after the functions deploy that reads users/{uid}/private/settings.
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.fcmToken.rawValue: token
        ])
    }

    // MARK: - Goal Settings
    func updateCurrentGoalId(goalId: String?) async throws {
        guard let currentGoalId = goalId else { return }
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.submittedCurrentGoalId.rawValue: currentGoalId
        ])
    }
    
    // MARK: - Consents
    func updateHealthConsents(disclaimerVersion: String, privacyVersion: String, acceptedAt: Date = Date()) async throws {
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.acceptedHealthDisclaimerVersion.rawValue: disclaimerVersion,
            UserModel.CodingKeys.acceptedHealthDisclaimerDate.rawValue: acceptedAt,
            UserModel.CodingKeys.acceptedHealthPrivacyPolicyVersion.rawValue: privacyVersion,
            UserModel.CodingKeys.acceptedHealthPrivacyPolicyDate.rawValue: acceptedAt
        ])
    }
    
    // MARK: - User Lookup

    func getUser(userId: String) async throws -> UserModel {
        try await userSyncEngine.getDocumentAsync(id: userId)
    }

    // MARK: - User Followers

    func fetchFollowers(userId: String) async throws -> [UserModel] {
        try await queryService.fetchFollowers(userId: userId).filter { !isBlocked($0) }
    }

    // MARK: - User Search

    func searchUsers(query: String) async throws -> [UserModel] {
        try await queryService.searchUsers(query: query).filter { !isBlocked($0) }
    }

    /// People worth following when the reader follows nobody: the newest accounts, minus the
    /// reader, anyone they already follow, and anyone they have blocked.
    func fetchSuggestedUsers(limit: Int = 10) async throws -> [UserModel] {
        let excluded = Set(
            [currentUser?.userId].compactMap { $0 }
            + (currentUser?.followingIds ?? [])
            + (currentUser?.blockedUserIds ?? [])
        )
        // Over-fetch so the exclusions do not leave the list short.
        return try await queryService.fetchSuggestedUsers(limit: limit + excluded.count)
            .filter { !excluded.contains($0.userId) && $0.isPrivate != true }
            .prefix(limit)
            .map { $0 }
    }

    func updatePrivacy(isPrivate: Bool) async throws {
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.isPrivate.rawValue: isPrivate
        ])
    }

    func updateSocialNotificationPreferences(type: ActivityNotificationModel.ActivityType, isEnabled: Bool) async throws {
        try await privateSettingsSyncEngine.saveDocument(privateSettings.settingSocialPush(type, isEnabled: isEnabled))
    }

    // MARK: - User Blocking

    /// Blocking also takes back the reader's follow, in the same write, so there is no moment where
    /// the block has landed and the follow has not.
    func blockUser(userId: String) async throws {
        var blockList = currentUser?.blockedUserIds ?? []
        if !blockList.contains(userId) {
            blockList.append(userId)
        }
        let followingIds = (currentUser?.followingIds ?? []).filter { $0 != userId }

        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.blockedUserIds.rawValue: blockList,
            UserModel.CodingKeys.followingIds.rawValue: followingIds
        ])
    }
    
    func unblockUser(userId: String) async throws {
        var blockedUserIds = currentUser?.blockedUserIds ?? []
        if let index = blockedUserIds.firstIndex(of: userId) {
            blockedUserIds.remove(at: index)
        }

        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.blockedUserIds.rawValue: blockedUserIds
        ])
    }

    // MARK: - User Following

    func followUser(userId: String) async throws {
        var followingIds = currentUser?.followingIds ?? []
        if !followingIds.contains(userId) {
            followingIds.append(userId)
        }

        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.followingIds.rawValue: followingIds
        ])
    }

    func unfollowUser(userId: String) async throws {
        var followingIds = currentUser?.followingIds ?? []
        if let index = followingIds.firstIndex(of: userId) {
            followingIds.remove(at: index)
        }

        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.followingIds.rawValue: followingIds
        ])
    }
    
    // MARK: - Follow Requests

    /// Asks to follow a private profile. Nothing is followed until its owner accepts.
    func sendFollowRequest(to user: UserModel) async throws {
        guard let requester = currentUser else { throw UserManagerError.noUserId }
        let request = FollowRequestModel(
            requesterId: requester.userId,
            requesterName: requester.fullNameCalculated ?? "Someone",
            requesterImageUrl: requester.profileImageNameCalculated,
            dateCreated: .now,
            status: .pending
        )
        try await queryService.sendFollowRequest(request, targetId: user.userId)
        sentFollowRequestIds.insert(user.userId)
    }

    func cancelFollowRequest(userId: String) async throws {
        guard let requesterId = currentUser?.userId else { throw UserManagerError.noUserId }
        try await queryService.deleteFollowRequest(requesterId: requesterId, targetId: userId)
        sentFollowRequestIds.remove(userId)
    }

    func fetchIncomingFollowRequests(userId: String) async throws {
        setIncomingFollowRequests(try await queryService.fetchPendingFollowRequests(userId: userId))
    }

    /// Accepting only writes the status; the `onFollowRequestUpdated` Cloud Function adds the
    /// follow to the requester's document and deletes the request.
    func respondToFollowRequest(requesterId: String, accept: Bool) async throws {
        guard let userId = currentUser?.userId else { throw UserManagerError.noUserId }
        try await queryService.updateFollowRequestStatus(accept ? .accepted : .declined, requesterId: requesterId, targetId: userId)
        incomingFollowRequests.removeAll { $0.requesterId == requesterId }
    }

    func fetchUsers(userIds: [String]) async throws -> [UserModel] {
        guard !userIds.isEmpty else { return [] }
        return try await queryService.fetchUsers(userIds: userIds).filter { !isBlocked($0) }
    }

    // MARK: - User deletion
    
    /// Stops this manager's listeners, then deletes the user document. Everything else — the
    /// subcollections (private settings included) and the user's traces in other people's data —
    /// is deleted by the `onUserDeleted` Cloud Function, so no listener here is left attached to a
    /// document it is about to lose. Does not sign out of Auth.
    func deleteCurrentUser(userId: String) async throws {
        signOut()
        try await userSyncEngine.deleteDocument(id: userId)
    }
        
    enum UserManagerError: LocalizedError {
        case noUserId
        
        var errorDescription: String? {
            switch self {
            case .noUserId:
                return "No user id available"
            }
        }
    }

    // MARK: - Follow Requests Live

    /// Stops the pending-request listener started at sign-in.
    @ObservationIgnored private var stopFollowRequestsListener: (@MainActor () -> Void)?

    private func startListeningToFollowRequests(userId: String) {
        stopListeningToFollowRequests()
        stopFollowRequestsListener = queryService.listenToPendingFollowRequests(userId: userId) { [weak self] requests in
            self?.setIncomingFollowRequests(requests)
        }
    }

    private func stopListeningToFollowRequests() {
        stopFollowRequestsListener?()
        stopFollowRequestsListener = nil
    }

    private func setIncomingFollowRequests(_ requests: [FollowRequestModel]) {
        incomingFollowRequests = requests
            .filter { !isBlocked(id: $0.requesterId) }
            .sorted { $0.dateCreated > $1.dateCreated }
    }
}

extension CoreInteractor {
    // MARK: UserManager
    
    func setActiveTrainingProgram(programId: String) async throws {
        try await userManager.updateActiveTrainingProgramId(programId: programId)
    }

    var currentUser: UserModel? {
        userManager.currentUser
    }
    
    var userId: String? {
        userManager.currentUser?.userId
    }
        
    var userImageUrl: String? {
        currentUser?.submittedProfileImage
    }
              
    func updateUser(data: [String: any DMCodableSendable]) async throws {
        try await userManager.updateUser(data: data)
    }

    func updateUserName(firstName: String? = nil, lastName: String? = nil) async throws {
        try await userManager.updateUserName(firstName: firstName, lastName: lastName)
    }
        
    func updateDateOfBirth(dob: Date) async throws {
        try await userManager.updateDateOfBirth(dob: dob)
    }
    
    func updateGender(gender: Gender) async throws {
        try await userManager.updateGender(gender: gender)
    }
    
    func updateWeight(userId: String, weight: Double, weightUnitPreference: WeightUnitPreference) async throws {
        try await userManager.updateUserWeight(weightInKilograms: weight, weightUnitPreference: weightUnitPreference)
    }

    func updateUnitPreferences(
        length: LengthUnitPreference,
        weight: WeightUnitPreference,
        distance: DistanceUnitPreference
    ) async throws {
        try await userManager.updateUnitPreferences(length: length, weight: weight, distance: distance)
    }
    
    func saveUserCompleteAccountSetup(input: [String: any DMCodableSendable]) async throws {
        try await userManager.saveUserCompleteAccountSetup(input: input)
    }
    
    // Image URL
    
    func updateProfileImageUrl(image: PlatformImage) async throws {
        try await userManager.updateProfileImage(image: image)
    }
    
    // Active Training Program
    
    func updateActiveTrainingProgramId(programId: String?) async throws {
        try await userManager.updateActiveTrainingProgramId(programId: programId)
    }
    
    // Favourite Gym Profile
    
    func updateFavouriteGymProfileId(profileId: String?) async throws {
        try await userManager.updateFavouriteGymProfileId(profileId: profileId)
    }
    
    // FCM Token
    
    func saveUserFCMToken(token: String) async throws {
        try await userManager.saveUserFCMToken(token: token)
    }

    // Update Metadata
            
    func saveOnboardingComplete() async throws {
        try await userManager.saveOnboardingCompleteForCurrentUser()
    }

    // Goal Settings
    func updateCurrentGoalId(goalId: String?) async throws {
        try await userManager.updateCurrentGoalId(goalId: goalId)
    }
    
    // Consents
    func updateHealthConsents(disclaimerVersion: String, privacyVersion: String, acceptedAt: Date = Date()) async throws {
        try await userManager.updateHealthConsents(disclaimerVersion: disclaimerVersion, privacyVersion: privacyVersion, acceptedAt: acceptedAt)
    }
    
    // User Blocking

    func blockUser(userId: String) async throws {
        let wasFollowing = currentUser?.followingIds?.contains(userId) ?? false
        try await userManager.blockUser(userId: userId)
        if wasFollowing {
            await didUnfollow(userId: userId)
        }
    }

    func unblockUser(userId: String) async throws {
        try await userManager.unblockUser(userId: userId)
    }

    // User Following

    var followingUsers: [UserModel] {
        userManager.followingUsers
    }

    func getUser(userId: String) async throws -> UserModel {
        try await userManager.getUser(userId: userId)
    }

    func followUser(userId: String) async throws {
        try await userManager.followUser(userId: userId)
        let ids = userManager.currentUser?.followingIds ?? []
        async let refreshSessions: () = workoutSessionManager.refreshFollowingSync(followingIds: ids)
        async let refreshProfiles: () = userManager.refreshFollowingUsers(followingIds: ids)
        await refreshSessions
        await refreshProfiles
        // The followed user hears about it the same way they hear about a like: a notification in
        // their own collection, keyed so that an unfollow can take it back.
        guard let actor = userManager.currentUser else { return }
        let notification = ActivityNotificationModel(
            id: "follow_\(actor.userId)",
            type: .follow,
            actorId: actor.userId,
            actorName: actor.fullNameCalculated ?? "Someone",
            actorImageUrl: actor.submittedProfileImage,
            sessionId: "",
            sessionAuthorId: userId,
            commentText: nil,
            dateCreated: .now,
            isRead: false
        )
        try? await activityNotificationManager.addNotification(notification, userId: userId)
    }

    /// The people the user has already nudged today (local day).
    var nudgedUserIdsToday: Set<String> {
        NudgeHistoryManager.nudgedUserIds()
    }

    /// Asks someone in the user's circle to train, at most once per person per local day. The
    /// notification id carries the day, so even a nudge the local log missed overwrites that
    /// day's rather than stacking a second one in the recipient's bell.
    func nudgeUser(userId: String) async throws {
        guard let actor = userManager.currentUser, !nudgedUserIdsToday.contains(userId) else { return }
        let now = Date.now
        let notification = ActivityNotificationModel(
            id: "nudge_\(actor.userId)_\(now.dayKey)",
            type: .nudge,
            actorId: actor.userId,
            actorName: actor.fullNameCalculated ?? "Someone",
            actorImageUrl: actor.submittedProfileImage,
            sessionId: "",
            sessionAuthorId: userId,
            commentText: nil,
            dateCreated: now,
            isRead: false
        )
        try await activityNotificationManager.addNotification(notification, userId: userId)
        NudgeHistoryManager.addNudge(userId: userId, on: now)
    }

    func unfollowUser(userId: String) async throws {
        try await userManager.unfollowUser(userId: userId)
        await didUnfollow(userId: userId)
    }

    /// Stops syncing an unfollowed user's sessions and profile, and takes back the follow
    /// notification. `userId` is removed explicitly because the engine may not have applied the
    /// write yet.
    private func didUnfollow(userId: String) async {
        let ids = (userManager.currentUser?.followingIds ?? []).filter { $0 != userId }
        async let refreshSessions: () = workoutSessionManager.refreshFollowingSync(followingIds: ids)
        async let refreshProfiles: () = userManager.refreshFollowingUsers(followingIds: ids)
        await refreshSessions
        await refreshProfiles
        guard let actorId = userManager.currentUser?.userId else { return }
        try? await activityNotificationManager.deleteNotification(id: "follow_\(actorId)", userId: userId)
    }

    func fetchFollowers(userId: String) async throws -> [UserModel] {
        try await userManager.fetchFollowers(userId: userId)
    }

    func fetchSuggestedUsers() async throws -> [UserModel] {
        try await userManager.fetchSuggestedUsers()
    }

    func fetchUsers(userIds: [String]) async throws -> [UserModel] {
        try await userManager.fetchUsers(userIds: userIds)
    }

    // Follow Requests

    var sentFollowRequestIds: Set<String> {
        userManager.sentFollowRequestIds
    }

    var incomingFollowRequests: [FollowRequestModel] {
        userManager.incomingFollowRequests
    }

    func sendFollowRequest(to user: UserModel) async throws {
        try await userManager.sendFollowRequest(to: user)
    }

    func cancelFollowRequest(userId: String) async throws {
        try await userManager.cancelFollowRequest(userId: userId)
    }

    func fetchIncomingFollowRequests() async throws {
        guard let userId else { return }
        try await userManager.fetchIncomingFollowRequests(userId: userId)
    }

    func respondToFollowRequest(requesterId: String, accept: Bool) async throws {
        try await userManager.respondToFollowRequest(requesterId: requesterId, accept: accept)
    }

    func updatePrivacy(isPrivate: Bool) async throws {
        try await userManager.updatePrivacy(isPrivate: isPrivate)
    }

    var privateUserSettings: PrivateUserSettings {
        userManager.privateSettings
    }

    func updateSocialNotificationPreferences(type: ActivityNotificationModel.ActivityType, isEnabled: Bool) async throws {
        try await userManager.updateSocialNotificationPreferences(type: type, isEnabled: isEnabled)
    }

}

// MARK: - Usernames

extension UserManager {
    /// `queryService` is private to this file; `UserManager+Username.swift` reaches it through this.
    var usernameQueryService: any UserQueryService { queryService }
}

// MARK: - ScheduledPush

extension UserManager {
    /// Merges the streak reminder and digest fields over the private settings document.
    func updatePrivateSettings(_ change: (inout PrivateUserSettings) -> Void) async throws {
        var settings = privateSettings
        change(&settings)
        try await privateSettingsSyncEngine.saveDocument(settings)
    }
}

// MARK: - Invites

extension UserManager {
    /// The `acceptInvite` Cloud Function wrote a request to a private inviter; this records it the
    /// way `sendFollowRequest` would, so their profile shows Requested. `sentFollowRequestIds` is
    /// private to this file, hence here.
    func markFollowRequestSent(to userId: String) {
        sentFollowRequestIds.insert(userId)
    }
}
