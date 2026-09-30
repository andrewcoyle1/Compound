//
//  SparklineChart.swift
//  DialedIn
//

import SwiftUI

/// A trend line for a summary card: QuickCharts' `ChartThumbnail`, which takes no touches, so the
/// card around it stays one button that opens the full chart.
struct SparklineChart: View {
    let data: [(date: Date, value: Double)]
    var color: Color = .accentColor
    var height: CGFloat = AnalyticsCardChartConfiguration.compact.height

    var body: some View {
        ChartThumbnail(
            data: [TimeSeries(name: "Trend", data: data.map { TimeSeriesDatapoint(date: $0.date, value: $0.value) })],
            style: .line,
            colors: [color],
            height: height
        )
        .accessibilityElement()
        .accessibilityLabel(Text("Trend"))
        .accessibilityValue(accessibilitySummary)
    }

    /// "From 82.3 to 82.7". The card around the chart names the metric and its unit.
    private var accessibilitySummary: String {
        guard let first = data.min(by: { $0.date < $1.date }), let last = data.max(by: { $0.date < $1.date }) else {
            return String(localized: "No data")
        }
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        return String(localized: "From \(first.value.formatted(format)) to \(last.value.formatted(format))")
    }
}

#Preview("Full data") {
    SparklineChart(
        data: (0..<7).map { (date: Date.now.addingTimeInterval(-86_400 * Double(6 - $0)), value: [82.3, 82.1, 82.4, 82.2, 82.6, 82.5, 82.7][$0]) },
        color: Color.Metric.scaleWeight
    )
    .padding()
}

#Preview("Single point") {
    SparklineChart(data: [(date: Date.now, value: 82.5)]).padding()
}

#Preview("Empty") {
    SparklineChart(data: []).padding()
}
