//
//  PushPendingDeepLinkTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// A push tapped while the app is not running arrives before any screen is listening, so
/// `PushManager` holds its destination until `logIn` has the managers listening.
@MainActor
struct PushPendingDeepLinkTests {

    private let sessionPayload: [AnyHashable: Any] = [
        "tab": "dashboard", "type": "comment", "session_id": "s1", "session_author_id": "u1"
    ]

    @Test("Test A Pending Link Is Consumed Exactly Once")
    func testAPendingLinkIsConsumedExactlyOnce() {
        let manager = PushManager()
        manager.setReadyForDeepLinks(true)
        manager.storePendingDeepLink(DeepLink(pushUserInfo: sessionPayload))

        #expect(manager.consumePendingDeepLink() == .session(id: "s1", authorId: "u1", openComments: true))
        #expect(manager.consumePendingDeepLink() == nil)
    }

    /// The cold-start order: the tap lands first, sign-in finishes later.
    @Test("Test A Pending Link Waits For Sign In")
    func testAPendingLinkWaitsForSignIn() {
        let manager = PushManager()
        manager.storePendingDeepLink(DeepLink(pushUserInfo: ["type": "follow_request"]))

        #expect(manager.consumePendingDeepLink() == nil)
        #expect(manager.pendingDeepLink == .notifications)

        manager.setReadyForDeepLinks(true)
        #expect(manager.consumePendingDeepLink() == .notifications)
    }

    @Test("Test An Unknown Payload Is Ignored")
    func testAnUnknownPayloadIsIgnored() {
        let manager = PushManager()
        manager.setReadyForDeepLinks(true)
        manager.storePendingDeepLink(DeepLink(pushUserInfo: ["tab": "nutrition"]))

        manager.storePendingDeepLink(DeepLink(pushUserInfo: ["body": "hello", "tab": "sleep"]))

        #expect(manager.consumePendingDeepLink() == .tab(.nutrition))
    }

    /// A link meant for the previous account must not route the next one.
    @Test("Test Sign Out Drops The Pending Link")
    func testSignOutDropsThePendingLink() {
        let manager = PushManager()
        manager.storePendingDeepLink(.tab(.analytics))

        manager.setReadyForDeepLinks(false)
        manager.setReadyForDeepLinks(true)

        #expect(manager.consumePendingDeepLink() == nil)
    }
}
