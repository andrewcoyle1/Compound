//
//  TodaysWorkoutCardInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 09/03/2026.
//

@MainActor
protocol TodaysWorkoutCardInteractor: GlobalInteractor {
    var activeTrainingProgram: TrainingProgram? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
}

extension CoreInteractor: TodaysWorkoutCardInteractor { }
