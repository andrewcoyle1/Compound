//
//  WorkoutTrackerResumeTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import UIKit
@testable import Compound

/// The tracker on return (system.md §2): the rest is the owner's, sets logged elsewhere get a
/// receipt, a forgotten workout is asked about, and a finish from elsewhere opens on its summary.
@MainActor
struct WorkoutTrackerResumeTests {

    /// One exercise, "e1", with three open sets of 100 kg × 8.
    private func makeScreen() throws -> WorkoutTrackerTypingScreen {
        try WorkoutTrackerTypingScreen(weights: [100, 100, 100])
    }

    /// The Live Activity's log: the handler stamps the set and saves through the manager.
    private func logElsewhere(_ setNumber: Int, at date: Date, on screen: WorkoutTrackerTypingScreen) throws {
        var saved = try #require(screen.interactor.activeSession)
        var exercises = saved.exercises
        exercises[0].sets[setNumber - 1].completedAt = date
        saved.updateExercises(exercises)
        screen.interactor.activeSession = saved
    }

    // MARK: - Rest

    /// system.md #3: a phone rest ran out (its start is kept, for Ready), then a set was logged
    /// from the Lock Screen, which started a rest of its own. The row used to vanish, because the
    /// screen compared the new set with its own stale start.
    @Test("Test A Rest Started From The Lock Screen After A Phone Rest Ran Out Is Shown")
    func testLockScreenRestAfterAnExpiredPhoneRest() throws {
        let screen = try makeScreen()
        let phoneRest = Date().addingTimeInterval(-300)
        try logElsewhere(1, at: phoneRest.addingTimeInterval(-1), on: screen)
        let loggedAt = Date().addingTimeInterval(-5)
        try logElsewhere(2, at: loggedAt, on: screen)
        // The owner's start moved with the Lock Screen's rest; the screen's own copy did not.
        screen.interactor.restStartedAt = loggedAt.addingTimeInterval(0.1)
        screen.interactor.restEndTime = loggedAt.addingTimeInterval(90)
        screen.presenter.adoptSavedSessionIfChanged()

        let exercise = try #require(screen.presenter.workoutSession.exercises.first)
        let timer = try #require(screen.presenter.restTimer(for: exercise))
        #expect(timer.anchor == .below(setId: "s2"))
        #expect(timer.startedAt == screen.interactor.restStartedAt)
    }

    // MARK: - Receipt

    @Test("Test A Set Logged From The Lock Screen Shows As A Receipt Until The Next Action")
    func testReceiptUntilNextAction() throws {
        let screen = try makeScreen()
        screen.presenter.startObservingActiveSession()
        screen.presenter.lastSeenSetCompletion = Date().addingTimeInterval(-10)

        try logElsewhere(2, at: Date().addingTimeInterval(-1), on: screen)
        screen.presenter.onScenePhaseChange(oldPhase: .inactive, newPhase: .active)

        #expect(screen.presenter.progressionNote == "Logged from Lock Screen: Set 2 · 100 kg × 8")

        screen.presenter.updateExerciseNotes("Felt heavy", exerciseId: "e1")
        #expect(screen.presenter.logReceipt == nil)
    }

    @Test("Test Dismissing The Receipt Clears It")
    func testDismissingTheReceipt() throws {
        let screen = try makeScreen()
        screen.presenter.startObservingActiveSession()
        screen.presenter.lastSeenSetCompletion = Date().addingTimeInterval(-10)
        try logElsewhere(1, at: Date().addingTimeInterval(-1), on: screen)
        screen.presenter.adoptSavedSessionIfChanged()
        #expect(screen.presenter.logReceipt != nil)

        screen.presenter.onProgressionNoteAcknowledged()

        #expect(screen.presenter.logReceipt == nil)
    }

    @Test("Test A Set Logged On This Screen Owes No Receipt")
    func testOwnLogOwesNoReceipt() throws {
        let screen = try makeScreen()
        screen.presenter.startObservingActiveSession()

        screen.presenter.logSet("s1", in: "e1")

        #expect(screen.presenter.workoutSession.exercises[0].sets[0].completedAt != nil)
        #expect(screen.presenter.logReceipt == nil)
    }

    /// Minimised, the presenter is released; the one built on reopening still owns up.
    @Test("Test A Tracker Rebuilt After A Minimise Still Shows The Receipt")
    func testReceiptSurvivesARebuild() throws {
        let screen = try makeScreen()
        screen.presenter.startObservingActiveSession()
        screen.presenter.minimizeSession()

        try logElsewhere(3, at: Date().addingTimeInterval(1), on: screen)
        let reopened = try WorkoutTrackerPresenter(interactor: screen.interactor, router: screen.router, saveRetryBackoff: .testImmediate)
        reopened.startObservingActiveSession()

        #expect(reopened.logReceipt == "Logged from Lock Screen: Set 3 · 100 kg × 8")
    }

    @Test("Test A Workout Opened For The First Time Owes No Receipt")
    func testFirstOpenOwesNothing() throws {
        let screen = try makeScreen()
        try logElsewhere(1, at: Date().addingTimeInterval(-60), on: screen)
        let presenter = try WorkoutTrackerPresenter(interactor: screen.interactor, router: screen.router, saveRetryBackoff: .testImmediate)

        presenter.startObservingActiveSession()

        #expect(presenter.logReceipt == nil)
    }

    // MARK: - Still training?

    @Test("Test An Hour With Nothing Logged Asks Once Whether The Workout Is Still On")
    func testIdleAsksOnce() throws {
        let screen = try makeScreen()
        try logElsewhere(1, at: Date().addingTimeInterval(-60), on: screen)
        screen.presenter.adoptSavedSessionIfChanged()
        screen.presenter.startObservingActiveSession()
        #expect(screen.router.alerts.isEmpty)

        let later = Date().addingTimeInterval(2 * 3_600)
        screen.presenter.askIfStillTraining(now: later)
        screen.presenter.askIfStillTraining(now: later)

        #expect(screen.router.alerts == ["Still training?"])
    }

    @Test("Test Within The Hour Nothing Is Asked")
    func testNotIdle() throws {
        let screen = try makeScreen()
        screen.presenter.startObservingActiveSession()
        screen.presenter.logSet("s1", in: "e1")

        screen.presenter.askIfStillTraining(now: Date().addingTimeInterval(30 * 60))

        #expect(screen.router.alerts.isEmpty)
    }

    /// The forgotten hour is not counted: the workout ends when its last set was logged.
    @Test("Test Finish At The Last Set Ends The Workout Then")
    func testFinishAtLastSet() async throws {
        let screen = try makeScreen()
        let lastSet = Date().addingTimeInterval(-2 * 3_600)
        try logElsewhere(1, at: lastSet, on: screen)
        screen.presenter.adoptSavedSessionIfChanged()

        screen.presenter.onFinishAtLastSetPressed()

        #expect(screen.router.summarySessions.first?.endedAt == lastSet)
        await screen.presenter.pendingFinishTask?.value
        #expect(screen.interactor.endedSessions.first?.endedAt == lastSet)
    }

    // MARK: - Finished elsewhere

    @Test("Test A Workout Finished From The Live Activity Opens On Its Summary")
    func testFinishedElsewhereShowsSummary() async throws {
        let screen = try makeScreen()
        var finished = try #require(screen.interactor.activeSession)
        finished.endSession(at: Date())
        try await screen.interactor.endWorkoutSession(finished)
        screen.interactor.activeSession = nil

        screen.presenter.adoptSavedSessionIfChanged()

        #expect(screen.router.shown == ["summary"])
        #expect(screen.router.summarySessions.first?.id == finished.id)
    }

    // MARK: - Minimise

    @Test("Test Minimising Lets The Phone Sleep Again")
    func testMinimiseClearsIdleTimer() throws {
        let screen = try makeScreen()
        UIApplication.shared.isIdleTimerDisabled = true

        screen.presenter.minimizeSession()

        #expect(UIApplication.shared.isIdleTimerDisabled == false)
    }
}
