//
//  SetTargetSetType.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/02/2026.
//

import Foundation

enum SetTargetSetType: String, DataSyncModelProtocol {
    
    var id: String { rawValue }
    
    case standard
    case drop
    case myo
    case failure

    init(from decoder: Decoder) throws {
        if let rawValue = try? decoder.singleValueContainer().decode(String.self),
           let value = SetTargetSetType(rawValue: rawValue) {
            self = value
            return
        }
        if let container = try? decoder.container(keyedBy: LegacyCodingKeys.self) {
            if let rawValue = try? container.decode(String.self, forKey: .rawValue),
               let value = SetTargetSetType(rawValue: rawValue) {
                self = value
                return
            }
            if let name = try? container.decode(String.self, forKey: .name),
               let value = SetTargetSetType.fromName(name) {
                self = value
                return
            }
        }
        self = .standard
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case rawValue
        case name
    }

    private static func fromName(_ name: String) -> SetTargetSetType? {
        switch name {
        case "Standard Set": return .standard
        case "Drop Set": return .drop
        case "Myo Set": return .myo
        case "Failure Set": return .failure
        default: return nil
        }
    }

    var name: String {
        switch self {
        case .standard: return String(localized: "Standard Set")
        case .drop: return String(localized: "Drop Set")
        case .myo: return String(localized: "Myo Set")
        case .failure: return String(localized: "Failure Set")
        }
    }

    var subtitle: String {
        switch self {
        case .standard: return String(localized: "A normal set of a fixed weight and target repitions.")
        case .drop: return String(localized: "A set where you continue repping to push muscle fatigue with progressively lower weight after reaching failure at a heavier load.")
        case .myo: return String(localized: "A set where you continue repping to push muscle fatigue with progressively low reps while keeping the weight constant.")
        case .failure: return String(localized: "A set where you perform reps until you can no longer maintain proper form (for compound exercises) or complete another rep (for isolation exercises).")
        }
    }
}
