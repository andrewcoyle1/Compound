//
//  WorkoutSessionTemplateBuilder.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2026.
//

import Foundation

/// Turns a logged session — usually someone else's, off the feed — into a workout template the
/// reader can run themselves.
///
/// The inverse of `WorkoutSessionModel.init(template:)`: that makes one working set per set target,
/// so here every working set (warm-ups excluded, a left/right pair counted once) becomes one set
/// target, carrying the reps that were done. `SetTarget` has no field for weight, time or distance,
/// so those do not survive the trip; the tracker prefills them from the reader's own history.
enum WorkoutSessionTemplateBuilder {

    /// `nil` when none of the session's exercises is in `availableExercises` — an empty template is
    /// not worth saving. Exercises are matched on the id first, which holds for the seeded library,
    /// then on the name, which is all a follower's own custom exercise has in common with the
    /// reader's; anything else is skipped.
    static func template(
        from session: WorkoutSessionModel,
        availableExercises: [ExerciseModel],
        existingNames: [String],
        authorId: String
    ) -> WorkoutTemplateModel? {
        let exercises: [WorkoutTemplateExercise] = session.exercises
            .sorted { $0.index < $1.index }
            .compactMap { logged in
                guard let exercise = resolve(logged, in: availableExercises) else { return nil }
                return WorkoutTemplateExercise(exercise: exercise, setTargets: setTargets(for: logged), setRestTimers: false)
            }
        guard !exercises.isEmpty else { return nil }

        let clashes = existingNames.contains { $0.caseInsensitiveCompare(session.name) == .orderedSame }
        return WorkoutTemplateModel(
            authorId: authorId,
            name: clashes ? "\(session.name) (copy)" : session.name,
            exercises: exercises
        )
    }

    private static func resolve(_ logged: WorkoutExerciseModel, in library: [ExerciseModel]) -> ExerciseModel? {
        if let byId = library.first(where: { $0.id == logged.templateId }) {
            return byId
        }
        let name = logged.name.trimmingCharacters(in: .whitespaces)
        return library.first { $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame }
    }

    /// One target per working set, a right side folded into the left one before it — the same rule
    /// as `pairedSetCount`.
    private static func setTargets(for logged: WorkoutExerciseModel) -> [SetTarget] {
        var targets: [SetTarget] = []
        var previousSide: SetSide?
        for set in logged.workingSets {
            defer { previousSide = set.side }
            if set.side == .right && previousSide == .left { continue }
            targets.append(SetTarget(setNumber: targets.count + 1, minReps: set.reps, maxReps: set.reps))
        }
        // An exercise with nothing logged still gets the one set a new template exercise starts with.
        return targets.isEmpty ? [SetTarget(setNumber: 1)] : targets
    }
}
