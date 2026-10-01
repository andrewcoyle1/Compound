//
//  WorkoutTemplateExercise.swift
//  Compound
//
//  Created by Andrew Coyle on 28/02/2026.
//

import Foundation

struct WorkoutTemplateExercise: DataSyncModelProtocol, Equatable, Hashable {
    var id: String = UUID().uuidString
    var exercise: ExerciseModel
    var setTargets: [SetTarget] = [SetTarget(setNumber: 1, setType: SetTargetSetType.standard)]
    var setRestTimers: Bool
        
    enum CodingKeys: String, CodingKey {
        case id
        case exercise
        case setTargets = "set_targets"
        case setRestTimers = "set_rest_timers"
    }
    
    static var mock: WorkoutTemplateExercise {
        mocks[0]
    }
    
    /// Six exercises from the seeded library — the length of a real workout, and enough to
    /// exercise a list without rendering all thirty-two.
    static var mocks: [WorkoutTemplateExercise] {
        ExerciseModel.mocks.prefix(6).map { exercise in
            WorkoutTemplateExercise(exercise: exercise, setRestTimers: false)
        }
    }
}
