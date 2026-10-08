//
//  PlateLoadedMachine.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct PlateLoadedMachine: Identifiable, Codable {
    var id: String
    /// The catalogue type this item is, which exercises name. A duplicate shares its original's;
    /// a machine the user made that works as nothing in the catalogue has its own id.
    var typeId: String
    var name: String
    var imageName: String?
    var description: String?
    var baseWeight: Double
    var unit: ExerciseWeightUnit
    /// How many sleeves (horns, posts) take plates: 2 on a leg press, 1 on a T-bar row. The
    /// smallest change is one of the smallest plates on each, and the plate calculator shares the
    /// load between them.
    var sleeves: Int

    var isActive: Bool
    
    init(
        id: String,
        typeId: String? = nil,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        baseWeight: Double,
        unit: ExerciseWeightUnit,
        sleeves: Int = 2,
        isActive: Bool
    ) {
        self.id = id
        self.typeId = typeId ?? id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.baseWeight = baseWeight
        self.unit = unit
        self.sleeves = sleeves
        self.isActive = isActive
    }
}

// MARK: - Decoding

extension PlateLoadedMachine {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, typeId, name, imageName, description, baseWeight, unit, sleeves, isActive
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
        baseWeight = try container.decodeIfPresent(Double.self, forKey: .baseWeight) ?? 0
        unit = try container.decodeIfPresent(ExerciseWeightUnit.self, forKey: .unit) ?? .kilograms
        // Machines saved before sleeves existed take the catalogue's answer, so a stored T-bar
        // loads on one; anything else is the usual two. Clamped, since the count divides.
        let typeId = typeId
        let stored = try container.decodeIfPresent(Int.self, forKey: .sleeves)
            ?? Self.defaultPlateLoadedMachines.first { $0.id == typeId }?.sleeves
            ?? 2
        sleeves = min(max(stored, 1), 2)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}
