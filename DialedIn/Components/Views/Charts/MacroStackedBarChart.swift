//
//  MacroStackedBarChart.swift
//  DialedIn
//
//  Created by Andrew Coyle on 06/02/2026.
//

import SwiftUI

/// A stacked bar chart showing protein, carbs, and fat for each of the last 7 days.
/// Each day is one vertical bar; within each bar, macros are stacked (protein bottom, carbs middle, fat top).
struct MacroStackedBarChart: View {
    var data: [DailyMacroTarget]
    
    private let barSpacing = Spacing.xs
    /// A bar is a few points wide, so its corners take the smallest step on the scale.
    private let cornerRadius = Spacing.xxs
    
    /// Max total grams (protein + carbs + fat) across all days for scaling
    private var maxTotalGrams: Double {
        data.map { $0.proteinGrams + $0.carbGrams + $0.fatGrams }.max() ?? 1
    }
    
    var body: some View {
        GeometryReader { geo in
            let barWidth = max(Spacing.xs, (geo.size.width - barSpacing * CGFloat(data.count - 1)) / CGFloat(max(1, data.count)))
            
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, day in
                    dayBar(day: day, maxHeight: geo.size.height, barWidth: barWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
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
    
    @ViewBuilder
    private func dayBar(day: DailyMacroTarget, maxHeight: CGFloat, barWidth: CGFloat) -> some View {
        let total = day.proteinGrams + day.carbGrams + day.fatGrams
        let barHeight: CGFloat = {
            guard maxTotalGrams > 0 else { return 0 }
            if total <= 0 { return Spacing.xs } // Minimal height for empty days
            return max(Spacing.xs, maxHeight * (total / maxTotalGrams))
        }()
        
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            // Stack order: fat (top), carbs (middle), protein (bottom)
            if total > 0 {
                segment(height: barHeight * (day.fatGrams / total), color: Color.fat)
                segment(height: barHeight * (day.carbGrams / total), color: Color.carbs)
                segment(height: barHeight * (day.proteinGrams / total), color: Color.protein)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.quaternary)
                    .frame(height: Spacing.xs)
            }
        }
        .frame(width: barWidth, height: maxHeight)
    }
    
    private func segment(height: CGFloat, color: Color) -> some View {
        Group {
            if height > 0.5 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color)
                    .frame(height: max(1, height))
            }
        }
    }
}

#Preview("With data") {
    MacroStackedBarChart(data: DailyMacroTarget.mocks)
        .frame(height: 36)
        .padding()
}

#Preview("Empty") {
    MacroStackedBarChart(data: Array(repeating: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0), count: 7))
        .frame(height: 36)
        .padding()
}
