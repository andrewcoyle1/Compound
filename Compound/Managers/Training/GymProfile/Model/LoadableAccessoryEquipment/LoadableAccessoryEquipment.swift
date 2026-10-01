//
//  LoadableAccessoryEquipment.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct LoadableAccessoryEquipment: Identifiable, Codable {
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
    
    static let defaultLoadableAccessoryEquipment: [LoadableAccessoryEquipment] = [
        LoadableAccessoryEquipment(
            id: "fat_grip_attachments",
            name: "Fat Grip Attachments",
            description: nil,
            baseWeight: 0,
            unit: .kilograms,
            isActive: false
        ),
        LoadableAccessoryEquipment(
            id: "head_harness",
            name: "Head Harness",
            description: nil,
            baseWeight: 0,
            unit: .kilograms,
            isActive: true
        ),
        LoadableAccessoryEquipment(
            id: "loadable_dip_pull-up_belt",
            name: "Loadable Dip/Pull-Up Belt",
            description: nil,
            baseWeight: 0,
            unit: .kilograms,
            isActive: false
        ),
        LoadableAccessoryEquipment(
            id: "wrist_roller",
            name: "Wrist Roller",
            description: nil,
            baseWeight: 0,
            unit: .kilograms,
            isActive: true
        )
    ]
    
    static var mock: LoadableAccessoryEquipment {
        mocks[0]
    }
    
    static let mocks: [LoadableAccessoryEquipment] = [
        LoadableAccessoryEquipment(
            id: "fat_grip_attachments",
            name: "Fat Grip Attachments",
            description: nil,
            baseWeight: 0,
            unit: .kilograms,
            isActive: false
        ),
        LoadableAccessoryEquipment(
            id: "head_harness",
            name: "Head Harness",
            description: nil,
            baseWeight: 0,
            unit: .kilograms,
            isActive: true
        ),
        LoadableAccessoryEquipment(
            id: "loadable_dip_pull-up_belt",
            name: "Loadable Dip/Pull-Up Belt",
            description: nil,
            baseWeight: 0,
            unit: .kilograms,
            isActive: false
        ),
        LoadableAccessoryEquipment(
            id: "wrist_roller",
            name: "Wrist Roller",
            description: nil,
            baseWeight: 0,
            unit: .kilograms,
            isActive: true
        )
    ]
}
