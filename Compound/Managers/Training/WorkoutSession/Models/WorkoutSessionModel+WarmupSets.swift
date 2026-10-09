//
//  WorkoutSessionModel+WarmupSets.swift
//  Compound
//
//  Extracted for function_body_length.
//

import Foundation

// MARK: - Warmup Sets Generation
extension WorkoutSessionModel {
    
    /// The warm-up sets before the working sets: a ramp of lighter sets whose reps taper as the
    /// load rises (8, 5, 3, then 2), so the last warm-up primes the working weight without being
    /// an extra working set. With no `count` from the plan, how many depends on how heavy the
    /// work is relative to the lifter, read from the working reps; with one, the ramp for that
    /// many (see `warmupPercentages`). Sources and Compound's own choices: `MethodInfo.warmupSets`.
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
        
        let targetReps = workingReps ?? setTargets.first?.minReps ?? setTargets.first?.maxReps
        let percentages = warmupPercentages(
            count: count ?? determineWarmupCount(workingReps: targetReps, exerciseType: exercise?.type)
        )

        // Create warmup sets
        let warmupSets = percentages.indices.map { index in
            let delegate = WarmupSetDelegate(
                index: index,
                authorId: authorId,
                exercise: exercise,
                percentage: percentages[index],
                workingWeightKg: workingWeightKg,
                // Bodyweight work has no load to taper against, so it warms up at the working reps.
                targetReps: trackingMode == .weightReps ? warmupReps(percentage: percentages[index]) : targetReps,
                gymProfile: gymProfile,
                unitPreferences: unitPreferences
            )
            return createWarmupSet(delegate: delegate)
        }

        // A plan's count is the user's choice and is kept whole. Without one, a warm-up the
        // equipment rounds up to the working weight, or onto the warm-up before it, is dropped:
        // on an empty bar every ramp is the bar.
        guard count == nil, let workingWeightKg, workingWeightKg > 0 else { return warmupSets }
        var kept: [WorkoutSetModel] = []
        for set in warmupSets {
            guard let weight = set.weightKg, weight > 0, weight < workingWeightKg,
                  weight > (kept.last?.weightKg ?? 0) else { continue }
            var set = set
            set.index = kept.count + 1
            kept.append(set)
        }
        return kept
    }
    
    /// The fraction of the working weight for each warm-up: about 45, 65 and 82 % for three, the
    /// 40–80 % span the warm-up studies used. A plan's count past four adds another at 90 %.
    private static func warmupPercentages(count: Int) -> [Double] {
        switch count {
        case ...0: return []
        case 1: return [0.60]
        case 2: return [0.50, 0.75]
        case 3: return [0.45, 0.65, 0.82]
        default: return [0.45, 0.60, 0.75, 0.85] + Array(repeating: 0.90, count: count - 4)
        }
    }

    /// Reps for a warm-up at `percentage` of the working weight: 8 up to half of it, 5 up to 70 %,
    /// 3 up to 85 %, 2 above. Fewer reps as the load rises, so the warm-ups add no fatigue.
    static func warmupReps(percentage: Double) -> Int {
        switch percentage {
        case ...0.5:  return 8
        case ...0.7:  return 5
        case ...0.85: return 3
        default:      return 2
        }
    }

    /// How many warm-ups without a plan. Isolation and core work needs one. Otherwise the working
    /// reps stand in for how close the weight is to the lifter's max (by Epley, 6 reps to failure
    /// is about 83 % of it, 12 about 71 %): heavy work of 6 reps or fewer gets three, 7–12 reps
    /// two, lighter work one. Two when the reps are unknown.
    private static func determineWarmupCount(workingReps: Int?, exerciseType: ExerciseType?) -> Int {
        switch exerciseType {
        case .isolationUpper, .isolationLower, .core:
            return 1
        case .compoundUpper, .compoundLower, nil:
            guard let reps = workingReps, reps > 0 else { return 2 }
            if reps <= 6 { return 3 }
            if reps <= 12 { return 2 }
            return 1
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
        
        // Rounded to a weight the gym can make, by the same rule the keyboard steps by.
        if let exercise = delegate.exercise {
            let rule = WeightRoundingRule(
                exercise: exercise,
                gymProfile: delegate.gymProfile,
                preferredWeightUnit: delegate.unitPreferences?[exercise.id]?.weightUnit
            )
            warmupWeight = warmupWeight.map(rule.round)
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
}
