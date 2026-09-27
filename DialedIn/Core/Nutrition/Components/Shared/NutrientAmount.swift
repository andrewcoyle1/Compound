//
//  NutrientAmount.swift
//  DialedIn
//

import SwiftUI

/// A named nutrient quantity for display, such as "Sodium, 120 mg". A nil value means the food
/// does not say.
struct NutrientAmount {
    let name: String
    let value: Double?
    let unit: String

    /// The value in its unit, or `Format.placeholder` when there is none.
    var formattedValue: String {
        value.map { Self.format($0, unit: unit) } ?? Format.placeholder
    }

    /// Grams and kcal go through `Format`; mg and mcg get the same 0–1 decimals as grams.
    /// `Format` has no general amount-with-unit function, so this fills that gap for nutrients.
    static func format(_ value: Double, unit: String) -> String {
        switch unit {
        case "g": return Format.grams(value)
        case "kcal": return Format.kcal(value)
        default: return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
        }
    }
}

/// A calories and macros summary as `LabeledContent` rows, for the amount sheets. Nil shows
/// `Format.placeholder`.
struct EstimatedMacrosSection: View {
    let title: LocalizedStringKey
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?

    var body: some View {
        Section(title) {
            LabeledContent("Calories", value: calories.map { Format.kcal($0) } ?? Format.placeholder)
            LabeledContent("Protein", value: protein.map { Format.grams($0) } ?? Format.placeholder)
            LabeledContent("Carbs", value: carbs.map { Format.grams($0) } ?? Format.placeholder)
            LabeledContent("Fat", value: fat.map { Format.grams($0) } ?? Format.placeholder)
        }
        .monospacedDigit()
    }
}
