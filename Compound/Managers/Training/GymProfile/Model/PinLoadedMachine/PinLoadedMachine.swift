//
//  PinLoadedMachine.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct PinLoadedMachine: Identifiable, Codable {
    /// Equipment identifier used in exercise models (e.g. PrebuiltExercises.json resistance_equipment / support_equipment).
    /// Must match the "id" in EquipmentRef so exercises can reference this machine.
    var id: String
    var name: String
    var imageName: String?
    var description: String?
    var defaultRangeId: String?
    var ranges: [PinLoadedMachineRange]
    
    var defaultRange: PinLoadedMachineRange? {
        ranges.first(where: { $0.id == self.defaultRangeId })
    }

    var isActive: Bool
    
    init(
        id: String,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        ranges: [PinLoadedMachineRange],
        isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.defaultRangeId = ranges.first?.id
        self.ranges = ranges
        self.isActive = isActive
    }
}

struct PinLoadedMachineRange: Identifiable, Codable, @MainActor WeightRange {
    var id: String
    var name: String
    
    var minWeight: Double
    var maxWeight: Double
    var increment: Double
    
    var unit: ExerciseWeightUnit

    var isActive: Bool
}
