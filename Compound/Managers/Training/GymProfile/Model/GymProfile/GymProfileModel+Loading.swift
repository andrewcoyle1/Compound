//
//  GymProfileModel+Loading.swift
//  Compound
//
//  The two things the plate calculator changes from inside a workout: which bar the gym loads,
//  and which plate weights it has. Pure, so the sheet's edits can be tested without it.
//

import Foundation

/// One plate weight the calculator offers, in the unit it is shown in.
struct PlateChoice: Equatable, Identifiable {
    let weight: Double
    let isOn: Bool
    var id: Double { weight }
}

extension GymProfileModel {

    /// The bar loaded for exercises naming `typeId`: the first switched-on one, as the weight
    /// keyboard takes it (`WeightStepper`).
    func loadedBar(typeId: String) -> LoadableBars? {
        loadableBars.first { $0.typeId == typeId && $0.isActive }
    }

    /// Makes `baseWeightId` the bar this gym loads under exercises naming `typeId`.
    mutating func chooseBarWeight(_ baseWeightId: String, typeId: String) {
        guard let index = loadableBars.firstIndex(where: { $0.typeId == typeId && $0.isActive }) else { return }
        loadableBars[index].chosenBaseWeightId = baseWeightId
    }

    /// Every plate weight the gym lists, in `unit`, with whether it is on. Only plates labelled
    /// in `unit` when there are any, so a kg gym is not offered its pound plates converted; the
    /// same rule `WeightStepper.availablePlates` loads by.
    func plateChoices(unit: ExerciseWeightUnit) -> [PlateChoice] {
        let entries = plateEntries(unit: unit)
        let byWeight = Dictionary(grouping: entries) { weight(of: $0, in: unit) }
        return byWeight
            .map { weight, entries in PlateChoice(weight: weight, isOn: entries.contains(where: \.isActive)) }
            .sorted { $0.weight > $1.weight }
    }

    /// Switches every plate of `weight` (in `unit`) on or off, across iron and bumper plates.
    mutating func setPlate(_ weight: Double, unit: ExerciseWeightUnit, isOn: Bool) {
        let labelled = hasPlates(labelledIn: unit)
        for item in freeWeights.indices where freeWeights[item].isActive && freeWeights[item].isPlates {
            for entry in freeWeights[item].range.indices {
                let plate = freeWeights[item].range[entry]
                guard !labelled || plate.unit == unit,
                      abs(self.weight(of: plate, in: unit) - weight) < 0.001 else { continue }
                freeWeights[item].range[entry].isActive = isOn
            }
        }
    }

    private func plateEntries(unit: ExerciseWeightUnit) -> [FreeWeightsAvailable] {
        let entries = freeWeights.filter { $0.isActive && $0.isPlates }.flatMap(\.range)
        return hasPlates(labelledIn: unit) ? entries.filter { $0.unit == unit } : entries
    }

    private func hasPlates(labelledIn unit: ExerciseWeightUnit) -> Bool {
        freeWeights.contains { $0.isActive && $0.isPlates && $0.range.contains { $0.unit == unit } }
    }

    private func weight(of plate: FreeWeightsAvailable, in unit: ExerciseWeightUnit) -> Double {
        let converted = UnitConversion.convertWeight(UnitConversion.convertWeightToKg(plate.availableWeights, from: plate.unit), to: unit)
        return (converted * 1000).rounded() / 1000
    }
}
