//
//  ExerciseDetailEntry.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// Represents daily estimated 1-RM for a specific exercise for list display.
struct ExerciseDetailEntry: Identifiable {
    let id: String
    let date: Date
    let oneRMKg: Double
}

extension ExerciseDetailEntry: @MainActor MetricEntry {
    var displayLabel: String {
        "\(date.formatted(.dateTime.day().month().year()))"
    }

    /// The unit is rendered separately by `MetricDetailView` from the configuration, and the
    /// value is converted to the exercise's own unit by the presenter — so this carries neither.
    var displayValue: String {
        oneRMKg.formatted(.number.precision(.fractionLength(1)))
    }

    var systemImageName: String {
        "dumbbell.fill"
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [MetricTimeSeriesPoint(seriesName: "1-RM", date: date, value: oneRMKg)]
    }
}
