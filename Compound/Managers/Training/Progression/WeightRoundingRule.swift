//
//  WeightRoundingRule.swift
//  Compound
//
//  What a weight is allowed to be, as plain numbers.
//
//  `WorkoutSessionModel`'s rounding needs a gym profile and so is `@MainActor`; the progression
//  engine is neither and must stay that way. Resolving the equipment once, on the main actor,
//  and handing the engine the four numbers that fall out of it keeps the rule in one place
//  without dragging the gym into the algorithm.
//

import Foundation

struct WeightRoundingRule: Equatable {

    /// The machine's own range, when the exercise is on one. Nothing else constrains a weight.
    struct Equipment: Equatable {
        let minWeight: Double
        let maxWeight: Double
        let increment: Double
        let unit: ExerciseWeightUnit
    }

    /// A bar loaded with plates: the bar and the plates the gym has, in `unit`.
    struct PlateLoading: Equatable {
        let bar: Double
        let plates: [Double]
        let unit: ExerciseWeightUnit
    }

    let equipment: Equipment?
    let preferredUnit: ExerciseWeightUnit?
    /// Set for a barbell (or plate-loaded machine) in a gym whose plates are known, so a weight
    /// comes out as one the bar can actually carry rather than the nearest half kilogram.
    var plateLoading: PlateLoading?

    init(equipment: Equipment?, preferredUnit: ExerciseWeightUnit?, plateLoading: PlateLoading? = nil) {
        self.equipment = equipment
        self.preferredUnit = preferredUnit
        self.plateLoading = plateLoading
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
        let range = exercise.flatMap {
            WorkoutSessionModel.equipmentWeightRange(
                exercise: $0,
                gymProfile: gymProfile,
                preferredWeightUnit: preferredWeightUnit,
                resistanceEquipment: resistanceEquipment
            )
        }
        self.equipment = range.map {
            Equipment(minWeight: $0.minWeight, maxWeight: $0.maxWeight, increment: $0.increment, unit: $0.unit)
        }
        self.preferredUnit = preferredWeightUnit
        let unit = preferredWeightUnit ?? .kilograms
        let refs = resistanceEquipment ?? exercise?.equipmentVariations.first?.resistanceEquipment
        let step = WeightStepper.steps(for: refs, profile: gymProfile, unit: unit)
        if let bar = step.baseWeight, step.isPlateLoaded,
           let smallest = step.plates.min(),
           UnitConversion.convertWeightToKg(smallest, from: unit) <= Self.smallestPlateForProgressionKg {
            self.plateLoading = PlateLoading(bar: bar, plates: step.plates, unit: unit)
        }
    }

    /// Progression rounds to plates only when the gym has small ones. A profile whose lightest
    /// plate is 5 kg is far more likely to be missing its small plates than to have none, and
    /// rounding to it would make every step 10 kg.
    static let smallestPlateForProgressionKg = 2.5 + 0.001

    /// The rule as the engine takes it.
    var progressionRounding: ProgressionRounding {
        ProgressionRounding(round: round, minimumIncrementKg: minimumIncrementKg)
    }

    /// kg in, kg the user could actually load out.
    func round(_ weightKg: Double) -> Double {
        if let equipment, equipment.increment > 0 {
            let inEquipmentUnit = UnitConversion.convertWeight(weightKg, to: equipment.unit)
            let rounded = (inEquipmentUnit / equipment.increment).rounded() * equipment.increment
            let clamped = max(equipment.minWeight, min(equipment.maxWeight, rounded))
            return UnitConversion.convertWeightToKg(clamped, from: equipment.unit)
        }

        if let plateLoading {
            return PlateCalculator.nearestLoadableKg(weightKg, bar: plateLoading.bar, plates: plateLoading.plates, unit: plateLoading.unit)
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

    /// The smallest step this rule can express, in kg: the machine's increment where there is
    /// one, a pair of the smallest plates on a bar, otherwise 2.5 kg or 5 lb — the smallest plate
    /// a user would actually add.
    var minimumIncrementKg: Double {
        if let equipment, equipment.increment > 0 {
            return UnitConversion.convertWeightToKg(equipment.increment, from: equipment.unit)
        }
        if let plateLoading, let smallest = plateLoading.plates.min() {
            return UnitConversion.convertWeightToKg(smallest * 2, from: plateLoading.unit)
        }
        switch preferredUnit ?? .kilograms {
        case .kilograms: return 2.5
        case .pounds:    return UnitConversion.convertWeightToKg(5, from: ExerciseWeightUnit.pounds)
        }
    }
}
