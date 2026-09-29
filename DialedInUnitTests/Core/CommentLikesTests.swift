//
//  CommentLikesTests.swift
//  DialedInUnitTests
//

import Testing
import SwiftUI
@testable import DialedIn

/// Hearts on comments, and who hears about a reply.
@MainActor
struct CommentLikesTests {

    private final class Interactor: SpyGlobalInteractor, CommentsInteractor {
        var currentUser: UserModel? = UserModel(userId: "me")
        var followingUsers: [UserModel] = []
        var fetched: [WorkoutSessionComment] = []
        var likeError: Error?
        private(set) var likeCalls: [String] = []

        func getUser(userId: String) async throws -> UserModel { throw URLError(.fileDoesNotExist) }
        func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment] { fetched }
        func addComment(_ comment: WorkoutSessionComment) async throws { }
        func deleteComment(id: String) async throws { }

        func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws {
            likeCalls.append("\(id)|\(userId)|\(isLiked)")
            if let likeError { throw likeError }
        }

        func report(
            contentType: ReportContentType,
            contentId: String,
            authorUserId: String?,
            reason: ReportReason,
            notes: String?
        ) async throws { }
    }

    private final class Router: CommentsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    private func comment(
        _ id: String,
        author: String = "friend",
        sessionAuthor: String = "owner",
        parentId: String? = nil,
        likedBy: [String] = []
    ) -> WorkoutSessionComment {
        var comment = WorkoutSessionComment(
            id: id,
            sessionId: "session-1",
            sessionAuthorId: sessionAuthor,
            authorId: author,
            authorName: "Jane",
            authorImageUrl: nil,
            text: "Nice",
            dateCreated: Date(timeIntervalSince1970: 0),
            parentId: parentId
        )
        comment.likedByUserIds = likedBy
        return comment
    }

    private func makeScreen(fetched: [WorkoutSessionComment]) -> (CommentsPresenter, Interactor) {
        let interactor = Interactor()
        interactor.fetched = fetched
        let presenter = CommentsPresenter(
            interactor: interactor,
            router: Router(),
            delegate: CommentsDelegate(session: WorkoutSessionModel.mock)
        )
        presenter.withPreviewState(comments: fetched)
        return (presenter, interactor)
    }

    // MARK: - Likes

    @Test("Test Liking Fills The Heart At Once And Writes The New State")
    func testLikingFillsTheHeartAtOnceAndWritesTheNewState() async {
        let (presenter, interactor) = makeScreen(fetched: [comment("c1", likedBy: ["other"])])

        presenter.onLikePressed(presenter.comments[0])

        #expect(presenter.isLikedByReader(presenter.comments[0]))
        #expect(presenter.comments[0].likedByUserIds.count == 2)
        #expect(await TestManagers.eventually { interactor.likeCalls == ["c1|me|true"] })
        #expect(presenter.isLikedByReader(presenter.comments[0]))
    }

    @Test("Test Unliking Removes Only The Readers Like")
    func testUnlikingRemovesOnlyTheReadersLike() async {
        let (presenter, interactor) = makeScreen(fetched: [comment("c1", likedBy: ["other", "me"])])

        presenter.onLikePressed(presenter.comments[0])

        #expect(presenter.comments[0].likedByUserIds == ["other"])
        #expect(await TestManagers.eventually { interactor.likeCalls == ["c1|me|false"] })
    }

    @Test("Test A Failed Like Puts The Heart Back")
    func testAFailedLikePutsTheHeartBack() async {
        let (presenter, interactor) = makeScreen(fetched: [comment("c1")])
        interactor.likeError = URLError(.notConnectedToInternet)

        presenter.onLikePressed(presenter.comments[0])
        #expect(presenter.isLikedByReader(presenter.comments[0]))

        #expect(await TestManagers.eventually { !presenter.isLikedByReader(presenter.comments[0]) })
        #expect(presenter.comments[0].likedByUserIds.isEmpty)
    }

    @Test("Test A Failed Unlike Puts The Like Back")
    func testAFailedUnlikePutsTheLikeBack() async {
        let (presenter, interactor) = makeScreen(fetched: [comment("c1", likedBy: ["me"])])
        interactor.likeError = URLError(.notConnectedToInternet)

        presenter.onLikePressed(presenter.comments[0])
        #expect(!presenter.isLikedByReader(presenter.comments[0]))

        #expect(await TestManagers.eventually { presenter.isLikedByReader(presenter.comments[0]) })
    }

    @Test("Test Signed Out Readers Cannot Like")
    func testSignedOutReadersCannotLike() async {
        let (presenter, interactor) = makeScreen(fetched: [comment("c1")])
        interactor.currentUser = nil

        presenter.onLikePressed(presenter.comments[0])

        #expect(presenter.comments[0].likedByUserIds.isEmpty)
        #expect(interactor.likeCalls.isEmpty)
    }

    // MARK: - Reply notifications

    @Test("Test A Reply Tells The Parents Author As A Reply And The Session Author As A Comment")
    func testAReplyTellsTheParentsAuthorAsAReplyAndTheSessionAuthorAsAComment() {
        let reply = comment("r1", author: "writer", parentId: "p1")

        let sent = reply.activityNotifications(parentAuthorId: "parent")

        #expect(sent.map(\.userId) == ["owner", "parent"])
        #expect(sent.allSatisfy { $0.notification.type == .comment && $0.notification.commentText == "Nice" })
        #expect(sent.first { $0.userId == "parent" }?.notification.isReply == true)
        #expect(sent.first { $0.userId == "owner" }?.notification.isReply == false)
    }

    @Test("Test A Reply To Yourself Or To The Session Author Sends No Reply")
    func testAReplyToYourselfOrToTheSessionAuthorSendsNoReply() {
        let toSelf = comment("r1", author: "writer", parentId: "p1").activityNotifications(parentAuthorId: "writer")
        #expect(toSelf.map(\.userId) == ["owner"])
        #expect(toSelf.allSatisfy { !$0.notification.isReply })

        let toOwner = comment("r2", author: "writer", parentId: "p1").activityNotifications(parentAuthorId: "owner")
        #expect(toOwner.map(\.userId) == ["owner"])
        #expect(toOwner.allSatisfy { !$0.notification.isReply })
    }

    @Test("Test A Top Level Comment Is Never A Reply")
    func testATopLevelCommentIsNeverAReply() {
        let sent = comment("c1", author: "writer").activityNotifications(parentAuthorId: nil)
        #expect(sent.map(\.userId) == ["owner"])
        #expect(sent.allSatisfy { !$0.notification.isReply })
    }
}
