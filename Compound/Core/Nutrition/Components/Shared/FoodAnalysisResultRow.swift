//
//  FoodAnalysisResultRow.swift
//  Compound
//

import SwiftUI

/// One food the AI found in a photo or a description: its name, amount and macros, with a button
/// that adds it to the plate. Shared by the photo scanner and the meal describer.
struct FoodAnalysisResultRow: View {
    let item: FoodAnalysisItem
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.name)
                    .font(.rowTitle)
                Text(Format.grams(item.amountGrams))
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                MacroChips(calories: item.calories, protein: item.proteinGrams, carbs: item.carbGrams, fat: item.fatGrams)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onAdd) {
                Label("Add", systemImage: Symbol.add)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text("Add \(item.name)"))
        }
        .padding(.vertical, Spacing.xs)
    }
}

/// The AI results' section header, with Add All: every result onto the plate at its estimate in
/// one tap, rather than a tap and a confirm per row.
struct AIEstimateHeader: View {
    let count: Int
    let isAdded: Bool
    let onAddAll: () -> Void

    var body: some View {
        HStack {
            Text("AI Estimate")
            Spacer()
            Button(action: onAddAll) {
                if isAdded {
                    Label("Added", systemImage: "checkmark")
                } else {
                    Text("Add All (\(count))")
                }
            }
            .disabled(isAdded)
            .textCase(nil)
        }
    }
}
