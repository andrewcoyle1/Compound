//
//  WorkoutSessionModel+WarmupSets.swift
//  Compound
//
//  Extracted for function_body_length.
//

import Foundation

// MARK: - Warmup Sets Generation
extension WorkoutSessionModel {
    
    /// Generates 1-3 warmup sets before working sets based on working weight
    /// Uses percentage-based values: 50%, 70%, 90% of working weight
    @MainActor
    static func generateWarmupSets(
        trackingMode: TrackingMode,
        authorId: String,
        workingWeightKg: Double?,
        workingReps: Int?,
        setTargets: [SetTarget],
        exercise: ExerciseModel? = nil,
        gymProfile: GymProfileModel? = nil,
        unitPreferences: [String: ExerciseUnitPreference]? = nil
    ) -> [WorkoutSetModel] {
        
        // Only generate warmup sets for weight-based tracking modes
        guard trackingMode == .weightReps || trackingMode == .repsOnly else {
            return []
        }
        
        let warmupCount = determineWarmupCount(workingWeightKg: workingWeightKg)
        let percentages: [Double] = [0.5, 0.7, 0.9]
        let targetReps = workingReps ?? setTargets.first?.minReps ?? setTargets.first?.maxReps
                
        // Create warmup sets
        let warmupSets = (0..<warmupCount).map { index in
            let delegate = WarmupSetDelegate(
                index: index,
                authorId: authorId,
                exercise: exercise,
                percentage: percentages[index],
                workingWeightKg: workingWeightKg,
                targetReps: targetReps,
                gymProfile: gymProfile,
                unitPreferences: unitPreferences
            )
            return createWarmupSet(delegate: delegate)
        }
        
        return warmupSets
    }
    
    private static func determineWarmupCount(workingWeightKg: Double?) -> Int {
        if let weight = workingWeightKg, weight > 0 {
            let count: Int
            if weight < 50 {
                count = 1
            } else if weight < 100 {
                count = 2
            } else {
                count = 3
            }
            return count
        } else {
            // Default to 2 warmup sets if weight is unknown
            let count = 2
            return count
        }
    }
    
    struct WarmupSetDelegate {
        let index: Int
        let authorId: String
        let exercise: ExerciseModel?
        var percentage: Double
        var workingWeightKg: Double?
        var targetReps: Int?
        let gymProfile: GymProfileModel?
        let unitPreferences: [String: ExerciseUnitPreference]?
    }
    
    @MainActor
    private static func createWarmupSet(delegate: WarmupSetDelegate) -> WorkoutSetModel {
        var warmupWeight = delegate.workingWeightKg.map { $0 * delegate.percentage }
        
        // Round warmup weight to equipment increments if exercise and gym profile are provided
        if let weight = warmupWeight, let exercise = delegate.exercise {
            warmupWeight = roundWarmupWeight(
                weight: weight,
                exercise: exercise,
                gymProfile: delegate.gymProfile,
                unitPreferences: delegate.unitPreferences
            )
        }
                
        return WorkoutSetModel(
            id: UUID().uuidString,
            authorId: delegate.authorId,
            index: delegate.index + 1, // Will be re-indexed after prepending
            reps: delegate.targetReps,
            weightKg: warmupWeight,
            durationSec: nil,
            distanceMeters: nil,
            rpe: nil,
            isWarmup: true,
            completedAt: nil,
            dateCreated: .now
        )
    }
    
    @MainActor
    private static func roundWarmupWeight(
        weight: Double,
        exercise: ExerciseModel,
        gymProfile: GymProfileModel?,
        unitPreferences: [String: ExerciseUnitPreference]?
    ) -> Double? {
        let exerciseId = exercise.id
        let unitPref = unitPreferences?[exerciseId]
        let preferredUnit = unitPref?.weightUnit
        
        // Try equipment rounding first (only applies to pin-loaded/cable machines)
        let roundedByEquipment = roundWeightToEquipmentIncrement(
            weightKg: weight,
            exercise: exercise,
            gymProfile: gymProfile,
            preferredWeightUnit: preferredUnit
        )
        
        // If equipment rounding didn't change the weight (free weights), apply unit rounding
        if roundedByEquipment == weight, let preferredUnit = preferredUnit {
            return roundWeightToPreferredUnit(
                weightKg: roundedByEquipment,
                preferredUnit: preferredUnit
            )
        } else {
            return roundedByEquipment
        }
    }
}
