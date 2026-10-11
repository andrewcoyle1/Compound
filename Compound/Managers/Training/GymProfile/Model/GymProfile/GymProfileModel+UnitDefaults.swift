//
//  GymProfileModel+UnitDefaults.swift
//  Compound
//
//  A new gym's catalogue set up for the unit its user weighs in: the bar and stacks a gym in that
//  unit has, so its weights read as they do on the equipment (`SessionLoadChoice.weightUnit`).
//  Only new gyms: an existing gym is the user's own record of what is there.
//

import Foundation

extension GymProfileModel {

    func adaptingDefaults(to unit: ExerciseWeightUnit) -> GymProfileModel {
        var gym = self
        switch unit {
        case .pounds:
            // The 45 lb bar, chosen to load, rather than a 20 kg bar read as 44.09 lb.
            for index in gym.loadableBars.indices where gym.loadableBars[index].typeId == Self.barbellTypeId {
                guard let bar = gym.loadableBars[index].baseWeights.firstIndex(where: {
                    $0.unit == .pounds && abs($0.baseWeight - 45) < 0.001
                }) else { continue }
                gym.loadableBars[index].baseWeights[bar].isActive = true
                gym.loadableBars[index].chosenBaseWeightId = gym.loadableBars[index].baseWeights[bar].id
            }
        case .kilograms:
            gym.pinLoadedMachines = gym.pinLoadedMachines.map { $0.inKilograms() }
            gym.cableMachines = gym.cableMachines.map { $0.inKilograms() }
        }
        return gym
    }

    static let barbellTypeId = "barbell"
}

extension StackMachine {

    /// The machine with a kilogram stack switched on and its pound stacks off: the one it has, or
    /// one of the same reach in fives (300 lb is 135 kg). A kg user on a pound stack stepped in
    /// 2.27 kg.
    func inKilograms() -> Self {
        var machine = self
        if !machine.ranges.contains(where: { $0.unit == .kilograms }) {
            let reach = machine.ranges.map { UnitConversion.convertWeightToKg($0.maxWeight, from: $0.unit) }.max() ?? 100
            machine.ranges.append(WeightStack(
                id: UUID().uuidString,
                name: String(localized: "Kilogram stack"),
                minWeight: 5,
                maxWeight: max(5, (reach / 5).rounded(.down) * 5),
                increment: 5,
                unit: .kilograms,
                isActive: true
            ))
        }
        for index in machine.ranges.indices {
            machine.ranges[index].isActive = machine.ranges[index].unit == .kilograms
        }
        machine.defaultRangeId = machine.ranges.first { $0.unit == .kilograms }?.id
        return machine
    }
}
