//
//  WorkoutTrackerPresenter+Focus.swift
//  Compound
//
//  Moving the card on its own: after a set is logged and when a rest ends. The rules are
//  `ActiveWorkout+Focus`; `setFocus` is the one place they take effect.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    enum FocusReason: String {
        /// On to the partner next in a superset's round.
        case supersetRound = "superset_round"
        /// A finished exercise, with no rest to wait out, hands on to the next.
        case exerciseFinished = "exercise_finished"
        /// The rest after a finished exercise ran out or was skipped.
        case restEnded = "rest_ended"
    }

    /// Opens `exerciseId` on the card and tells the Live Activity. Nothing happens when the card
    /// is already there.
    func setFocus(_ exerciseId: String, reason: FocusReason) {
        guard let index = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }),
              expandedExerciseId != exerciseId || currentExerciseIndex != index else { return }
        expandedExerciseId = exerciseId
        currentExerciseIndex = index
        persistFocus(exerciseId)
        interactor.trackEvent(event: FocusEvent.focusMoved(reason: reason))
        refreshLiveActivity()
    }

    /// Records the exercise the user is on in the screen state, where the Live Activity's handler
    /// reads it and a rebuilt tracker picks it up.
    func persistFocus(_ exerciseId: String?) {
        guard let exerciseId else { return }
        var state = ActiveWorkoutScreenState.load(sessionId: workoutSession.id, from: interactor.activeWorkoutScreenStateStore)
        guard state.focusExerciseId != exerciseId else { return }
        state.focusExerciseId = exerciseId
        state.save(to: interactor.activeWorkoutScreenStateStore)
    }

    /// A tracker rebuilt after a minimise or a relaunch opens on the exercise the last one, or the
    /// Live Activity, was on, while it still has a set to log.
    func restoreFocus(from state: ActiveWorkoutScreenState) {
        guard let id = state.focusExerciseId,
              let index = workoutSession.exercises.firstIndex(where: { $0.id == id }),
              ActiveWorkout.currentSet(in: workoutSession.exercises[index]) != nil else { return }
        expandedExerciseId = id
        currentExerciseIndex = index
    }

    /// The rest after logging `set`, by the rules across the whole workout, or a rest set by hand
    /// on its row. `nil` for none.
    func restAfterLogging(_ set: WorkoutSetModel, in exercise: WorkoutExerciseModel, customRestSeconds custom: Int? = nil) -> Int? {
        RestDurationRules.restAfterCompleting(
            set,
            in: exercise,
            workout: workoutSession.exercises,
            settings: interactor.workoutSettings,
            context: restContext(for: exercise),
            customRestSeconds: custom ?? customRestSeconds[set.id]
        )
    }

    /// Where the card goes once `setId` is logged, here or from the Live Activity: to a superset
    /// partner, on from a finished exercise when no rest follows, or nowhere while a rest runs
    /// after one (`onRestEnded` moves it then).
    func moveFocus(afterLogging setId: String) {
        let exercises = workoutSession.exercises
        guard let exercise = exercises.first(where: { $0.sets.contains { $0.id == setId } }),
              let set = exercise.sets.first(where: { $0.id == setId }) else { return }
        let settings = interactor.workoutSettings
        let restFollows = settings.useRestTimers && restAfterLogging(set, in: exercise) != nil
        guard let target = ActiveWorkout.focus(afterLogging: setId, in: exercises, settings: settings, restFollows: restFollows) else { return }
        let sameBlock = ActiveWorkout.blocks(exercises).contains { $0.contains(exercise.id) && $0.contains(target) }
        setFocus(target, reason: sameBlock ? .supersetRound : .exerciseFinished)
    }

    /// A rest ran out or was skipped. A card left on a finished exercise for the rest moves on.
    func onRestEnded() {
        guard let target = ActiveWorkout.focusWhenRestEnds(
            current: currentExercise?.id,
            exercises: workoutSession.exercises,
            settings: interactor.workoutSettings
        ) else { return }
        setFocus(target, reason: .restEnded)
    }

    /// Kept beside the rule it reports on rather than in `Event`, which another package owns.
    enum FocusEvent: LoggableEvent {
        case focusMoved(reason: FocusReason)

        var eventName: String { "WorkoutTracker_Focus_Moved" }

        var parameters: [String: Any]? {
            switch self {
            case .focusMoved(let reason): ["reason": reason.rawValue]
            }
        }

        var type: LogType { .analytic }
    }
}
