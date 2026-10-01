//
//  MuscleGroupDetailInteractor.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@MainActor
protocol MuscleGroupDetailInteractor {
    var auth: UserAuthInfo? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var allExercises: [ExerciseModel] { get }
}

extension CoreInteractor: MuscleGroupDetailInteractor { }
