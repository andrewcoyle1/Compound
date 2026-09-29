//
//  Laterality.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/02/2026.
//

import Foundation

enum Laterality: String, CaseIterable, DataSyncModelProtocol, PickableItem {
    
    var id: String { self.rawValue }
    
    case bilateral
    case unilateral
    case assymetrical
    case unilateralBilateral
    
    var name: String {
        switch self {
        case .bilateral: return String(localized: "Bilateral")
        case .unilateral: return String(localized: "Unilateral")
        case .assymetrical: return String(localized: "Asymmetrical")
        case .unilateralBilateral: return String(localized: "Unilateral & Bilateral")
        }
    }
    
    var description: String? {
        switch self {
        case .bilateral: return String(localized: "Both sides of the body work together at the same time.")
        case .unilateral: return String(localized: "Only one side of the body works independently at a time.")
        case .assymetrical: return String(localized: "Both sides work together, but with uneven load or position.")
        case .unilateralBilateral: return String(localized: "Exercises performed with both sides at once, but each limb works independently on its own path.")
        }
    }
}
