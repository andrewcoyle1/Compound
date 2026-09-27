//
//  MealItemModel+Display.swift
//  DialedIn
//

import Foundation

extension MealItemModel {

    /// "412 kcal · 31 g P · 12 g F · 42 g C", through `Format`.
    var macroSummary: String {
        [
            Format.kcal(calories ?? 0),
            String(localized: "\(Format.grams(proteinGrams ?? 0)) P"),
            String(localized: "\(Format.grams(fatGrams ?? 0)) F"),
            String(localized: "\(Format.grams(carbGrams ?? 0)) C")
        ].joined(separator: " · ")
    }

    /// The logged amount in its own unit, "150 g" or "1.5 serving".
    var formattedAmount: String {
        "\(amount.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
    }
}
