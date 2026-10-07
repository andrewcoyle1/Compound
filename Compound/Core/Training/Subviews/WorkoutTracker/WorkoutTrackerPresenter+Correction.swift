//
//  WorkoutTrackerPresenter+Correction.swift
//  Compound
//
//  Correcting a set after it is logged, and undoing it. The correction row under the set just
//  logged takes reps off or on, records reps in reserve and un-logs it; the window's
//  `UndoManager` carries log, un-log, delete and those reps taps, so shake and ⌘Z undo them too.
//  The rules are in `ActiveWorkout+Correction`.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    // MARK: - Correction row

    /// The correction row for `exercise`'s card, or `nil` when there is nothing to correct on it.
    func correction(for exercise: WorkoutExerciseModel) -> SetCorrection? {
        let latest = ActiveWorkout.latestCompletedSet(in: workoutSession.exercises)
        guard let setId = ActiveWorkout.correctionTarget(in: exercise, latestLogged: latest),
              let set = exercise.sets.first(where: { $0.id == setId }) else { return nil }
        let units = units(for: exercise)
        let countsReps = exercise.trackingMode == .weightReps || exercise.trackingMode == .repsOnly
        return SetCorrection(
            setId: setId,
            title: ActiveWorkout.correctionTitle(for: set, in: exercise, unit: units.weightUnit, distanceUnit: units.distanceUnit),
            spokenLabel: ActiveWorkout.correctionSpokenLabel(for: set, in: exercise, unit: units.weightUnit, distanceUnit: units.distanceUnit),
            correctsReps: countsReps && set.reps != nil,
            canRemoveRep: (set.reps ?? 0) > 1,
            showsRIR: countsReps && showRIRTracking,
            selectedRIR: ActiveWorkout.rirChip(forRPE: set.rpe)
        )
    }

    func onCorrection(_ action: SetCorrectionAction, setId: String, in exerciseId: String) {
        switch action {
        case .reps(let delta):
            correctReps(by: delta, setId: setId, in: exerciseId)
        case .rir(let chip):
            setRIR(chip, setId: setId, in: exerciseId)
        case .undo:
            interactor.trackEvent(event: CorrectionEvent.undo)
            unlog(setId, in: exerciseId)
        }
    }

    /// A rep off or on, after the set: the remaining sets are suggested again from what was done.
    private func correctReps(by delta: Int, setId: String, in exerciseId: String) {
        guard var set = loggedSet(setId, in: exerciseId), let reps = set.reps else { return }
        let corrected = max(1, reps + delta)
        guard corrected != reps else { return }
        registerRepsUndo(restoring: set, in: exerciseId)
        set.reps = corrected
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: CorrectionEvent.reps(delta: delta))
        updateSet(set, in: exerciseId)
        applyLiveProgression(after: set, in: exerciseId)
    }

    /// Stored as RPE, as the keypad's chips store it. The chip already chosen clears it.
    private func setRIR(_ chip: Int, setId: String, in exerciseId: String) {
        guard var set = loggedSet(setId, in: exerciseId) else { return }
        let rpe = ActiveWorkout.rirChip(chip)
        set.rpe = set.rpe == rpe ? nil : rpe
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: CorrectionEvent.rir(chip))
        updateSet(set, in: exerciseId)
    }

    /// Un-logs a set and calls off the rest it started, as the row's circle does.
    func unlog(_ setId: String, in exerciseId: String) {
        guard var set = loggedSet(setId, in: exerciseId) else { return }
        let before = workoutSession
        set.completedAt = nil
        interactor.playHaptic(option: .light)
        updateSet(set, in: exerciseId)
        // `updateSet` writes with the session observer held off, so the observer's own check for
        // an undone set never runs.
        cancelRestIfUndone(comparedTo: before)
    }

    private func loggedSet(_ setId: String, in exerciseId: String) -> WorkoutSetModel? {
        workoutSession.exercises.first { $0.id == exerciseId }?.sets.first { $0.id == setId && $0.completedAt != nil }
    }

    // MARK: - UndoManager

    /// The window's undo manager, from the card while it is on screen; `nil` once it has gone,
    /// which takes this screen's actions off the stack, so a shake elsewhere offers none of them.
    func onUndoManagerChanged(_ manager: UndoManager?) {
        guard manager !== undoManager else { return }
        undoManager?.removeAllActions(withTarget: self)
        undoManager = manager
        coalescingRepsSetId = nil
    }

    /// Called first thing in `updateSet`, before the set changes: a log or un-log is registered
    /// against what the set held.
    func recordUndo(replacing updated: WorkoutSetModel, in exerciseId: String) {
        guard undoManager != nil,
              let exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }),
              let current = exercise.sets.first(where: { $0.id == updated.id }) else { return }
        recordCompletionChange(from: current, to: updated, in: exercise)
    }

    /// Called first thing in `handleWorkoutSessionChange`: the changes that arrive there rather
    /// than through `updateSet`, which are the row's circle, a set swiped away, and a set logged
    /// from the Live Activity.
    func recordUndo(from oldSession: WorkoutSessionModel) {
        guard undoManager != nil else { return }
        for oldExercise in oldSession.exercises {
            guard let exercise = workoutSession.exercises.first(where: { $0.id == oldExercise.id }),
                  exercise.sets != oldExercise.sets else { continue }
            let ids = Set(exercise.sets.map(\.id))
            let oldIds = Set(oldExercise.sets.map(\.id))
            let removed = oldExercise.sets.enumerated().filter { !ids.contains($0.element.id) }
            // Only a removal: sets replaced by others, as splitting sides does, are not a delete.
            if !removed.isEmpty, ids.isSubset(of: oldIds) {
                let restore = removed.map { (offset: $0.offset, set: $0.element) }
                registerUndo(named: String(localized: "Delete Set")) { $0.restore(restore, in: exercise.id) }
                continue
            }
            for set in exercise.sets {
                guard let old = oldExercise.sets.first(where: { $0.id == set.id }) else { continue }
                recordCompletionChange(from: old, to: set, in: exercise)
            }
        }
    }

    /// "Log Set 2" undoes to open; "Unlog Set 2" undoes to logged. Either is skipped if the set
    /// has been logged or un-logged again since.
    private func recordCompletionChange(from old: WorkoutSetModel, to new: WorkoutSetModel, in exercise: WorkoutExerciseModel) {
        guard old.completedAt != new.completedAt, (old.completedAt == nil) != (new.completedAt == nil) else { return }
        let label = ActiveWorkout.setNumberLabel(for: new, in: exercise)
        let (setId, exerciseId) = (new.id, exercise.id)
        let (expected, restored) = (new.completedAt, old.completedAt)
        let name = new.completedAt == nil ? String(localized: "Unlog Set \(label)") : String(localized: "Log Set \(label)")
        registerUndo(named: name) { presenter in
            presenter.restoreCompletion(of: setId, in: exerciseId, expected: expected, restored: restored)
        }
    }

    private func restoreCompletion(of setId: String, in exerciseId: String, expected: Date?, restored: Date?) {
        guard var set = workoutSession.exercises.first(where: { $0.id == exerciseId })?.sets.first(where: { $0.id == setId }),
              set.completedAt == expected else { return }
        guard let restored else {
            unlog(setId, in: exerciseId)
            return
        }
        set.completedAt = restored
        updateSet(set, in: exerciseId)
    }

    /// Puts deleted sets back where they were.
    private func restore(_ removed: [(offset: Int, set: WorkoutSetModel)], in exerciseId: String) {
        guard let index = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        var sets = workoutSession.exercises[index].sets
        for (offset, set) in removed where !sets.contains(where: { $0.id == set.id }) {
            sets.insert(set, at: min(offset, sets.count))
        }
        workoutSession.exercises[index].sets = sets
    }

    /// Reps taps on one set undo together, back to what was logged (HIG: batch incremental
    /// changes). Any other registration ends the run.
    private func registerRepsUndo(restoring original: WorkoutSetModel, in exerciseId: String) {
        guard let undoManager else { return }
        let name = String(localized: "Change Reps")
        if coalescingRepsSetId == original.id, undoManager.canUndo, undoManager.undoActionName == name { return }
        registerUndo(named: name) { presenter in
            guard var set = presenter.loggedSet(original.id, in: exerciseId), set.completedAt == original.completedAt else { return }
            set.reps = original.reps
            presenter.updateSet(set, in: exerciseId)
            presenter.applyLiveProgression(after: set, in: exerciseId)
        }
        coalescingRepsSetId = original.id
    }

    /// One undo group per action. The handler holds the presenter weakly, so the stack never keeps
    /// a closed screen alive. While undoing, the manager names the redo after the action undone.
    private func registerUndo(named name: String, _ action: @escaping @MainActor (WorkoutTrackerPresenter) -> Void) {
        guard let undoManager else { return }
        coalescingRepsSetId = nil
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                action(self)
            }
        }
        if !undoManager.isUndoing { undoManager.setActionName(name) }
        undoManager.endUndoGrouping()
    }

    enum CorrectionEvent: LoggableEvent {
        case reps(delta: Int)
        case rir(Int)
        case undo

        var eventName: String {
            switch self {
            case .reps: return "WorkoutTracker_Correction_Reps"
            case .rir: return "WorkoutTracker_Correction_RIR"
            case .undo: return "WorkoutTracker_Correction_Undo"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .reps(let delta): return ["delta": delta]
            case .rir(let rir): return ["rir": rir]
            case .undo: return nil
            }
        }

        var type: LogType { .analytic }
    }
}
