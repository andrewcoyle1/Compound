//
//  WorkoutTemplateDetailInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol WorkoutTemplateDetailInteractor: GlobalInteractor, WorkoutStartInteractor {
    var currentUser: UserModel? { get }
    func deleteActiveSession() throws
    func deleteWorkoutTemplate(id: String) async throws
    func getPreference(templateId: String) -> ExerciseUnitPreference
}

extension CoreInteractor: WorkoutTemplateDetailInteractor { }

/// Starting a workout from a template. Every Start button goes through
/// `startWorkout(for:in:isDeloadCycle:)`, so none of them can skip a deload microcycle's weight cut.
@MainActor
protocol WorkoutStartInteractor {
    var activeSession: WorkoutSessionModel? { get }
    func startWorkout(for template: WorkoutTemplateModel, in mesocycleId: String?) async throws
    func updateActiveSession(_ session: WorkoutSessionModel) throws
}

extension WorkoutStartInteractor {
    func startWorkout(for template: WorkoutTemplateModel, in mesocycleId: String?, isDeloadCycle: Bool) async throws {
        try await startWorkout(for: template, in: mesocycleId)
        guard isDeloadCycle, var session = activeSession else { return }
        session.applyDeloadWeightReduction()
        // The workout has started either way; a failed cut leaves the planned weights, not no workout.
        try? updateActiveSession(session)
    }
}
