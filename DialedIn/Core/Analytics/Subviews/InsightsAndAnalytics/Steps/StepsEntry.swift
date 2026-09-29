//
//  StepsEntry.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// Represents daily step count for list display.
struct StepsEntry: Identifiable {
    let id: String
    let date: Date
    let steps: Int
}

extension StepsEntry: @MainActor MetricEntry {
    var displayLabel: String {
        "\(date.formatted(.dateTime.day().month().year()))"
    }

    var displayValue: String {
        String(localized: "\(steps.formatted()) steps")
    }

    var systemImageName: String {
        "figure.walk"
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [MetricTimeSeriesPoint(seriesName: "Steps", date: date, value: Double(steps))]
    }
}
