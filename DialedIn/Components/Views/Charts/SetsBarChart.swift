//
//  SetsBarChart.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

/// Sets per day (or per workout) as bars, for a summary card: QuickCharts' `ChartThumbnail`, which
/// takes no touches. When `slotCount` is set the data is padded with zeroes to that many bars, and
/// a zero draws as a grey stub, so the card always shows the same number of slots.
struct SetsBarChart: View {
    var data: [Double]
    var slotCount: Int?
    var color: Color = .accentColor

    private var displayData: [Double] {
        guard let count = slotCount else { return data }
        if data.count >= count { return Array(data.prefix(count)) }
        return data + Array(repeating: 0.0, count: count - data.count)
    }

    var body: some View {
        ChartThumbnail(data: [TimeSeries.slots("Sets", displayData)], style: .bars, colors: [color])
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
}

extension TimeSeries {

    /// Values that belong to consecutive slots rather than dates (the last seven days, or the last
    /// seven workouts), laid out one day apart and ending today, so a thumbnail draws them in order.
    static func slots(_ name: String, _ values: [Double]) -> TimeSeries {
        let today = Calendar.current.startOfDay(for: .now)
        return TimeSeries(name: name, data: values.enumerated().map { index, value in
            TimeSeriesDatapoint(
                id: "\(name)-\(index)",
                date: Calendar.current.date(byAdding: .day, value: index - values.count + 1, to: today) ?? today,
                value: value
            )
        })
    }
}

#Preview("With data") {
    SetsBarChart(data: [0, 3, 6, 4, 8, 5, 2], color: Color.Metric.muscleGroups).padding()
}

#Preview("Empty") {
    SetsBarChart(data: Array(repeating: 0, count: 7), color: Color.Metric.muscleGroups).padding()
}

#Preview("3 workouts, 7 slots") {
    SetsBarChart(data: [4, 8, 6], slotCount: 7, color: Color.Metric.workouts).padding()
}
