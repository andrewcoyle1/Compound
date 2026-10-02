//
//  WeightTrendEntry.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// Represents a weight trend (EWMA) value at a date for list display.
/// Holds the original entry id for deletion (clearing the underlying scale weight).
struct WeightTrendEntry: Identifiable {
    let id: String
    let date: Date
    let trendValue: Double
}

extension WeightTrendEntry: @MainActor MetricEntry {
    var displayLabel: String {
        "\(date.formatted(.dateTime.day().month().year()))"
    }

    var displayValue: String {
        trendValue.formatted(.number.precision(.fractionLength(1)))
    }

    var systemImageName: String {
        "chart.line.uptrend.xyaxis"
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [MetricTimeSeriesPoint(seriesName: "Trend Weight", date: date, value: trendValue)]
    }
}
