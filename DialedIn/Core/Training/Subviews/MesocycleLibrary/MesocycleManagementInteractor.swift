//
//  MesocycleLibraryInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol MesocycleLibraryInteractor: GlobalInteractor {
    var activeMesocycle: Mesocycle? { get }
    var mesocycles: [Mesocycle] { get }
    var prebuiltMesocycles: [Mesocycle] { get }
    func setActiveMesocycle(mesocycleId: String) async throws
    func deleteMesocycle(mesocycleId: String) async throws
}

extension CoreInteractor: MesocycleLibraryInteractor { }
