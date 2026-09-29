//
//  ActivityNotificationManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

/// Likes and comments other people leave on the signed-in user's sessions.
///
/// The manager keeps its own copy of the list rather than re-reading the service after every
/// change, so each mutation has to be applied twice — once remotely and once to `notifications`.
/// A miss there shows up as a row that reappears after being deleted, or an unread badge that
/// never clears. The listener path is driven through `EmittingActivityNotificationService` below,
/// because `MockActivityNotificationService.startListening` is a no-op and can never emit.
@MainActor
struct ActivityNotificationManagerTests {

    private func makeManager(
        service: ActivityNotificationService = MockActivityNotificationService()
    ) -> ActivityNotificationManager {
        ActivityNotificationManager(service: service)
    }

    private func notification(
        id: String,
        type: ActivityNotificationModel.ActivityType = .like,
        isRead: Bool = false
    ) -> ActivityNotificationModel {
        ActivityNotificationModel(
            id: id,
            type: type,
            actorId: "actor-\(id)",
            actorName: "Actor \(id)",
            actorImageUrl: nil,
            sessionId: "session-1",
            sessionAuthorId: "user-1",
            commentText: type == .comment ? "Nice work" : nil,
            dateCreated: Date(),
            isRead: isRead
        )
    }

    // MARK: - Reading

    @Test("Test Notifications Are Empty Until Fetched")
    func testNotificationsAreEmptyUntilFetched() {
        // The manager holds nothing on construction, however much the service already has.
        #expect(makeManager().notifications.isEmpty)
    }

    @Test("Test Fetching Loads The Stored Notifications")
    func testFetchingLoadsTheStoredNotifications() async throws {
        let manager = makeManager()

        try await manager.fetchNotifications(userId: "user-1")

        #expect(manager.notifications.map(\.id) == ActivityNotificationModel.mocks.map(\.id))
    }

    @Test("Test Pending Banner Starts Empty")
    func testPendingBannerStartsEmpty() {
        // Nothing has arrived yet, so nothing should be on screen.
        #expect(makeManager().pendingBanner == nil)
    }

    // MARK: - Writing

    /// A notification is written by whoever caused it, so the newest one has to land at the top of
    /// the list the next fetch returns rather than wherever the service happened to append it.
    @Test("Test Adding A Notification Puts It First On The Next Fetch")
    func testAddingANotificationPutsItFirstOnTheNextFetch() async throws {
        let manager = makeManager()
        let new = notification(id: "new-like")

        try await manager.addNotification(new, userId: "user-1")
        try await manager.fetchNotifications(userId: "user-1")

        #expect(manager.notifications.first?.id == "new-like")
        #expect(manager.notifications.count == ActivityNotificationModel.mocks.count + 1)
    }

    /// `addNotification` does not touch the in-memory list — the listener is what puts a new row on
    /// screen. Writing one while a fetched list is held must therefore not change what is shown.
    @Test("Test Adding A Notification Does Not Change The Held List")
    func testAddingANotificationDoesNotChangeTheHeldList() async throws {
        let manager = makeManager()
        try await manager.fetchNotifications(userId: "user-1")
        let before = manager.notifications.map(\.id)

        try await manager.addNotification(notification(id: "new-like"), userId: "user-1")

        #expect(manager.notifications.map(\.id) == before)
    }

    @Test("Test Deleting Removes The Notification From The Held List")
    func testDeletingRemovesTheNotificationFromTheHeldList() async throws {
        let manager = makeManager()
        try await manager.fetchNotifications(userId: "user-1")
        let removedId = try #require(manager.notifications.first?.id)

        try await manager.deleteNotification(id: removedId, userId: "user-1")

        #expect(!manager.notifications.contains(where: { $0.id == removedId }))
    }

    /// The local removal is only half of it: a deleted row that survived remotely would come back
    /// on the next launch.
    @Test("Test Deleting Removes The Notification Remotely Too")
    func testDeletingRemovesTheNotificationRemotelyToo() async throws {
        let manager = makeManager()
        try await manager.fetchNotifications(userId: "user-1")
        let removedId = try #require(manager.notifications.first?.id)

        try await manager.deleteNotification(id: removedId, userId: "user-1")
        try await manager.fetchNotifications(userId: "user-1")

        #expect(!manager.notifications.contains(where: { $0.id == removedId }))
    }

    @Test("Test Deleting An Unknown Id Leaves The List Alone")
    func testDeletingAnUnknownIdLeavesTheListAlone() async throws {
        let manager = makeManager()
        try await manager.fetchNotifications(userId: "user-1")
        let before = manager.notifications.map(\.id)

        try await manager.deleteNotification(id: "not-a-notification", userId: "user-1")

        #expect(manager.notifications.map(\.id) == before)
    }

    /// The unread badge is derived from these flags, so marking read has to update the copy already
    /// on screen — not only the one the next fetch would return.
    @Test("Test Marking All Read Flags The Held Notifications")
    func testMarkingAllReadFlagsTheHeldNotifications() async throws {
        let manager = makeManager()
        try await manager.fetchNotifications(userId: "user-1")
        #expect(manager.notifications.contains(where: { !$0.isRead }))

        try await manager.markAllRead(userId: "user-1")

        // Hoisted out of `#expect`: the macro rewrites a key-path argument into a throwing
        // function, so `allSatisfy(\.isRead)` inline fails to compile.
        let everyNotificationIsRead = manager.notifications.allSatisfy(\.isRead)
        #expect(everyNotificationIsRead)
    }

    @Test("Test Marking All Read Persists Remotely")
    func testMarkingAllReadPersistsRemotely() async throws {
        let manager = makeManager()
        try await manager.fetchNotifications(userId: "user-1")

        try await manager.markAllRead(userId: "user-1")
        try await manager.fetchNotifications(userId: "user-1")

        // Hoisted out of `#expect`: the macro rewrites a key-path argument into a throwing
        // function, so `allSatisfy(\.isRead)` inline fails to compile.
        let everyNotificationIsRead = manager.notifications.allSatisfy(\.isRead)
        #expect(everyNotificationIsRead)
    }

    /// Marking read must not reorder or drop anything — the list stays on screen while it happens.
    @Test("Test Marking All Read Keeps The Order And Contents")
    func testMarkingAllReadKeepsTheOrderAndContents() async throws {
        let manager = makeManager()
        try await manager.fetchNotifications(userId: "user-1")
        let before = manager.notifications.map(\.id)

        try await manager.markAllRead(userId: "user-1")

        #expect(manager.notifications.map(\.id) == before)
    }

    // MARK: - Listening

    @Test("Test Start Listening Subscribes For The Given User")
    func testStartListeningSubscribesForTheGivenUser() {
        let service = EmittingActivityNotificationService()
        let manager = makeManager(service: service)

        manager.startListening(userId: "user-1")

        #expect(service.listeningUserId == "user-1")
    }

    /// A notification that arrives while the screen is open has to appear at the top without a
    /// refetch, which is the only reason the manager holds the list at all.
    @Test("Test An Incoming Notification Is Inserted First")
    func testAnIncomingNotificationIsInsertedFirst() async throws {
        let service = EmittingActivityNotificationService()
        let manager = makeManager(service: service)
        try await manager.fetchNotifications(userId: "user-1")
        manager.startListening(userId: "user-1")
        let before = manager.notifications.count

        service.emit(notification(id: "incoming"))

        #expect(manager.notifications.first?.id == "incoming")
        #expect(manager.notifications.count == before + 1)
    }

    @Test("Test An Incoming Notification Becomes The Pending Banner")
    func testAnIncomingNotificationBecomesThePendingBanner() {
        let service = EmittingActivityNotificationService()
        let manager = makeManager(service: service)
        manager.startListening(userId: "user-1")

        service.emit(notification(id: "incoming", type: .comment))

        #expect(manager.pendingBanner?.id == "incoming")
    }

    /// `AppView` shows the banner off this post rather than observing the manager, so a missing
    /// post means no in-app toast even though the row is in the list.
    @Test("Test An Incoming Notification Is Posted To Notification Center")
    func testAnIncomingNotificationIsPostedToNotificationCenter() async {
        let service = EmittingActivityNotificationService()
        let manager = makeManager(service: service)
        manager.startListening(userId: "user-1")
        var receivedId: String?
        let observer = NotificationCenter.default.addObserver(
            forName: .newActivityNotification,
            object: nil,
            queue: .main
        ) { posted in
            receivedId = (posted.object as? ActivityNotificationModel)?.id
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        service.emit(notification(id: "posted"))
        await TestManagers.eventually { receivedId != nil }

        #expect(receivedId == "posted")
    }

    /// Two likes in quick succession should leave the newer one showing, not queue behind the
    /// older banner.
    @Test("Test A Second Notification Replaces The Pending Banner")
    func testASecondNotificationReplacesThePendingBanner() {
        let service = EmittingActivityNotificationService()
        let manager = makeManager(service: service)
        manager.startListening(userId: "user-1")

        service.emit(notification(id: "first"))
        service.emit(notification(id: "second"))

        #expect(manager.pendingBanner?.id == "second")
        #expect(manager.notifications.map(\.id) == ["second", "first"])
    }

    /// The banner dismisses itself after four seconds; the wait is real time, which is why this is
    /// the only test that pays for it.
    @Test("Test The Pending Banner Clears Itself")
    func testThePendingBannerClearsItself() async {
        let service = EmittingActivityNotificationService()
        let manager = makeManager(service: service)
        manager.startListening(userId: "user-1")

        service.emit(notification(id: "incoming"))

        // The manager dismisses the banner from a detached task it does not keep a handle to, so
        // there is nothing to await and this has to be polled. The ceiling is generous rather than
        // tight to the four seconds: on GitHub Actions run 35781891366, sharing ~3 cores with the
        // rest of the suite, 15s expired before the timer fired. A ceiling costs nothing when the
        // condition holds — `eventually` returns the moment it does.
        #expect(await TestManagers.eventually(timeout: .seconds(60)) { manager.pendingBanner == nil })
    }

    @Test("Test Stop Listening Unsubscribes")
    func testStopListeningUnsubscribes() {
        let service = EmittingActivityNotificationService()
        let manager = makeManager(service: service)
        manager.startListening(userId: "user-1")

        manager.stopListening()

        #expect(service.listeningUserId == nil)
        #expect(service.stopCount == 1)
    }
}

/// A service that hands back the listener closure so a test can deliver a notification.
///
/// `MockActivityNotificationService` accepts the closure and drops it, so nothing it is given can
/// ever reach the manager.
@MainActor
private final class EmittingActivityNotificationService: ActivityNotificationService {

    private(set) var listeningUserId: String?
    private(set) var stopCount: Int = 0
    private var onNew: ((ActivityNotificationModel) -> Void)?
    private var stored: [ActivityNotificationModel] = ActivityNotificationModel.mocks

    func fetchNotifications(userId: String) async throws -> [ActivityNotificationModel] {
        stored
    }

    func addNotification(_ notification: ActivityNotificationModel, userId: String) async throws {
        stored.removeAll { $0.id == notification.id }
        stored.insert(notification, at: 0)
    }

    func deleteNotification(id: String, userId: String) async throws {
        stored.removeAll { $0.id == id }
    }

    func markAllRead(userId: String) async throws {
        stored = stored.map {
            var notification = $0
            notification.isRead = true
            return notification
        }
    }

    func startListening(userId: String, onNew: @escaping (ActivityNotificationModel) -> Void) {
        listeningUserId = userId
        self.onNew = onNew
    }

    func stopListening() {
        listeningUserId = nil
        onNew = nil
        stopCount += 1
    }

    // MARK: - GroupedNotifications

    func fetchNotifications(userId: String, before: Date) async throws -> [ActivityNotificationModel] { [] }

    func markRead(ids: [String], userId: String) async throws { }

    func emit(_ notification: ActivityNotificationModel) {
        onNew?(notification)
    }
}
