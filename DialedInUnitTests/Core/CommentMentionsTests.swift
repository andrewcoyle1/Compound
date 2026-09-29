//
//  CommentMentionsTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 24/09/2026.
//

import Testing
import SwiftUI
@testable import DialedIn

/// `@mentions` in the comment thread: who is suggested, what picking one does to the draft, what
/// the sent comment records, and who is notified about it.
///
/// Display and identity are separate on purpose — the text carries `@FirstName`, the comment
/// carries the id — so two people called Sam stay two people.
@MainActor
struct CommentMentionsTests {

    private final class Interactor: SpyGlobalInteractor, CommentsInteractor {
        var currentUser: UserModel? = UserModel(userId: "me", submittedFirstName: "Andrew", submittedLastName: "Coyle")
        var followingUsers: [UserModel] = [
            UserModel(userId: "sam", submittedFirstName: "Sam", submittedLastName: "Lee"),
            UserModel(userId: "sara", submittedFirstName: "Sara", submittedLastName: "Jones")
        ]
        var fetched: [WorkoutSessionComment] = []
        var sessionAuthor: UserModel?
        private(set) var added: [WorkoutSessionComment] = []
        private(set) var fetchedUserIds: [String] = []

        func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment] { fetched }
        func addComment(_ comment: WorkoutSessionComment) async throws { added.append(comment) }
        func deleteComment(id: String) async throws { }
        func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws { }

        func getUser(userId: String) async throws -> UserModel {
            fetchedUserIds.append(userId)
            guard let sessionAuthor else { throw URLError(.fileDoesNotExist) }
            return sessionAuthor
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

    private func makeScreen(
        fetched: [WorkoutSessionComment] = [],
        sessionAuthor: UserModel? = nil
    ) async -> (presenter: CommentsPresenter, interactor: Interactor) {
        let interactor = Interactor()
        interactor.fetched = fetched
        interactor.sessionAuthor = sessionAuthor
        let session = DashboardFixture.session(id: "session-x", author: "author", on: DashboardFixture.date(day: 2))
        let presenter = CommentsPresenter(interactor: interactor, router: Router(), delegate: CommentsDelegate(session: session))
        presenter.onViewAppear()
        await TestManagers.eventually { !presenter.isLoading && !interactor.fetchedUserIds.isEmpty }
        return (presenter, interactor)
    }

    private func comment(_ id: String, author: String, name: String, mentioning: [String] = [], text: String = "Nice") -> WorkoutSessionComment {
        WorkoutSessionComment(
            id: id,
            sessionId: "session-x",
            sessionAuthorId: "author",
            authorId: author,
            authorName: name,
            authorImageUrl: nil,
            text: text,
            dateCreated: DashboardFixture.date(day: 2, hour: 10),
            mentionedUserIds: mentioning
        )
    }

    // MARK: - Suggestions

    /// Nothing is suggested until an `@` is followed by at least one letter at the end of the draft.
    @Test("Test Suggestions Need An At Sign Followed By Letters")
    func testSuggestionsNeedAnAtSignFollowedByLetters() async {
        let screen = await makeScreen()

        screen.presenter.commentDraft = "Great"
        #expect(screen.presenter.mentionSuggestions.isEmpty)
        screen.presenter.commentDraft = "Great @"
        #expect(screen.presenter.mentionSuggestions.isEmpty)
        screen.presenter.commentDraft = "email@sam"
        #expect(screen.presenter.mentionSuggestions.isEmpty)
        screen.presenter.commentDraft = "Great @sa"
        #expect(screen.presenter.mentionSuggestions.map(\.id) == ["sam", "sara"])
    }

    /// First name or the whole name with its spaces dropped, either case.
    @Test("Test Suggestions Match First Or Full Name")
    func testSuggestionsMatchFirstOrFullName() async {
        let screen = await makeScreen()

        screen.presenter.commentDraft = "@SamL"
        #expect(screen.presenter.mentionSuggestions.map(\.id) == ["sam"])
        screen.presenter.commentDraft = "@saraj"
        #expect(screen.presenter.mentionSuggestions.map(\.id) == ["sara"])
        screen.presenter.commentDraft = "@Lee"
        #expect(screen.presenter.mentionSuggestions.isEmpty)
    }

    /// Follows, commenters and the session's author are pooled, each person once, never the
    /// reader, and at most five.
    @Test("Test Suggestions Pool Everyone Once Without The Reader And Cap At Five")
    func testSuggestionsPoolEveryoneOnceWithoutTheReaderAndCapAtFive() async {
        let screen = await makeScreen(
            fetched: [
                comment("c1", author: "sam", name: "Sam Lee"),
                comment("c2", author: "me", name: "Andrew Coyle"),
                comment("c3", author: "stu", name: "Stu Park"),
                comment("c4", author: "sid", name: "Sid Ray"),
                comment("c5", author: "sol", name: "Sol Ng")
            ],
            sessionAuthor: UserModel(userId: "author", submittedFirstName: "Sky", submittedLastName: "Hart")
        )

        screen.presenter.commentDraft = "@s"
        await TestManagers.eventually { screen.presenter.mentionSuggestions.contains { $0.id == "author" } }
        let ids = screen.presenter.mentionSuggestions.map(\.id)
        #expect(ids.count == 5)
        #expect(Set(ids).count == ids.count)
        #expect(ids.contains { $0 == "author" })
        #expect(!ids.contains { $0 == "me" })

        screen.presenter.commentDraft = "@an"
        #expect(screen.presenter.mentionSuggestions.isEmpty)
    }

    /// The author is fetched only when nobody else names them, so they can be mentioned before
    /// they have said anything.
    @Test("Test An Unnamed Session Author Is Fetched And Suggested")
    func testAnUnnamedSessionAuthorIsFetchedAndSuggested() async {
        let screen = await makeScreen(sessionAuthor: UserModel(userId: "author", submittedFirstName: "Kim"))

        #expect(screen.interactor.fetchedUserIds == ["author"])
        screen.presenter.commentDraft = "@ki"
        await TestManagers.eventually { !screen.presenter.mentionSuggestions.isEmpty }
        #expect(screen.presenter.mentionSuggestions.map(\.id) == ["author"])
    }

    // MARK: - Picking and sending

    /// Picking a suggestion swaps the typed fragment for `@FirstName ` and remembers the id.
    @Test("Test Picking A Suggestion Inserts The First Name And Records The Id")
    func testPickingASuggestionInsertsTheFirstNameAndRecordsTheId() async throws {
        let screen = await makeScreen()
        screen.presenter.commentDraft = "Nice one @sa"
        let sam = try #require(screen.presenter.mentionSuggestions.first { $0.id == "sam" })

        screen.presenter.onMentionSuggestionPressed(sam)

        #expect(screen.presenter.commentDraft == "Nice one @Sam ")
        #expect(screen.presenter.draftMentions.map(\.id) == ["sam"])
        #expect(screen.presenter.mentionSuggestions.isEmpty)
    }

    /// The sent comment carries the ids of the mentions still in its text; one deleted from the
    /// draft before sending is not recorded.
    @Test("Test Send Carries The Mentioned User Ids Still In The Text")
    func testSendCarriesTheMentionedUserIdsStillInTheText() async throws {
        let screen = await makeScreen()
        screen.presenter.commentDraft = "@sa"
        screen.presenter.onMentionSuggestionPressed(try #require(screen.presenter.mentionSuggestions.first { $0.id == "sam" }))
        screen.presenter.commentDraft += "and @sar"
        screen.presenter.onMentionSuggestionPressed(try #require(screen.presenter.mentionSuggestions.first { $0.id == "sara" }))
        screen.presenter.commentDraft = screen.presenter.commentDraft.replacingOccurrences(of: "@Sara", with: "Sara")

        screen.presenter.onSendPressed()
        await TestManagers.eventually { !screen.interactor.added.isEmpty }

        #expect(screen.interactor.added.first?.mentionedUserIds == ["sam"])
        #expect(screen.presenter.draftMentions.isEmpty)
    }

    /// A mention in the thread is drawn in the accent colour; the rest of the text is not.
    @Test("Test A Mention Is Highlighted In The Thread")
    func testAMentionIsHighlightedInTheThread() async throws {
        let screen = await makeScreen()
        let text = screen.presenter.attributedText(for: comment("c1", author: "sara", name: "Sara Jones", mentioning: ["sam"], text: "Go @Sam go"))

        let range = try #require(text.range(of: "@Sam"))
        let mentionColor: Color? = text[range].foregroundColor
        #expect(mentionColor == Color.accentColor)
        let plain = try #require(text.range(of: "Go "))
        let plainColor: Color? = text[plain].foregroundColor
        #expect(plainColor == nil)
    }

    // MARK: - Recipients

    /// The session author and the parent's author get a comment; everyone else mentioned gets a
    /// mention; the writer gets nothing; nobody gets both.
    @Test("Test Recipients Are The Union Minus The Writer With No Duplicates")
    func testRecipientsAreTheUnionMinusTheWriterWithNoDuplicates() {
        var reply = comment("c1", author: "writer", name: "W", mentioning: ["author", "parent", "writer", "sam", "sam"])
        reply.parentId = "p1"

        let recipients = reply.activityRecipients(parentAuthorId: "parent")

        #expect(recipients.commented == ["author", "parent"])
        #expect(recipients.mentioned == ["sam"])

        let own = comment("c2", author: "author", name: "A", mentioning: ["sam"]).activityRecipients(parentAuthorId: nil)
        #expect(own.commented.isEmpty)
        #expect(own.mentioned == ["sam"])
    }

    // MARK: - Usernames

    /// Someone with a handle is suggested by it, labelled `@handle`, and picking them inserts the
    /// handle; the comment still records the id.
    @Test("Test A Handle Is Suggested Inserted And Recorded By Id")
    func testAHandleIsSuggestedInsertedAndRecordedById() async throws {
        let screen = await makeScreen()
        screen.interactor.followingUsers.append(
            UserModel(userId: "bob", submittedFirstName: "Bob", submittedLastName: "Martinez").withUsername("bob_lifts")
        )

        screen.presenter.commentDraft = "Strong @bob_l"
        let bob = try #require(screen.presenter.mentionSuggestions.first { $0.id == "bob" })
        #expect(bob.label == "@bob_lifts")

        screen.presenter.onMentionSuggestionPressed(bob)
        #expect(screen.presenter.commentDraft == "Strong @bob_lifts ")

        screen.presenter.onSendPressed()
        await TestManagers.eventually { !screen.interactor.added.isEmpty }
        #expect(screen.interactor.added.first?.mentionedUserIds == ["bob"])
    }
}
