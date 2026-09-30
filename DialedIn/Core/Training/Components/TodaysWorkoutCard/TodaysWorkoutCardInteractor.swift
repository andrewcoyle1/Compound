//
//  TodaysWorkoutCardInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 09/03/2026.
//

@MainActor
protocol TodaysWorkoutCardInteractor: GlobalInteractor {
    var activeTrainingProgram: TrainingProgram? { get }
    var activeProgramRun: ProgramSchedule.Run? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    func skipScheduledWorkout(_ slot: ProgramSchedule.Slot) async throws
}

extension CoreInteractor: TodaysWorkoutCardInteractor { }
