//
//  UnitConversion.swift
//  Compound
//
//  Created by Andrew Coyle on 19/10/2025.
//

import Foundation

struct UnitConversion {
    
    // MARK: - Weight Conversion
    
    /// Convert kilograms to pounds
    static func kgToLbs(_ kilograms: Double) -> Double {
        return kilograms * 2.20462
    }
    
    /// Convert pounds to kilograms
    static func lbsToKg(_ lbs: Double) -> Double {
        return lbs / 2.20462
    }
    
    /// Convert weight from kg to the specified unit
    static func convertWeight(_ kilograms: Double, to unit: ExerciseWeightUnit) -> Double {
        switch unit {
        case .kilograms:
            return kilograms
        case .pounds:
            return kgToLbs(kilograms)
        }
    }
    
    /// Convert weight from the specified unit to kg
    static func convertWeightToKg(_ value: Double, from unit: ExerciseWeightUnit) -> Double {
        switch unit {
        case .kilograms:
            return value
        case .pounds:
            return lbsToKg(value)
        }
    }
    
    /// Convert weight from one unit to another
    static func convertWeight(_ value: Double, from: ExerciseWeightUnit, into: ExerciseWeightUnit) -> Double {
        if from == into {
            return value
        }
        // Convert to kg first, then to target unit
        let kilograms = convertWeightToKg(value, from: from)
        return convertWeight(kilograms, to: into)
    }
    
    /// Format weight for display with appropriate decimal places
    static func formatWeight(_ kilograms: Double, unit: ExerciseWeightUnit) -> String {
        let converted = convertWeight(kilograms, to: unit)
        switch unit {
        case .kilograms:
            return String(format: "%.1f", converted)
        case .pounds:
            return String(format: "%.1f", converted)
        }
    }
    
    // MARK: - User-Level Preferences
    //
    // `ExerciseWeightUnit` above is the per-exercise preference. `WeightUnitPreference` and
    // `LengthUnitPreference` are the user-level ones set during onboarding, and nothing here
    // covered them — so `2.20462` was written out by hand in ProfilePresenter,
    // ExerciseTemplateDetailPresenter and three onboarding presenters, and the Analytics tab
    // skipped conversion altogether.

    /// Convert weight from kg to the user's preferred unit.
    static func convertWeight(_ kilograms: Double, to unit: WeightUnitPreference) -> Double {
        switch unit {
        case .kilograms:
            return kilograms
        case .pounds:
            return kgToLbs(kilograms)
        }
    }

    /// Convert a value in the user's preferred unit back to kg for storage.
    static func convertWeightToKg(_ value: Double, from unit: WeightUnitPreference) -> Double {
        switch unit {
        case .kilograms:
            return value
        case .pounds:
            return lbsToKg(value)
        }
    }

    static func formatWeight(_ kilograms: Double, unit: WeightUnitPreference, decimals: Int = 1) -> String {
        convertWeight(kilograms, to: unit)
            .formatted(.number.precision(.fractionLength(decimals)))
    }

    // MARK: - Length Conversion
    //
    // Body circumferences are stored in centimetres — `LogNeckMeasurementPresenter.measurementCm`
    // and its eighteen siblings multiply inches by 2.54 on the way in.

    static func cmToInches(_ centimeters: Double) -> Double {
        return centimeters / 2.54
    }

    static func inchesToCm(_ inches: Double) -> Double {
        return inches * 2.54
    }

    /// Convert a stored centimetre value to the user's preferred unit.
    static func convertLength(_ centimeters: Double, to unit: LengthUnitPreference) -> Double {
        switch unit {
        case .centimeters:
            return centimeters
        case .inches:
            return cmToInches(centimeters)
        }
    }

    /// Convert a value in the user's preferred unit back to centimetres for storage.
    static func convertLengthToCm(_ value: Double, from unit: LengthUnitPreference) -> Double {
        switch unit {
        case .centimeters:
            return value
        case .inches:
            return inchesToCm(value)
        }
    }

    // MARK: - Distance Conversion
    
    /// Convert meters to miles
    static func metersToMiles(_ meters: Double) -> Double {
        return meters * 0.000621371
    }
    
    /// Convert miles to meters
    static func milesToMeters(_ miles: Double) -> Double {
        return miles / 0.000621371
    }
    
    /// Convert distance from meters to the specified unit
    static func convertDistance(_ meters: Double, to unit: ExerciseDistanceUnit) -> Double {
        switch unit {
        case .meters:
            return meters
        case .miles:
            return metersToMiles(meters)
        }
    }
    
    /// Convert distance from the specified unit to meters
    static func convertDistanceToMeters(_ value: Double, from unit: ExerciseDistanceUnit) -> Double {
        switch unit {
        case .meters:
            return value
        case .miles:
            return milesToMeters(value)
        }
    }
    
    /// Convert distance from one unit to another
    static func convertDistance(_ value: Double, from: ExerciseDistanceUnit, into: ExerciseDistanceUnit) -> Double {
        if from == into {
            return value
        }
        // Convert to meters first, then to target unit
        let meters = convertDistanceToMeters(value, from: from)
        return convertDistance(meters, to: into)
    }
    
    /// Format distance for display with appropriate decimal places
    static func formatDistance(_ meters: Double, unit: ExerciseDistanceUnit) -> String {
        let converted = convertDistance(meters, to: unit)
        switch unit {
        case .meters:
            // Show in km if over 1000m
            if converted >= 1000 {
                return String(format: "%.2f km", converted / 1000)
            }
            return String(format: "%.0f m", converted)
        case .miles:
            return String(format: "%.2f", converted)
        }
    }
}
