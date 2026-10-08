//
//  WeightStepper.swift
//  Compound
//
//  What an exercise may weigh in one gym: the weight keyboard's − / + buttons, and the rounding
//  that prefill, warm-ups and progression apply (`WeightRoundingRule`). Pure: the equipment is
//  resolved once, here, into a `WeightStep` value, and everything after that is arithmetic.
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
    let plates: [Plate]
    /// How many sleeves the plates share: 2 on a bar, 1 on a T-bar row.
    var sleeves = 2
    /// The weight is assistance (`ExerciseModel.isAssisted`), stored negative. An empty field then
    /// steps from zero, and the keyboard offers a ± key.
    var isAssisted = false
    /// Whether the gym's equipment limits what the weight can be. The 2.5 kg fallback (no gym, or
    /// equipment it lacks), body weight and bands only say how far a tap moves the value, so a
    /// prescribed weight is not rounded to them.
    var constrainsWeight = true

    /// Whether the keyboard offers the plate calculator.
    var isPlateLoaded: Bool { baseWeight != nil && !plates.isEmpty }

    /// The next weight up from `value`, or the lightest there is when nothing is entered.
    func next(after value: Double?) -> Double? {
        let value = value ?? (isAssisted ? 0 : nil)
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
        let value = value ?? (isAssisted ? 0 : nil)
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

    /// The weight this equipment can make that is closest to `value`: the nearest total the plates
    /// load, the nearest grid point, or the nearest listed weight (the lighter on a tie). Bands
    /// carry no weight, so `value` is returned as it was.
    func nearest(to value: Double) -> Double {
        if isPlateLoaded, let baseWeight {
            return PlateCalculator.nearestLoadable(total: value, bar: baseWeight, plates: plates, sleeves: sleeves)
        }
        switch kind {
        case let .increment(step, min, max):
            return clamp(min + ((value - min) / step).rounded() * step, min: min, max: max)
        case .list(let weights):
            return weights.min { abs($0 - value) < abs($1 - value) } ?? value
        case .bands:
            return value
        }
    }

    /// The smallest change this equipment can make: the grid's step (one of the smallest plates on
    /// each sleeve), or the smallest gap between listed weights. `nil` for bands or a single weight.
    var smallestStep: Double? {
        switch kind {
        case .increment(let step, _, _):
            return step
        case .list(let weights):
            return zip(weights, weights.dropFirst()).map { $1 - $0 }.filter { $0 > Self.epsilon }.min()
        case .bands:
            return nil
        }
    }

    /// The same equipment giving assistance: mirrored below zero, down to the most it gives (or
    /// 200 steps where it has no top), and never above zero for an exercise that cannot be loaded
    /// (`isBodyweight`). −30 kg up one 2.5 kg step is −27.5 kg: less help, a harder set.
    func assisted(bodyweightOnly: Bool) -> WeightStep {
        let mirrored: Kind
        switch kind {
        case let .increment(step, _, max):
            let deepest = ((max ?? step * 200) / step).rounded(.up) * step
            mirrored = .increment(step, min: -deepest, max: bodyweightOnly ? 0 : max)
        case .list(let weights):
            let below = weights.map { -$0 } + [0] + (bodyweightOnly ? [] : weights)
            mirrored = .list(Array(Set(below)).sorted())
        case .bands:
            return self
        }
        return WeightStep(kind: mirrored, chip: chip, baseWeight: nil, plates: [], isAssisted: true, constrainsWeight: constrainsWeight)
    }

    /// "Per side: 20 + 10 + 2.5 kg" for a breakdown from `PlateCalculator`; "Plates: …" when
    /// there is one sleeve, so there is no other side.
    func plateText(_ perSide: [Double], unit: ExerciseWeightUnit) -> String {
        guard !perSide.isEmpty else { return String(localized: "Empty bar") }
        let label = sleeves == 1 ? String(localized: "Plates: ") : String(localized: "Per side: ")
        return label + perSide.map { WeightStepper.format($0) }.joined(separator: " + ") + " \(unit.abbreviation)"
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
        return steps(for: variation?.resistanceEquipment, profile: profile, unit: unit)
    }

    /// The step for one equipment variation's resistance equipment, the first that `profile` has.
    static func steps(for refs: [EquipmentRef]?, profile: GymProfileModel?, unit: ExerciseWeightUnit) -> WeightStep {
        guard let profile, let refs else { return fallback(unit) }

        for ref in refs {
            if let step = step(for: ref, profile: profile, unit: unit) { return step }
        }
        return fallback(unit)
    }

    /// No gym or no equipment: the smallest pair of plates a user would actually add.
    static func fallback(_ unit: ExerciseWeightUnit) -> WeightStep {
        WeightStep(kind: .increment(unit == .pounds ? 5 : 2.5, min: 0, max: nil), chip: nil, baseWeight: nil, plates: [], constrainsWeight: false)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func step(for ref: EquipmentRef, profile: GymProfileModel, unit: ExerciseWeightUnit) -> WeightStep? {
        let id = ref.equipmentId
        switch ref.kind {
        case .loadableBar:
            guard let bar = profile.loadableBars.first(where: { $0.id == id && $0.isActive }),
                  let base = bar.defaultBaseWeight ?? bar.baseWeights.first(where: \.isActive) else { return nil }
            let barWeight = convert(base.baseWeight, from: base.unit, to: unit)
            let collars = convert(bar.collarWeight * 2, from: .kilograms, to: unit)
            let chip = collars > 0
                ? String(localized: "Bar \(format(barWeight)) \(unit.abbreviation) + collars")
                : String(localized: "Bar \(format(barWeight)) \(unit.abbreviation)")
            return plateLoaded(base: ((barWeight + collars) * 1000).rounded() / 1000, chip: chip, sleeves: 2, profile: profile, unit: unit)

        case .plateLoadedMachine:
            guard let machine = profile.plateLoadedMachines.first(where: { $0.id == id && $0.isActive }) else { return nil }
            let base = convert(machine.baseWeight, from: machine.unit, to: unit)
            let chip = String(localized: "Bar \(format(base)) \(unit.abbreviation)")
            return plateLoaded(base: base, chip: chip, sleeves: machine.sleeves, profile: profile, unit: unit)

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
            return active.isEmpty ? nil : WeightStep(kind: .bands(active.map(\.name)), chip: nil, baseWeight: nil, plates: [], constrainsWeight: false)

        case .bodyWeight:
            // External load on top of the body: 1.25 kg, or the nearest round step in pounds.
            return WeightStep(
                kind: .increment(unit == .pounds ? 2.5 : 1.25, min: 0, max: nil), chip: "BW", baseWeight: nil, plates: [], constrainsWeight: false
            )

        case .supportEquipment, .accessoryEquipment, .loadableAccessoryEquipment:
            return nil
        }
    }

    /// Every sleeve is loaded alike, so the smallest change is one of the smallest plates on each.
    private static func plateLoaded(base: Double, chip: String, sleeves: Int, profile: GymProfileModel, unit: ExerciseWeightUnit) -> WeightStep {
        let plates = availablePlates(profile: profile, unit: unit, sleeves: sleeves)
        let step = (plates.first.map { $0.weight * Double(sleeves) }) ?? fallbackStep(unit)
        return WeightStep(
            kind: .increment(step, min: base, max: nil),
            chip: chip,
            baseWeight: base,
            plates: plates,
            sleeves: sleeves
        )
    }

    /// Every active plate in the gym, in the unit it is labelled in when any are, ascending, with
    /// how many of each fit on one of `sleeves`. A weight that both iron and bumper plates come in
    /// adds their counts, and is unlimited if either is; one too few to put on every sleeve is left
    /// out.
    static func availablePlates(profile: GymProfileModel, unit: ExerciseWeightUnit, sleeves: Int = 2) -> [Plate] {
        let entries = profile.freeWeights
            .filter { $0.isActive && $0.isPlates }
            .flatMap(\.range)
            .filter(\.isActive)
        let matching = entries.filter { $0.unit == unit }
        let byWeight = Dictionary(grouping: matching.isEmpty ? entries : matching) {
            convert($0.availableWeights, from: $0.unit, to: unit)
        }
        return byWeight.compactMap { weight, entries -> Plate? in
            let counts = entries.map(\.count)
            let perSleeve = counts.contains(nil) ? nil : counts.compactMap { $0 }.reduce(0, +) / max(sleeves, 1)
            guard weight > 0, (perSleeve ?? 1) > 0 else { return nil }
            return Plate(weight: weight, perSleeve: perSleeve)
        }
        .sorted { $0.weight < $1.weight }
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

    /// Two decimals at most, whole numbers without a trailing zero, in the region's decimal
    /// separator ("82,5" in Spanish) and without grouping, so it types back in as shown.
    static func format(_ value: Double, locale: Locale = .current) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale))
    }
}
