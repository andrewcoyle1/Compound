//
//  WorkoutSessionModel+Prefill.swift
//  Compound
//
//  How a new session's working sets are filled in before the user touches them, and the two
//  pieces of equipment arithmetic the progression engine needs handed to it as plain numbers.
//

import Foundation

extension SessionPrefill {

    /// Whether the working sets are filled in at all. `.empty` leaves every one of them blank.
    var fillsWorkingSets: Bool {
        switch self {
        case .empty:                        return false
        case .previousValues, .suggestions: return true
        }
    }

    /// The suggestion for one exercise, or `nil` when there is none worth applying — which
    /// includes `.noHistory`, since the engine never invents a starting weight.
    func suggestion(for templateId: String) -> ProgressionSuggestion? {
        guard case .suggestions(let byExercise) = self,
              let suggestion = byExercise[templateId],
              suggestion.rationale != .noHistory else { return nil }
        return suggestion
    }
}

extension ProgressionSuggestion {

    /// The suggestion for one set, or `nil` past the end of the list.
    func set(at index: Int) -> SuggestedSet? {
        guard index >= 0, index < sets.count else { return nil }
        let suggested = sets[index]
        return suggested.isEmpty ? nil : suggested
    }
}

/// Everything one exercise's working sets are filled in from.
struct WorkingSetPrefill {
    let prefill: SessionPrefill
    let previousSets: [WorkoutSetModel]?
    let authorId: String
    let exercise: ExerciseModel
    let gymProfile: GymProfileModel?
    let unitPreferences: [String: ExerciseUnitPreference]?

    /// Fills `workingSets` from the suggestion for this exercise, falling back per field to what
    /// was logged last time. A set with neither is left exactly as it was built.
    ///
    /// `workingSets` has one row per set, a per-side exercise included (one `both` row each). Last
    /// session may have been split into a left and a right row per set, so it is read one row per
    /// set too, the left standing for the pair — otherwise set 2 would inherit set 1's right arm.
    @MainActor
    func apply(to workingSets: inout [WorkoutSetModel]) {
        guard prefill.fillsWorkingSets else { return }

        let suggestion = prefill.suggestion(for: exercise.id)
        // A drop or mini-set is part of the set before it, and filled by hand when it is added:
        // matched by position, last time's drop would hand its lighter weight to the next set.
        let previousWorkingSets = (previousSets ?? []).filter { !$0.isWarmup && $0.side != .right && !$0.isSubSet }
        let preferredUnit = unitPreferences?[exercise.id]?.weightUnit

        for (position, index) in workingSets.indices.filter({ !workingSets[$0].isSubSet }).enumerated() {
            let suggested = suggestion?.set(at: position)
            let previous = position < previousWorkingSets.count ? previousWorkingSets[position] : nil
            guard suggested != nil || previous != nil else { continue }

            var weightKg = suggested?.weightKg ?? previous?.weightKg ?? workingSets[index].weightKg
            if let weight = weightKg {
                weightKg = WorkoutSessionModel.roundWeightForLogging(
                    weightKg: weight,
                    exercise: exercise,
                    gymProfile: gymProfile,
                    preferredWeightUnit: preferredUnit
                )
            }

            // Changed in place rather than rebuilt field by field, so its kind and parent survive.
            // The rows were built for `authorId` (`defaultSets`).
            workingSets[index].reps = suggested?.reps ?? previous?.reps ?? workingSets[index].reps
            workingSets[index].weightKg = weightKg
            workingSets[index].durationSec = suggested?.durationSec ?? previous?.durationSec ?? workingSets[index].durationSec
            workingSets[index].distanceMeters = suggested?.distanceMeters ?? previous?.distanceMeters ?? workingSets[index].distanceMeters
            workingSets[index].isWarmup = false
            workingSets[index].completedAt = nil
            workingSets[index].dateCreated = .now
        }
    }
}

extension WorkoutSessionModel {

    /// Equipment first, then the user's unit: a pin stack can only be moved a pin at a time, and
    /// anything the equipment does not constrain is rounded to something a user would type.
    @MainActor
    static func roundWeightForLogging(
        weightKg: Double,
        exercise: ExerciseModel,
        gymProfile: GymProfileModel?,
        preferredWeightUnit: ExerciseWeightUnit?
    ) -> Double {
        let roundedByEquipment = roundWeightToEquipmentIncrement(
            weightKg: weightKg,
            exercise: exercise,
            gymProfile: gymProfile,
            preferredWeightUnit: preferredWeightUnit
        )

        if roundedByEquipment == weightKg, let preferredWeightUnit {
            return roundWeightToPreferredUnit(
                weightKg: roundedByEquipment,
                preferredUnit: preferredWeightUnit
            ) ?? roundedByEquipment
        }
        return roundedByEquipment
    }

    /// The weight range this exercise's weight would be rounded to, or `nil` when nothing about
    /// its equipment constrains the weight. It mirrors the range resolution
    /// `roundWeightToEquipmentIncrement` does, because a step the machine cannot be set to is
    /// not a step at all.
    @MainActor
    static func equipmentWeightRange(
        exercise: ExerciseModel,
        gymProfile: GymProfileModel?,
        preferredWeightUnit: ExerciseWeightUnit?,
        resistanceEquipment: [EquipmentRef]? = nil
    ) -> (any WeightRange)? {
        // The equipment chosen for this session when there is one, else the exercise's first.
        let refs = resistanceEquipment ?? exercise.equipmentVariations.first?.resistanceEquipment ?? []
        let gym = gymProfile ?? GymProfileModel(authorId: "")
        let fallbackGym = GymProfileModel(authorId: "")

        for equipmentRef in refs {
            let range: (any WeightRange)?
            switch equipmentRef.kind {
            case .pinLoadedMachine:
                let machine = gym.pinLoadedMachines.first(where: { $0.id == equipmentRef.equipmentId && $0.isActive })
                    ?? fallbackGym.pinLoadedMachines.first(where: { $0.id == equipmentRef.equipmentId })
                range = machine.flatMap { machine in
                    preferredRange(machine.ranges, defaultRange: machine.defaultRange, unit: preferredWeightUnit)
                }
            case .cableMachine:
                let machine = gym.cableMachines.first(where: { $0.id == equipmentRef.equipmentId && $0.isActive })
                    ?? fallbackGym.cableMachines.first(where: { $0.id == equipmentRef.equipmentId })
                range = machine.flatMap { machine in
                    preferredRange(machine.ranges, defaultRange: machine.defaultRange, unit: preferredWeightUnit)
                }
            default:
                range = nil
            }

            if let range {
                return range
            }
        }

        return nil
    }

    /// First range whose unit matches the user's, else the machine's default, else the first
    /// active one — the same order the rounding uses.
    private static func preferredRange<Range: WeightRange>(
        _ ranges: [Range],
        defaultRange: Range?,
        unit: ExerciseWeightUnit?
    ) -> (any WeightRange)? {
        if let unit, let match = ranges.first(where: { $0.unit == unit }) {
            return match
        }
        return defaultRange ?? ranges.first
    }
}
