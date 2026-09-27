//
//  MealItemModel+Display.swift
//  DialedIn
//

import Foundation

extension MealItemModel {

    /// "412 kcal · 31 g P · 12 g F · 42 g C", through `Format`.
    var macroSummary: String {
        detail()
    }

    /// The item's second line: calories, macros and amount, each only when asked for, separated by
    /// middle dots.
    func detail(showsCalories: Bool = true, showsMacros: Bool = true, showsAmount: Bool = false) -> String {
        var parts: [String] = []
        if showsCalories {
            parts.append(Format.kcal(calories ?? 0))
        }
        if showsMacros {
            parts.append(String(localized: "\(Format.grams(proteinGrams ?? 0)) P"))
            parts.append(String(localized: "\(Format.grams(fatGrams ?? 0)) F"))
            parts.append(String(localized: "\(Format.grams(carbGrams ?? 0)) C"))
        }
        if showsAmount {
            parts.append(formattedAmount)
        }
        return parts.joined(separator: " · ")
    }

    /// The logged amount in its own unit, "150 g" or "1.5 serving".
    var formattedAmount: String {
        "\(amount.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
    }
}
