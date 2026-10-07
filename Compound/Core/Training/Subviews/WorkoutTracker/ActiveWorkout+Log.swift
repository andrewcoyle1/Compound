//
//  ActiveWorkout+Log.swift
//  Compound
//
//  Logging a set, as one rule: the tracker's log button and the Live Activity's Complete both
//  call it, so they refuse the same sets, rest for the same time and move to the same exercise.
//  Each caller then does its own side effects (haptics, analytics, starting the rest, the push).
//

import Foundation

extension ActiveWorkout {

    struct LogOutcome: Equatable {
        /// The session with the set stamped, or unchanged when it was refused.
        var session: WorkoutSessionModel
        /// Why the set was refused, in the user's words; `nil` when it was logged.
        var problem: String?
        /// The rest that follows by the rules, or the row's own; `nil` for none. Started only
        /// when `useRestTimers` is on.
        var restSeconds: Int?
        /// Where the card goes next (`focus(afterLogging:)`); `nil` to stay on the exercise.
        var focusExerciseId: String?
    }

    /// Logs `setId`: checks it, stamps `completedAt = now`, and works out the rest and the next
    /// focus across the whole workout. `context` is the set's exercise's, and `customRestSeconds`
    /// a rest set by hand on its row, which wins.
    ///
    /// `nil` when there is nothing to log: the set is not in the session, or is already logged.
    static func log(
        setId: String,
        in session: WorkoutSessionModel,
        settings: WorkoutSettings,
        context: RestDurationRules.ExerciseContext,
        customRestSeconds: Int? = nil,
        now: Date = Date()
    ) -> LogOutcome? {
        var exercises = session.exercises
        guard let exerciseIndex = exercises.firstIndex(where: { $0.sets.contains { $0.id == setId } }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }),
              exercises[exerciseIndex].sets[setIndex].completedAt == nil else { return nil }

        if let problem = SetValidation.problem(
            with: exercises[exerciseIndex].sets[setIndex],
            trackingMode: exercises[exerciseIndex].trackingMode
        ) {
            return LogOutcome(session: session, problem: problem)
        }

        exercises[exerciseIndex].sets[setIndex].completedAt = now
        var logged = session
        logged.updateExercises(exercises)

        let rest = RestDurationRules.restAfterCompleting(
            exercises[exerciseIndex].sets[setIndex],
            in: exercises[exerciseIndex],
            workout: exercises,
            settings: settings,
            context: context,
            customRestSeconds: customRestSeconds
        )
        let focus = focus(
            afterLogging: setId,
            in: exercises,
            settings: settings,
            restFollows: settings.useRestTimers && rest != nil
        )
        return LogOutcome(session: logged, restSeconds: rest, focusExerciseId: focus)
    }
}
