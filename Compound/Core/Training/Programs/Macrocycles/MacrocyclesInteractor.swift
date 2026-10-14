//
//  MacrocyclesInteractor.swift
//  Compound
//

@MainActor
protocol MacrocyclesInteractor: GlobalInteractor {
    var macrocycles: [Macrocycle] { get }
    var currentMacrocycle: Macrocycle? { get }
}

extension CoreInteractor: MacrocyclesInteractor { }
