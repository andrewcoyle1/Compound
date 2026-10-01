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
}
