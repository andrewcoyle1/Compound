//
//  WorkoutTrackerPrimarySlotTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The button at the foot of the tracker on the live screen: a double tap logs once, a rest that
/// runs out holds the button for a second, and a paused workout resumes from it.
@MainActor
struct WorkoutTrackerPrimarySlotTests {

    private func makeScreen() throws -> (WorkoutTrackerPresenter, WorkoutTrackerInteractorDouble) {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Legs", dateCreated: Date(),
            exercises: [
                WorkoutExerciseModel(
                    id: "e1", authorId: "author-1", templateId: "t1", name: "Squat", trackingMode: .weightReps, index: 1,
                    sets: ["s1", "s2"].map { id in
                        WorkoutSetModel(id: id, authorId: "author-1", index: 1, reps: 5, weightKg: 100, isWarmup: false, completedAt: nil, dateCreated: Date())
                    }
                )
            ]
        )
        return (try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble()), interactor)
    }

    private func loggedCount(_ presenter: WorkoutTrackerPresenter) -> Int {
        presenter.workoutSession.exercises[0].sets.filter { $0.completedAt != nil }.count
    }

    /// The second tap lands on Skip Rest, which the first tap has just made the button.
    @Test("Test A Double Tap Logs One Set And Leaves The Rest Running")
    func testDoubleTap() throws {
        let (presenter, interactor) = try makeScreen()
        let now = Date()

        presenter.onPrimarySlotPressed(at: now)
        presenter.onPrimarySlotPressed(at: now.addingTimeInterval(0.1))

        #expect(loggedCount(presenter) == 1)
        #expect(interactor.startedRests == [90])
        #expect(!interactor.didCancelRest)
        #expect(presenter.primarySlot == .skipRest)
    }

    @Test("Test A Tap After The Lockout Skips The Rest, And One Straight After Does Not Log")
    func testTapAfterLockout() throws {
        let (presenter, interactor) = try makeScreen()
        let now = Date()

        presenter.onPrimarySlotPressed(at: now)
        presenter.onPrimarySlotPressed(at: now.addingTimeInterval(0.5))
        #expect(interactor.didCancelRest)
        #expect(presenter.primarySlot == .log(exerciseId: "e1", setId: "s2"))

        presenter.onPrimarySlotPressed(at: now.addingTimeInterval(0.6))
        #expect(loggedCount(presenter) == 1)

        presenter.onPrimarySlotPressed(at: now.addingTimeInterval(1))
        #expect(loggedCount(presenter) == 2)
    }

    /// Typing into the set changes the title, not the action, so it does not hold the button.
    @Test("Test The Same Action Reported Again Does Not Restart The Lockout")
    func testSameActionKeepsLockout() throws {
        let (presenter, _) = try makeScreen()
        presenter.onPrimarySlotChanged(presenter.primarySlot)
        presenter.workoutSession.exercises[0].sets[0].weightKg = 102.5
        presenter.onPrimarySlotChanged(presenter.primarySlot)

        presenter.onPrimarySlotPressed()

        #expect(loggedCount(presenter) == 1)
    }

    @Test("Test A Rest That Runs Out Holds The Button For A Second")
    func testRestDoneGrace() throws {
        let (presenter, interactor) = try makeScreen()
        let start = Date()
        presenter.onPrimarySlotPressed(at: start)
        // The rest timer's owner forgets the end the moment it passes.
        let end = Date().addingTimeInterval(-0.2)
        interactor.restEndTime = nil
        presenter.onRunningRestEndChanged(from: end, to: nil, now: end.addingTimeInterval(0.1))

        #expect(presenter.isPrimarySlotInGrace)
        #expect(presenter.primarySlotTitle == "Rest done · Log set 2 · 100 kg × 5")
        presenter.onPrimarySlotPressed(at: end.addingTimeInterval(0.6))
        #expect(loggedCount(presenter) == 1)

        presenter.onPrimarySlotPressed(at: end.addingTimeInterval(1.1))
        #expect(loggedCount(presenter) == 2)
    }

    @Test("Test A Skipped Rest Has No Grace")
    func testSkippedRestHasNoGrace() throws {
        let (presenter, _) = try makeScreen()
        let end = Date().addingTimeInterval(60)

        presenter.onRunningRestEndChanged(from: end, to: nil)

        #expect(presenter.expiredRestEnd == nil)
        #expect(!presenter.isPrimarySlotInGrace)
        #expect(presenter.primarySlotTitle == "Log set 1 · 100 kg × 5")
    }

    @Test("Test Paused, The Button And The Title Say So, And The Button Resumes")
    func testPaused() throws {
        let (presenter, interactor) = try makeScreen()
        presenter.onPauseResumePressed()

        #expect(presenter.primarySlot == .resume)
        #expect(presenter.primarySlotTitle == "Resume Workout")
        #expect(presenter.clockText(at: Date()) == "Paused")

        presenter.onPrimarySlotPressed(at: Date().addingTimeInterval(1))

        #expect(interactor.isWorkoutActive)
        #expect(loggedCount(presenter) == 0)
        #expect(presenter.primarySlot == .log(exerciseId: "e1", setId: "s1"))
    }

    @Test("Test Gym Settings Is Offered Only With A Gym")
    func testGymSettingsNeedsAGym() throws {
        let (presenter, interactor) = try makeScreen()
        #expect(!presenter.hasGymProfile)

        interactor.favouriteGymProfile = GymProfileModel(id: "gym-1", authorId: "author-1", name: "Home Gym")

        #expect(presenter.hasGymProfile)
    }

    @Test("Test The Current Set Follows A Log, For The List To Scroll To")
    func testCurrentLogSetId() throws {
        let (presenter, _) = try makeScreen()
        #expect(presenter.currentLogSetId == "s1")

        presenter.onPrimaryActionPressed()

        #expect(presenter.currentLogSetId == "s2")
    }
}
