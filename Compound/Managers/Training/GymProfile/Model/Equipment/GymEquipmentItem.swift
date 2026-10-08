//
//  GymEquipmentItem.swift
//  Compound
//
//  Created by Andrew Coyle on 01/27/2026.
//

import Foundation

protocol GymEquipmentItem: Identifiable, Codable {
    static var kind: EquipmentKind { get }

    /// This item in this gym. Unique within its list, so two lat pulldowns can sit side by side.
    var id: String { get }
    /// The catalogue type the item is, which is what exercises name. Equal to `id` for catalogue
    /// items and for machines the user made that work as nothing in the catalogue.
    var typeId: String { get }
    var name: String { get }
    var imageName: String? { get }
    var description: String? { get }
    var isActive: Bool { get set }
}

extension GymEquipmentItem {
    var equipmentRef: EquipmentRef {
        EquipmentRef(kind: Self.kind, id: typeId)
    }
}

/// The machine kinds a gym can hold more than one of, or one the catalogue does not have:
/// cable, pin-loaded and plate-loaded. Everything else is one item per catalogue type.
protocol CustomizableMachine: GymEquipmentItem {
    var id: String { get set }
    var typeId: String { get set }
    var name: String { get set }
    static var catalogue: [Self] { get }
}

extension CustomizableMachine {
    /// A duplicate or a machine the user made. Only these can be renamed and deleted; a catalogue
    /// item deleted from a gym would come back on the next decode anyway.
    var isCustom: Bool {
        !Self.catalogue.contains { $0.id == id }
    }
}

extension CableMachine: CustomizableMachine {
    static var catalogue: [CableMachine] { defaultCableMachines }
}

extension PinLoadedMachine: CustomizableMachine {
    static var catalogue: [PinLoadedMachine] { defaultPinLoadedMachines }
}

extension PlateLoadedMachine: CustomizableMachine {
    static var catalogue: [PlateLoadedMachine] { defaultPlateLoadedMachines }
}
