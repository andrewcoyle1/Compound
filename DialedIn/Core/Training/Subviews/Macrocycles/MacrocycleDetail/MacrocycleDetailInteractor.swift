//
//  MacrocycleDetailInteractor.swift
//  DialedIn
//

@MainActor
protocol MacrocycleDetailInteractor: GlobalInteractor {
    var userId: String? { get }
    var mesocycles: [Mesocycle] { get }
    var currentMacrocycle: Macrocycle? { get }
    func saveMacrocycle(_ macrocycle: Macrocycle) async throws
    func startMacrocycle(_ macrocycle: Macrocycle, atMesocycle mesocycleIndex: Int, microcycle microcycleIndex: Int) async throws
    func deleteMacrocycle(_ macrocycle: Macrocycle) async throws
}

extension CoreInteractor: MacrocycleDetailInteractor { }
