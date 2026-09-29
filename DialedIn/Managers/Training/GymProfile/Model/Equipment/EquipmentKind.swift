//
//  EquipmentKind.swift
//  DialedIn
//
//  Created by Andrew Coyle on 01/27/2026.
//

import Foundation

enum EquipmentKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case freeWeight
    case loadableBar
    case fixedWeightBar
    case bands
    case bodyWeight
    case supportEquipment
    case accessoryEquipment
    case loadableAccessoryEquipment
    case cableMachine
    case plateLoadedMachine
    case pinLoadedMachine
    
    var id: String { rawValue }
}

extension EquipmentKind {
    var sectionTitle: String {
        switch self {
        case .freeWeight:
            return String(localized: "Free Weights")
        case .loadableBar:
            return String(localized: "Loadable Bars")
        case .fixedWeightBar:
            return String(localized: "Fixed Weight Bars")
        case .bands:
            return String(localized: "Bands")
        case .bodyWeight:
            return String(localized: "Body Weights")
        case .supportEquipment:
            return String(localized: "Support Equipment")
        case .accessoryEquipment:
            return String(localized: "Accessory Equipment")
        case .loadableAccessoryEquipment:
            return String(localized: "Loadable Accessory Equipment")
        case .cableMachine:
            return String(localized: "Cable Machines")
        case .plateLoadedMachine:
            return String(localized: "Plate Loaded Machines")
        case .pinLoadedMachine:
            return String(localized: "Pin Loaded Machines")
        }
    }
}
