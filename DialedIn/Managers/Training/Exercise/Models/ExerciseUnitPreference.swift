//
//  ExerciseUnitPreference.swift
//  DialedIn
//
//  Created by Andrew Coyle on 19/10/2025.
//

import Foundation

enum ExerciseWeightUnit: String, Codable, CaseIterable {
    case kilograms
    case pounds

    /// The same unit as the Live Activity's own copy, which lives in `Shared/`.
    var liveActivityUnit: LiveActivityWeightUnit { self == .pounds ? .pounds : .kilograms }
    
    var abbreviation: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lbs"
        }
    }
    
    var displayName: String {
        switch self {
        case .kilograms: return String(localized: "Kilograms")
        case .pounds: return String(localized: "Pounds")
        }
    }
}

enum ExerciseDistanceUnit: String, Codable, CaseIterable {
    case meters
    case miles
    
    var abbreviation: String {
        switch self {
        case .meters: return "m"
        case .miles: return "mi"
        }
    }
    
    var displayName: String {
        switch self {
        case .meters: return String(localized: "Meters")
        case .miles: return String(localized: "Miles")
        }
    }
}

struct ExerciseUnitPreference: Codable {
    let exerciseModelId: String
    var weightUnit: ExerciseWeightUnit
    var distanceUnit: ExerciseDistanceUnit
    
    init(exerciseModelId: String, weightUnit: ExerciseWeightUnit = .kilograms, distanceUnit: ExerciseDistanceUnit = .meters) {
        self.exerciseModelId = exerciseModelId
        self.weightUnit = weightUnit
        self.distanceUnit = distanceUnit
    }
}
