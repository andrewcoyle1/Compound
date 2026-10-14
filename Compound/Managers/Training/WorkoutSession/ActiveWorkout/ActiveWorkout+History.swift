//
//  ActiveWorkout+History.swift
//  Compound
//
//  How "last time" is keyed. A plan can list the same exercise twice in one workout (a heavy
//  6–8 set, then a 1 × 20 back-off), and each needs its own history: the nth appearance of an
//  exercise is matched to the nth appearance of it last time.
//

import Foundation

extension ActiveWorkout {

    /// The key last time's figures and smart progression's suggestion are kept under:
    /// `"<templateId>#<occurrence>"`, the occurrence counted from 0 in workout order.
    static func historyKey(templateId: String, occurrence: Int) -> String {
        "\(templateId)#\(occurrence)"
    }

    /// `exercise`'s key, its occurrence read from where it sits in `session`.
    static func historyKey(for exercise: WorkoutExerciseModel, in session: WorkoutSessionModel) -> String {
        historyKey(templateId: exercise.templateId, occurrence: session.occurrence(of: exercise))
    }
}
