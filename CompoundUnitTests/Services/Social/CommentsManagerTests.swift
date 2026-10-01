//
//  CommentsManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// Comments on a workout session.
///
/// The manager is a pass-through over `CommentsManagerService`, so what is worth pinning down is
/// the contract the comments screen is written against: a fetch is scoped to one session, deleted
/// comments never come back, and every call surfaces its error rather than returning an empty list
/// that the screen would render as "no comments yet".
///
/// There is no in-memory collection here and no listener — each fetch is a round trip — so nothing
/// in this suite needs `eventually`.
@MainActor
struct CommentsManagerTests {

    private func comment(
        id: String,
        sessionId: String = "session-a",
        authorId: String = "author-1",
        text: String = "Nice work",
        minutesAgo: Double = 0,
        deletedAt: Date? = nil
    ) -> WorkoutSessionComment {
        WorkoutSessionComment(
            id: id,
            sessionId: sessionId,
            sessionAuthorId: "session-author",
            authorId: authorId,
            authorName: "Jane Smith",
            authorImageUrl: nil,
            text: text,
            dateCreated: Date().addingTimeInterval(-minutesAgo * 60),
            deletedAt: deletedAt
        )
    }

    // MARK: - Reading

    /// The comments sheet is opened from one session, and a fetch that leaked another session's
    /// comments would put strangers' replies under the wrong workout.
    @Test("Test Fetching Returns Only That Session's Comments")
    func testFetchingReturnsOnlyThatSessionsComments() async throws {
        let manager = TestManagers.commentsManager(comments: [
            comment(id: "c1", sessionId: "session-a"),
            comment(id: "c2", sessionId: "session-b"),
            comment(id: "c3", sessionId: "session-a")
        ])

        let comments = try await manager.fetchComments(sessionId: "session-a")

        #expect(comments.map(\.id) == ["c1", "c3"])
    }

    @Test("Test Fetching A Session With No Comments Returns Nothing")
    func testFetchingASessionWithNoCommentsReturnsNothing() async throws {
        let manager = TestManagers.commentsManager(comments: [comment(id: "c1", sessionId: "session-a")])

        let comments = try await manager.fetchComments(sessionId: "session-z")

        #expect(comments.isEmpty)
    }

    /// Deletion is a tombstone rather than a removal, so the filter is the only thing keeping a
    /// deleted comment off screen.
    @Test("Test Fetching Leaves Out Already Deleted Comments")
    func testFetchingLeavesOutAlreadyDeletedComments() async throws {
        let manager = TestManagers.commentsManager(comments: [
            comment(id: "c1"),
            comment(id: "c2", deletedAt: Date())
        ])

        let comments = try await manager.fetchComments(sessionId: "session-a")

        #expect(comments.map(\.id) == ["c1"])
    }

    /// The manager hands the list back in store order and sorts nothing, so ordering by date is
    /// the screen's job — worth stating, because a list that looks sorted here only looks that way.
    @Test("Test Comments Come Back In Store Order")
    func testCommentsComeBackInStoreOrder() async throws {
        let manager = TestManagers.commentsManager(comments: [
            comment(id: "newest", minutesAgo: 1),
            comment(id: "oldest", minutesAgo: 600),
            comment(id: "middle", minutesAgo: 60)
        ])

        let comments = try await manager.fetchComments(sessionId: "session-a")

        #expect(comments.map(\.id) == ["newest", "oldest", "middle"])
    }

    // MARK: - Writing

    @Test("Test An Added Comment Appears In The Next Fetch")
    func testAnAddedCommentAppearsInTheNextFetch() async throws {
        let manager = TestManagers.commentsManager(comments: [])

        try await manager.addComment(comment(id: "c1", text: "First"))
        let comments = try await manager.fetchComments(sessionId: "session-a")

        #expect(comments.count == 1)
        #expect(comments.first?.text == "First")
    }

    @Test("Test A Deleted Comment Disappears From The Next Fetch")
    func testADeletedCommentDisappearsFromTheNextFetch() async throws {
        let manager = TestManagers.commentsManager(comments: [
            comment(id: "c1"),
            comment(id: "c2")
        ])

        try await manager.deleteComment(id: "c1")
        let comments = try await manager.fetchComments(sessionId: "session-a")

        #expect(comments.map(\.id) == ["c2"])
    }

    /// Deleting the same comment twice, or a comment another device already removed, is an
    /// ordinary race on a shared thread — it must not surface as an error to the user.
    @Test("Test Deleting A Comment That Is Not There Does Nothing")
    func testDeletingACommentThatIsNotThereDoesNothing() async throws {
        let manager = TestManagers.commentsManager(comments: [comment(id: "c1")])

        try await manager.deleteComment(id: "missing")

        let comments = try await manager.fetchComments(sessionId: "session-a")
        #expect(comments.map(\.id) == ["c1"])
    }

    // MARK: - Errors

    /// A failed fetch has to throw. Swallowing it would render as an empty thread, and the user
    /// would reply again into a comment list that is only missing.
    @Test("Test A Failing Fetch Throws")
    func testAFailingFetchThrows() async {
        let manager = TestManagers.commentsManager(comments: [comment(id: "c1")], showError: true)

        await #expect(throws: (any Error).self) {
            _ = try await manager.fetchComments(sessionId: "session-a")
        }
    }

    @Test("Test A Failing Add Throws")
    func testAFailingAddThrows() async {
        let manager = TestManagers.commentsManager(comments: [], showError: true)

        await #expect(throws: (any Error).self) {
            try await manager.addComment(comment(id: "c1"))
        }
    }

    @Test("Test A Failing Delete Throws")
    func testAFailingDeleteThrows() async {
        let manager = TestManagers.commentsManager(comments: [comment(id: "c1")], showError: true)

        await #expect(throws: (any Error).self) {
            try await manager.deleteComment(id: "c1")
        }
    }

    // MARK: - Stored form

    /// The wire format, which the in-memory mock service does not exercise. `deleted_at` is what
    /// hides a comment, so a key that stops matching un-deletes every removed comment at once.
    @Test("Test A Comment Round Trips Through Its Stored Form")
    func testACommentRoundTripsThroughItsStoredForm() throws {
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let original = comment(id: "c1", text: "Impressive volume", deletedAt: deletedAt)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkoutSessionComment.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.sessionId == original.sessionId)
        #expect(decoded.authorId == original.authorId)
        #expect(decoded.text == original.text)
        // Dates go through a Double, so compare within a millisecond rather than exactly.
        let decodedDeletedAt = try #require(decoded.deletedAt)
        #expect(abs(decodedDeletedAt.timeIntervalSince1970 - deletedAt.timeIntervalSince1970) < 0.001)

        let object = try JSONSerialization.jsonObject(with: encoded)
        let json = try #require(object as? [String: Any])
        #expect(json["session_id"] as? String == "session-a")
        #expect(json["author_id"] as? String == "author-1")
        #expect(json.keys.contains("deleted_at"))
    }
}
