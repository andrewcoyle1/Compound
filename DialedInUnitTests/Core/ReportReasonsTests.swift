//
//  ReportReasonsTests.swift
//  DialedInUnitTests
//
//  The report flow's reason and note, and what a report-hidden session or comment looks like to
//  its readers.
//

import Testing
import SwiftUI
@testable import DialedIn

// MARK: - Reason and note

/// A report needs a reason; "Other" also needs a note, and a note has a length limit the rules
/// enforce too. An invalid report goes back to the note alert instead of being sent.
@MainActor
struct ReportReasonFlowTests {

    private final class Interactor: SpyGlobalInteractor, ReportInteractor {
        private(set) var reports: [String] = []

        func report(
            contentType: ReportContentType,
            contentId: String,
            authorUserId: String?,
            reason: ReportReason,
            notes: String?
        ) async throws {
            reports.append("\(contentType.rawValue)|\(contentId)|\(reason.rawValue)|\(notes ?? "nil")")
        }
    }

    private final class Router: GlobalRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alerts: [String] = []

        func showDevSettingsView() { }
        func showAlert(error: Error) { alerts.append("error") }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alerts.append("\(title): \(subtitle ?? "")")
        }
        func showSimpleAlert(title: String, subtitle: String?) { alerts.append(title) }
    }

    private let comment = ReportedContent(type: .comment, id: "c1", authorUserId: "friend", noun: "comment")

    @Test("Test Validation Needs A Reason, A Note For Other, And A Short Note")
    func testValidationNeedsAReasonANoteForOtherAndAShortNote() {
        #expect(ReportFlow.validationMessage(reason: nil, note: "") != nil)
        #expect(ReportFlow.validationMessage(reason: .spam, note: "") == nil)
        #expect(ReportFlow.validationMessage(reason: .other, note: "   \n") != nil)
        #expect(ReportFlow.validationMessage(reason: .other, note: "Fake workout") == nil)
        #expect(ReportFlow.validationMessage(reason: .harassment, note: String(repeating: "a", count: 501)) != nil)
        #expect(ReportFlow.validationMessage(reason: .harassment, note: String(repeating: "a", count: 500)) == nil)
    }

    @Test("Test Other Without A Note Is Not Sent And Asks Again")
    func testOtherWithoutANoteIsNotSentAndAsksAgain() async {
        let interactor = Interactor(), router = Router()
        let flow = ReportFlow(interactor: interactor, router: router)

        flow.start(comment)
        flow.onReasonSelected(.other)
        flow.onSendPressed()

        #expect(interactor.reports.isEmpty)
        #expect(flow.pending == comment)
        #expect(router.alerts.last == "Add a Note: Add a note saying what is wrong.")

        flow.note = "  Posting someone else's workout  "
        flow.onSendPressed()
        await TestManagers.eventually { !interactor.reports.isEmpty }

        #expect(interactor.reports == ["comment|c1|other|Posting someone else's workout"])
        #expect(router.alerts.last == "Report Sent")
    }

    @Test("Test A Reason Without A Note Sends No Note")
    func testAReasonWithoutANoteSendsNoNote() async {
        let interactor = Interactor(), router = Router()
        let flow = ReportFlow(interactor: interactor, router: router)

        flow.start(comment)
        flow.onReasonSelected(.inappropriate)
        flow.note = "   "
        flow.onSendPressed()
        await TestManagers.eventually { !interactor.reports.isEmpty }

        #expect(interactor.reports == ["comment|c1|inappropriate|nil"])
    }

    @Test("Test Cancelling Sends Nothing")
    func testCancellingSendsNothing() {
        let interactor = Interactor(), router = Router()
        let flow = ReportFlow(interactor: interactor, router: router)

        flow.start(comment)
        flow.onReasonSelected(.spam)
        flow.onCancelPressed()
        flow.onSendPressed()

        #expect(flow.pending == nil)
        #expect(interactor.reports.isEmpty)
    }
}

// MARK: - Hidden in the feed

/// Three reports hide a session: everyone but its author stops seeing it in the feed.
@MainActor
struct ReportHiddenFeedTests {

    private func hidden(_ session: WorkoutSessionModel) -> WorkoutSessionModel {
        var copy = session
        copy.hidden = true
        return copy
    }

    @Test("Test A Hidden Session Is Left Out Of Everyone's Feed But Its Author's")
    func testAHiddenSessionIsLeftOutOfEveryonesFeedButItsAuthors() {
        let interactor = DashboardFeedPresenterTests.Interactor()
        let presenter = DashboardPresenter(interactor: interactor, router: DashboardFeedPresenterTests.Router())
        interactor.followingUsers = [DashboardFixture.user("friend")]
        interactor.workoutSessions = [
            hidden(DashboardFixture.session(id: "mine-hidden", on: DashboardFixture.date(day: 1)))
        ]
        interactor.followingWorkoutSessions = [
            DashboardFixture.session(id: "theirs", author: "friend", on: DashboardFixture.date(day: 3)),
            hidden(DashboardFixture.session(id: "theirs-hidden", author: "friend", on: DashboardFixture.date(day: 4)))
        ]

        #expect(presenter.feedSessions.map(\.id) == ["theirs", "mine-hidden"])
    }

    @Test("Test Hidden Survives Decoding And Is Absent On Older Sessions")
    func testHiddenSurvivesDecodingAndIsAbsentOnOlderSessions() throws {
        let session = hidden(DashboardFixture.session(id: "s1", author: "friend", on: DashboardFixture.date(day: 2)))
        let decoded = try JSONDecoder().decode(WorkoutSessionModel.self, from: JSONEncoder().encode(session))
        #expect(decoded.hidden == true)

        let older = DashboardFixture.session(id: "s2", author: "friend", on: DashboardFixture.date(day: 2))
        let decodedOlder = try JSONDecoder().decode(WorkoutSessionModel.self, from: JSONEncoder().encode(older))
        #expect(decodedOlder.hidden == nil)
        #expect(decodedOlder.isHidden(from: "me") == false)
    }
}

// MARK: - Hidden in a thread

/// A hidden comment, and the replies under it, drop out of a thread for everyone but its author.
@MainActor
struct ReportHiddenCommentsTests {

    private final class Interactor: SpyGlobalInteractor, CommentsInteractor {
        var currentUser: UserModel?
        var fetched: [WorkoutSessionComment] = []
        var followingUsers: [UserModel] = []
        func getUser(userId: String) async throws -> UserModel { throw URLError(.fileDoesNotExist) }
        func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment] { fetched }
        func addComment(_ comment: WorkoutSessionComment) async throws { }
        func deleteComment(id: String) async throws { }
        func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws { }
        func report(contentType: ReportContentType, contentId: String, authorUserId: String?, reason: ReportReason, notes: String?) async throws { }
    }

    private final class Router: CommentsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    private func thread(readBy reader: String) async -> [String] {
        let interactor = Interactor()
        interactor.currentUser = UserModel(userId: reader)
        var flagged = WorkoutSessionComment(
            id: "flagged", sessionId: "session-x", sessionAuthorId: "friend", authorId: "troll",
            authorName: "troll", authorImageUrl: nil, text: "Rude", dateCreated: DashboardFixture.date(day: 2, hour: 10)
        )
        flagged.hidden = true
        interactor.fetched = [
            WorkoutSessionComment(
                id: "kept", sessionId: "session-x", sessionAuthorId: "friend", authorId: "friend",
                authorName: "friend", authorImageUrl: nil, text: "Nice", dateCreated: DashboardFixture.date(day: 2, hour: 9)
            ),
            flagged,
            WorkoutSessionComment(
                id: "reply", sessionId: "session-x", sessionAuthorId: "friend", authorId: "friend",
                authorName: "friend", authorImageUrl: nil, text: "What?", dateCreated: DashboardFixture.date(day: 2, hour: 11),
                parentId: "flagged"
            )
        ]
        let presenter = CommentsPresenter(
            interactor: interactor,
            router: Router(),
            delegate: CommentsDelegate(session: DashboardFixture.session(id: "session-x", author: "friend", on: DashboardFixture.date(day: 2)))
        )
        presenter.onViewAppear()
        await TestManagers.eventually { !presenter.comments.isEmpty }
        return presenter.comments.map(\.id)
    }

    @Test("Test A Hidden Comment Is Shown Only To Its Author")
    func testAHiddenCommentIsShownOnlyToItsAuthor() async {
        #expect(await thread(readBy: "me") == ["kept"])
        #expect(await thread(readBy: "troll") == ["kept", "flagged", "reply"])
    }
}
