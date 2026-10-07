//
//  WorkoutTrackerCorrectionTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The correction row under the set just logged, and the undo stack behind shake and ⌘Z.
///
/// A set is logged first and corrected after (`docs/specs/workout-tracker/input.md` §2): a rep
/// off re-suggests the sets still to come, reps in reserve are stored as RPE, and Undo un-logs
/// the set and calls off its rest. The undo manager carries log, un-log, delete and reps taps,
/// with the taps on one set undone as one.
@MainActor
struct WorkoutTrackerCorrectionTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// Three sets of 60 kg × 8 against an 8–12 target, as smart progression's tests use.
    private func makeScreen(rirTracking: Bool = false) throws -> (presenter: WorkoutTrackerPresenter, interactor: WorkoutTrackerInteractorDouble) {
        let sets = (1...3).map {
            WorkoutSetModel(id: "set-\($0)", authorId: "author-1", index: $0, reps: 8, weightKg: 60, isWarmup: false, dateCreated: start)
        }
        let exercise = WorkoutExerciseModel(
            id: "exercise-1", authorId: "author-1", templateId: "template-exercise-1", name: "Bench Press",
            trackingMode: .weightReps, index: 1, sets: sets,
            setTargets: (1...3).map { SetTarget(id: "target-\($0)", setNumber: $0, minReps: 8, maxReps: 12) }
        )
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.workoutSettings.smartProgressionApplyInSession = true
        interactor.workoutSettings.propagateChanges = false
        interactor.workoutSettings.rirTracking = rirTracking
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Push Day", workoutTemplateId: "template-1", dateCreated: start, exercises: [exercise]
        )
        let presenter = try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble(), saveRetryBackoff: .testImmediate)
        return (presenter, interactor)
    }

    /// An undo manager that groups only what the presenter groups, so each action is one step
    /// without a run loop turning between them.
    private func undoManager(for presenter: WorkoutTrackerPresenter) -> UndoManager {
        let undo = UndoManager()
        undo.groupsByEvent = false
        presenter.onUndoManagerChanged(undo)
        return undo
    }

    private func sets(_ presenter: WorkoutTrackerPresenter) -> [WorkoutSetModel] {
        presenter.workoutSession.exercises[0].sets
    }

    private func card(_ presenter: WorkoutTrackerPresenter) -> SetCorrection? {
        presenter.correction(for: presenter.workoutSession.exercises[0])
    }

    // MARK: - The row

    @Test func theRowFollowsTheSetJustLogged() throws {
        let (presenter, _) = try makeScreen(rirTracking: true)
        #expect(card(presenter) == nil)

        presenter.logSet("set-1", in: "exercise-1")
        let correction = try #require(card(presenter))
        #expect(correction.setId == "set-1")
        #expect(correction.title == "Set 1 · 60 kg × 8")
        #expect(correction.correctsReps && correction.canRemoveRep && correction.showsRIR)

        presenter.logSet("set-2", in: "exercise-1")
        #expect(card(presenter)?.setId == "set-2")
    }

    /// Two reps short of the range: the sets still to come are lightened, as they would have been
    /// had the set been logged at six.
    @Test func takingRepsOffReSuggestsTheRemainingSets() throws {
        let (presenter, _) = try makeScreen()
        presenter.logSet("set-1", in: "exercise-1")
        #expect(sets(presenter).dropFirst().allSatisfy { $0.weightKg == 60 })

        presenter.onCorrection(.reps(delta: -1), setId: "set-1", in: "exercise-1")
        presenter.onCorrection(.reps(delta: -1), setId: "set-1", in: "exercise-1")

        #expect(sets(presenter)[0].reps == 6)
        #expect(sets(presenter)[0].completedAt != nil)
        #expect(sets(presenter).dropFirst().allSatisfy { $0.weightKg == 57 && $0.reps == 8 })
    }

    @Test func repsNeverGoBelowOne() throws {
        let (presenter, _) = try makeScreen()
        presenter.workoutSession.exercises[0].sets[0].reps = 1
        presenter.logSet("set-1", in: "exercise-1")
        #expect(card(presenter)?.canRemoveRep == false)
        presenter.onCorrection(.reps(delta: -1), setId: "set-1", in: "exercise-1")
        #expect(sets(presenter)[0].reps == 1)
    }

    @Test func aRIRChipStoresTheMappedRPEAndTogglesOff() throws {
        let (presenter, _) = try makeScreen(rirTracking: true)
        presenter.logSet("set-1", in: "exercise-1")

        presenter.onCorrection(.rir(2), setId: "set-1", in: "exercise-1")
        #expect(sets(presenter)[0].rpe == 8)
        #expect(card(presenter)?.selectedRIR == 2)

        presenter.onCorrection(.rir(4), setId: "set-1", in: "exercise-1")
        #expect(sets(presenter)[0].rpe == 6)

        presenter.onCorrection(.rir(4), setId: "set-1", in: "exercise-1")
        #expect(sets(presenter)[0].rpe == nil)
    }

    @Test func noChipsWithRIRTrackingOff() throws {
        let (presenter, _) = try makeScreen(rirTracking: false)
        presenter.logSet("set-1", in: "exercise-1")
        #expect(card(presenter)?.showsRIR == false)
    }

    @Test func undoUnlogsTheSetAndCancelsTheRest() throws {
        let (presenter, interactor) = try makeScreen()
        presenter.logSet("set-1", in: "exercise-1")
        #expect(interactor.startedRests.count == 1)
        #expect(presenter.restTimer(for: presenter.workoutSession.exercises[0]) != nil)

        presenter.onCorrection(.undo, setId: "set-1", in: "exercise-1")

        #expect(sets(presenter)[0].completedAt == nil)
        #expect(interactor.didCancelRest)
        #expect(presenter.restStartedAt == nil)
        #expect(card(presenter) == nil)
    }

    // MARK: - Undo manager

    @Test func theUndoStackCarriesTheActionNames() throws {
        let (presenter, interactor) = try makeScreen()
        let undo = undoManager(for: presenter)

        presenter.logSet("set-1", in: "exercise-1")
        #expect(undo.undoActionName == "Log Set 1")
        #expect(undo.undoMenuItemTitle == "Undo Log Set 1")

        undo.undo()
        #expect(sets(presenter)[0].completedAt == nil)
        #expect(interactor.didCancelRest)
        #expect(undo.redoActionName == "Log Set 1")

        undo.redo()
        #expect(sets(presenter)[0].completedAt != nil)

        // The row's circle un-logs through the binding, not `updateSet`.
        presenter.workoutSession.exercises[0].sets[0].completedAt = nil
        #expect(undo.undoActionName == "Unlog Set 1")
        undo.undo()
        #expect(sets(presenter)[0].completedAt != nil)
    }

    /// A swipe removes the set through the binding; undoing puts it back where it was.
    @Test func aDeletedSetComesBackInPlace() throws {
        let (presenter, _) = try makeScreen()
        let undo = undoManager(for: presenter)

        presenter.workoutSession.exercises[0].sets.remove(at: 1)
        #expect(undo.undoActionName == "Delete Set")

        undo.undo()
        #expect(sets(presenter).map(\.id) == ["set-1", "set-2", "set-3"])
    }

    @Test func threeRepsTapsUndoAsOne() throws {
        let (presenter, _) = try makeScreen()
        let undo = undoManager(for: presenter)
        presenter.logSet("set-1", in: "exercise-1")

        for _ in 0..<3 {
            presenter.onCorrection(.reps(delta: 1), setId: "set-1", in: "exercise-1")
        }
        #expect(sets(presenter)[0].reps == 11)
        #expect(undo.undoActionName == "Change Reps")

        undo.undo()
        #expect(sets(presenter)[0].reps == 8)
        #expect(sets(presenter)[0].completedAt != nil)
        #expect(undo.undoActionName == "Log Set 1")
    }

    /// The set's log was stamped again since (adopted from the Live Activity, say): the old
    /// undo no longer describes it and leaves it alone.
    @Test func anUndoIsSkippedOnceTheSetHasChanged() throws {
        let (presenter, _) = try makeScreen()
        let undo = undoManager(for: presenter)
        presenter.logSet("set-1", in: "exercise-1")

        let restamped = start.addingTimeInterval(3_600)
        presenter.workoutSession.exercises[0].sets[0].completedAt = restamped
        undo.undo()

        #expect(sets(presenter)[0].completedAt == restamped)
    }

    /// The card going takes this screen's actions off the window's stack.
    @Test func theCardGoingClearsItsActions() throws {
        let (presenter, _) = try makeScreen()
        let undo = undoManager(for: presenter)
        presenter.logSet("set-1", in: "exercise-1")
        #expect(undo.canUndo)

        presenter.onUndoManagerChanged(nil)
        #expect(!undo.canUndo)
    }
}
