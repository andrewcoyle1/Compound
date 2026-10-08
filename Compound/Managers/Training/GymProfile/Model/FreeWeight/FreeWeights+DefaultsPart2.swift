//
//  FreeWeights+Defaults.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import SwiftUI

extension FreeWeights {

    static let defaultFreeWeightsPart2: [FreeWeights] = [
        FreeWeights(
            id: "medicine_ball",
            name: "Medicine Ball",
            imageName: "medicine_ball_icon",
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
                    availableWeights: 4,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 6,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 8,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 10,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 12,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 14,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 16,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 18,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 20,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 25,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    availableWeights: 30,
                    unit: .pounds,
                    isActive: false
                )
            ],
            isActive: true
        ),
        FreeWeights(
            id: "weight_plates",
            name: "Weight Plates",
            imageName: "weight_plates_icon",
            description: nil,
            needsColour: true,
            isPlates: true,
            range: [
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.green.asHex(),
                    availableWeights: 1.25,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.blue.asHex(),
                    availableWeights: 2.5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.gray.asHex(),
                    availableWeights: 10,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.gray.asHex(),
                    availableWeights: 5,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.green.asHex(),
                    availableWeights: 10,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.green.asHex(),
                    availableWeights: 25,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.yellow.asHex(),
                    availableWeights: 15,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.yellow.asHex(),
                    availableWeights: 35,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.blue.asHex(),
                    availableWeights: 20,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.blue.asHex(),
                    availableWeights: 45,
                    unit: .pounds,
                    isActive: false
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.red.asHex(),
                    availableWeights: 25,
                    unit: .kilograms,
                    isActive: true
                ),
                FreeWeightsAvailable(
                    id: UUID().uuidString,
                    plateColour: Color.red.asHex(),
                    availableWeights: 55,
                    unit: .pounds,
                    isActive: false
                )
            ],
            isActive: true
        )
    ]
}
