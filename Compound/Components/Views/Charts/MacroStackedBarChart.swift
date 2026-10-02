//
//  MacroStackedBarChart.swift
//  Compound
//
//  Created by Andrew Coyle on 06/02/2026.
//

import SwiftUI

/// Protein, carbs and fat stacked in a bar per day, for a summary card: QuickCharts'
/// `ChartThumbnail`, which takes no touches. A day with nothing logged draws as a grey stub.
struct MacroStackedBarChart: View {
    var data: [DailyMacroTarget]

    var body: some View {
        ChartThumbnail(
            data: [
                TimeSeries.slots(String(localized: "Protein"), data.map(\.proteinGrams)),
                TimeSeries.slots(String(localized: "Carbs"), data.map(\.carbGrams)),
                TimeSeries.slots(String(localized: "Fat"), data.map(\.fatGrams))
            ],
            style: .bars,
            colors: [.protein, .carbs, .fat]
        )
        .accessibilityElement()
        .accessibilityLabel(Text("Macros, last \(data.count) days"))
        .accessibilityValue(accessibilitySummary)
    }

    /// "Daily average: protein 140 g, carbs 210 g, fat 70 g".
    private var accessibilitySummary: String {
        guard !data.isEmpty else { return Format.placeholder }
        let count = Double(data.count)
        let protein = Format.grams(data.map(\.proteinGrams).reduce(0, +) / count)
        let carbs = Format.grams(data.map(\.carbGrams).reduce(0, +) / count)
        let fat = Format.grams(data.map(\.fatGrams).reduce(0, +) / count)
        return String(localized: "Daily average: protein \(protein), carbs \(carbs), fat \(fat)")
    }
}

#Preview("With data") {
    MacroStackedBarChart(data: DailyMacroTarget.mocks).padding()
}

#Preview("Empty") {
    MacroStackedBarChart(data: Array(repeating: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0), count: 7))
        .padding()
}
