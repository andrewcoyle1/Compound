//
//  Format.swift
//  DialedIn
//

import Foundation

/// Display strings for numbers with units. Locale-aware (`FormatStyle`), never `String(format:)`.
///
/// - The energy unit is always `kcal`, and its label is always "Calories".
/// - A missing value is `Format.placeholder` ("—"), never "--" or "0".
/// - Weight and distance take the stored metric value and the user's unit; the conversion is
///   `UnitConversion`'s.
///
/// Every function takes `locale` for tests; callers leave it at the default.
enum Format {
    /// Shown in place of a missing value.
    static let placeholder = "—"

    /// `"1,850 kcal"`, no decimals.
    static func kcal(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)).locale(locale))) kcal"
    }

    /// `"12 g"`. No decimals from 10 g up; up to one below, so `"2.5 g"` but `"3 g"`.
    static func grams(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String {
        let digits = abs(value) >= 10 ? 0...0 : 0...1
        return "\(value.formatted(.number.precision(.fractionLength(digits)).locale(locale))) g"
    }

    /// `"82.5 kg"` / `"181.9 lb"`, up to one decimal, from a value stored in kilograms.
    static func weight(kg kilograms: Double, unit: ExerciseWeightUnit, locale: Locale = .autoupdatingCurrent) -> String {
        weight(UnitConversion.convertWeight(kilograms, to: unit), isPounds: unit == .pounds, locale: locale)
    }

    /// `"82.5 kg"` / `"181.9 lb"`, up to one decimal, from a value stored in kilograms.
    static func weight(kg kilograms: Double, unit: WeightUnitPreference, locale: Locale = .autoupdatingCurrent) -> String {
        weight(UnitConversion.convertWeight(kilograms, to: unit), isPounds: unit == .pounds, locale: locale)
    }

    private static func weight(_ value: Double, isPounds: Bool, locale: Locale) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))) \(isPounds ? "lb" : "kg")"
    }

    /// `"8 reps"`, `"1 rep"`.
    static func reps(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        count == 1 ? String(localized: "1 rep") : String(localized: "\(count.formatted(.number.locale(locale))) reps")
    }

    /// `"8–12"`, with an en dash.
    static func repRange(_ lower: Int, _ upper: Int, locale: Locale = .autoupdatingCurrent) -> String {
        "\(lower.formatted(.number.locale(locale)))–\(upper.formatted(.number.locale(locale)))"
    }

    /// `"4:30"` under an hour, `"1:05:30"` from an hour up. Fractions of a second are dropped.
    static func duration(_ seconds: TimeInterval, locale: Locale = .autoupdatingCurrent) -> String {
        let whole = Duration.seconds(Int(seconds.rounded(.down)))
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3600 ? .hourMinuteSecond : .minuteSecond
        return whole.formatted(.time(pattern: pattern).locale(locale))
    }

    /// `"5.2 km"` / `"3.2 mi"`, up to one decimal, from a value stored in metres.
    static func distance(meters: Double, unit: DistanceUnitPreference, locale: Locale = .autoupdatingCurrent) -> String {
        let value = unit == .miles ? UnitConversion.metersToMiles(meters) : meters / 1000
        return "\(value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))) \(unit.abbreviation)"
    }

    /// `"45%"` from a fraction (`0.45`), no decimals.
    static func percent(_ fraction: Double, locale: Locale = .autoupdatingCurrent) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}
