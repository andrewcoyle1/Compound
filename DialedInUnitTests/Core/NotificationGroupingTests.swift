//
//  NotificationGroupingTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// Same type + same session within 24 hours of the group's newest member collapse into one row.
@MainActor
struct NotificationGroupingTests {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func item(
        _ id: String,
        _ type: ActivityNotificationModel.ActivityType = .like,
        actor: String? = nil,
        session: String = "s1",
        hoursAgo: Double = 0,
        isRead: Bool = false
    ) -> ActivityNotificationModel {
        ActivityNotificationModel(
            id: id, type: type, actorId: actor ?? "actor-\(id)", actorName: actor ?? "Actor \(id)",
            actorImageUrl: "url-\(actor ?? id)", sessionId: type == .follow || type == .nudge ? "" : session,
            sessionAuthorId: "me", commentText: nil,
            dateCreated: now.addingTimeInterval(-hoursAgo * 3600), isRead: isRead
        )
    }

    private func ids(_ groups: [NotificationGroup]) -> [[String]] {
        groups.map { $0.members.map(\.id) }
    }

    @Test("Test Likes On One Session Within A Day Collapse")
    func testLikesOnOneSessionWithinADayCollapse() {
        let groups = NotificationGrouping.group([item("a", hoursAgo: 23), item("b"), item("c", hoursAgo: 2)])
        #expect(ids(groups) == [["b", "c", "a"]])
    }

    @Test("Test The Window Is Measured From The Newest Member")
    func testTheWindowIsMeasuredFromTheNewestMember() {
        // 12h steps would chain forever; anchoring on the newest member cuts at 24h.
        let groups = NotificationGrouping.group([item("a"), item("b", hoursAgo: 12), item("c", hoursAgo: 24.5), item("d", hoursAgo: 36)])
        #expect(ids(groups) == [["a", "b"], ["c", "d"]])
    }

    @Test("Test Groups Are Ordered By Their Newest Member")
    func testGroupsAreOrderedByTheirNewestMember() {
        let groups = NotificationGrouping.group([
            item("old-s2", session: "s2", hoursAgo: 5),
            item("s1-a", hoursAgo: 3),
            item("new-s2", session: "s2", hoursAgo: 1),
            item("s1-b", hoursAgo: 4)
        ])
        #expect(ids(groups) == [["new-s2", "old-s2"], ["s1-a", "s1-b"]])
    }

    @Test("Test Mixed Types And Sessions Do Not Merge")
    func testMixedTypesAndSessionsDoNotMerge() {
        let groups = NotificationGrouping.group([item("like"), item("comment", .comment, hoursAgo: 1), item("other", session: "s2", hoursAgo: 2)])
        #expect(groups.count == 3)
    }

    @Test("Test Follows And Nudges Never Group")
    func testFollowsAndNudgesNeverGroup() {
        let groups = NotificationGrouping.group([
            item("f1", .follow), item("f2", .follow, hoursAgo: 1),
            item("n1", .nudge), item("n2", .nudge, hoursAgo: 1)
        ])
        #expect(groups.count == 4)
        #expect(groups.allSatisfy { $0.members.count == 1 })
    }

    @Test("Test The Title Names The Newest Actor And Counts The Rest")
    func testTheTitleNamesTheNewestActorAndCountsTheRest() {
        let four = NotificationGrouping.group(["Alice", "Bob", "Cara", "Dan"].enumerated().map { index, name in
            item(name, actor: name, hoursAgo: Double(index))
        })
        #expect(four.first?.groupedTitle == "Alice and 3 others liked your workout")
        #expect(four.first?.avatarUrls == ["url-Alice", "url-Bob", "url-Cara"])

        let two = NotificationGrouping.group([item("a", .comment, actor: "Alice"), item("b", .comment, actor: "Bob", hoursAgo: 1)])
        #expect(two.first?.groupedTitle == "Alice and Bob commented on your workout")

        // One person commenting twice is one actor, not "and 1 others".
        let repeatCommenter = NotificationGrouping.group([item("a", .comment, actor: "Alice"), item("b", .comment, actor: "Alice", hoursAgo: 1)])
        #expect(repeatCommenter.first?.groupedTitle == "Alice commented on your workout")

        #expect(NotificationGrouping.group([item("solo")]).first?.groupedTitle == nil)
    }

    @Test("Test The Badge Counts Unread Groups Not Rows")
    func testTheBadgeCountsUnreadGroupsNotRows() {
        let notifications = [
            item("a"), item("b", hoursAgo: 1), item("c", hoursAgo: 2, isRead: true),
            item("read", session: "s2", hoursAgo: 1, isRead: true),
            item("follow", .follow)
        ]
        #expect(NotificationGrouping.unreadGroupCount(notifications) == 2)
    }

    @Test("Test A Group Is Unread While Any Member Is")
    func testAGroupIsUnreadWhileAnyMemberIs() throws {
        let group = try #require(NotificationGrouping.group([item("a", isRead: true), item("b", hoursAgo: 1)]).first)
        #expect(!group.isRead)
        #expect(group.unreadIds == ["b"])
    }
}

/// Paging by date cursor and marking single notifications read, through the manager.
@MainActor
struct ActivityNotificationPagingTests {

    /// Behaves like the Firestore service: newest first, a page at a time, `before` exclusive.
    private final class PagedService: ActivityNotificationService {
        var stored: [ActivityNotificationModel]
        private(set) var markedIds: [String] = []

        init(count: Int) {
            stored = (0..<count).map { index in
                ActivityNotificationModel(
                    id: "n\(index)", type: .like, actorId: "a\(index)", actorName: "A", actorImageUrl: nil,
                    sessionId: "s\(index)", sessionAuthorId: "me", commentText: nil,
                    dateCreated: Date(timeIntervalSince1970: Double(1_000_000 - index * 60)), isRead: false
                )
            }
        }

        func fetchNotifications(userId: String) async throws -> [ActivityNotificationModel] {
            Array(stored.prefix(ActivityNotificationManager.pageSize))
        }
        func fetchNotifications(userId: String, before: Date) async throws -> [ActivityNotificationModel] {
            Array(stored.filter { $0.dateCreated < before }.prefix(ActivityNotificationManager.pageSize))
        }
        func markRead(ids: [String], userId: String) async throws { markedIds += ids }
        func addNotification(_ notification: ActivityNotificationModel, userId: String) async throws { }
        func deleteNotification(id: String, userId: String) async throws { }
        func markAllRead(userId: String) async throws { }
        func startListening(userId: String, onNew: @escaping (ActivityNotificationModel) -> Void) { }
        func stopListening() { }
    }

    @Test("Test Load More Walks Back A Page At A Time Until A Short Page")
    func testLoadMoreWalksBackAPageAtATimeUntilAShortPage() async throws {
        let manager = ActivityNotificationManager(service: PagedService(count: 120))

        try await manager.fetchNotifications(userId: "me")
        #expect(manager.notifications.count == 50)
        #expect(manager.hasMore)

        try await manager.fetchMore(userId: "me")
        #expect(manager.notifications.count == 100)
        #expect(manager.hasMore)

        try await manager.fetchMore(userId: "me")
        #expect(manager.notifications.map(\.id) == (0..<120).map { "n\($0)" })
        #expect(!manager.hasMore)
    }

    @Test("Test A Short First Page Offers No More")
    func testAShortFirstPageOffersNoMore() async throws {
        let manager = ActivityNotificationManager(service: PagedService(count: 3))
        try await manager.fetchNotifications(userId: "me")
        #expect(!manager.hasMore)
    }

    @Test("Test Marking Ids Read Touches Only Those")
    func testMarkingIdsReadTouchesOnlyThose() async throws {
        let service = PagedService(count: 3)
        let manager = ActivityNotificationManager(service: service)
        try await manager.fetchNotifications(userId: "me")

        try await manager.markRead(ids: ["n0", "n2"], userId: "me")

        #expect(service.markedIds == ["n0", "n2"])
        #expect(manager.notifications.map(\.isRead) == [true, false, true])
    }

    @Test("Test The Mock Service Pages And Marks Read")
    func testTheMockServicePagesAndMarksRead() async throws {
        let service = MockActivityNotificationService()
        let all = try await service.fetchNotifications(userId: "me")
        let newest = try #require(all.map(\.dateCreated).max())

        let older = try await service.fetchNotifications(userId: "me", before: newest)
        #expect(older.count == all.count - 1)

        try await service.markRead(ids: ["mock_like_1"], userId: "me")
        let after = try await service.fetchNotifications(userId: "me")
        #expect(after.first(where: { $0.id == "mock_like_1" })?.isRead == true)
        #expect(after.first(where: { $0.id == "mock_follow_1" })?.isRead == false)
    }
}
