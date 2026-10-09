//
//  BodyWeights.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import SwiftUI

struct BodyWeights: Identifiable, Codable {
    var id: String
    /// The catalogue type this item is, which exercises name. A duplicate shares its original's;
    /// a machine the user made that works as nothing in the catalogue has its own id.
    var typeId: String
    var name: String
    var imageName: String?
    var description: String?
    var range: [BodyWeightsAvailable]
    
    var isActive: Bool
    
    init(
        id: String,
        typeId: String? = nil,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        range: [BodyWeightsAvailable],
        isActive: Bool
    ) {
        self.id = id
        self.typeId = typeId ?? id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.range = range
        self.isActive = isActive
    }
}

struct BodyWeightsAvailable: Identifiable, Codable {
    var id: String
    
    var plateColour: String?
    var availableWeights: Double
    var unit: ExerciseWeightUnit
    
    var isActive: Bool
}

// MARK: - Decoding

extension BodyWeights {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, typeId, name, imageName, description, range, isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        self.id = id
        // Items saved before custom and duplicate machines are their own type.
        typeId = try container.decodeIfPresent(String.self, forKey: .typeId) ?? id
        name = try container.decode(String.self, forKey: .name)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        range = container.decodeLossyArray(BodyWeightsAvailable.self, forKey: .range) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}

extension BodyWeightsAvailable {
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
