//
//  WorkoutNotesTests.swift
//  DialedInUnitTests
//
//  Exercise and session notes: last session's note as a hint, the header's note sheet, the finish
//  screen, the author-only feed line, and the notes surviving the session manager.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

// MARK: - Fixtures

@MainActor
private enum NotesFixture {
    static let start = Date(timeIntervalSince1970: 1_000_000)

    static func exercise(id: String = "e1", templateId: String = "template-e1", notes: String? = nil) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id,
            authorId: "author-1",
            templateId: templateId,
            name: "Bench Press",
            trackingMode: .weightReps,
            index: 1,
            notes: notes,
            sets: []
        )
    }

    static func session(
        id: String = "session-1",
        authorId: String = "author-1",
        endedAt: Date? = nil,
        notes: String? = nil,
        exercises: [WorkoutExerciseModel]
    ) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: id,
            authorId: authorId,
            name: "Push Day",
            dateCreated: start,
            endedAt: endedAt,
            notes: notes,
            exercises: exercises
        )
    }

    struct Tracker {
        let presenter: WorkoutTrackerPresenter
        let interactor: WorkoutTrackerInteractorDouble
        let router: WorkoutTrackerRouterDouble
    }

    static func tracker(
        exercises: [WorkoutExerciseModel]? = nil,
        history: [WorkoutSessionModel] = []
    ) throws -> Tracker {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = session(exercises: exercises ?? [exercise()])
        interactor.completedSessions = history
        let router = WorkoutTrackerRouterDouble()
        let presenter = try WorkoutTrackerPresenter(interactor: interactor, router: router, saveRetryBackoff: .testImmediate)
        return Tracker(presenter: presenter, interactor: interactor, router: router)
    }

    static func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }
}

// MARK: - Last session's note

@MainActor
struct WorkoutPreviousNoteTests {

    private typealias Fixture = NotesFixture

    @Test("Test The Hint Is The Note From The Last Session Containing The Exercise")
    func testTheHintIsTheNoteFromTheLastSessionContainingTheExercise() async throws {
        let presenter = try Fixture.tracker(history: [
            Fixture.session(id: "older", endedAt: Fixture.start.addingTimeInterval(-86400 * 7),
                            exercises: [Fixture.exercise(id: "o", notes: "Older note")]),
            Fixture.session(id: "latest", endedAt: Fixture.start.addingTimeInterval(-86400),
                            exercises: [Fixture.exercise(id: "l", notes: "  Grip wider  \n")])
        ]).presenter

        presenter.loadPreviousWorkoutSession()
        await Fixture.settle()

        #expect(presenter.previousNote(forExerciseTemplateId: "template-e1") == "Grip wider")
    }

    /// The last session is the last session: one that left no note gives no hint, rather than
    /// reaching further back for an older one that may no longer apply.
    @Test("Test No Hint When The Last Session Left No Note")
    func testNoHintWhenTheLastSessionLeftNoNote() async throws {
        let presenter = try Fixture.tracker(history: [
            Fixture.session(id: "older", endedAt: Fixture.start.addingTimeInterval(-86400 * 7),
                            exercises: [Fixture.exercise(id: "o", notes: "Older note")]),
            Fixture.session(id: "latest", endedAt: Fixture.start.addingTimeInterval(-86400),
                            exercises: [Fixture.exercise(id: "l", notes: "   ")])
        ]).presenter

        presenter.loadPreviousWorkoutSession()
        await Fixture.settle()

        #expect(presenter.previousNote(forExerciseTemplateId: "template-e1") == nil)
    }

    @Test("Test No Hint For An Exercise Never Done Before")
    func testNoHintForAnExerciseNeverDoneBefore() async throws {
        let presenter = try Fixture.tracker().presenter

        presenter.loadPreviousWorkoutSession()
        await Fixture.settle()

        #expect(presenter.previousNote(forExerciseTemplateId: "template-e1") == nil)
    }
}

// MARK: - The exercise header's note sheet

@MainActor
struct ExerciseNoteSheetTests {

    private final class Interactor: SpyGlobalInteractor, ExerciseTrackerInteractor {
        func exerciseNote(for exerciseId: String) -> String? { nil }
    }

    private final class Router: ExerciseTrackerRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var delegates: [WorkoutNotesDelegate] = []
        func showWorkoutNotesView(delegate: WorkoutNotesDelegate) { delegates.append(delegate) }
    }

    @Test("Test The Sheet Starts From This Session's Note With Last Session's As The Hint")
    func testTheSheetStartsFromThisSessionsNoteWithLastSessionsAsTheHint() throws {
        let router = Router()
        let presenter = ExerciseTrackerPresenter(interactor: Interactor(), router: router)
        var saved: [String] = []

        presenter.onNotePressed(
            for: NotesFixture.exercise(notes: "Felt strong"),
            previousNote: "Grip wider",
            onSave: { saved.append($0) }
        )
        let delegate = try #require(router.delegates.first)

        #expect(delegate.notes.wrappedValue == "Felt strong")
        #expect(delegate.hint == "Grip wider")
        #expect(delegate.title == "Bench Press")

        delegate.notes.wrappedValue = "Felt stronger"
        delegate.onSave()

        #expect(saved == ["Felt stronger"])
    }

    /// The header hands the note to the tracker, which stores it on the exercise; saving it empty
    /// or as whitespace clears it.
    @Test("Test Saving The Note Stores It On The Exercise And Blank Clears It")
    func testSavingTheNoteStoresItOnTheExerciseAndBlankClearsIt() throws {
        let screen = try NotesFixture.tracker()
        let presenter = screen.presenter, interactor = screen.interactor

        presenter.updateExerciseNotes("  Elbows in ", exerciseId: "e1")
        #expect(presenter.workoutSession.exercises[0].notes == "Elbows in")
        #expect(interactor.activeSession?.exercises[0].notes == "Elbows in")

        presenter.updateExerciseNotes(" \n", exerciseId: "e1")
        #expect(presenter.workoutSession.exercises[0].notes == nil)
    }
}

// MARK: - The finish screen

@MainActor
struct WorkoutFinishNoteTests {

    @Test("Test Finishing Saves The Session Note Then Ends The Workout")
    func testFinishingSavesTheSessionNoteThenEndsTheWorkout() async throws {
        let screen = try NotesFixture.tracker()
        let presenter = screen.presenter, interactor = screen.interactor, router = screen.router

        presenter.onFinishPressed()
        let delegate = try #require(router.notesDelegates.first)
        #expect(delegate.saveTitle == "Finish")

        delegate.notes.wrappedValue = " Good session "
        delegate.onSave()
        // Nothing ends until the sheet is gone.
        #expect(!presenter.isDone)
        delegate.onDidDismiss?()

        #expect(presenter.isDone)
        let ended = await TestManagers.eventually { !interactor.endedSessions.isEmpty }
        #expect(ended)
        #expect(interactor.endedSessions.first?.notes == "Good session")
    }

    @Test("Test Cancelling The Finish Screen Keeps The Workout Going")
    func testCancellingTheFinishScreenKeepsTheWorkoutGoing() throws {
        let screen = try NotesFixture.tracker()
        let presenter = screen.presenter, interactor = screen.interactor, router = screen.router

        presenter.onFinishPressed()
        let delegate = try #require(router.notesDelegates.first)
        delegate.notes.wrappedValue = "Draft"
        delegate.onDidDismiss?()

        #expect(!presenter.isDone)
        #expect(presenter.workoutSession.notes == nil)
        #expect(interactor.endedSessions.isEmpty)
    }

    /// A resumed workout's note used to show as "None" and be wiped by the next save, because the
    /// draft always started empty.
    @Test("Test A Resumed Workout's Note Seeds The Editor")
    func testAResumedWorkoutsNoteSeedsTheEditor() throws {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = NotesFixture.session(notes: "Deload week", exercises: [NotesFixture.exercise()])
        let router = WorkoutTrackerRouterDouble()
        let presenter = try WorkoutTrackerPresenter(interactor: interactor, router: router)

        presenter.presentWorkoutNotes()
        let delegate = try #require(router.notesDelegates.first)
        #expect(delegate.notes.wrappedValue == "Deload week")

        delegate.onSave()
        #expect(presenter.workoutSession.notes == "Deload week")
    }
}

// MARK: - The feed row

@MainActor
struct WorkoutSessionRowNoteTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutSessionRowInteractor {
        var currentUser: UserModel?
        var allExercises: [ExerciseModel] = []
        var allWorkoutTemplates: [WorkoutTemplateModel] = []
        init(readerId: String) { currentUser = UserModel(userId: readerId) }
        func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel] { [] }
        func likeSession(sessionId: String, authorId: String, userId: String) async throws { }
        func unlikeSession(sessionId: String, authorId: String, userId: String) async throws { }
        func report(contentType: ReportContentType, contentId: String, authorUserId: String?, reason: ReportReason, notes: String?) async throws { }
        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws { }
    }

    private final class Router: WorkoutSessionRowRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { }
        func showSocialProfileView(delegate: SocialProfileDelegate) { }
        func showCommentsView(delegate: CommentsDelegate) { }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { }
        func showShareToFollowerView(delegate: ShareToFollowerDelegate) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    private func row(readerId: String, notes: String?) -> WorkoutSessionRowPresenter {
        let session = NotesFixture.session(endedAt: NotesFixture.start, notes: notes, exercises: [NotesFixture.exercise()])
        return WorkoutSessionRowPresenter(
            interactor: Interactor(readerId: readerId),
            router: Router(),
            delegate: WorkoutSessionRowDelegate(session: session, author: UserModel(userId: "author-1"))
        )
    }

    @Test("Test The Author Sees Their Note On The Feed Row")
    func testTheAuthorSeesTheirNoteOnTheFeedRow() {
        #expect(row(readerId: "author-1", notes: "Left shoulder twinged").authorNote == "Left shoulder twinged")
    }

    @Test("Test A Follower Never Sees The Note")
    func testAFollowerNeverSeesTheNote() {
        #expect(row(readerId: "friend", notes: "Left shoulder twinged").authorNote == nil)
    }

    @Test("Test A Blank Note Shows Nothing")
    func testABlankNoteShowsNothing() {
        #expect(row(readerId: "author-1", notes: "  ").authorNote == nil)
    }
}

// MARK: - Through the session manager

@MainActor
struct WorkoutNotesPersistenceTests {

    @Test("Test Notes Survive The Active Session And Ending It")
    func testNotesSurviveTheActiveSessionAndEndingIt() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [])
        let live = NotesFixture.session(
            id: "live",
            notes: "Tired today",
            exercises: [NotesFixture.exercise(notes: "Elbows in")]
        )

        try manager.updateActiveSession(live)
        #expect(manager.activeSession?.notes == "Tired today")
        #expect(manager.activeSession?.exercises.first?.notes == "Elbows in")

        var ended = live
        ended.endSession(at: NotesFixture.start.addingTimeInterval(3600))
        try await manager.endWorkoutSession(ended)

        let logged = await TestManagers.eventually { manager.workoutSessions.map(\.id) == ["live"] }
        #expect(logged)
        let saved = try #require(manager.workoutSessions.first)
        #expect(saved.notes == "Tired today")
        #expect(saved.exercises.first?.notes == "Elbows in")
    }

    /// Firestore stores the session as encoded, so the notes must round-trip through Codable.
    @Test("Test Notes Round-Trip Through Encoding")
    func testNotesRoundTripThroughEncoding() throws {
        let session = NotesFixture.session(notes: "Tired today", exercises: [NotesFixture.exercise(notes: "Elbows in")])

        let decoded = try JSONDecoder().decode(WorkoutSessionModel.self, from: JSONEncoder().encode(session))

        #expect(decoded.notes == "Tired today")
        #expect(decoded.exercises.first?.notes == "Elbows in")
    }
}
