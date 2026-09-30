//
//  CreateMacrocycleInteractor.swift
//  DialedIn
//

@MainActor
protocol CreateMacrocycleInteractor: GlobalInteractor {
    var mesocycles: [Mesocycle] { get }
    func startMacrocycle(name: String, mesocycleIds: [String]) async throws
}

extension CoreInteractor: CreateMacrocycleInteractor { }
