//
//  MacroChips.swift
//  DialedIn
//

import SwiftUI

/// A food's calories and macros as a wrapping row of `Chip`s, each in its macro colour with its
/// symbol, so the colour is never the only cue. A nil value leaves its chip out.
///
/// Replaces the three private `macroChip` helpers the meal describer, photo scanner and barcode
/// scanner each carried (one of which drew protein blue).
struct MacroChips: View {
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?

    var body: some View {
        FlowLayout(spacing: Spacing.xs) {
            chip(.cals, value: calories.map { Format.kcal($0) }, symbol: Symbol.calories)
            chip(.protein, value: protein.map { Format.grams($0) }, symbol: Symbol.protein)
            chip(.carbs, value: carbs.map { Format.grams($0) }, symbol: Symbol.carbs)
            chip(.fat, value: fat.map { Format.grams($0) }, symbol: Symbol.fat)
        }
    }

    @ViewBuilder
    private func chip(_ macro: Macro, value: String?, symbol: String) -> some View {
        if let value {
            Chip(value, systemImage: symbol, tint: macro.colour)
                .accessibilityLabel(Text(verbatim: "\(macro.title), \(value)"))
        }
    }
}

#Preview {
    List {
        MacroChips(calories: 412, protein: 31.5, carbs: 42, fat: 12.2)
        MacroChips(calories: 90, protein: 2)
    }
}
