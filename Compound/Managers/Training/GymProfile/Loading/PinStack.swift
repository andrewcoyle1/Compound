//
//  PinStack.swift
//  Compound
//
//  How to make a weight on a stack with add-ons: which pin, and which add-ons to engage. The
//  stack's counterpart to `PlateCalculator`, shown where a bar shows its plates.
//

import Foundation

/// A weight stack with add-ons, in the display unit.
struct PinStack: Equatable {
    /// Where the pin can go, ascending.
    let pins: [Double]
    /// Each add-on's weight, in the order the gym lists them.
    let addOns: [Double]

    struct Breakdown: Equatable {
        let pin: Double
        let addOns: [Double]
    }

    /// The pin and add-ons that make `total`, or nil when nothing does. Uses as few add-ons as
    /// possible, and among equally few the ones listed first, so the answer never changes between
    /// two looks at the same weight: 16 on 7 kg pins with [2, 2] is pin 14 and the first 2.
    func breakdown(total: Double) -> Breakdown? {
        let masks = (0..<(1 << addOns.count)).sorted { ($0.nonzeroBitCount, $0) < ($1.nonzeroBitCount, $1) }
        for mask in masks {
            let engaged = addOns.indices.filter { mask & (1 << $0) != 0 }.map { addOns[$0] }
            let pin = total - engaged.reduce(0, +)
            if let match = pins.first(where: { abs($0 - pin) < WeightStep.epsilon }) {
                return Breakdown(pin: match, addOns: engaged)
            }
        }
        return nil
    }

    /// "Pin 14 + 2 kg", or "Pin 14 kg" when no add-on is needed; nil when the stack cannot make
    /// `total`.
    func summary(total: Double, unit: ExerciseWeightUnit) -> String? {
        guard let breakdown = breakdown(total: total) else { return nil }
        let pin = WeightStepper.format(breakdown.pin)
        guard !breakdown.addOns.isEmpty else {
            return String(localized: "Pin \(pin) \(unit.abbreviation)")
        }
        let addOns = breakdown.addOns.map { WeightStepper.format($0) }.joined(separator: " + ")
        return String(localized: "Pin \(pin) + \(addOns) \(unit.abbreviation)")
    }
}
