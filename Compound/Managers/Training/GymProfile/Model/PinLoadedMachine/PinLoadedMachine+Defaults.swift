//
//  PinLoadedMachine+Defaults.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

extension PinLoadedMachine {

    static var defaultPinLoadedMachines: [PinLoadedMachine] {
        defaultPinLoadedMachinesPart1 + defaultPinLoadedMachinesPart2
    }

    static var mock: PinLoadedMachine {
        mocks[0]
    }

    static var mocks: [PinLoadedMachine] {
        defaultPinLoadedMachinesMocksPart1 + defaultPinLoadedMachinesMocksPart2
    }
}
