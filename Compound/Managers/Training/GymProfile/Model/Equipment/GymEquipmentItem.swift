//
//  GymEquipmentItem.swift
//  Compound
//
//  Created by Andrew Coyle on 01/27/2026.
//

import Foundation

protocol GymEquipmentItem: Identifiable, Codable {
    static var kind: EquipmentKind { get }
    
    var id: String { get }
    var name: String { get }
    var imageName: String? { get }
    var description: String? { get }
    var isActive: Bool { get set }
}

extension GymEquipmentItem {
    var equipmentRef: EquipmentRef {
        EquipmentRef(kind: Self.kind, id: id)
    }
}
