//
//  AnyEquipment.swift
//  Compound
//
//  Created by Andrew Coyle on 01/27/2026.
//

import Foundation

struct AnyEquipment: Identifiable, Hashable, Sendable {
    /// The type, which is what exercises name and what pickers select by.
    let ref: EquipmentRef
    /// The item in its gym. Two lat pulldowns share a `ref` but not this.
    let instanceId: String
    let name: String
    let imageName: String?
    let description: String?
    let isActive: Bool

    var id: String { "\(ref.kind.rawValue):\(instanceId)" }

    init<T: GymEquipmentItem>(_ item: T) {
        self.ref = item.equipmentRef
        self.instanceId = item.id
        self.name = item.name
        self.imageName = item.imageName
        self.description = item.description
        self.isActive = item.isActive
    }
}

extension Array where Element == AnyEquipment {
    /// The name to show for `ref`: the first item of that type, else its id.
    func name(for ref: EquipmentRef) -> String {
        first { $0.ref == ref }?.name ?? ref.equipmentId
    }
}
