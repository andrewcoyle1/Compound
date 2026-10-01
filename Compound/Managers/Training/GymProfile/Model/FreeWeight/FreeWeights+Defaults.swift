//
//  FreeWeights+Defaults.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import SwiftUI

extension FreeWeights {

    static var defaultFreeWeights: [FreeWeights] {
        defaultFreeWeightsPart1 + defaultFreeWeightsPart2
    }

    static var mock: FreeWeights {
        mocks[0]
    }

    static var mocks: [FreeWeights] {
        defaultFreeWeightsMocksPart1 + defaultFreeWeightsMocksPart2
    }
}
