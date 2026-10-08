//
//  Format.swift
//  Compound
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

    /// `"16.9 g"`, `"120 mg"`: up to one decimal at any size, for nutrition labels and nutrient
    /// tables, which keep the precision the label printed. Elsewhere use `grams(_:)`.
    static func nutrient(_ value: Double, unit: String = "g", locale: Locale = .autoupdatingCurrent) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))) \(unit)"
    }

    /// `"82.5 kg"` / `"181.9 lb"`, up to one decimal, from a value stored in kilograms.
    static func weight(kg kilograms: Double, unit: ExerciseWeightUnit, locale: Locale = .autoupdatingCurrent) -> String {
        weight(UnitConversion.convertWeight(kilograms, to: unit), isPounds: unit == .pounds, locale: locale)
    }

    /// `"82.5 kg"` / `"181.9 lb"`, up to one decimal, from a value stored in kilograms.
    /// A weekly rate passes `maximumFractionDigits: 2`, because at one decimal 0.25 kg reads "0.2 kg".
    static func weight(
        kg kilograms: Double,
        unit: WeightUnitPreference,
        maximumFractionDigits: Int = 1,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        weight(
            UnitConversion.convertWeight(kilograms, to: unit),
            isPounds: unit == .pounds,
            maximumFractionDigits: maximumFractionDigits,
            locale: locale
        )
    }

    private static func weight(_ value: Double, isPounds: Bool, maximumFractionDigits: Int = 1, locale: Locale) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...maximumFractionDigits)).locale(locale))) \(isPounds ? "lb" : "kg")"
    }

    /// A set's load: `"60 kg + Red"`, `"Red + Blue"`, `"60 kg"`, from its weight already formatted
    /// (with or without the unit, spoken or written) and the bands on the set (`WorkoutSetModel.bands`).
    /// `nil` with neither. The one place a set's bands are joined to its weight.
    static func load(_ weight: String?, bands: [String]?) -> String? {
        let parts = [weight].compactMap { $0 } + (bands ?? [])
        return parts.isEmpty ? nil : parts.joined(separator: " + ")
    }

    /// `"8 reps"`, `"1 rep"`.
    static func reps(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        count == 1 ? String(localized: "1 rep") : String(localized: "\(count.formatted(.number.locale(locale))) reps")
    }

    /// `"1 set"`, `"12 sets"`, `"2.5 sets"`. Up to one decimal, since a muscle an exercise only
    /// assists earns half a set. Whole counts use the catalog's plural variations for `%lld sets`;
    /// a fractional count is always plural.
    static func sets(_ count: Double, locale: Locale = .autoupdatingCurrent) -> String {
        let rounded = (count * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(localized: "\(Int(rounded)) sets", locale: locale)
        }
        return String(localized: "\(rounded.formatted(.number.precision(.fractionLength(0...1)).locale(locale))) sets", locale: locale)
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

    /// `"400 m"` / `"3.11 mi"` from a value stored in metres, in the unit one exercise is logged in.
    /// Metres take no decimals; miles up to two, so a quarter-mile reads `"0.25 mi"`.
    ///
    /// Its own label because `.miles` is a case of both distance enums, so `unit:` would be ambiguous.
    static func distance(meters: Double, exerciseUnit unit: ExerciseDistanceUnit, locale: Locale = .autoupdatingCurrent) -> String {
        let digits = unit == .miles ? 0...2 : 0...0
        let value = UnitConversion.convertDistance(meters, to: unit)
        return "\(value.formatted(.number.precision(.fractionLength(digits)).locale(locale))) \(unit.abbreviation)"
    }

    /// `"45%"` from a fraction (`0.45`), no decimals.
    static func percent(_ fraction: Double, locale: Locale = .autoupdatingCurrent) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}
