//
//  SocialSafetyTests.swift
//  DialedInUnitTests
//
//  Blocking and reporting across the social surfaces: what a block hides, and what a report sends.
//

import Testing
import SwiftUI
@testable import DialedIn

// MARK: - Comments

/// A blocked person's comments vanish from a thread, and so do the replies under them — which
/// would otherwise surface at the top level as orphans.
@MainActor
struct BlockedCommentsTests {

    private final class Interactor: SpyGlobalInteractor, CommentsInteractor {
        var currentUser: UserModel? = UserModel(userId: "me", blockedUserIds: ["blocked"])
        var fetched: [WorkoutSessionComment] = []
        var followingUsers: [UserModel] = []
        func getUser(userId: String) async throws -> UserModel { throw URLError(.fileDoesNotExist) }
        private(set) var reports: [String] = []

        func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment] { fetched }
        func addComment(_ comment: WorkoutSessionComment) async throws { }
        func deleteComment(id: String) async throws { }
        func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws { }

        func report(
            contentType: ReportContentType,
            contentId: String,
            authorUserId: String?,
            reason: ReportReason,
            notes: String?
        ) async throws {
            reports.append("\(contentType.rawValue)|\(contentId)|\(authorUserId ?? "")")
        }
    }

    private final class Router: CommentsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    private func comment(_ id: String, author: String, hour: Int, parentId: String? = nil) -> WorkoutSessionComment {
        WorkoutSessionComment(
            id: id,
            sessionId: "session-x",
            sessionAuthorId: "friend",
            authorId: author,
            authorName: author,
            authorImageUrl: nil,
            text: "Nice work",
            dateCreated: DashboardFixture.date(day: 2, hour: hour),
            parentId: parentId
        )
    }

    @Test("Test A Blocked Authors Comment And Its Replies Are Hidden")
    func testABlockedAuthorsCommentAndItsRepliesAreHidden() async {
        let interactor = Interactor()
        interactor.fetched = [
            comment("kept", author: "friend", hour: 9),
            comment("blocked-root", author: "blocked", hour: 10),
            comment("reply-to-blocked", author: "friend", hour: 11, parentId: "blocked-root"),
            comment("blocked-reply", author: "blocked", hour: 12, parentId: "kept"),
            comment("reply-to-kept", author: "friend", hour: 13, parentId: "kept")
        ]
        let presenter = CommentsPresenter(
            interactor: interactor,
            router: Router(),
            delegate: CommentsDelegate(session: DashboardFixture.session(id: "session-x", author: "friend", on: DashboardFixture.date(day: 2)))
        )

        presenter.onViewAppear()
        await TestManagers.eventually { !presenter.comments.isEmpty }

        #expect(presenter.comments.map(\.id) == ["kept", "reply-to-kept"])
    }
}

// MARK: - Reporting

/// Every report goes through `ReportFlow`: a reason picker, then a note, then one call naming the content
/// type, its id and its author.
@MainActor
struct ReportFlowTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutSessionRowInteractor {
        var currentUser: UserModel? = UserModel(userId: "me")
        private(set) var reports: [String] = []

        func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel] { [] }
        func likeSession(sessionId: String, authorId: String, userId: String) async throws { }
        func unlikeSession(sessionId: String, authorId: String, userId: String) async throws { }

        func report(
            contentType: ReportContentType,
            contentId: String,
            authorUserId: String?,
            reason: ReportReason,
            notes: String?
        ) async throws {
            reports.append("\(contentType.rawValue)|\(contentId)|\(authorUserId ?? "")|\(reason.rawValue)")
        }

        var allExercises: [ExerciseModel] { [] }
        var allWorkoutTemplates: [WorkoutTemplateModel] { [] }
        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws { }
    }

    private final class Router: WorkoutSessionRowRouter {
        func showShareToFollowerView(delegate: ShareToFollowerDelegate) { }
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []

        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { }
        func showSocialProfileView(delegate: SocialProfileDelegate) { }
        func showCommentsView(delegate: CommentsDelegate) { }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Row {
        let presenter: WorkoutSessionRowPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeRow(author: String) -> Row {
        let interactor = Interactor()
        let router = Router()
        let session = DashboardFixture.session(id: "session-x", author: author, on: DashboardFixture.date(day: 2))
        let presenter = WorkoutSessionRowPresenter(
            interactor: interactor,
            router: router,
            delegate: WorkoutSessionRowDelegate(session: session, author: UserModel(userId: author))
        )
        return Row(presenter: presenter, interactor: interactor, router: router)
    }

    @Test("Test Reporting A Session Card Sends The Session")
    func testReportingASessionCardSendsTheSession() async {
        let row = makeRow(author: "friend")
        let presenter = row.presenter, interactor = row.interactor, router = row.router

        presenter.onReportPressed()
        #expect(router.alertTitles == ["Report Workout"])
        #expect(interactor.reports.isEmpty)

        presenter.reportFlow.onReasonSelected(.spam)
        #expect(interactor.reports.isEmpty)
        presenter.reportFlow.onSendPressed()
        await TestManagers.eventually { !interactor.reports.isEmpty }

        #expect(interactor.reports == ["session|session-x|friend|spam"])
        #expect(router.alertTitles == ["Report Workout", "Add a Note", "Report Sent"])
    }

    @Test("Test The Reader Cannot Report Their Own Session")
    func testTheReaderCannotReportTheirOwnSession() {
        let row = makeRow(author: "me")
        let presenter = row.presenter, router = row.router

        presenter.onReportPressed()

        #expect(presenter.canReport == false)
        #expect(router.alertTitles.isEmpty)
    }
}
