import SwiftUI

@MainActor
protocol ActiveMesocycleInteractor: GlobalInteractor {
    var activeSession: WorkoutSessionModel? { get }
    var currentUser: UserModel? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var activeMesocycleRun: MesocycleSchedule.Run? { get }
    var currentMacrocycle: Macrocycle? { get }
    func skipScheduledWorkout(_ slot: MesocycleSchedule.Slot) async throws
    func deleteActiveSession() throws
    func saveWorkoutSession(_ session: WorkoutSessionModel) async throws
    func deleteWorkoutSession(id: String) async throws
    func deleteMesocycle(mesocycleId: String) async throws
}

extension CoreInteractor: ActiveMesocycleInteractor { }
