//
//  PrebuiltMesocycleDetailInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/09/2026.
//

@MainActor
protocol PrebuiltMesocycleDetailInteractor: GlobalInteractor {
    func startPrebuiltMesocycle(_ mesocycle: Mesocycle) async throws -> Mesocycle
}

extension CoreInteractor: PrebuiltMesocycleDetailInteractor { }
