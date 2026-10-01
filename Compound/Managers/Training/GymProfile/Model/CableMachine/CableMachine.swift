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
    
    var defaultRange: CableMachineRange? {
        ranges.first(where: { $0.id == self.defaultRangeId })
    }

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
                    minWeight: 0,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
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
                    minWeight: 0,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
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
                    minWeight: 0,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
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
                    minWeight: 0,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
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
        mocks[0]
    }
    
    static let mocks: [CableMachine] = [
        CableMachine(
            id: "cable_lat_pulldown_machine",
            name: "Cable Lat Pulldown Machine",
            description: nil,
            ranges: [
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
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
                    minWeight: 0,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
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
                    minWeight: 0,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
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
                    minWeight: 0,
                    maxWeight: 250,
                    increment: 5,
                    unit: .kilograms,
                    isActive: false
                ),
                CableMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 500,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        )
    ]

}

struct CableMachineRange: Identifiable, Codable, @MainActor WeightRange {
    var id: String
    
    var name: String
    var minWeight: Double
    var maxWeight: Double
    var increment: Double
    
    var unit: ExerciseWeightUnit

    var isActive: Bool
}
