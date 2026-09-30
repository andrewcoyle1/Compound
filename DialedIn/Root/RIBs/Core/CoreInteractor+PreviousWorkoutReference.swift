//
//  CoreInteractor+PreviousWorkoutReference.swift
//  DialedIn
//
//  The one place `previousWorkoutReference` is turned into a list of past sessions. The tracker's
//  "Prev" column and smart progression both go through it, so they can never disagree about what
//  "last time" was.
//

import Foundation

/// The three lookups the scope switch needs. Conformers supply the raw lookups; the switch and
/// the fallback live in the extension below so there is exactly one copy of them.
@MainActor
protocol PreviousWorkoutReferenceResolving {

    /// Which past session the user asked to compare against.
    var previousWorkoutReferenceScope: PreviousWorkoutReferenceOption { get }

    /// The last completed sessions of one workout template, most recent first.
    func completedSessionsForWorkoutTemplate(
        templateId: String,
        authorId: String,
        inMesocycleId: String?,
        limit: Int
    ) async -> [WorkoutSessionModel]

    /// The last completed sessions that included one exercise, whatever workout they were.
    func completedSessionsContainingExercise(
        exerciseTemplateId: String,
        authorId: String,
        inMesocycleId: String?,
        limit: Int
    ) async -> [WorkoutSessionModel]
}

extension PreviousWorkoutReferenceResolving {

    /// The sessions "last time" should be read from, for one exercise of one workout.
    ///
    /// `.sameWorkout` and `.workoutsInMesocycle` look at this workout's own history and fall back to
    /// the any-exercise lookup when it holds nothing for the exercise — a brand new template built
    /// from exercises the user has trained for months must still show that history rather than a
    /// blank column. `.workoutsInMesocycle` applied to a workout logged outside any mesocycle has no
    /// mesocycle to be within, so it keeps the unrestricted template lookup instead of filtering on
    /// nothing.
    func previousSessions(
        forExerciseTemplateId exerciseTemplateId: String,
        workoutTemplateId: String?,
        authorId: String,
        mesocycleId: String?,
        limit: Int = 3
    ) async -> [WorkoutSessionModel] {
        let scope = previousWorkoutReferenceScope

        if scope != .anyExercise, let workoutTemplateId {
            let mesocycleId: String? = scope == .workoutsInMesocycle ? mesocycleId : nil
            let fromTemplate = await completedSessionsForWorkoutTemplate(
                templateId: workoutTemplateId,
                authorId: authorId,
                inMesocycleId: mesocycleId,
                limit: limit
            )
            let containingExercise = fromTemplate.filter { session in
                session.exercises.contains(where: { $0.templateId == exerciseTemplateId })
            }
            if !containingExercise.isEmpty {
                return containingExercise
            }
        }

        return await completedSessionsContainingExercise(
            exerciseTemplateId: exerciseTemplateId,
            authorId: authorId,
            inMesocycleId: nil,
            limit: limit
        )
    }
}

extension CoreInteractor: PreviousWorkoutReferenceResolving {

    var previousWorkoutReferenceScope: PreviousWorkoutReferenceOption {
        workoutSettings.previousWorkoutReference
    }

    func completedSessionsForWorkoutTemplate(
        templateId: String,
        authorId: String,
        inMesocycleId: String?,
        limit: Int
    ) async -> [WorkoutSessionModel] {
        (try? await getLastCompletedSessionsForTemplate(
            templateId: templateId,
            authorId: authorId,
            inMesocycleId: inMesocycleId,
            limit: limit
        )) ?? []
    }

    func completedSessionsContainingExercise(
        exerciseTemplateId: String,
        authorId: String,
        inMesocycleId: String?,
        limit: Int
    ) async -> [WorkoutSessionModel] {
        (try? await getLastCompletedSessionsContainingExercise(
            exerciseTemplateId: exerciseTemplateId,
            authorId: authorId,
            inMesocycleId: inMesocycleId,
            limit: limit
        )) ?? []
    }
}
