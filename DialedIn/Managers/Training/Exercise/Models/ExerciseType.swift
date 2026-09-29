//
//  ExerciseType.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/01/2026.
//

enum ExerciseType: String, Equatable, CaseIterable, DataSyncModelProtocol, PickableItem {
    
    var id: String { self.rawValue }
    
    case compoundUpper
    case compoundLower
    case isolationUpper
    case isolationLower
    case core
    
    var name: String {
        switch self {
        case .compoundUpper: return String(localized: "Upper Compound")
        case .compoundLower: return String(localized: "Lower Compound")
        case .isolationUpper: return String(localized: "Upper Isolation")
        case .isolationLower: return String(localized: "Lower Isolation")
        case .core: return String(localized: "Core")
        }
    }
    
    var description: String? {
        nil
    }
}
