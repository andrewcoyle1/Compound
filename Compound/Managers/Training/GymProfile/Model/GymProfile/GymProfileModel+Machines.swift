//
//  GymProfileModel+Machines.swift
//  Compound
//
//  Duplicating, adding and deleting machines. A gym holds one item per catalogue type for
//  everything else; machines can repeat (two lat pulldowns) or be the user's own.
//

import Foundation

extension GymProfileModel {

    /// Copies the machine `id` under a new id and the next free "<name> 2" name, keeping its
    /// type, and puts it after the original. Returns the copy's id.
    @discardableResult
    mutating func duplicateMachine<Machine: CustomizableMachine>(
        in list: WritableKeyPath<GymProfileModel, [Machine]>,
        id: String
    ) -> String? {
        guard let index = self[keyPath: list].firstIndex(where: { $0.id == id }) else { return nil }
        var copy = self[keyPath: list][index]
        copy.id = UUID().uuidString
        copy.name = Self.nextFreeName(after: copy.name, taken: Set(self[keyPath: list].map(\.name)))
        self[keyPath: list].insert(copy, at: index + 1)
        return copy.id
    }

    /// Adds a machine of `kind`, switched on. With `worksAs`, a catalogue type of that kind, it
    /// takes that type's loading and stands in for it in exercises; without one it is its own
    /// type. Returns its id, or nil when `kind` is not a machine.
    @discardableResult
    mutating func addMachine(kind: EquipmentKind, name: String, worksAs: String?) -> String? {
        switch kind {
        case .cableMachine:
            return addMachine(in: \.cableMachines, name: name, worksAs: worksAs, standalone: CableMachine.catalogue[0])
        case .pinLoadedMachine:
            return addMachine(in: \.pinLoadedMachines, name: name, worksAs: worksAs, standalone: PinLoadedMachine.catalogue[0])
        case .plateLoadedMachine:
            let standalone = PlateLoadedMachine(id: "", name: "", baseWeight: 0, unit: .kilograms, isActive: true)
            return addMachine(in: \.plateLoadedMachines, name: name, worksAs: worksAs, standalone: standalone)
        default:
            return nil
        }
    }

    /// Removes the machine `id` if the user made it. Catalogue machines only switch off: the
    /// catalogue merge would put one back on the next decode.
    mutating func deleteMachine(kind: EquipmentKind, id: String) {
        switch kind {
        case .cableMachine: cableMachines.removeAll { $0.id == id && $0.isCustom }
        case .pinLoadedMachine: pinLoadedMachines.removeAll { $0.id == id && $0.isCustom }
        case .plateLoadedMachine: plateLoadedMachines.removeAll { $0.id == id && $0.isCustom }
        default: break
        }
    }

    /// `standalone` lends its loading (stacks or base weight) to a machine that works as nothing
    /// in the catalogue; its own id and name are replaced.
    private mutating func addMachine<Machine: CustomizableMachine>(
        in list: WritableKeyPath<GymProfileModel, [Machine]>,
        name: String,
        worksAs: String?,
        standalone: Machine
    ) -> String {
        let template = worksAs.flatMap { type in Machine.catalogue.first { $0.id == type } }
        var machine = template ?? standalone
        machine.id = UUID().uuidString
        machine.typeId = template?.id ?? machine.id
        machine.name = name
        machine.isActive = true
        self[keyPath: list].append(machine)
        return machine.id
    }

    /// "Lat Pulldown 2", or the first number after it no other item in the list is called.
    static func nextFreeName(after name: String, taken: Set<String>) -> String {
        var number = 2
        while taken.contains(String(localized: "\(name) \(number)")) {
            number += 1
        }
        return String(localized: "\(name) \(number)")
    }
}

extension GymProfileModel {

    /// Every type an exercise can name: the catalogue, then the user's own machines that work as
    /// nothing in it, from any of `profiles`, once each.
    static func equipmentTypes(including profiles: [GymProfileModel]) -> [AnyEquipment] {
        let catalogue = allEquipmentCatalog
        var seen = Set(catalogue.map(\.ref))
        let own = profiles.flatMap(\.allEquipment).filter { seen.insert($0.ref).inserted }
        return catalogue + own
    }
}
