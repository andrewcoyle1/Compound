//
//  PlateLoadedMachine.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct PlateLoadedMachine: Identifiable, Codable {
    var id: String
    var name: String
    var imageName: String?
    var description: String?
    var baseWeight: Double
    var unit: ExerciseWeightUnit
    
    var isActive: Bool
    
    init(
        id: String,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        baseWeight: Double,
        unit: ExerciseWeightUnit,
        isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.baseWeight = baseWeight
        self.unit = unit
        self.isActive = isActive
    }
}
