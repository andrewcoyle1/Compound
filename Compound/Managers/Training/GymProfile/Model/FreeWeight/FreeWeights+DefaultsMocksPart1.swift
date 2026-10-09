//
//  FreeWeights+Defaults.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import SwiftUI

extension FreeWeights {

    static let defaultFreeWeightsMocksPart1: [FreeWeights] = [
        FreeWeights(
            id: "bumper_plates",
            name: "Bumper Plates",
            imageName: "bumper_plates_icon",
            description: nil,
            needsColour: true,
            isPlates: true,
            range: [
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 10,
                    unit: .pounds,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 10,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 25,
                    unit: .pounds,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 15,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 35,
                    unit: .pounds,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 20,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 45,
                    unit: .pounds,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 25,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 55,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        ),
        FreeWeights(
            id: "dumbbells",
            name: "Dumbbells",
            imageName: "dumbbells_icon",
            description: nil,
            needsColour: false,
            range: [
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 1,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 2,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 3,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 4,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 6,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 6,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 7,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 8,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 9,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 10,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 12,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 12.5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 14,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 15,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 16,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 17.5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 18,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 20,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 22,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 22.5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 24,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 25,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 26,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 27.5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 28,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 30,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 32,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 32.5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 34,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 36,
                    unit: .kilograms,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 37.5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 38,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 40,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 42,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 42.5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 44,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 45,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 46,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 47.5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 48,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 50,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 57.5,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        )
    ]
}
