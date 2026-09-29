//
//  TrainingProgramLibraryInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol TrainingProgramLibraryInteractor: GlobalInteractor {
    var activeTrainingProgram: TrainingProgram? { get }
    var trainingPrograms: [TrainingProgram] { get }
    var prebuiltPrograms: [TrainingProgram] { get }
    func setActiveTrainingProgram(programId: String) async throws
    func deleteTrainingProgram(programId: String) async throws
}

extension CoreInteractor: TrainingProgramLibraryInteractor { }
