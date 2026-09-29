//
//  WeightSource.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/02/2026.
//

enum WeightSource: String, DataSyncModelProtocol {
    
    var id: String { self.rawValue }
    
    case manual
    case healthkit
    case imported

    var displayName: String {
        switch self {
        case .manual: return String(localized: "Manual Entry")
        case .healthkit: return String(localized: "HealthKit")
        case .imported: return String(localized: "Imported")
        }
    }
}
