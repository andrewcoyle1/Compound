//
//  WorkoutTemplateDetailInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol WorkoutTemplateDetailInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var activeSession: WorkoutSessionModel? { get }
    func startWorkout(for template: WorkoutTemplateModel, in mesocycleId: String?) async throws
    func updateActiveSession(_ session: WorkoutSessionModel) throws
    func deleteActiveSession() throws
    func deleteWorkoutTemplate(id: String) async throws
    func getPreference(templateId: String) -> ExerciseUnitPreference
}

extension CoreInteractor: WorkoutTemplateDetailInteractor { }
