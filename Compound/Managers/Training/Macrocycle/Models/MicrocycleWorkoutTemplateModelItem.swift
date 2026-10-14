//
//  MicrocycleWorkoutTemplateModelItem.swift
//  Compound
//

import Foundation

struct MicrocycleWorkoutTemplateModelItem: Identifiable {
    let id: String
    let date: Date
    let dayPlan: WorkoutTemplateModel
    let completedSessionId: String?
    /// The microcycle the day belongs to, 1-based as the header shows it; nil when unknown.
    var cycleIndex: Int?

    var isCompleted: Bool {
        completedSessionId != nil
    }
}
