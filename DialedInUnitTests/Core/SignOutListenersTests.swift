//
//  SignOutListenersTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// `signOut()` and `deleteAccount()` stop listeners through the one list,
/// `stopListeningBeforeAccountDeletion()`, so a listener added to it is stopped by both.
@MainActor
struct SignOutListenersTests {

    @Test("Sign-out stops the listeners on the shared list")
    func signOutStopsSharedListeners() async throws {
        let preview = DevPreview()
        let interactor = CoreInteractor(container: preview.container())

        await preview.workoutSessionManager.signIn(userId: "mock_user_123", followingIds: [])
        await preview.progressPhotoManager.startListening(userId: "mock_user_123")
        #expect(preview.workoutSessionManager.hasLoadedFollowingSessions)
        #expect(!preview.progressPhotoManager.photos.isEmpty)

        try await interactor.signOut()

        #expect(!preview.workoutSessionManager.hasLoadedFollowingSessions)
        #expect(preview.progressPhotoManager.userId == nil)
        #expect(preview.progressPhotoManager.photos.isEmpty)
    }
}
