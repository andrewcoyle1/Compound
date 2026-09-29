//
//  WeightStepper.swift
//  DialedIn
//
//  What the weight keyboard's − / + buttons do for one exercise in one gym. Pure: the equipment
//  is resolved once, here, into a `WeightStep` value, and everything after that is arithmetic.
//

import Foundation

/// How one exercise's weight moves up and down. Every number is in the display unit.
struct WeightStep: Equatable {

    enum Kind: Equatable {
        /// A fixed step from a grid starting at `min`, clamped to `min...max`.
        case increment(Double, min: Double, max: Double?)
        /// Only these weights exist (a dumbbell rack, a set of fixed bars), ascending.
        case list([Double])
        /// Bands carry no weight. The keyboard cycles these names and leaves the weight empty.
        case bands([String])
    }

    let kind: Kind
    /// A short label beside the value: the bar's weight, or "BW".
    let chip: String?
    /// What the bar or sled weighs empty, for the plate calculator.
    let baseWeight: Double?
    /// The plates that can go on, ascending. Empty when the equipment is not plate-loaded.
    let plates: [Double]

    /// Whether the keyboard offers the plate calculator.
    var isPlateLoaded: Bool { baseWeight != nil && !plates.isEmpty }

    /// The next weight up from `value`, or the lightest there is when nothing is entered.
    func next(after value: Double?) -> Double? {
        switch kind {
        case let .increment(step, min, max):
            guard let value else { return min }
            let steps = ((value - min) / step + Self.epsilon).rounded(.down) + 1
            return clamp(min + steps * step, min: min, max: max)
        case .list(let weights):
            guard let value else { return weights.first }
            return weights.first { $0 > value + Self.epsilon } ?? weights.last
        case .bands:
            return nil
        }
    }

    /// The next weight down from `value`, never below the lightest there is.
    func previous(before value: Double?) -> Double? {
        switch kind {
        case let .increment(step, min, max):
            guard let value else { return min }
            let steps = ((value - min) / step - Self.epsilon).rounded(.up) - 1
            return clamp(min + steps * step, min: min, max: max)
        case .list(let weights):
            guard let value else { return weights.first }
            return weights.last { $0 < value - Self.epsilon } ?? weights.first
        case .bands:
            return nil
        }
    }

    /// The band after (or before) `index`, wrapping round: bands cycle rather than stop.
    func band(after index: Int?, forward: Bool) -> Int? {
        guard case .bands(let names) = kind, !names.isEmpty else { return nil }
        guard let index else { return forward ? 0 : names.count - 1 }
        return (index + (forward ? 1 : -1) + names.count) % names.count
    }

    private func clamp(_ value: Double, min: Double, max: Double?) -> Double {
        let rounded = (value * 1000).rounded() / 1000
        return Swift.min(Swift.max(rounded, min), max ?? .infinity)
    }

    /// Stored kg converted to pounds and back is never exactly the number typed.
    static let epsilon = 0.001
}

enum WeightStepper {

    /// The step for `exercise`'s chosen equipment in `profile`, in `unit`.
    static func steps(for exercise: WorkoutExerciseModel, profile: GymProfileModel?, unit: ExerciseWeightUnit) -> WeightStep {
        let variation = exercise.equipmentVariations.first { $0.id == exercise.chosenVariationId }
            ?? exercise.equipmentVariations.first
        guard let profile, let refs = variation?.resistanceEquipment else { return fallback(unit) }

        for ref in refs {
            if let step = step(for: ref, profile: profile, unit: unit) { return step }
        }
        return fallback(unit)
    }

    /// No gym or no equipment: the smallest pair of plates a user would actually add.
    static func fallback(_ unit: ExerciseWeightUnit) -> WeightStep {
        WeightStep(kind: .increment(unit == .pounds ? 5 : 2.5, min: 0, max: nil), chip: nil, baseWeight: nil, plates: [])
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func step(for ref: EquipmentRef, profile: GymProfileModel, unit: ExerciseWeightUnit) -> WeightStep? {
        let id = ref.equipmentId
        switch ref.kind {
        case .loadableBar:
            guard let bar = profile.loadableBars.first(where: { $0.id == id && $0.isActive }),
                  let base = bar.defaultBaseWeight ?? bar.baseWeights.first(where: \.isActive) else { return nil }
            return plateLoaded(base: convert(base.baseWeight, from: base.unit, to: unit), profile: profile, unit: unit)

        case .plateLoadedMachine:
            guard let machine = profile.plateLoadedMachines.first(where: { $0.id == id && $0.isActive }) else { return nil }
            return plateLoaded(base: convert(machine.baseWeight, from: machine.unit, to: unit), profile: profile, unit: unit)

        case .cableMachine:
            guard let machine = profile.cableMachines.first(where: { $0.id == id && $0.isActive }) else { return nil }
            let ranges = machine.ranges.filter(\.isActive).map { MachineRange(id: $0.id, min: $0.minWeight, max: $0.maxWeight, increment: $0.increment, unit: $0.unit) }
            return ranged(ranges, defaultId: machine.defaultRangeId, unit: unit)

        case .pinLoadedMachine:
            guard let machine = profile.pinLoadedMachines.first(where: { $0.id == id && $0.isActive }) else { return nil }
            let ranges = machine.ranges.filter(\.isActive).map { MachineRange(id: $0.id, min: $0.minWeight, max: $0.maxWeight, increment: $0.increment, unit: $0.unit) }
            return ranged(ranges, defaultId: machine.defaultRangeId, unit: unit)

        case .freeWeight:
            guard let item = profile.freeWeights.first(where: { $0.id == id && $0.isActive }) else { return nil }
            let weights = inUnit(item.range.filter(\.isActive).map { ($0.availableWeights, $0.unit) }, unit: unit)
            return weights.isEmpty ? nil : WeightStep(kind: .list(weights), chip: nil, baseWeight: nil, plates: [])

        case .fixedWeightBar:
            guard let bar = profile.fixedWeightBars.first(where: { $0.id == id && $0.isActive }) else { return nil }
            let weights = inUnit(bar.baseWeights.filter(\.isActive).map { ($0.baseWeight, $0.unit) }, unit: unit)
            return weights.isEmpty ? nil : WeightStep(kind: .list(weights), chip: nil, baseWeight: nil, plates: [])

        case .bands:
            guard let bands = profile.bands.first(where: { $0.id == id && $0.isActive }) else { return nil }
            let active = bands.range.filter(\.isActive)
                .sorted { convert($0.availableResistance, from: $0.unit, to: .kilograms) < convert($1.availableResistance, from: $1.unit, to: .kilograms) }
            return active.isEmpty ? nil : WeightStep(kind: .bands(active.map(\.name)), chip: nil, baseWeight: nil, plates: [])

        case .bodyWeight:
            // External load on top of the body: 1.25 kg, or the nearest round step in pounds.
            return WeightStep(kind: .increment(unit == .pounds ? 2.5 : 1.25, min: 0, max: nil), chip: "BW", baseWeight: nil, plates: [])

        case .supportEquipment, .accessoryEquipment, .loadableAccessoryEquipment:
            return nil
        }
    }

    /// A bar is loaded symmetrically, so the smallest change is one of the smallest plates a side.
    private static func plateLoaded(base: Double, profile: GymProfileModel, unit: ExerciseWeightUnit) -> WeightStep {
        let plates = availablePlates(profile: profile, unit: unit)
        let step = (plates.first.map { $0 * 2 }) ?? fallbackStep(unit)
        return WeightStep(
            kind: .increment(step, min: base, max: nil),
            chip: String(localized: "Bar \(format(base)) \(unit.abbreviation)"),
            baseWeight: base,
            plates: plates
        )
    }

    /// Every active plate in the gym, in the unit it is labelled in when any are, ascending.
    static func availablePlates(profile: GymProfileModel, unit: ExerciseWeightUnit) -> [Double] {
        let plates = profile.freeWeights
            .filter { $0.isActive && $0.id.hasSuffix("plates") }
            .flatMap(\.range)
            .filter(\.isActive)
            .map { ($0.availableWeights, $0.unit) }
        return inUnit(plates, unit: unit)
    }

    /// A cable or pin-loaded range, read off whichever machine type it came from.
    private struct MachineRange {
        let id: String
        let min: Double
        let max: Double
        let increment: Double
        let unit: ExerciseWeightUnit
    }

    /// The range in the user's unit when the machine has one, else its default, else the first.
    private static func ranged(
        _ ranges: [MachineRange],
        defaultId: String?,
        unit: ExerciseWeightUnit
    ) -> WeightStep? {
        guard let range = ranges.first(where: { $0.unit == unit })
                ?? ranges.first(where: { $0.id == defaultId })
                ?? ranges.first,
              range.increment > 0 else { return nil }
        return WeightStep(
            kind: .increment(
                convert(range.increment, from: range.unit, to: unit),
                min: convert(range.min, from: range.unit, to: unit),
                max: convert(range.max, from: range.unit, to: unit)
            ),
            chip: nil,
            baseWeight: nil,
            plates: []
        )
    }

    /// The weights labelled in `unit` when there are any — a mixed rack is used in the user's
    /// unit — else all of them converted. Ascending and without duplicates.
    private static func inUnit(_ weights: [(Double, ExerciseWeightUnit)], unit: ExerciseWeightUnit) -> [Double] {
        let matching = weights.filter { $0.1 == unit }
        let chosen = matching.isEmpty ? weights.map { convert($0.0, from: $0.1, to: unit) } : matching.map(\.0)
        return Array(Set(chosen.map { ($0 * 1000).rounded() / 1000 })).sorted()
    }

    private static func fallbackStep(_ unit: ExerciseWeightUnit) -> Double { unit == .pounds ? 5 : 2.5 }

    private static func convert(_ value: Double, from source: ExerciseWeightUnit, to target: ExerciseWeightUnit) -> Double {
        let converted = UnitConversion.convertWeight(value, from: source, into: target)
        return (converted * 1000).rounded() / 1000
    }

    /// Two decimals at most, and whole numbers without ".0".
    static func format(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() && abs(rounded) < 1e15 ? String(Int(rounded)) : String(rounded)
    }
}
