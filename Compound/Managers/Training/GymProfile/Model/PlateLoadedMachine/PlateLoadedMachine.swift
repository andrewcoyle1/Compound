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

// MARK: - Decoding

extension PlateLoadedMachine {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, name, imageName, description, baseWeight, unit, isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        baseWeight = try container.decodeIfPresent(Double.self, forKey: .baseWeight) ?? 0
        unit = try container.decodeIfPresent(ExerciseWeightUnit.self, forKey: .unit) ?? .kilograms
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}
