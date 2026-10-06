//
//  WorkoutTrackerSaveCoalescingTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The session is written once per burst of typing, and at once whenever waiting could lose it.
@MainActor
struct WorkoutTrackerSaveCoalescingTests {

    /// Longer than `WorkoutSavePath.debounce`, so the debounced write has had its chance.
    private let pastTheDebounce: Duration = .milliseconds(600)

    @Test("Test A Burst Of Keystrokes Is One Write")
    func testABurstOfKeystrokesIsOneWrite() async throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100, 80])
        let before = screen.writes

        screen.type(1, 10, 100, 102, 102.5, into: 1)
        #expect(screen.writes == before)

        try await Task.sleep(for: pastTheDebounce)
        #expect(screen.writes == before + 1)
        #expect(screen.savedWeights?.first == 102.5)
    }

    @Test("Test A Flush Writes At Once And Leaves Nothing Waiting")
    func testAFlushWritesAtOnceAndLeavesNothingWaiting() async throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100, 80])
        let before = screen.writes

        screen.type(1, 10, 105, into: 1)
        screen.presenter.flushSave()
        #expect(screen.writes == before + 1)
        #expect(screen.savedWeights == [105, 105, 80])

        try await Task.sleep(for: pastTheDebounce)
        #expect(screen.writes == before + 1)
    }

    @Test("Test A Flush With Nothing Changed Writes Nothing")
    func testAFlushWithNothingChangedWritesNothing() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100])
        let before = screen.writes

        screen.presenter.flushSave()

        #expect(screen.writes == before)
    }

    // MARK: - Each flush

    @Test("Test Logging A Set Writes At Once")
    func testLoggingASetWritesAtOnce() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100])

        screen.type(1, 10, 105, into: 1)
        screen.presenter.logSet("s1", in: "e1")

        let saved = try #require(screen.interactor.activeSession?.exercises[0].sets)
        #expect(saved[0].completedAt != nil)
        #expect(saved.map(\.weightKg) == [105, 105])
    }

    @Test("Test Leaving The Foreground Writes At Once", arguments: [ScenePhase.inactive, .background])
    func testLeavingTheForegroundWritesAtOnce(phase: ScenePhase) throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100])

        screen.type(1, 10, 105, into: 1)
        screen.presenter.onScenePhaseChange(oldPhase: .active, newPhase: phase)

        #expect(screen.savedWeights == [105, 105])
    }

    @Test("Test Minimizing Writes At Once")
    func testMinimizingWritesAtOnce() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100])

        screen.type(1, 10, 105, into: 1)
        screen.presenter.minimizeSession()

        #expect(screen.savedWeights == [105, 105])
        #expect(screen.router.shown == ["dismiss"])
    }

    /// The finished session is left as the active one, with the last edit, until the shared finish
    /// clears it, so a failed save still has something for Training to resume.
    @Test("Test Finishing Writes At Once")
    func testFinishingWritesAtOnce() async throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100])

        screen.type(1, 10, 105, into: 1)
        screen.presenter.finishWorkout()

        #expect(screen.savedWeights == [105, 105])
        #expect(screen.interactor.activeSession?.endedAt != nil)
        await screen.presenter.pendingFinishTask?.value
    }

    /// A discarded workout is deleted, and the write still waiting must not put it back.
    @Test("Test Discarding Leaves Nothing To Write Back")
    func testDiscardingLeavesNothingToWriteBack() async throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100])
        let before = screen.writes

        screen.type(1, 10, 105, into: 1)
        screen.presenter.discardWorkout()
        try await Task.sleep(for: pastTheDebounce)

        #expect(screen.writes == before)
        #expect(screen.interactor.activeSession == nil)
    }

    // MARK: - Adoption

    /// An observed write while an edit waits to be saved would overwrite it with older values.
    @Test("Test A Saved Session Is Not Adopted While A Save Is Waiting")
    func testASavedSessionIsNotAdoptedWhileASaveIsWaiting() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100])
        let older = try #require(screen.interactor.activeSession)

        screen.type(1, 10, 105, into: 1)
        screen.interactor.activeSession = older
        screen.presenter.adoptSavedSessionIfChanged()
        #expect(screen.weights == [105, 100])

        // Once nothing is waiting, a write made elsewhere is taken on again.
        screen.presenter.flushSave()
        var elsewhere = try #require(screen.interactor.activeSession)
        var exercises = elsewhere.exercises
        exercises[0].sets[1].completedAt = Date()
        elsewhere.updateExercises(exercises)
        screen.interactor.activeSession = elsewhere
        screen.presenter.adoptSavedSessionIfChanged()
        #expect(screen.presenter.workoutSession.exercises[0].sets[1].completedAt != nil)
    }

    /// A workout finished from the Live Activity still closes the screen with a save waiting, and
    /// that save does not resurrect it.
    @Test("Test A Workout Finished Elsewhere Closes The Screen Even With A Save Waiting")
    func testAWorkoutFinishedElsewhereClosesTheScreenEvenWithASaveWaiting() async throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100])

        screen.type(1, 10, 105, into: 1)
        screen.interactor.activeSession = nil
        screen.presenter.adoptSavedSessionIfChanged()
        try await Task.sleep(for: pastTheDebounce)

        #expect(screen.router.shown == ["dismiss"])
        #expect(screen.interactor.activeSession == nil)
    }
}
