//
//  SetsBarChart.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

/// A simple bar chart showing sets per day (e.g. last 7 days).
/// Each day is one vertical bar; bars are scaled to the max value and use a single color.
/// When slotCount is set, data is padded to that many slots (with 0) so the chart always shows that many bars.
struct SetsBarChart: View {
    var data: [Double]
    /// When set, pads data to this many slots so the chart always shows this many bars (e.g. 7 for "last 7 workouts").
    var slotCount: Int?
    var color: Color = .accentColor

    private let barSpacing = Spacing.xs
    /// A bar is a few points wide, so its corners take the smallest step on the scale.
    private let cornerRadius = Spacing.xxs

    private var displayData: [Double] {
        guard let count = slotCount else { return data }
        if data.count >= count { return Array(data.prefix(count)) }
        return data + Array(repeating: 0.0, count: count - data.count)
    }

    /// Max value across all days for scaling
    private var maxValue: Double {
        displayData.max() ?? 1
    }

    var body: some View {
        GeometryReader { geo in
            let count = displayData.count
            let barWidth = max(Spacing.xs, (geo.size.width - barSpacing * CGFloat(max(0, count - 1))) / CGFloat(max(1, count)))

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(Array(displayData.enumerated()), id: \.offset) { _, value in
                    dayBar(value: value, maxHeight: geo.size.height, barWidth: barWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel(Text("Working sets"))
        .accessibilityValue(accessibilitySummary)
    }

    /// "38 in total, the most in one bar 8". A bar is a day or a workout, depending on the card.
    private var accessibilitySummary: String {
        let total = displayData.reduce(0, +)
        let most = displayData.max() ?? 0
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        return String(localized: "\(total.formatted(format)) in total, the most in one bar \(most.formatted(format))")
    }

    @ViewBuilder
    private func dayBar(value: Double, maxHeight: CGFloat, barWidth: CGFloat) -> some View {
        let barHeight: CGFloat = {
            guard maxValue > 0 else { return 0 }
            if value <= 0 { return Spacing.xs }
            return max(Spacing.xs, maxHeight * (value / maxValue))
        }()

        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if value > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color)
                    .frame(height: max(1, barHeight))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.quaternary)
                    .frame(height: Spacing.xs)
            }
        }
        .frame(width: barWidth, height: maxHeight)
    }
}

#Preview("With data") {
    SetsBarChart(data: [0, 3, 6, 4, 8, 5, 2], color: Color.Metric.muscleGroups)
        .frame(height: 36)
        .padding()
}

#Preview("Empty") {
    SetsBarChart(data: Array(repeating: 0, count: 7), color: Color.Metric.muscleGroups)
        .frame(height: 36)
        .padding()
}

#Preview("3 workouts, 7 slots") {
    SetsBarChart(data: [4, 8, 6], slotCount: 7, color: Color.Metric.workouts)
        .frame(height: 36)
        .padding()
}
