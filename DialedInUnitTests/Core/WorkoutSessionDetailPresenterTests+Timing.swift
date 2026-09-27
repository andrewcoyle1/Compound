//
//  WorkoutSessionDetailPresenterTests+Timing.swift
//  DialedInUnitTests
//
//  Split out of WorkoutSessionDetailPresenterTests.swift, which reached the 750-line file limit.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

extension WorkoutSessionDetailPresenterTests {

    // MARK: - Timing

    /// Moving the start moves the end with it, so correcting when a workout began does not silently
    /// change how long it lasted.
    @Test("Test Moving The Start Keeps The Duration")
    func testMovingTheStartKeepsTheDuration() async {
        let screen = makeScreen()
        let workout = MutableSession(session(duration: 3600))
        let newStart = start.addingTimeInterval(7200)

        screen.presenter.onStartTimeChanged(newStart, session: workout.binding)
        await settle()

        #expect(workout.value.dateCreated == newStart)
        #expect(workout.value.endedAt == newStart.addingTimeInterval(3600))
        #expect(screen.interactor.savedSessions.count == 1)
    }

    @Test("Test Editing The Duration Starts From What The Session Lasted")
    func testEditingTheDurationStartsFromWhatTheSessionLasted() {
        let screen = makeScreen()

        screen.presenter.onEditDurationPressed(session: MutableSession(session(duration: 5400)).binding)

        #expect(screen.presenter.durationHours == 1)
        #expect(screen.presenter.durationMinutes == 30)
        #expect(screen.router.shown == ["duration"])
    }

    /// The picker is a router sheet now; saving from it is the same confirm, and it plays the
    /// success haptic once the write lands.
    @Test("Test Saving From The Duration Sheet Saves And Confirms")
    func testSavingFromTheDurationSheetSavesAndConfirms() async {
        let screen = makeScreen()
        let workout = MutableSession(session(duration: 3600))
        screen.presenter.onEditDurationPressed(session: workout.binding)
        screen.presenter.durationMinutes = 45

        screen.router.durationSave?()
        await settle()

        #expect(workout.value.endedAt == start.addingTimeInterval(3600 + 45 * 60))
        #expect(screen.interactor.savedSessions.count == 1)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    @Test("Test Moving The Start From The Sheet Saves It")
    func testMovingTheStartFromTheSheetSavesIt() async {
        let screen = makeScreen()
        let workout = MutableSession(session(duration: 3600))
        let newStart = start.addingTimeInterval(-600)
        screen.presenter.onEditStartTimePressed(session: workout.binding)

        screen.router.startTimeDate?.wrappedValue = newStart
        await settle()

        #expect(workout.value.dateCreated == newStart)
        #expect(screen.interactor.savedSessions.count == 1)
    }

    @Test("Test A Failed Timing Save Plays The Error Haptic")
    func testAFailedTimingSavePlaysTheErrorHaptic() async {
        let screen = makeScreen()
        screen.interactor.saveError = URLError(.notConnectedToInternet)
        let workout = MutableSession(session(duration: 3600))

        screen.presenter.onStartTimeChanged(start.addingTimeInterval(60), session: workout.binding)
        await settle()

        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    @Test("Test Confirming A Duration Moves The End")
    func testConfirmingADurationMovesTheEnd() async {
        let screen = makeScreen()
        let workout = MutableSession(session(duration: 3600))
        screen.presenter.durationHours = 2
        screen.presenter.durationMinutes = 15

        screen.presenter.onDurationConfirmed(session: workout.binding)
        await settle()

        #expect(workout.value.endedAt == start.addingTimeInterval(2 * 3600 + 15 * 60))
    }

    /// A zero duration would put the end before the beginning, so it is refused rather than saved.
    @Test("Test A Zero Duration Is Refused")
    func testAZeroDurationIsRefused() async {
        let screen = makeScreen()
        let workout = MutableSession(session(duration: 3600))
        screen.presenter.durationHours = 0
        screen.presenter.durationMinutes = 0

        screen.presenter.onDurationConfirmed(session: workout.binding)
        await settle()

        #expect(workout.value.endedAt == start.addingTimeInterval(3600))
        #expect(screen.interactor.savedSessions.isEmpty)
    }
}

// MARK: - Only the author edits
extension WorkoutSessionDetailPresenterTests {
    /// The feed opens other people's sessions here. Their timing rows used to open the pickers and
    /// save, and Edit Workout used to open the notes editor, for whoever was reading.
    @Test("Test A Reader Who Is Not The Author Cannot Edit")
    func testAReaderWhoIsNotTheAuthorCannotEdit() {
        let screen = makeScreen(user: UserModel(userId: "someone-else"))
        let workout = MutableSession(session(duration: 3600))

        screen.presenter.onEditStartTimePressed(session: workout.binding)
        screen.presenter.onEditDurationPressed(session: workout.binding)
        screen.presenter.enterEditMode(session: workout.value)

        #expect(screen.router.shown.isEmpty)
        #expect(!screen.presenter.isEditMode)
    }
}
