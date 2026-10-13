//
//  EquipmentVariation.swift
//  Compound
//
//  Created by Andrew Coyle on 18/03/2026.
//

import Foundation

struct EquipmentVariation: Identifiable, Codable, Hashable {
    var id: String
    var resistanceEquipment: [EquipmentRef]
    var supportEquipment: [EquipmentRef]

    init(
        id: String = UUID().uuidString,
        resistanceEquipment: [EquipmentRef] = [],
        supportEquipment: [EquipmentRef] = []
    ) {
        self.id = id
        self.resistanceEquipment = resistanceEquipment
        self.supportEquipment = supportEquipment
    }

    enum CodingKeys: String, CodingKey {
        case id
        case resistanceEquipment = "resistance_equipment"
        case supportEquipment = "support_equipment"
    }

    /// Ref by ref: one naming a kind of equipment a later build added is skipped rather than
    /// failing the exercise, the template or the session it is stored in.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        resistanceEquipment = container.decodeLossyArray(EquipmentRef.self, forKey: .resistanceEquipment) ?? []
        supportEquipment = container.decodeLossyArray(EquipmentRef.self, forKey: .supportEquipment) ?? []
    }
}
