//
//  WeightStack.swift
//  Compound
//
//  The weight stack of a cable or pin-loaded machine: where the pin can go, and the add-on weights
//  that sit on top of it. One type for both machine kinds, so the keyboard, rounding and the gym
//  editor read stacks one way.
//

import Foundation

/// The stored names are kept from when cable and pin-loaded machines each had their own range type,
/// so stored gyms and existing code read unchanged.
typealias PinLoadedMachineRange = WeightStack
typealias CableMachineRange = WeightStack

struct WeightStack: Identifiable, Codable, Hashable {
    var id: String
    var name: String

    /// The lightest pin. Stacks saved before G3 store 0 here, which no stack can be set to; see
    /// `lightestPin`.
    var minWeight: Double
    var maxWeight: Double
    var increment: Double

    var unit: ExerciseWeightUnit

    var isActive: Bool

    /// Weights that sit on the stack independently of the pin, each on or off: a 2 kg toggle is
    /// `[2]`, two of them `[2, 2]`. A three-position lever (none, half, full) is two equal toggles.
    var addOns: [Double] = []

    /// An uneven stack: every pin weight, replacing the grid of `minWeight`, `maxWeight` and
    /// `increment` when set.
    var weights: [Double]?

    /// The most add-ons combined. Each one doubles the loads (2⁶ = 64 per pin), and no machine
    /// carries more than a couple, so anything past this is a typing slip rather than a stack.
    static let maxAddOns = 6

    /// The first weight the pin can select. No stack can be set to zero — the top plate always
    /// lifts — so a stored minimum of 0 (every catalogue stack before G3) means one increment.
    var lightestPin: Double {
        minWeight > 0 ? minWeight : increment
    }

    /// Where the pin can go, ascending: the uneven list, or the grid from the lightest pin to the
    /// heaviest. Empty when there is no usable step.
    var pinPositions: [Double] {
        if let weights {
            return Self.distinct(weights.filter { $0 > 0 })
        }
        guard increment > 0, lightestPin <= maxWeight else { return [] }
        let count = Int(((maxWeight - lightestPin) / increment + 0.001).rounded(.down))
        return Self.distinct((0...count).map { lightestPin + Double($0) * increment })
    }

    /// The add-ons that count: positive, and at most `maxAddOns` of them.
    var usableAddOns: [Double] {
        Array(addOns.filter { $0 > 0 }.prefix(Self.maxAddOns))
    }

    /// Every weight the machine can be set to: each pin position plus every combination of
    /// add-ons, ascending, without duplicates.
    func loads() -> [Double] {
        let pins = pinPositions
        let addOns = usableAddOns
        let sums = (0..<(1 << addOns.count)).map { mask in
            addOns.indices.reduce(0.0) { mask & (1 << $1) != 0 ? $0 + addOns[$1] : $0 }
        }
        return Self.distinct(pins.flatMap { pin in sums.map { pin + $0 } })
    }

    /// Ascending and de-duplicated to the gram, so 7 + 2 and 9 are one weight.
    private static func distinct(_ values: [Double]) -> [Double] {
        Array(Set(values.map { ($0 * 1000).rounded() / 1000 })).sorted()
    }
}

// MARK: - Machines with a stack

/// A cable or pin-loaded machine: one or more stacks, and the one it is taken to be set to.
protocol StackMachine {
    var name: String { get }
    var ranges: [WeightStack] { get set }
    var defaultRangeId: String? { get set }
}

extension StackMachine {

    var defaultRange: WeightStack? {
        ranges.first { $0.id == defaultRangeId }
    }

    /// Adds `stack`. The first one becomes the default: a machine with no default stack rounds
    /// nothing.
    mutating func addStack(_ stack: WeightStack) {
        ranges.append(stack)
        if defaultRangeId == nil {
            defaultRangeId = stack.id
        }
    }

    /// Removes the stacks with `ids`. If the default goes with them, the first remaining active
    /// stack takes over (else the first, else none), so the default never names a stack that is
    /// gone.
    mutating func removeStacks(ids: Set<String>) {
        ranges.removeAll { ids.contains($0.id) }
        guard let current = defaultRangeId, ids.contains(current) else { return }
        defaultRangeId = (ranges.first(where: \.isActive) ?? ranges.first)?.id
    }
}

extension PinLoadedMachine: StackMachine { }
extension CableMachine: StackMachine { }

// MARK: - Decoding

extension WeightStack {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The weights stay required: there is no sensible default for one, and a zero would reach
    /// arithmetic that divides by it. An entry without them is skipped by its parent's lossy list.
    /// `addOns` and `weights` arrived with G3 and are optional on the wire.
    enum CodingKeys: String, CodingKey {
        case id, name, minWeight, maxWeight, increment, unit, isActive, addOns, weights
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        minWeight = try container.decode(Double.self, forKey: .minWeight)
        maxWeight = try container.decode(Double.self, forKey: .maxWeight)
        increment = try container.decode(Double.self, forKey: .increment)
        unit = try container.decodeIfPresent(ExerciseWeightUnit.self, forKey: .unit) ?? .kilograms
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        addOns = (try? container.decodeIfPresent([Double].self, forKey: .addOns)) ?? []
        weights = try? container.decodeIfPresent([Double].self, forKey: .weights)
    }
}
