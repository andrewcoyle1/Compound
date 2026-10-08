//
//  WeightRoundingRule.swift
//  Compound
//
//  What a weight is allowed to be, as a plain value.
//
//  Resolving the equipment needs a gym profile and happens on the main actor; the progression
//  engine is neither and must stay that way. Resolving once, through the same `WeightStepper` the
//  weight keyboard uses, and handing the engine the resulting `WeightStep` keeps one answer to
//  "what can this exercise weigh here" without dragging the gym into the algorithm.
//

import Foundation

struct WeightRoundingRule: Equatable {

    /// What the exercise's equipment allows, in `unit`. A step that does not constrain the weight
    /// (no gym, equipment the gym lacks, body weight, bands) leaves rounding to the user's unit.
    let step: WeightStep
    /// The unit `step`'s numbers are in.
    let unit: ExerciseWeightUnit
    let preferredUnit: ExerciseWeightUnit?

    init(step: WeightStep, unit: ExerciseWeightUnit, preferredUnit: ExerciseWeightUnit?) {
        self.step = step
        self.unit = unit
        self.preferredUnit = preferredUnit
    }

    /// Resolves the rule for one exercise in one gym, on `resistanceEquipment` (the variation
    /// chosen for the session) or else the exercise's first. The result is a value: nothing it
    /// returns needs the main actor again.
    @MainActor
    init(
        exercise: ExerciseModel?,
        gymProfile: GymProfileModel?,
        preferredWeightUnit: ExerciseWeightUnit?,
        resistanceEquipment: [EquipmentRef]? = nil
    ) {
        let unit = preferredWeightUnit ?? .kilograms
        let refs = resistanceEquipment ?? exercise?.equipmentVariations.first?.resistanceEquipment
        var step = WeightStepper.steps(for: refs, profile: gymProfile, unit: unit)
        // Assistance is stored negative, so the equipment is mirrored below zero exactly as the
        // keyboard mirrors it; otherwise a machine's grid would clamp every assisted weight to its
        // lightest pin.
        if let exercise, exercise.isAssisted {
            step = step.assisted(bodyweightOnly: exercise.isBodyweight)
        }
        self.init(step: step, unit: unit, preferredUnit: preferredWeightUnit)
    }

    /// Progression rounds to plates only when the gym has small ones. A profile whose lightest
    /// plate is 5 kg is far more likely to be missing its small plates than to have none, and
    /// rounding to it would make every step 10 kg.
    static let smallestPlateForProgressionKg = 2.5 + 0.001

    /// The rule progression uses: this one, except that a bar in a gym without small plates is
    /// rounded as though nothing constrained it (`smallestPlateForProgressionKg`).
    var forProgression: WeightRoundingRule {
        guard step.isPlateLoaded, let smallest = step.plates.map(\.weight).min(),
              UnitConversion.convertWeightToKg(smallest, from: unit) > Self.smallestPlateForProgressionKg else { return self }
        var unconstrained = step
        unconstrained.constrainsWeight = false
        return WeightRoundingRule(step: unconstrained, unit: unit, preferredUnit: preferredUnit)
    }

    /// The rule as the engine takes it.
    var progressionRounding: ProgressionRounding {
        ProgressionRounding(round: round, minimumIncrementKg: minimumIncrementKg)
    }

    /// kg in, kg the user could actually load out.
    func round(_ weightKg: Double) -> Double {
        if step.constrainsWeight {
            // Rounded to the gram first, as the stepper's own figures are, so a weight that is on
            // the equipment already is not pushed off it by the conversion.
            let value = (UnitConversion.convertWeight(weightKg, to: unit) * 1000).rounded() / 1000
            return UnitConversion.convertWeightToKg(step.nearest(to: value), from: unit)
        }

        guard let preferredUnit else { return weightKg }
        let inPreferredUnit = UnitConversion.convertWeight(weightKg, to: preferredUnit)
        let rounded: Double
        switch preferredUnit {
        case .kilograms: rounded = (inPreferredUnit * 2).rounded() / 2
        case .pounds:    rounded = inPreferredUnit.rounded()
        }
        return UnitConversion.convertWeightToKg(rounded, from: preferredUnit)
    }

    /// The smallest step this rule can express, in kg: the equipment's smallest change where it
    /// constrains the weight, otherwise 2.5 kg or 5 lb — the smallest plate a user would actually
    /// add.
    var minimumIncrementKg: Double {
        if step.constrainsWeight, let smallest = step.smallestStep {
            return UnitConversion.convertWeightToKg(smallest, from: unit)
        }
        switch preferredUnit ?? .kilograms {
        case .kilograms: return 2.5
        case .pounds:    return UnitConversion.convertWeightToKg(5, from: ExerciseWeightUnit.pounds)
        }
    }
}
