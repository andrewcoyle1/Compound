import SwiftUI

@MainActor
protocol ActiveTrainingProgramInteractor: GlobalInteractor {
    var activeSession: WorkoutSessionModel? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var activeProgramRun: ProgramSchedule.Run? { get }
    var currentTrainingPlan: TrainingPlan? { get }
    func skipScheduledWorkout(_ slot: ProgramSchedule.Slot) async throws
    func deleteActiveSession() throws
    func deleteTrainingProgram(programId: String) async throws
}

extension CoreInteractor: ActiveTrainingProgramInteractor { }
