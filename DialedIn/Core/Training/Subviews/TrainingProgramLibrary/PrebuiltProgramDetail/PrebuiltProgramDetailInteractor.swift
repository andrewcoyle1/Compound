//
//  PrebuiltProgramDetailInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/09/2026.
//

@MainActor
protocol PrebuiltProgramDetailInteractor: GlobalInteractor {
    func startPrebuiltProgram(_ program: TrainingProgram) async throws -> TrainingProgram
}

extension CoreInteractor: PrebuiltProgramDetailInteractor { }
