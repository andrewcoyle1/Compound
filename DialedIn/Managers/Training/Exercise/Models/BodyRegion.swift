//
//  BodyRegion.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/02/2026.
//

import Foundation

enum BodyRegion: String, CaseIterable, DataSyncModelProtocol {
    
    var id: String { rawValue }
    
    case upperBody, lowerBody
    
    var name: String {
        switch self {
        case .upperBody: return String(localized: "Upper Body")
        case .lowerBody: return String(localized: "Lower Body")
        }
    }
}
