//
//  EquipmentRef.swift
//  Compound
//
//  Created by Andrew Coyle on 01/27/2026.
//

import Foundation

struct EquipmentRef: DataSyncModelProtocol, Hashable, Sendable {
    let kind: EquipmentKind
    let equipmentId: String
    
    var id: String {
        "\(kind.rawValue):\(equipmentId)"
    }
    
    init(kind: EquipmentKind, id: String) {
        self.kind = kind
        self.equipmentId = id
    }
    
    enum CodingKeys: String, CodingKey {
        case kind
        case equipmentId = "id"
    }
}
