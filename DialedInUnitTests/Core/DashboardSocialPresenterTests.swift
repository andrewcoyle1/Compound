//
//  DashboardSocialPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

// MARK: - Workout session row

/// One workout in the feed: whose it is, what it amounted to, and the like button.
///
/// Liking is optimistic — the heart fills before the write lands — so the state it keeps has to
/// agree with the array on the session, and a failed write has to put it back exactly as it was.
@MainActor
struct SocialWorkoutSessionRowTests {

    final class Interactor: SpyGlobalInteractor, WorkoutSessionRowInteractor {
        var currentUser: UserModel? = DashboardFixture.user("me")
        var history: [WorkoutSessionModel] = []
        var likeError: Error?
        var unlikeError: Error?
        private(set) var likes: [String] = []
        private(set) var unlikes: [String] = []

        func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel] { history.filter { $0.authorId == authorId } }

        func likeSession(sessionId: String, authorId: String, userId: String) async throws {
            if let likeError { throw likeError }
            likes.append("\(sessionId)|\(authorId)|\(userId)")
        }

        func unlikeSession(sessionId: String, authorId: String, userId: String) async throws {
            if let unlikeError { throw unlikeError }
            unlikes.append("\(sessionId)|\(authorId)|\(userId)")
        }

        func report(contentType: ReportContentType, contentId: String, authorUserId: String?, reason: ReportReason, notes: String?) async throws { }
        var allExercises: [ExerciseModel] { [] }
        var allWorkoutTemplates: [WorkoutTemplateModel] { [] }
        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws { }
    }

    final class Router: WorkoutSessionRowRouter {
        func showShareToFollowerView(delegate: ShareToFollowerDelegate) { }
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var profileDelegates: [SocialProfileDelegate] = []
        private(set) var commentsDelegates: [CommentsDelegate] = []

        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { shown.append("sessionDetail") }

        func showSocialProfileView(delegate: SocialProfileDelegate) {
            shown.append("profile")
            profileDelegates.append(delegate)
        }

        func showCommentsView(delegate: CommentsDelegate) {
            shown.append("comments")
            commentsDelegates.append(delegate)
        }

        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { }
    }

    private struct Screen {
        let presenter: WorkoutSessionRowPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(
        session: WorkoutSessionModel,
        author: UserModel,
        signedInUser: UserModel? = nil,
        signedOut: Bool = false,
        history: [WorkoutSessionModel] = []
    ) -> Screen {
        let interactor = Interactor()
        interactor.history = history
        // The default has to be built here rather than in the parameter list: a default value is
        // evaluated outside the main actor, and the fixtures are main-actor isolated.
        interactor.currentUser = signedOut ? nil : (signedInUser ?? DashboardFixture.user("me"))
        let router = Router()
        return Screen(
            presenter: WorkoutSessionRowPresenter(
                interactor: interactor,
                router: router,
                delegate: WorkoutSessionRowDelegate(session: session, author: author)
            ),
            interactor: interactor,
            router: router
        )
    }

    private func set(_ index: Int, side: SetSide? = nil, reps: Int? = 10, weightKg: Double? = 20, isWarmup: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)-\(side?.rawValue ?? "both")",
            authorId: "friend",
            index: index,
            reps: reps,
            weightKg: weightKg,
            side: side,
            isWarmup: isWarmup,
            completedAt: DashboardFixture.date(day: 2),
            dateCreated: DashboardFixture.date(day: 2)
        )
    }

    private func exercise(_ name: String, sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: name.lowercased(),
            authorId: "friend",
            templateId: "template-\(name.lowercased())",
            name: name,
            trackingMode: .weightReps,
            index: 1,
            sets: sets
        )
    }

    // MARK: Identity

    /// The row is built from a session and the user who authored it, handed over together — so the
    /// name on the row is the name of the person whose workout it is, never the reader's.
    @Test("Test The Row Shows The Session And Its Author")
    func testTheRowShowsTheSessionAndItsAuthor() {
        let friend = DashboardFixture.user("friend")
        let session = DashboardFixture.session(id: "theirs", author: "friend", on: DashboardFixture.date(day: 2))
        let screen = makeScreen(session: session, author: friend)

        #expect(screen.presenter.session.id == "theirs")
        #expect(screen.presenter.author.userId == "friend")
    }

    /// Tapping the name opens that author's profile, not the reader's own.
    @Test("Test Tapping The Author Opens Their Profile")
    func testTappingTheAuthorOpensTheirProfile() {
        let friend = DashboardFixture.user("friend")
        let session = DashboardFixture.session(id: "theirs", author: "friend", on: DashboardFixture.date(day: 2))
        let screen = makeScreen(session: session, author: friend)

        screen.presenter.onUserPressed()

        #expect(screen.router.shown == ["profile"])
        #expect(screen.router.profileDelegates.first?.user.userId == "friend")
    }

    @Test("Test Tapping The Row Opens The Workout And The Comment Button Opens Its Comments")
    func testTappingTheRowOpensTheWorkoutAndTheCommentButtonOpensItsComments() {
        let session = DashboardFixture.session(id: "theirs", author: "friend", on: DashboardFixture.date(day: 2))
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"))

        screen.presenter.onWorkoutPressed()
        screen.presenter.onCommentButtonPressed()

        #expect(screen.router.shown == ["sessionDetail", "comments"])
        #expect(screen.router.commentsDelegates.first?.session.id == "theirs")
    }

    // MARK: Likes

    /// The count is the length of the array on the session, and the heart is whether the reader is
    /// in it — so the row opens agreeing with what the server holds.
    @Test("Test The Like State Comes From The Sessions Own Array")
    func testTheLikeStateComesFromTheSessionsOwnArray() {
        let session = DashboardFixture.session(
            id: "theirs",
            author: "friend",
            on: DashboardFixture.date(day: 2),
            likedBy: ["me", "someone"]
        )
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"))

        #expect(screen.presenter.isLiked)
        #expect(screen.presenter.likeCount == 2)
    }

    @Test("Test A Session You Have Not Liked Opens Unliked")
    func testASessionYouHaveNotLikedOpensUnliked() {
        let session = DashboardFixture.session(
            id: "theirs",
            author: "friend",
            on: DashboardFixture.date(day: 2),
            likedBy: ["someone"]
        )
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"))

        #expect(screen.presenter.isLiked == false)
        #expect(screen.presenter.likeCount == 1)
    }

    /// Liking is a toggle, so a second tap unlikes rather than counting the same person twice. The
    /// count returns to where it started and the writes are one like and one unlike.
    @Test("Test Liking Twice Unlikes Rather Than Counting You Twice")
    func testLikingTwiceUnlikesRatherThanCountingYouTwice() async {
        let session = DashboardFixture.session(id: "theirs", author: "friend", on: DashboardFixture.date(day: 2))
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"))

        screen.presenter.onLikeButtonPressed()
        await TestManagers.eventually { !screen.interactor.likes.isEmpty }
        #expect(screen.presenter.likeCount == 1)

        screen.presenter.onLikeButtonPressed()
        await TestManagers.eventually { !screen.interactor.unlikes.isEmpty }

        #expect(screen.presenter.isLiked == false)
        #expect(screen.presenter.likeCount == 0)
        #expect(screen.interactor.likes == ["theirs|friend|me"])
        #expect(screen.interactor.unlikes == ["theirs|friend|me"])
    }

    /// Unliking removes the reader alone — everyone else's like stays, so the count drops by one
    /// rather than to zero.
    @Test("Test Unliking Removes Only You")
    func testUnlikingRemovesOnlyYou() async {
        let session = DashboardFixture.session(
            id: "theirs",
            author: "friend",
            on: DashboardFixture.date(day: 2),
            likedBy: ["me", "someone", "another"]
        )
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"))

        screen.presenter.onLikeButtonPressed()
        await TestManagers.eventually { !screen.interactor.unlikes.isEmpty }

        #expect(screen.presenter.isLiked == false)
        #expect(screen.presenter.likeCount == 2)
    }

    /// The heart fills immediately, so a write that fails has to hand it back — otherwise the row
    /// claims a like the author will never see.
    @Test("Test A Failed Like Is Put Back")
    func testAFailedLikeIsPutBack() async {
        let session = DashboardFixture.session(
            id: "theirs",
            author: "friend",
            on: DashboardFixture.date(day: 2),
            likedBy: ["someone"]
        )
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"))
        screen.interactor.likeError = DashboardTestError.failed

        screen.presenter.onLikeButtonPressed()
        await TestManagers.eventually { screen.presenter.isLiked == false }

        #expect(screen.presenter.likeCount == 1)
    }

    @Test("Test A Failed Unlike Is Put Back")
    func testAFailedUnlikeIsPutBack() async {
        let session = DashboardFixture.session(
            id: "theirs",
            author: "friend",
            on: DashboardFixture.date(day: 2),
            likedBy: ["me"]
        )
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"))
        screen.interactor.unlikeError = DashboardTestError.failed

        screen.presenter.onLikeButtonPressed()
        await TestManagers.eventually { screen.presenter.isLiked }

        #expect(screen.presenter.likeCount == 1)
    }

    /// Signed out there is nobody to attribute the like to, so the button does nothing at all
    /// rather than sending an empty user id.
    @Test("Test Liking Does Nothing Without A Signed In User")
    func testLikingDoesNothingWithoutASignedInUser() async {
        let session = DashboardFixture.session(id: "theirs", author: "friend", on: DashboardFixture.date(day: 2))
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"), signedOut: true)

        screen.presenter.onLikeButtonPressed()

        #expect(screen.presenter.isLiked == false)
        #expect(screen.presenter.likeCount == 0)
        #expect(screen.interactor.likes.isEmpty)
    }

    // MARK: Share summary

    /// The share text is the row's own summary. Warm-ups are excluded from both figures, as
    /// everywhere else — a longer ramp is not more training.
    @Test("Test The Share Summary Excludes Warmups")
    func testTheShareSummaryExcludesWarmups() {
        let session = DashboardFixture.session(
            id: "theirs",
            author: "friend",
            name: "Leg Day",
            on: DashboardFixture.date(day: 2),
            exercises: [
                exercise("Squat", sets: [
                    set(1, reps: 10, weightKg: 20, isWarmup: true),
                    set(2, reps: 5, weightKg: 100),
                    set(3, reps: 5, weightKg: 100)
                ])
            ]
        )
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"))

        #expect(screen.presenter.shareSummary == "Leg Day · 1 exercises · 2 sets · 1000 kg lifted")
    }

    /// A left set and a right set are one set, so a single-arm exercise logged as six rows shares as
    /// three sets — but every row was lifted, so the volume still sums all six.
    @Test("Test Paired Sides Count As One Set But All The Volume")
    func testPairedSidesCountAsOneSetButAllTheVolume() {
        let session = DashboardFixture.session(
            id: "theirs",
            author: "friend",
            name: "Row",
            on: DashboardFixture.date(day: 2),
            exercises: [
                exercise("Single Arm Row", sets: [
                    set(1, side: .left), set(1, side: .right),
                    set(2, side: .left), set(2, side: .right),
                    set(3, side: .left), set(3, side: .right)
                ])
            ]
        )
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"))

        #expect(screen.presenter.shareSummary == "Row · 1 exercises · 3 sets · 1200 kg lifted")
    }

    /// A bodyweight or duration workout has no kilograms to report, so the volume clause is dropped
    /// rather than sharing "0 kg lifted".
    @Test("Test A Weightless Workout Shares Without A Volume")
    func testAWeightlessWorkoutSharesWithoutAVolume() {
        let session = DashboardFixture.session(
            id: "theirs",
            author: "friend",
            name: "Core",
            on: DashboardFixture.date(day: 2),
            exercises: [
                exercise("Plank", sets: [set(1, reps: nil, weightKg: nil)])
            ]
        )
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"))

        #expect(screen.presenter.shareSummary == "Core · 1 exercises · 1 sets")
    }

    /// The card's highlights come from the author's own history, asked of the interactor.
    @Test("Test The Row Shows The Author's Records And Weekly Count")
    func testTheRowShowsTheAuthorsRecordsAndWeeklyCount() {
        let bench = { (weight: Double) in [self.exercise("Bench", sets: [self.set(1, reps: 5, weightKg: weight)])] }
        let earlier = DashboardFixture.session(id: "a", author: "friend", on: DashboardFixture.date(day: 2), exercises: bench(90))
        let session = DashboardFixture.session(id: "b", author: "friend", on: DashboardFixture.date(day: 4), exercises: bench(100))
        let screen = makeScreen(session: session, author: DashboardFixture.user("friend"), history: [earlier, session])

        #expect(screen.presenter.personalRecords == [.init(exerciseName: "Bench", detail: "100 kg × 5")])
        #expect(screen.presenter.weeklyWorkoutText == "2nd workout of the week")
    }
}

// MARK: - Comments

/// The comment thread under a workout.
///
/// Posting is optimistic in the sense that the draft is cleared straight away, so everything here is
/// about not losing what the user typed and not showing a comment that never landed.
@MainActor
struct SocialCommentsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, CommentsInteractor {
        var currentUser: UserModel? = DashboardFixture.user("me", firstName: "Andrew")
        var fetched: [WorkoutSessionComment] = []
        var followingUsers: [UserModel] = []
        func getUser(userId: String) async throws -> UserModel { throw URLError(.fileDoesNotExist) }
        var fetchError: Error?
        var addError: Error?
        var deleteError: Error?
        var reportError: Error?
        private(set) var added: [WorkoutSessionComment] = []
        private(set) var deletedIds: [String] = []
        private(set) var reports: [String] = []

        func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment] {
            if let fetchError { throw fetchError }
            return fetched.filter { $0.sessionId == sessionId }
        }

        func addComment(_ comment: WorkoutSessionComment) async throws {
            if let addError { throw addError }
            added.append(comment)
        }

        func deleteComment(id: String) async throws {
            if let deleteError { throw deleteError }
            deletedIds.append(id)
        }

        func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws { }

        func report(
            contentType: ReportContentType,
            contentId: String,
            authorUserId: String?,
            reason: ReportReason,
            notes: String?
        ) async throws {
            if let reportError { throw reportError }
            reports.append("\(contentId)|\(reason.rawValue)")
        }
    }

    private final class Router: CommentsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []

        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alertTitles.append(title)
        }

        func showSimpleAlert(title: String, subtitle: String?) {
            alertTitles.append(title)
        }
    }

    private struct Screen {
        let presenter: CommentsPresenter
        let interactor: Interactor
        let router: Router
    }

    private let session = DashboardFixture.session(id: "session-x", author: "friend", on: DashboardFixture.date(day: 2))

    private func makeScreen(signedOut: Bool = false) -> Screen {
        let interactor = Interactor()
        // Built here rather than as a default argument, which is evaluated off the main actor.
        interactor.currentUser = signedOut ? nil : DashboardFixture.user("me", firstName: "Andrew")
        let router = Router()
        return Screen(
            presenter: CommentsPresenter(
                interactor: interactor,
                router: router,
                delegate: CommentsDelegate(session: session)
            ),
            interactor: interactor,
            router: router
        )
    }

    private func comment(
        _ id: String,
        author: String = "friend",
        text: String = "Nice work",
        on date: Date,
        sessionId: String = "session-x"
    ) -> WorkoutSessionComment {
        WorkoutSessionComment(
            id: id,
            sessionId: sessionId,
            sessionAuthorId: "friend",
            authorId: author,
            authorName: author,
            authorImageUrl: nil,
            text: text,
            dateCreated: date
        )
    }

    // MARK: Loading

    @Test("Test Appearing Loads This Sessions Comments")
    func testAppearingLoadsThisSessionsComments() async {
        let screen = makeScreen()
        screen.interactor.fetched = [
            comment("a", on: DashboardFixture.date(day: 2, hour: 10)),
            comment("elsewhere", on: DashboardFixture.date(day: 2, hour: 11), sessionId: "other-session")
        ]

        screen.presenter.onViewAppear()
        await TestManagers.eventually { !screen.presenter.comments.isEmpty }

        #expect(screen.presenter.comments.map(\.id) == ["a"])
        #expect(screen.presenter.isLoading == false)
    }

    /// The thread reads oldest first. The query behind it has no order clause, so comments arrive
    /// in document-id order — a reply could otherwise sit above the comment it answers.
    @Test("Test The Thread Reads Oldest First")
    func testTheThreadReadsOldestFirst() async {
        let screen = makeScreen()
        screen.interactor.fetched = [
            comment("newest", on: DashboardFixture.date(day: 2, hour: 18)),
            comment("oldest", on: DashboardFixture.date(day: 2, hour: 9)),
            comment("middle", on: DashboardFixture.date(day: 2, hour: 12))
        ]

        screen.presenter.onViewAppear()
        await TestManagers.eventually { screen.presenter.comments.count == 3 }

        #expect(screen.presenter.comments.map(\.id) == ["oldest", "middle", "newest"])
    }

    /// A comment posted now belongs at the bottom of a thread that reads oldest first.
    @Test("Test A New Comment Lands At The End Of The Thread")
    func testANewCommentLandsAtTheEndOfTheThread() async {
        let screen = makeScreen()
        screen.interactor.fetched = [comment("earlier", on: DashboardFixture.date(day: 2, hour: 9))]
        screen.presenter.onViewAppear()
        await TestManagers.eventually { screen.presenter.comments.count == 1 }

        screen.presenter.commentDraft = "Mine"
        screen.presenter.onSendPressed()
        await TestManagers.eventually { screen.presenter.comments.count == 2 }

        #expect(screen.presenter.comments.map(\.text) == ["Nice work", "Mine"])
    }

    /// A thread that cannot be loaded shows as empty rather than as an error over the workout, and
    /// the screen stops spinning either way.
    @Test("Test A Failed Load Leaves The Thread Empty")
    func testAFailedLoadLeavesTheThreadEmpty() async {
        let screen = makeScreen()
        screen.interactor.fetchError = DashboardTestError.failed

        screen.presenter.onViewAppear()
        await TestManagers.eventually { screen.presenter.isLoading == false }

        #expect(screen.presenter.comments.isEmpty)
    }

    /// Whose comment it is decides which swipe action the row offers — delete for your own, report
    /// for everyone else's.
    @Test("Test Your Own Comment Is Recognised As Yours")
    func testYourOwnCommentIsRecognisedAsYours() {
        let screen = makeScreen()
        let mine = comment("mine", author: "me", on: DashboardFixture.date(day: 2))
        let theirs = comment("theirs", author: "friend", on: DashboardFixture.date(day: 2))

        #expect(screen.presenter.isOwnComment(mine))
        #expect(screen.presenter.isOwnComment(theirs) == false)
    }

    /// Signed out, nothing is yours — the delete action must not appear over someone else's words.
    @Test("Test No Comment Is Yours When Signed Out")
    func testNoCommentIsYoursWhenSignedOut() {
        let screen = makeScreen(signedOut: true)

        #expect(screen.presenter.isOwnComment(comment("mine", author: "me", on: DashboardFixture.date(day: 2))) == false)
    }

    // MARK: Posting

    @Test("Test Sending A Comment Posts It And Clears The Draft")
    func testSendingACommentPostsItAndClearsTheDraft() async {
        let screen = makeScreen()
        screen.presenter.commentDraft = "  Strong session  "

        screen.presenter.onSendPressed()
        #expect(screen.presenter.comments.map(\.text) == ["Strong session"]) // before the write returns
        await TestManagers.eventually { !screen.interactor.added.isEmpty }

        #expect(screen.interactor.added.map(\.text) == ["Strong session"])
        #expect(screen.interactor.added.first?.authorId == "me")
        #expect(screen.interactor.added.first?.sessionId == "session-x")
        #expect(screen.interactor.added.first?.sessionAuthorId == "friend")
        #expect(screen.presenter.commentDraft.isEmpty)
        #expect(screen.router.alertTitles.isEmpty)
    }

    // MARK: Replies

    /// A thread is a comment followed by its replies, oldest first, and a reply whose parent has
    /// been deleted is shown rather than lost.
    @Test("Test Replies Sit Under Their Parent And Orphans Stay Visible")
    func testRepliesSitUnderTheirParentAndOrphansStayVisible() {
        var reply = comment("r1", author: "me", text: "Thanks", on: DashboardFixture.date(day: 3))
        reply.parentId = "c1"
        var orphan = comment("r2", text: "Lost", on: DashboardFixture.date(day: 4))
        orphan.parentId = "gone"
        let thread = CommentsPresenter.threaded([
            comment("c2", on: DashboardFixture.date(day: 2)),
            reply,
            comment("c1", on: DashboardFixture.date(day: 1)),
            orphan
        ])

        #expect(thread.map(\.id) == ["c1", "r1", "c2", "r2"])
    }

    /// Replying carries the parent's id, clears the target on send, and replying to a reply
    /// joins that reply's thread rather than nesting deeper.
    @Test("Test Replying Sends The Parent Id And Stays One Level Deep")
    func testReplyingSendsTheParentIdAndStaysOneLevelDeep() async {
        let screen = makeScreen()
        var reply = comment("r1", text: "Thanks", on: DashboardFixture.date(day: 2))
        reply.parentId = "c1"
        screen.interactor.fetched = [comment("c1", on: DashboardFixture.date(day: 1)), reply]
        screen.presenter.onViewAppear()
        await TestManagers.eventually { screen.presenter.comments.count == 2 }
        #expect(screen.presenter.isReply(reply))

        screen.presenter.onReplyPressed(reply)
        #expect(screen.presenter.replyingTo?.id == "c1")

        screen.presenter.commentDraft = "Agreed"
        screen.presenter.onSendPressed()
        await TestManagers.eventually { !screen.interactor.added.isEmpty }

        #expect(screen.interactor.added.first?.parentId == "c1")
        #expect(screen.presenter.replyingTo == nil)
        #expect(screen.presenter.comments.map(\.id) == ["c1", "r1", screen.interactor.added.first?.id ?? ""])
    }

    @Test("Test Cancelling A Reply Sends A Plain Comment")
    func testCancellingAReplySendsAPlainComment() async {
        let screen = makeScreen()
        screen.presenter.onReplyPressed(comment("c1", on: DashboardFixture.date(day: 1)))
        screen.presenter.onCancelReplyPressed()
        screen.presenter.commentDraft = "Hello"

        screen.presenter.onSendPressed()
        await TestManagers.eventually { !screen.interactor.added.isEmpty }

        #expect(screen.interactor.added.first?.parentId == nil)
    }

    @Test("Test An Empty Comment Cannot Be Posted")
    func testAnEmptyCommentCannotBePosted() {
        let screen = makeScreen()
        screen.presenter.commentDraft = ""

        screen.presenter.onSendPressed()

        #expect(screen.interactor.added.isEmpty)
    }

    /// A draft of nothing but spaces is not a comment — posting it would put a blank row under
    /// someone's workout.
    @Test("Test A Whitespace Only Comment Cannot Be Posted")
    func testAWhitespaceOnlyCommentCannotBePosted() {
        let screen = makeScreen()
        screen.presenter.commentDraft = "   "

        screen.presenter.onSendPressed()

        #expect(screen.interactor.added.isEmpty)
    }

    /// The return key inserts a newline rather than sending, so a draft of nothing but blank lines
    /// is easy to produce — and posting it puts an empty row under someone's workout.
    @Test("Test A Comment Of Only Blank Lines Cannot Be Posted")
    func testACommentOfOnlyBlankLinesCannotBePosted() {
        let screen = makeScreen()
        screen.presenter.commentDraft = "\n \n"

        screen.presenter.onSendPressed()

        #expect(screen.interactor.added.isEmpty)
    }

    /// Signed out there is no author to attach, so the send button does nothing rather than posting
    /// anonymously.
    @Test("Test A Comment Cannot Be Posted Without A Signed In User")
    func testACommentCannotBePostedWithoutASignedInUser() {
        let screen = makeScreen(signedOut: true)
        screen.presenter.commentDraft = "Nice"

        screen.presenter.onSendPressed()

        #expect(screen.interactor.added.isEmpty)
        #expect(screen.presenter.commentDraft == "Nice")
    }

    /// A comment that never reached the server must not appear in the thread, and the words the user
    /// typed have to come back so they can try again.
    @Test("Test A Failed Send Restores The Draft And Shows Nothing New")
    func testAFailedSendRestoresTheDraftAndShowsNothingNew() async {
        let screen = makeScreen()
        screen.interactor.addError = DashboardTestError.failed
        screen.presenter.commentDraft = "Strong session"

        screen.presenter.onSendPressed()
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.presenter.comments.isEmpty)
        #expect(screen.presenter.commentDraft == "Strong session")
        #expect(screen.router.alertTitles == ["Unable to Post Comment"])
    }

    // MARK: Deleting and reporting

    @Test("Test Deleting Your Comment Removes Only That One")
    func testDeletingYourCommentRemovesOnlyThatOne() async {
        let screen = makeScreen()
        screen.interactor.fetched = [
            comment("a", author: "me", on: DashboardFixture.date(day: 2, hour: 10)),
            comment("b", author: "me", on: DashboardFixture.date(day: 2, hour: 11))
        ]
        screen.presenter.onViewAppear()
        await TestManagers.eventually { screen.presenter.comments.count == 2 }

        screen.presenter.onDeleteConfirmed(screen.presenter.comments[0])
        #expect(screen.presenter.comments.map(\.id) == ["b"]) // before the write returns
        await TestManagers.eventually { !screen.interactor.deletedIds.isEmpty }

        #expect(screen.interactor.deletedIds == ["a"])
    }

    /// A delete that failed used to look like it worked until the next refresh brought the comment
    /// back. It stays put, and the user is told.
    @Test("Test A Failed Delete Keeps The Comment")
    func testAFailedDeleteKeepsTheComment() async {
        let screen = makeScreen()
        screen.interactor.fetched = [comment("a", author: "me", on: DashboardFixture.date(day: 2))]
        screen.interactor.deleteError = DashboardTestError.failed
        screen.presenter.onViewAppear()
        await TestManagers.eventually { screen.presenter.comments.count == 1 }

        screen.presenter.onDeleteConfirmed(screen.presenter.comments[0])
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.presenter.comments.map(\.id) == ["a"])
        #expect(screen.router.alertTitles == ["Unable to Delete Comment"])
    }

    /// Deleting asks first: the destructive work happens in the alert's button, so the prompt alone
    /// must delete nothing.
    @Test("Test Deleting Asks Before It Removes Anything")
    func testDeletingAsksBeforeItRemovesAnything() {
        let screen = makeScreen()

        screen.presenter.onDeletePressed(comment("a", author: "me", on: DashboardFixture.date(day: 2)))

        #expect(screen.router.alertTitles == ["Delete Comment?"])
        #expect(screen.interactor.deletedIds.isEmpty)
    }

    /// Reporting names the comment and its author, so moderation knows what was reported and who
    /// wrote it, and the reporter is told it was sent.
    @Test("Test Reporting Asks For A Reason Before Sending")
    func testReportingAsksForAReasonBeforeSending() {
        let screen = makeScreen()

        screen.presenter.onReportPressed(comment("a", on: DashboardFixture.date(day: 2)))

        #expect(screen.router.alertTitles == ["Report Comment"])
        #expect(screen.interactor.reports.isEmpty)
    }
}
