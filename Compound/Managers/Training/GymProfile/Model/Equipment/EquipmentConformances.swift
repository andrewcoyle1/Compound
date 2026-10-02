//
//  EquipmentConformances.swift
//  Compound
//
//  Created by Andrew Coyle on 01/27/2026.
//

import Foundation

extension FreeWeights: GymEquipmentItem {
    static var kind: EquipmentKind { .freeWeight }
}

extension LoadableBars: GymEquipmentItem {
    static var kind: EquipmentKind { .loadableBar }
}

extension FixedWeightBars: GymEquipmentItem {
    static var kind: EquipmentKind { .fixedWeightBar }
}

extension Bands: GymEquipmentItem {
    static var kind: EquipmentKind { .bands }
}

extension BodyWeights: GymEquipmentItem {
    static var kind: EquipmentKind { .bodyWeight }
}

extension SupportEquipment: GymEquipmentItem {
    static var kind: EquipmentKind { .supportEquipment }
}

extension AccessoryEquipment: GymEquipmentItem {
    static var kind: EquipmentKind { .accessoryEquipment }
}

extension LoadableAccessoryEquipment: GymEquipmentItem {
    static var kind: EquipmentKind { .loadableAccessoryEquipment }
}

extension CableMachine: GymEquipmentItem {
    static var kind: EquipmentKind { .cableMachine }
}

extension PlateLoadedMachine: GymEquipmentItem {
    static var kind: EquipmentKind { .plateLoadedMachine }
}

extension PinLoadedMachine: GymEquipmentItem {
    static var kind: EquipmentKind { .pinLoadedMachine }
}
