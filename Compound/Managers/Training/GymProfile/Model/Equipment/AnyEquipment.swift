//
//  AnyEquipment.swift
//  Compound
//
//  Created by Andrew Coyle on 01/27/2026.
//

import Foundation

struct AnyEquipment: Identifiable, Hashable, Sendable {
    let ref: EquipmentRef
    let name: String
    let imageName: String?
    let description: String?
    let isActive: Bool
    
    var id: String { ref.id }
    
    init<T: GymEquipmentItem>(_ item: T) {
        self.ref = item.equipmentRef
        self.name = item.name
        self.imageName = item.imageName
        self.description = item.description
        self.isActive = item.isActive
    }
}
