//
//  TodaysWorkoutCardInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

@MainActor
protocol TodaysWorkoutCardInteractor: GlobalInteractor {
    var activeMesocycle: Mesocycle? { get }
    var activeMesocycleRun: MesocycleSchedule.Run? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    func skipScheduledWorkout(_ slot: MesocycleSchedule.Slot) async throws
}

extension CoreInteractor: TodaysWorkoutCardInteractor { }
