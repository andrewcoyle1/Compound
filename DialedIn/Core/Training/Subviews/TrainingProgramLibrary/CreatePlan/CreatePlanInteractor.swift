//
//  CreatePlanInteractor.swift
//  DialedIn
//

@MainActor
protocol CreatePlanInteractor: GlobalInteractor {
    var trainingPrograms: [TrainingProgram] { get }
    func startTrainingPlan(name: String, programIds: [String]) async throws
}

extension CoreInteractor: CreatePlanInteractor { }
