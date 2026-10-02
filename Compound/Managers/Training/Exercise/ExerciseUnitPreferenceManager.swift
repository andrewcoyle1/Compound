//
//  ExerciseUnitPreferenceManager.swift
//  Compound
//
//  Created by Andrew Coyle on 19/10/2025.
//

import Foundation
import SwiftUI

@Observable
@MainActor
class ExerciseUnitPreferenceManager {
    
    private let userDefaults: UserDefaults
    private let userManager: UserManager
    
    // Cache for preferences to avoid repeated UserDefaults reads
    private var preferencesCache: [String: ExerciseUnitPreference] = [:]
    
    init(userDefaults: UserDefaults = .standard, userManager: UserManager) {
        self.userDefaults = userDefaults
        self.userManager = userManager
    }
    
    // MARK: - Public Methods
    
    /// Get the unit preference for a specific exercise template
    func getPreference(for templateId: String) -> ExerciseUnitPreference {
        // Check cache first
        if let cached = preferencesCache[templateId] {
            return cached
        }
        
        // Try to load from UserDefaults
        if let userId = userManager.currentUser?.userId,
           let key = preferenceKey(userId: userId, templateId: templateId),
           let data = userDefaults.data(forKey: key),
           let preference = try? JSONDecoder().decode(ExerciseUnitPreference.self, from: data) {
            preferencesCache[templateId] = preference
            return preference
        }
        
        // Return default based on user's global preferences
        let defaultPreference = createDefaultPreference(for: templateId)
        preferencesCache[templateId] = defaultPreference
        return defaultPreference
    }
    
    /// Set the weight unit preference for a specific exercise template
    func setWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String) {
        var preference = getPreference(for: templateId)
        preference.weightUnit = unit
        savePreference(preference)
    }
    
    /// Set the distance unit preference for a specific exercise template
    func setDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String) {
        var preference = getPreference(for: templateId)
        preference.distanceUnit = unit
        savePreference(preference)
    }
    
    /// Set both unit preferences for a specific exercise template
    func setPreference(weightUnit: ExerciseWeightUnit? = nil, distanceUnit: ExerciseDistanceUnit? = nil, for templateId: String) {
        var preference = getPreference(for: templateId)
        if let weightUnit = weightUnit {
            preference.weightUnit = weightUnit
        }
        if let distanceUnit = distanceUnit {
            preference.distanceUnit = distanceUnit
        }
        savePreference(preference)
    }
    
    /// Clear all cached preferences (useful when user signs out)
    func clearCache() {
        preferencesCache.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func savePreference(_ preference: ExerciseUnitPreference) {
        guard let userId = userManager.currentUser?.userId,
              let key = preferenceKey(userId: userId, templateId: preference.exerciseModelId),
              let data = try? JSONEncoder().encode(preference) else {
            return
        }
        
        userDefaults.set(data, forKey: key)
        preferencesCache[preference.exerciseModelId] = preference
    }
    
    private func preferenceKey(userId: String, templateId: String) -> String? {
        return "exercise_unit_preference_\(userId)_\(templateId)"
    }
    
    private func createDefaultPreference(for templateId: String) -> ExerciseUnitPreference {
        // Try to use user's global preferences as defaults
        let user = userManager.currentUser
        
        let defaultWeightUnit: ExerciseWeightUnit
        if let userWeightPref = user?.submittedWeightUnitPreference {
            defaultWeightUnit = userWeightPref == .kilograms ? .kilograms : .pounds
        } else {
            defaultWeightUnit = .kilograms
        }
        
        let defaultDistanceUnit: ExerciseDistanceUnit
        if let userDistancePref = user?.submittedDistanceUnitPreference {
            defaultDistanceUnit = userDistancePref == .kilometers ? .meters : .miles
        } else if let userLengthPref = user?.submittedLengthUnitPreference {
            // Users who onboarded before distance had its own preference only ever set the length
            // one, so fall back to it rather than resetting them to metric.
            defaultDistanceUnit = userLengthPref == .centimeters ? .meters : .miles
        } else {
            defaultDistanceUnit = .meters
        }
        
        return ExerciseUnitPreference(
            exerciseModelId: templateId,
            weightUnit: defaultWeightUnit,
            distanceUnit: defaultDistanceUnit
        )
    }
}

extension CoreInteractor {
    // MARK: ExerciseUnitPreferenceManager
    
    func getPreference(templateId: String) -> ExerciseUnitPreference {
        exerciseUnitPreferenceManager.getPreference(for: templateId)
    }
    
    /// Set the weight unit preference for a specific exercise template
    func setWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String) {
        exerciseUnitPreferenceManager.setWeightUnit(unit, for: templateId)
    }
    
    /// Set the distance unit preference for a specific exercise template
    func setDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String) {
        exerciseUnitPreferenceManager.setDistanceUnit(unit, for: templateId)
    }
    
    /// Set both unit preferences for a specific exercise template
    func setPreference(weightUnit: ExerciseWeightUnit? = nil, distanceUnit: ExerciseDistanceUnit? = nil, for templateId: String) {
        exerciseUnitPreferenceManager.setPreference(weightUnit: weightUnit, distanceUnit: distanceUnit, for: templateId)
    }
    
    /// Clear all cached preferences (useful when user signs out)
    func clearCache() {
        exerciseUnitPreferenceManager.clearCache()
    }

}
