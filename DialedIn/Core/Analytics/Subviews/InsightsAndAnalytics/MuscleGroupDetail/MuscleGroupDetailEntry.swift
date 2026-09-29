//
//  MuscleGroupDetailEntry.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// Represents daily completed sets for a specific muscle group for list display.
struct MuscleGroupDetailEntry: Identifiable {
    let id: String
    let date: Date
    let sets: Double
}

extension MuscleGroupDetailEntry: @MainActor MetricEntry {
    var displayLabel: String {
        "\(date.formatted(.dateTime.day().month().year()))"
    }

    var displayValue: String {
        String(localized: "\(sets.formatted(.number.precision(.fractionLength(0...1)))) sets")
    }

    var systemImageName: String {
        "dumbbell.fill"
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [MetricTimeSeriesPoint(seriesName: "Sets", date: date, value: sets)]
    }
}
