//
//  Muscles.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/02/2026.
//

import Foundation

enum Muscles: String, CodingKeyRepresentable, CaseIterable, DataSyncModelProtocol {
    
    var id: String { self.rawValue }
    
    case triceps, upperTraps, obliques, neck, lats, forearms, sideDelts, rearDelts, frontDelts, chest, biceps, upperBack, lowerBack, abs, serratus
    case quads, hamstrings, glutes, calves, abductors, adductors, tibialis
    
    var name: String {
        switch self {
        case .triceps: return String(localized: "Triceps")
        case .upperTraps: return String(localized: "Upper Traps")
        case .obliques: return String(localized: "Obliques")
        case .neck: return String(localized: "Neck")
        case .lats: return String(localized: "Lats")
        case .forearms: return String(localized: "Forearms")
        case .sideDelts: return String(localized: "Side Delts")
        case .rearDelts: return String(localized: "Rear Delts")
        case .frontDelts: return String(localized: "Front Delts")
        case .chest: return String(localized: "Chest")
        case .biceps: return String(localized: "Biceps")
        case .upperBack: return String(localized: "Upper Back")
        case .lowerBack: return String(localized: "Lower Back")
        case .abs: return String(localized: "Abs")
        case .serratus: return String(localized: "Serratus")
        case .quads: return String(localized: "Quads")
        case .hamstrings: return String(localized: "Hamstrings")
        case .glutes: return String(localized: "Glutes")
        case .calves: return String(localized: "Calves")
        case .abductors: return String(localized: "Abductors")
        case .adductors: return String(localized: "Adductors")
        case .tibialis: return String(localized: "Tibialis")
        }
    }

    var bodyRegion: BodyRegion {
        switch self {
        case .triceps, .upperTraps, .obliques, .neck, .lats, .forearms, .sideDelts, .rearDelts, .frontDelts, .chest, .biceps, .upperBack, .lowerBack, .abs, .serratus:
            return .upperBody
        case .quads, .hamstrings, .glutes, .calves, .abductors, .adductors, .tibialis:
            return .lowerBody
        }
    }
}
