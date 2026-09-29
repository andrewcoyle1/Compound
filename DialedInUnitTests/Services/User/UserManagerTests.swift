//
//  UserManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 28/10/2025.
//

import Testing
import Foundation
@testable import DialedIn

@MainActor
struct UserManagerTests {

    // MARK: - Current User

    @Test("Test Current User Comes From The Sync Engine")
    func testCurrentUserComesFromTheSyncEngine() async throws {
        // Captured once: `UserModel.mock` is computed, and builds its dates from `Date()`, so two
        // reads of it are never equal.
        let mockUser = UserModel.mock
        let manager = TestManagers.userManager(user: mockUser)

        try await manager.signIn(auth: auth(uid: mockUser.userId), isNewUser: false)

        await TestManagers.eventually { manager.currentUser != nil }
        #expect(manager.currentUser == mockUser)
    }

    @Test("Test Current User Is Nil Before Signing In")
    func testCurrentUserIsNilBeforeSigningIn() async {
        let manager = TestManagers.userManager(user: UserModel.mock)

        // The engine only holds a document once it is listening, so a manager that has not signed
        // in has no user, whatever the remote holds.
        #expect(manager.currentUser == nil)
    }

    @Test("Test Current User Is Nil When The Remote Has No Document")
    func testCurrentUserIsNilWhenTheRemoteHasNoDocument() async throws {
        let manager = TestManagers.userManager(user: nil)

        try await manager.signIn(auth: auth(), isNewUser: false)

        #expect(manager.currentUser == nil)
    }

    // MARK: - Sign in

    @Test("Test Signing In As A New User Creates Their Document")
    func testSigningInAsANewUserCreatesTheirDocument() async throws {
        let manager = TestManagers.userManager(user: nil)
        let authInfo = auth(email: "\(String.random)@example.com")

        try await manager.signIn(auth: authInfo, isNewUser: true)

        await TestManagers.eventually { manager.currentUser != nil }
        let user = try #require(manager.currentUser)
        #expect(user.userId == authInfo.uid)
        #expect(user.email == authInfo.email)
        #expect(user.didCompleteOnboarding == false)
    }

    /// A returning user's stored profile is what counts: signing in must not write a fresh document
    /// over it and send them back through onboarding.
    @Test("Test Signing In As An Existing User Keeps Their Profile")
    func testSigningInAsAnExistingUserKeepsTheirProfile() async throws {
        let existingUser = UserModel.mockExisting
        let manager = TestManagers.userManager(user: existingUser)

        try await manager.signIn(auth: auth(uid: existingUser.userId), isNewUser: false)

        await TestManagers.eventually { manager.currentUser != nil }
        let user = try #require(manager.currentUser)
        #expect(user.userId == existingUser.userId)
        #expect(user.didCompleteOnboarding == true)
        #expect(user.inferredOnboardingStep == OnboardingStep.complete)
    }

    /// The listener delivers the profile on its own task, so the moment `signIn` returns the
    /// profile may not be there yet; log-in reads it through this instead of `currentUser`.
    @Test("Test The Profile Can Be Read The Moment Sign In Returns")
    func testTheProfileCanBeReadTheMomentSignInReturns() async throws {
        let existingUser = UserModel.mockExisting
        let manager = TestManagers.userManager(user: existingUser)

        try await manager.signIn(auth: auth(uid: existingUser.userId), isNewUser: false)
        let user = await manager.currentUserOrFetched(userId: existingUser.userId)

        #expect(user?.followingIds == existingUser.followingIds)
    }

    @Test("Test Signing In Anonymously Keeps No Email")
    func testSigningInAnonymouslyKeepsNoEmail() async throws {
        let manager = TestManagers.userManager(user: nil)

        try await manager.signIn(auth: auth(email: nil, isAnonymous: true), isNewUser: true)

        await TestManagers.eventually { manager.currentUser != nil }
        let user = try #require(manager.currentUser)
        #expect(user.isAnonymous == true)
        #expect(user.email == nil)
    }

    // MARK: - Sign out

    @Test("Test Signing Out Clears The Current User")
    func testSigningOutClearsTheCurrentUser() async throws {
        let mockUser = UserModel.mock
        let manager = TestManagers.userManager(user: mockUser)
        try await manager.signIn(auth: auth(uid: mockUser.userId), isNewUser: false)
        await TestManagers.eventually { manager.currentUser != nil }
        #expect(manager.currentUser != nil)

        manager.signOut()

        #expect(manager.currentUser == nil)
    }

    // MARK: - Following

    @Test("Test Following Users Are Empty Until Refreshed")
    func testFollowingUsersAreEmptyUntilRefreshed() async {
        let manager = TestManagers.userManager(user: UserModel.mock, following: UserModel.mocks)

        #expect(manager.followingUsers.isEmpty)
    }

    // MARK: - Blocking

    private struct Recording {
        let manager: UserManager
        let remote: RecordingRemoteDocumentService<UserModel>
        let privateRemote: RecordingRemoteDocumentService<PrivateUserSettings>
    }

    /// Blocking someone the reader follows takes the follow back in the same write, so a blocked
    /// person's sessions stop syncing into the feed.
    /// The mock remote never applies an update, so these read the write itself: blocking drops the
    /// follow in the same write as the block, and unblocking touches only the block list.
    private func recordingManager(
        _ user: UserModel,
        privateSettings: PrivateUserSettings? = nil,
        queryService: MockUserQueryService = MockUserQueryService()
    ) async throws -> Recording {
        let remote = RecordingRemoteDocumentService<UserModel>(document: user)
        let privateRemote = RecordingRemoteDocumentService<PrivateUserSettings>(document: privateSettings)
        let manager = UserManager(
            queryService: queryService,
            userSyncEngine: DocumentSyncEngine<UserModel>(
                remote: remote, managerKey: TestManagers.key("user"), enableLocalPersistence: false
            ),
            followingUsersSyncEngine: TestManagers.collectionEngine([UserModel](), key: "following-users"),
            privateSettingsSyncEngine: DocumentSyncEngine<PrivateUserSettings>(
                remote: privateRemote, managerKey: TestManagers.key("private-user-settings"), enableLocalPersistence: false
            )
        )
        try await manager.signIn(auth: UserAuthInfo(uid: user.userId), isNewUser: false)
        await TestManagers.eventually { manager.currentUser != nil }
        if let privateSettings {
            await TestManagers.eventually { manager.privateSettings == privateSettings }
        }
        return Recording(manager: manager, remote: remote, privateRemote: privateRemote)
    }

    @Test("Test Blocking A Followed User Unfollows Them")
    func testBlockingAFollowedUserUnfollowsThem() async throws {
        let recording = try await recordingManager(UserModel(userId: "me", followingIds: ["friend", "other"]))

        try await recording.manager.blockUser(userId: "friend")

        #expect(recording.remote.lastStrings(for: UserModel.CodingKeys.blockedUserIds.rawValue) == ["friend"])
        #expect(recording.remote.lastStrings(for: UserModel.CodingKeys.followingIds.rawValue) == ["other"])
    }

    @Test("Test Unblocking Does Not Restore The Follow")
    func testUnblockingDoesNotRestoreTheFollow() async throws {
        let recording = try await recordingManager(UserModel(userId: "me", blockedUserIds: ["friend"], followingIds: ["other"]))

        try await recording.manager.unblockUser(userId: "friend")

        #expect(recording.remote.lastStrings(for: UserModel.CodingKeys.blockedUserIds.rawValue) == [])
        #expect(recording.remote.lastStrings(for: UserModel.CodingKeys.followingIds.rawValue) == nil)
    }

    // MARK: - Private Settings

    /// The push opt-outs are owner-only now: a switch writes the private settings document, and
    /// the public profile, which any signed-in user can read, is not touched.
    @Test("Test Social Push Preference Writes The Private Settings Not The Profile")
    func testSocialPushPreferenceWritesThePrivateSettingsNotTheProfile() async throws {
        let recording = try await recordingManager(UserModel(userId: "me"))

        try await recording.manager.updateSocialNotificationPreferences(type: .comment, isEnabled: false)

        #expect(recording.privateRemote.saves.last == PrivateUserSettings(socialPushComments: false))
        #expect(recording.remote.updates.isEmpty)
        #expect(await TestManagers.eventually { !recording.manager.privateSettings.isSocialPushEnabled(for: .comment) })
        #expect(recording.manager.privateSettings.isSocialPushEnabled(for: .like))
    }

    /// A preference write is a merge over what the document already holds, so flipping one switch
    /// keeps the push token and the other switches.
    @Test("Test Social Push Preference Keeps The Other Private Fields")
    func testSocialPushPreferenceKeepsTheOtherPrivateFields() async throws {
        let stored = PrivateUserSettings(fcmToken: "tok", socialPushLikes: false)
        let recording = try await recordingManager(UserModel(userId: "me"), privateSettings: stored)

        try await recording.manager.updateSocialNotificationPreferences(type: .follow, isEnabled: false)

        #expect(recording.privateRemote.saves.last == PrivateUserSettings(fcmToken: "tok", socialPushLikes: false, socialPushFollows: false))
    }

    /// The token goes to the private document, and for one release also to the legacy profile
    /// field so the Cloud Function deployed before the move keeps finding it.
    @Test("Test FCM Token Writes The Private Settings And The Legacy Field")
    func testFCMTokenWritesThePrivateSettingsAndTheLegacyField() async throws {
        let recording = try await recordingManager(UserModel(userId: "me"))

        try await recording.manager.saveUserFCMToken(token: "abc-123")

        #expect(recording.privateRemote.saves.last?.fcmToken == "abc-123")
        // The scheduled pushes read the user's clock from here.
        #expect(recording.privateRemote.saves.last?.timezone == TimeZone.current.identifier)
        #expect(recording.remote.updates.last?[UserModel.CodingKeys.fcmToken.rawValue] as? String == "abc-123")
    }

    // MARK: - Follow requests

    private func pending(from requesterId: String) -> FollowRequestModel {
        FollowRequestModel(requesterId: requesterId, requesterName: requesterId, requesterImageUrl: nil, dateCreated: Date(), status: .pending)
    }

    /// Following a public profile is one write to the reader's own document, and no request.
    @Test("Test Following A Public Profile Is Immediate")
    func testFollowingAPublicProfileIsImmediate() async throws {
        let queries = MockUserQueryService()
        let recording = try await recordingManager(UserModel(userId: "me"), queryService: queries)
        let manager = recording.manager
        let remote = recording.remote

        try await manager.followUser(userId: "friend")

        #expect(remote.lastStrings(for: UserModel.CodingKeys.followingIds.rawValue) == ["friend"])
        #expect(manager.sentFollowRequestIds.isEmpty)
        #expect(queries.followRequests["friend"] == nil)
    }

    /// A request to a private profile is a pending document under the target, keyed by the
    /// requester; the reader's own following list is not touched until the owner accepts.
    @Test("Test Requesting A Private Profile Creates A Pending Request And Cancel Removes It")
    func testRequestingAPrivateProfileCreatesAPendingRequestAndCancelRemovesIt() async throws {
        let queries = MockUserQueryService()
        let recording = try await recordingManager(UserModel(userId: "me", submittedFirstName: "Sam"), queryService: queries)
        let manager = recording.manager
        let remote = recording.remote

        try await manager.sendFollowRequest(to: UserModel(userId: "friend", isPrivate: true))

        let request = try #require(queries.followRequests["friend"]?.first)
        #expect(request.requesterId == "me")
        #expect(request.requesterName == "Sam")
        #expect(request.status == .pending)
        #expect(manager.sentFollowRequestIds == ["friend"])
        #expect(remote.lastStrings(for: UserModel.CodingKeys.followingIds.rawValue) == nil)

        try await manager.cancelFollowRequest(userId: "friend")

        #expect(queries.followRequests["friend"]?.isEmpty == true)
        #expect(manager.sentFollowRequestIds.isEmpty)
    }

    /// Sign-in learns both sides: the requests the reader is waiting on and the ones waiting on them.
    @Test("Test Signing In Seeds Sent And Incoming Requests")
    func testSigningInSeedsSentAndIncomingRequests() async throws {
        let queries = MockUserQueryService()
        try await queries.sendFollowRequest(pending(from: "me"), targetId: "private-friend")
        try await queries.sendFollowRequest(pending(from: "fan"), targetId: "me")
        var declined = pending(from: "me")
        declined.status = .declined
        try await queries.sendFollowRequest(declined, targetId: "said-no")

        let recording = try await recordingManager(UserModel(userId: "me"), queryService: queries)
        let manager = recording.manager

        #expect(manager.sentFollowRequestIds == ["private-friend"])
        #expect(manager.incomingFollowRequests.map(\.requesterId) == ["fan"])

        manager.signOut()
        #expect(manager.sentFollowRequestIds.isEmpty)
        #expect(manager.incomingFollowRequests.isEmpty)
    }

    /// Requests arrive live after sign-in, without a fetch, and stop arriving after sign-out.
    @Test("Test Incoming Requests Arrive Live Until Sign Out")
    func testIncomingRequestsArriveLiveUntilSignOut() async throws {
        let queries = MockUserQueryService()
        let manager = try await recordingManager(UserModel(userId: "me"), queryService: queries).manager
        #expect(manager.incomingFollowRequests.isEmpty)

        try await queries.sendFollowRequest(pending(from: "fan"), targetId: "me")
        try await queries.sendFollowRequest(pending(from: "other"), targetId: "someone-else")

        #expect(await TestManagers.eventually { manager.incomingFollowRequests.map(\.requesterId) == ["fan"] })

        try await queries.deleteFollowRequest(requesterId: "fan", targetId: "me")
        #expect(await TestManagers.eventually { manager.incomingFollowRequests.isEmpty })

        manager.signOut()
        try await queries.sendFollowRequest(pending(from: "late"), targetId: "me")
        #expect(manager.incomingFollowRequests.isEmpty)
    }

    /// Accepting and declining write only the status; the Cloud Function does the rest.
    @Test("Test Accept And Decline Write The Request Status")
    func testAcceptAndDeclineWriteTheRequestStatus() async throws {
        let queries = MockUserQueryService()
        try await queries.sendFollowRequest(pending(from: "a"), targetId: "me")
        try await queries.sendFollowRequest(pending(from: "b"), targetId: "me")
        let recording = try await recordingManager(UserModel(userId: "me"), queryService: queries)
        let manager = recording.manager
        let remote = recording.remote
        #expect(manager.incomingFollowRequests.count == 2)

        try await manager.respondToFollowRequest(requesterId: "a", accept: true)
        try await manager.respondToFollowRequest(requesterId: "b", accept: false)

        let statuses = Dictionary(uniqueKeysWithValues: (queries.followRequests["me"] ?? []).map { ($0.requesterId, $0.status) })
        #expect(statuses == ["a": .accepted, "b": .declined])
        #expect(manager.incomingFollowRequests.isEmpty)
        #expect(remote.updates.isEmpty)
    }

    // MARK: - Helpers

    private func auth(
        uid: String = String.random,
        email: String? = "\(String.random)@example.com",
        isAnonymous: Bool = false
    ) -> UserAuthInfo {
        UserAuthInfo(
            uid: uid,
            email: email,
            isAnonymous: isAnonymous,
            creationDate: Date(),
            lastSignInDate: Date()
        )
    }
}
