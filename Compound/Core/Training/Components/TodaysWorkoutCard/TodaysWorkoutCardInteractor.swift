//
//  TodaysWorkoutCardInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

@MainActor
protocol TodaysWorkoutCardInteractor: GlobalInteractor, WorkoutStartInteractor {
    var activeMesocycle: Mesocycle? { get }
    var activeMesocycleRun: MesocycleSchedule.Run? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    func skipScheduledWorkout(_ slot: MesocycleSchedule.Slot) async throws
    func deleteActiveSession() throws
    var currentUser: UserModel? { get }
    func getPreference(templateId: String) -> ExerciseUnitPreference
    func plannedSession(for template: WorkoutTemplateModel, in mesocycleId: String?) async throws -> WorkoutSessionModel
}

extension CoreInteractor: TodaysWorkoutCardInteractor { }
