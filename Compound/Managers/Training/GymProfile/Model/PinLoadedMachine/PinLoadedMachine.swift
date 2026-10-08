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

// MARK: - Decoding

extension PinLoadedMachine {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, name, imageName, description, defaultRangeId, ranges, isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        defaultRangeId = try container.decodeIfPresent(String.self, forKey: .defaultRangeId)
        ranges = container.decodeLossyArray(PinLoadedMachineRange.self, forKey: .ranges) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}
