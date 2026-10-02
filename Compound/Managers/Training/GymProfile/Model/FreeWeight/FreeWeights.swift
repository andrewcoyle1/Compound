//
//  FreeWeights.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import SwiftUI

struct FreeWeights: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var imageName: String?
    var description: String?
    var needsColour: Bool
    var range: [FreeWeightsAvailable]
    
    var isActive: Bool
    
    init(
        id: String,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        needsColour: Bool,
        range: [FreeWeightsAvailable],
        isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.needsColour = needsColour
        self.range = range
        self.isActive = isActive
    }

    nonisolated static func == (lhs: FreeWeights, rhs: FreeWeights) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct FreeWeightsAvailable: Identifiable, Codable {
    var id: String
    
    var plateColour: String?
    var availableWeights: Double
    var unit: ExerciseWeightUnit
    
    var isActive: Bool
}
