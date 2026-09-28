//
//  Double+EXT.swift
//  DialedIn
//

import Foundation

// A `Double` that is not finite is not merely a wrong number — it is a crash. `Int(_:)` traps on
// NaN and on either infinity, and most of the conversions in this app run inside a SwiftUI view
// body, so the app goes down as the screen draws rather than printing something odd.
//
// The reflex that keeps being reached for is `max(value, floor)`, and it does not work. Swift's
// `max` is `y >= x ? y : x`, and every comparison against NaN is false, so `max(.nan, 30)` returns
// `.nan` rather than the floor. It also leaves the top open, so an infinity is already above the
// floor and passes straight through. Six crashes of exactly this shape have been fixed; these two
// helpers exist so the seventh cannot be written.

extension Double {

    /// The value held inside `range`, with anything that is not a usable number replaced.
    ///
    /// Use this wherever a figure read off a stored document reaches arithmetic that must not
    /// produce a non-finite result — body weight and height being the recurring examples, since
    /// they arrive from Firestore as plain `Double`s and a corrupt or half-written profile can
    /// carry a NaN or an infinity.
    ///
    /// Unlike a one-sided `max(_:_:)`, this filters NaN (via `isFinite`) and closes the top end.
    ///
    /// - Parameters:
    ///   - range: the bounds the arithmetic downstream is known to survive.
    ///   - fallback: what to read instead when the value is NaN or infinite. Callers that have no
    ///     better default pass `range.lowerBound`.
    func clamped(to range: ClosedRange<Double>, whenNotFinite fallback: Double) -> Double {
        guard isFinite else { return fallback }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    /// A number typed into a decimal text field, as something the arithmetic can survive.
    ///
    /// A text field is the shortest route a non-finite number has into the app: `Double`'s string
    /// initialiser parses `"nan"`, `"inf"` and `"-inf"` literally, and `"1e400"` overflows to
    /// infinity. Every screen that takes an amount or a count feeds it into nutrient arithmetic
    /// that is both printed through `Int(_:)` and written to the meal log, so an unsanitised parse
    /// crashes the screen and persists nonsense.
    ///
    /// Anything that is not a usable number reads as zero, which is what an empty field already
    /// reads as, so every one of these screens already refuses to submit on it. The ceiling is far
    /// above any real portion or serving count and is only there so a finite but absurd figure
    /// cannot multiply a nutrient up to infinity.
    static func enteredAmount(_ text: String) -> Double {
        (typed(text) ?? 0).clamped(to: 0...maximumEnteredAmount, whenNotFinite: 0)
    }

    /// A number as a person types it, which `Double`'s own initialiser does not read.
    ///
    /// The decimal pad offers only the region's separator, so in most of Europe and South America
    /// "1,5" is the only way to type one and a half. `Double("1,5")` is nil, which every amount
    /// field read as zero and so refused to submit. Digits in other scripts failed the same way.
    /// Both the region's separator and a full stop are read as the decimal point; a grouped
    /// figure such as "1,234.5" is still rejected rather than guessed at.
    static func typed(_ text: String, locale: Locale = .current) -> Double? {
        let separator = locale.decimalSeparator ?? "."
        let ascii = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: separator, with: ".")
            .replacingOccurrences(of: ",", with: ".")
            .map { $0.wholeNumberValue.map(String.init) ?? String($0) }
            .joined()
        guard let value = Double(ascii), value.isFinite else { return nil }
        return value
    }

    /// One tonne of food, or a million servings. Nothing legitimate comes near it.
    private static let maximumEnteredAmount: Double = 1_000_000
}
