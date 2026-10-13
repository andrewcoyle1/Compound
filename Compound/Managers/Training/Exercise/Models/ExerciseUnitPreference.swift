//
//  ExerciseUnitPreference.swift
//  Compound
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
        case .pounds: return "lb"
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
    
    var liveActivityUnit: LiveActivityDistanceUnit { self == .miles ? .miles : .meters }

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
    /// Whether the user chose `weightUnit` for this exercise. When they have not, a session enters
    /// its weights in the unit the equipment is labelled in (`SessionLoadChoice.weightUnit`), and
    /// `weightUnit` is only the app-wide unit. A preference stored before this existed was stored
    /// because the user changed something, so it reads as chosen.
    var weightUnitIsChosen: Bool

    init(
        exerciseModelId: String,
        weightUnit: ExerciseWeightUnit = .kilograms,
        distanceUnit: ExerciseDistanceUnit = .meters,
        weightUnitIsChosen: Bool = false
    ) {
        self.exerciseModelId = exerciseModelId
        self.weightUnit = weightUnit
        self.distanceUnit = distanceUnit
        self.weightUnitIsChosen = weightUnitIsChosen
    }

    enum CodingKeys: String, CodingKey {
        case exerciseModelId, weightUnit, distanceUnit, weightUnitIsChosen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseModelId = try container.decode(String.self, forKey: .exerciseModelId)
        weightUnit = try container.decode(ExerciseWeightUnit.self, forKey: .weightUnit)
        distanceUnit = try container.decode(ExerciseDistanceUnit.self, forKey: .distanceUnit)
        weightUnitIsChosen = try container.decodeIfPresent(Bool.self, forKey: .weightUnitIsChosen) ?? true
    }
}
