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

// MARK: - Decoding

extension FreeWeights {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, name, imageName, description, needsColour, range, isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        needsColour = try container.decodeIfPresent(Bool.self, forKey: .needsColour) ?? false
        range = container.decodeLossyArray(FreeWeightsAvailable.self, forKey: .range) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}

extension FreeWeightsAvailable {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The weights stay required: there is no sensible default for one, and a zero would reach
    /// arithmetic that divides by it. An entry without them is skipped by its parent's lossy list.
    enum CodingKeys: String, CodingKey {
        case id, plateColour, availableWeights, unit, isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        plateColour = try container.decodeIfPresent(String.self, forKey: .plateColour)
        availableWeights = try container.decode(Double.self, forKey: .availableWeights)
        unit = try container.decodeIfPresent(ExerciseWeightUnit.self, forKey: .unit) ?? .kilograms
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}
