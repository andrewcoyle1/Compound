//
//  LoadableAccessoryEquipment.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct LoadableAccessoryEquipment: Identifiable, Codable {
    var id: String
    /// The catalogue type this item is, which exercises name. A duplicate shares its original's;
    /// a machine the user made that works as nothing in the catalogue has its own id.
    var typeId: String
    var name: String
    var imageName: String?
    var description: String?
    var baseWeight: Double
    var unit: ExerciseWeightUnit
    var isActive: Bool
    
    init(
        id: String,
        typeId: String? = nil,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        baseWeight: Double,
        unit: ExerciseWeightUnit,
        isActive: Bool
    ) {
        self.id = id
        self.typeId = typeId ?? id
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

// MARK: - Decoding

extension LoadableAccessoryEquipment {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, typeId, name, imageName, description, baseWeight, unit, isActive
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
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}
