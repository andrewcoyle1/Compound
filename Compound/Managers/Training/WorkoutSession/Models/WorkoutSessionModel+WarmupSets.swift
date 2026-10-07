//
//  WorkoutSessionModel+WarmupSets.swift
//  Compound
//
//  Extracted for function_body_length.
//

import Foundation

// MARK: - Warmup Sets Generation
extension WorkoutSessionModel {
    
    /// The warm-up sets before the working sets. With no `count` from the plan, one to three by
    /// working weight at 50, 70 and 90 % of it; with one, the ramp for that many (see
    /// `warmupPercentages`).
    @MainActor
    static func generateWarmupSets(
        trackingMode: TrackingMode,
        authorId: String,
        workingWeightKg: Double?,
        workingReps: Int?,
        setTargets: [SetTarget],
        exercise: ExerciseModel? = nil,
        gymProfile: GymProfileModel? = nil,
        unitPreferences: [String: ExerciseUnitPreference]? = nil,
        count: Int? = nil
    ) -> [WorkoutSetModel] {
        
        // Only generate warmup sets for weight-based tracking modes
        guard trackingMode == .weightReps || trackingMode == .repsOnly else {
            return []
        }
        
        let percentages = warmupPercentages(count: count, workingWeightKg: workingWeightKg)
        let targetReps = workingReps ?? setTargets.first?.minReps ?? setTargets.first?.maxReps
                
        // Create warmup sets
        let warmupSets = percentages.indices.map { index in
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
    
    /// The fraction of the working weight for each warm-up. A plan's count gets a ramp that ends
    /// at 85 %, and any set past four another at 90 %; without one, the weight decides how many.
    private static func warmupPercentages(count: Int?, workingWeightKg: Double?) -> [Double] {
        guard let count else {
            return Array([0.5, 0.7, 0.9].prefix(determineWarmupCount(workingWeightKg: workingWeightKg)))
        }
        switch count {
        case ...0: return []
        case 1: return [0.60]
        case 2: return [0.50, 0.70]
        case 3: return [0.45, 0.65, 0.85]
        default: return [0.45, 0.60, 0.75, 0.85] + Array(repeating: 0.90, count: count - 4)
        }
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
