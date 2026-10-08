//
//  CableMachine.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct CableMachine: Identifiable, Codable {
    var id: String
    /// The catalogue type this item is, which exercises name. A duplicate shares its original's;
    /// a machine the user made that works as nothing in the catalogue has its own id.
    var typeId: String
    var name: String
    var imageName: String?
    var description: String?
    var defaultRangeId: String?
    var ranges: [CableMachineRange]

    var isActive: Bool
    
    init(
        id: String,
        typeId: String? = nil,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        ranges: [CableMachineRange],
        isActive: Bool
    ) {
        self.id = id
        self.typeId = typeId ?? id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.defaultRangeId = ranges.first?.id
        self.ranges = ranges
        self.isActive = isActive
    }

    static let defaultCableMachines: [CableMachine] = [
        CableMachine(
            id: "cable_lat_pulldown_machine",
            name: "Cable Lat Pulldown Machine",
            description: nil,
            ranges: [
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 5,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 5,
                    maxWeight: 500,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        ),
        CableMachine(
            id: "pin-loaded_dual_cable_machine",
            name: "Pin-Loaded Dual Cable Machine",
            description: nil,
            ranges: [
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 5,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 5,
                    maxWeight: 500,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        ),
        CableMachine(
            id: "pin-loaded_single_cable_machine",
            name: "Pin-Loaded Single Cable Machine",
            description: nil,
            ranges: [
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 5,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 5,
                    maxWeight: 500,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        ),
        CableMachine(
            id: "seated_cable_row_machine",
            name: "Seated Cable Row Machine",
            description: nil,
            ranges: [
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 5,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 5,
                    maxWeight: 500,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        )
    ]
    
    static var mock: CableMachine {
        defaultCableMachines[0]
    }
}

// MARK: - Decoding

extension CableMachine {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, typeId, name, imageName, description, defaultRangeId, ranges, isActive
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
        defaultRangeId = try container.decodeIfPresent(String.self, forKey: .defaultRangeId)
        ranges = container.decodeLossyArray(CableMachineRange.self, forKey: .ranges) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}
