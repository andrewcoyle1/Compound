//
//  PlateLoadedMachine+Defaults.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

extension PlateLoadedMachine {

    static var defaultPlateLoadedMachines: [PlateLoadedMachine] {
        defaultPlateLoadedMachinesPart1
    }

    static var mock: PlateLoadedMachine {
        mocks[0]
    }

    /// The catalogue itself: no preview or test needs a machine set up differently.
    static var mocks: [PlateLoadedMachine] {
        defaultPlateLoadedMachines
    }
}
