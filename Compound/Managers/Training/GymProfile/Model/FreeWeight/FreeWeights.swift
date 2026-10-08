//
//  FreeWeights.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import SwiftUI

struct FreeWeights: Identifiable, Codable, Hashable {
    var id: String
    /// The catalogue type this item is, which exercises name. A duplicate shares its original's;
    /// a machine the user made that works as nothing in the catalogue has its own id.
    var typeId: String
    var name: String
    var imageName: String?
    var description: String?
    var needsColour: Bool
    /// Plates for a bar or a plate-loaded machine, which the plate calculator loads from.
    var isPlates: Bool
    var range: [FreeWeightsAvailable]
    
    var isActive: Bool
    
    init(
        id: String,
        typeId: String? = nil,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        needsColour: Bool,
        isPlates: Bool = false,
        range: [FreeWeightsAvailable],
        isActive: Bool
    ) {
        self.id = id
        self.typeId = typeId ?? id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.needsColour = needsColour
        self.isPlates = isPlates
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
    /// How many of this plate the gym has, shared between a bar's sleeves. `nil` is as many as
    /// a load needs, which is what every entry meant before counts existed.
    var count: Int?
}

// MARK: - Decoding

extension FreeWeights {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, typeId, name, imageName, description, needsColour, isPlates, range, isActive
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
        needsColour = try container.decodeIfPresent(Bool.self, forKey: .needsColour) ?? false
        // Before the flag, plates were recognised by their catalogue id ("weight_plates").
        isPlates = try container.decodeIfPresent(Bool.self, forKey: .isPlates) ?? id.hasSuffix("plates")
        range = container.decodeLossyArray(FreeWeightsAvailable.self, forKey: .range) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}

extension FreeWeightsAvailable {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The weights stay required: there is no sensible default for one, and a zero would reach
    /// arithmetic that divides by it. An entry without them is skipped by its parent's lossy list.
    enum CodingKeys: String, CodingKey {
        case id, plateColour, availableWeights, unit, isActive, count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        plateColour = try container.decodeIfPresent(String.self, forKey: .plateColour)
        availableWeights = try container.decode(Double.self, forKey: .availableWeights)
        unit = try container.decodeIfPresent(ExerciseWeightUnit.self, forKey: .unit) ?? .kilograms
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        count = try container.decodeIfPresent(Int.self, forKey: .count)
    }
}
