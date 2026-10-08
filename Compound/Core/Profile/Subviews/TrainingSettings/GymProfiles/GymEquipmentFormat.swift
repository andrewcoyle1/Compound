//
//  GymEquipmentFormat.swift
//  Compound
//

import Foundation

/// Equipment weights as the gym profile stores them: in the unit they were entered in, with only
/// the decimals they need ("1.25 kg", "20 kg"). `Format.weight` converts from kilograms and keeps
/// at most one decimal, which would show a 1.25 kg plate as "1.3 kg".
enum GymEquipmentFormat {

    static func weight(_ value: Double, _ unit: ExerciseWeightUnit, locale: Locale = .autoupdatingCurrent) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))) \(unit.abbreviation)"
    }

    /// `"5–100 kg, 2.5 kg increments"`.
    static func range(min: Double, max: Double, increment: Double, unit: ExerciseWeightUnit, locale: Locale = .autoupdatingCurrent) -> String {
        let bounds = "\(min.formatted(.number.precision(.fractionLength(0...2)).locale(locale)))–\(weight(max, unit, locale: locale))"
        return String(localized: "\(bounds), \(weight(increment, unit, locale: locale)) increments")
    }

    /// A stack on one line: `"5–300 lb, 5 lb increments · +2, +2"`, or `"Uneven · 12 weights"`.
    static func stack(_ stack: WeightStack, locale: Locale = .autoupdatingCurrent) -> String {
        let pins = stack.weights == nil
            ? range(min: stack.lightestPin, max: stack.maxWeight, increment: stack.increment, unit: stack.unit, locale: locale)
            : String(localized: "Uneven · \(stack.pinPositions.count) weights")
        guard !stack.addOns.isEmpty else { return pins }
        let addOns = stack.addOns.map { "+" + $0.formatted(.number.precision(.fractionLength(0...2)).locale(locale)) }
        return "\(pins) · \(addOns.joined(separator: ", "))"
    }
}
