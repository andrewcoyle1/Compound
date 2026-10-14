//
//  LiveActivityUpdateParams.swift
//  Compound
//

import Foundation

/// Parameters for updating a workout live activity's status and metrics.
struct LiveActivityUpdateParams {
    let session: WorkoutSessionModel
    let isActive: Bool
    let currentExerciseIndex: Int
    let restEndsAt: Date?
}
