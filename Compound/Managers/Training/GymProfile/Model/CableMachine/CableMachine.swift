//
//  CableMachine.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct CableMachine: Identifiable, Codable {
    var id: String
    var name: String
    var imageName: String?
    var description: String?
    var defaultRangeId: String?
    var ranges: [CableMachineRange]

    var isActive: Bool
    
    init(
        id: String,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        ranges: [CableMachineRange],
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
        case id, name, imageName, description, defaultRangeId, ranges, isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        defaultRangeId = try container.decodeIfPresent(String.self, forKey: .defaultRangeId)
        ranges = container.decodeLossyArray(CableMachineRange.self, forKey: .ranges) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}
