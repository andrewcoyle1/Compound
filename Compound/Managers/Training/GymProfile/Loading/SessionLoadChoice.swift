//
//  SessionLoadChoice.swift
//  Compound
//
//  What an exercise is loaded with in one session, decided when it joins the session: which of
//  its equipment variations, what kind of load that is, the unit its weights are entered in, and
//  how many of the weight one set lifts. Pure apart from reading the gym it is given.
//

import Foundation

/// What a variation is lifted with, for deciding which past sessions speak for this one: a
/// dumbbell press says nothing about the barbell weight. A cable stack and a pin stack are one
/// kind, as are any dumbbells; each other kind of free weight is its own.
enum LoadKind: Hashable {
    case stack
    case barAndPlates
    case plateMachine
    case fixedBar
    case freeWeight(String)
    case bodyweight
    case bands

    /// The load of `refs`: a bar or plate machine first (the plates beside it only load it),
    /// then a stack, a free weight, a fixed bar, plates held alone, body weight and bands.
    /// `nil` for a variation with none of them.
    init?(refs: [EquipmentRef]) {
        let kinds = refs.map(\.kind)
        let freeWeights = refs.filter { $0.kind == .freeWeight }
        let isPlates = { (ref: EquipmentRef) in ref.equipmentId.hasSuffix("plates") }
        if kinds.contains(.loadableBar) {
            self = .barAndPlates
        } else if kinds.contains(.plateLoadedMachine) {
            self = .plateMachine
        } else if kinds.contains(.cableMachine) || kinds.contains(.pinLoadedMachine) {
            self = .stack
        } else if let weight = freeWeights.first(where: { !isPlates($0) }) ?? freeWeights.first {
            self = .freeWeight(weight.equipmentId)
        } else if kinds.contains(.fixedWeightBar) {
            self = .fixedBar
        } else if kinds.contains(.bodyWeight) {
            self = .bodyweight
        } else if kinds.contains(.bands) {
            self = .bands
        } else {
            return nil
        }
    }
}

enum SessionLoadChoice {

    /// The variation an exercise starts the session on: the one used last time when that was in
    /// this gym and the gym can still do it, else the first this gym can do, else the first.
    /// `previous` is the exercise last time and `previousGymId` the gym that session was in.
    static func variationId(
        among variations: [EquipmentVariation],
        previous: WorkoutExerciseModel?,
        previousGymId: String?,
        gym: GymProfileModel?
    ) -> String? {
        let available = gym.map { Set($0.allEquipment.filter(\.isActive).map(\.ref)) }
        func isPerformable(_ variation: EquipmentVariation) -> Bool {
            guard let available else { return true }
            return Set(variation.resistanceEquipment + variation.supportEquipment).isSubset(of: available)
        }
        // ponytail: last time means the last session of this workout; a search back through
        // older sessions for one in this gym if people often alternate gyms on one plan.
        if let previous, previousGymId == gym?.id,
           let used = previous.activeVariation?.id,
           let variation = variations.first(where: { $0.id == used }), isPerformable(variation) {
            return variation.id
        }
        return (variations.first(where: isPerformable) ?? variations.first)?.id
    }

    /// The unit the exercise's weights are entered in: the user's own choice for the exercise
    /// when they made one, else the unit the equipment is labelled in, so weights read as they do
    /// on the rack, else the app-wide unit the preference defaults to.
    static func weightUnit(
        preference: ExerciseUnitPreference?,
        refs: [EquipmentRef]?,
        gym: GymProfileModel?
    ) -> ExerciseWeightUnit? {
        if let preference, preference.weightUnitIsChosen { return preference.weightUnit }
        return WeightStepper.equipmentUnit(for: refs, profile: gym) ?? preference?.weightUnit
    }

    /// 2 when the exercise holds one weight in each hand (`weightPerSide` on an exercise that is
    /// not worked a side at a time): a dumbbell set is logged as one dumbbell, as it reads on the
    /// rack, and its volume counts both.
    static func loadsPerSet(_ exercise: ExerciseModel) -> Int? {
        exercise.trackableMetrics.contains(.weightPerSide) && !WorkoutSessionModel.isPerSide(exercise) ? 2 : nil
    }

    /// The base weight, in kg, of the plate-loaded machine `refs` load on in `gym`, when it is set
    /// to enter plates only; `nil` for anything else. The machine is the one the keyboard steps
    /// on: the first switched-on of its type.
    static func machineBaseKg(refs: [EquipmentRef]?, gym: GymProfileModel?) -> Double? {
        guard let gym, let refs else { return nil }
        for ref in refs where ref.kind == .plateLoadedMachine {
            guard let machine = gym.plateLoadedMachines.first(where: { $0.typeId == ref.equipmentId && $0.isActive }) else { continue }
            guard machine.excludesBaseFromLoad, machine.baseWeight > 0 else { return nil }
            return UnitConversion.convertWeightToKg(machine.baseWeight, from: machine.unit)
        }
        return nil
    }
}

extension WorkoutExerciseModel {

    /// Puts the exercise on `exercise`'s equipment for this session, as `SessionLoadChoice` picks
    /// it in `gym`: added part-way through, or swapped in.
    mutating func takeLoad(
        from exercise: ExerciseModel,
        gym: GymProfileModel?,
        preference: ExerciseUnitPreference?,
        previous: WorkoutExerciseModel? = nil,
        previousGymId: String? = nil
    ) {
        equipmentVariations = exercise.equipmentVariations
        chosenVariationId = SessionLoadChoice.variationId(
            among: exercise.equipmentVariations,
            previous: previous,
            previousGymId: previousGymId,
            gym: gym
        )
        weightUnit = SessionLoadChoice.weightUnit(preference: preference, refs: activeVariation?.resistanceEquipment, gym: gym)
        loadsPerSet = SessionLoadChoice.loadsPerSet(exercise)
        machineBaseKg = SessionLoadChoice.machineBaseKg(refs: activeVariation?.resistanceEquipment, gym: gym)
    }

    /// After the equipment or the gym changes: the unit its weights are entered in again, and
    /// every set not yet logged on a weight the equipment makes. Logged sets keep what was lifted.
    @MainActor
    mutating func refitLoad(library exercise: ExerciseModel?, gym: GymProfileModel?, preference: ExerciseUnitPreference?) {
        let refs = activeVariation?.resistanceEquipment
        weightUnit = SessionLoadChoice.weightUnit(preference: preference, refs: refs, gym: gym)
        machineBaseKg = SessionLoadChoice.machineBaseKg(refs: refs, gym: gym)
        let rule = WeightRoundingRule(exercise: exercise, gymProfile: gym, preferredWeightUnit: weightUnit, resistanceEquipment: refs)
        for index in sets.indices where sets[index].completedAt == nil {
            sets[index].weightKg = sets[index].weightKg.map(rule.round)
        }
    }
}
