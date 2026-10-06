//
//  WorkoutTrackerPropagationTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import UIKit
@testable import Compound

/// A typed edit is carried onto its siblings once it is over, from the value the set held before
/// the first key, never from something typed on the way.
@MainActor
struct WorkoutTrackerPropagationTests {

    /// The edge-case report's #5. Per keystroke, the mistyped "80" became the original for the next
    /// key and the back-off set was rewritten.
    @Test("Test Typing 82.5 Leaves The 80 Back-Off Set Alone")
    func testTyping82Point5LeavesThe80BackOffSetAlone() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100, 80])

        screen.type(8, 80, 8, 82, 82.5, into: 1)
        screen.presenter.flushSave()

        #expect(screen.weights == [82.5, 82.5, 80])
        #expect(screen.savedWeights == [82.5, 82.5, 80])
    }

    /// A pause long enough for the debounced write is not the end of the edit.
    @Test("Test A Pause Mid-Edit Does Not Commit It")
    func testAPauseMidEditDoesNotCommitIt() async throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100, 80])

        screen.type(8, 80, into: 1)
        try await Task.sleep(for: .milliseconds(600))
        #expect(screen.savedWeights == [80, 100, 80])
        screen.type(8, 82, 82.5, into: 1)
        screen.presenter.flushSave()

        #expect(screen.weights == [82.5, 82.5, 80])
    }

    @Test("Test Siblings Do Not Change While Typing")
    func testSiblingsDoNotChangeWhileTyping() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100])

        screen.type(1, 10, 105, into: 1)

        #expect(screen.weights == [105, 100])
    }

    @Test("Test The Keyboard Hiding Commits The Edit")
    func testTheKeyboardHidingCommitsTheEdit() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100, 100])
        screen.presenter.onViewAppear()

        screen.type(105, into: 1)
        NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
        #expect(screen.weights == [105, 105, 105])

        // Not observed once the screen has gone.
        screen.presenter.onViewDisappear()
        screen.type(110, into: 1)
        NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
        #expect(screen.weights == [110, 105, 105])
    }

    /// Moving to another set ends the first edit, which carries before the second begins; the set
    /// now being typed keeps what is typed into it.
    @Test("Test Editing Another Set Commits The First Edit")
    func testEditingAnotherSetCommitsTheFirstEdit() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100, 100])

        screen.type(105, into: 1)
        screen.type(1, into: 3)
        #expect(screen.weights == [105, 105, 1])

        screen.type(90, into: 3)
        screen.presenter.flushSave()
        #expect(screen.weights == [105, 105, 90])
    }

    @Test("Test Logging The Set Being Typed Commits Its Edit")
    func testLoggingTheSetBeingTypedCommitsItsEdit() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100, 80])

        screen.type(8, 82, 82.5, into: 1)
        screen.presenter.logSet("s1", in: "e1")

        #expect(screen.weights == [82.5, 82.5, 80])
    }

    /// Logging another set logs what the user was looking at in it; the edit still carries on to
    /// the sets after it.
    @Test("Test Logging Another Set Logs What It Showed")
    func testLoggingAnotherSetLogsWhatItShowed() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100, 100])

        screen.type(105, into: 1)
        screen.presenter.logSet("s2", in: "e1")

        #expect(screen.weights == [105, 100, 105])
        #expect(screen.presenter.workoutSession.exercises[0].sets[1].completedAt != nil)
    }

    @Test("Test With Propagation Off Nothing Carries")
    func testWithPropagationOffNothingCarries() throws {
        let screen = try WorkoutTrackerTypingScreen(weights: [100, 100], propagateChanges: false)

        screen.type(105, into: 1)
        screen.presenter.flushSave()

        #expect(screen.weights == [105, 100])
    }
}
