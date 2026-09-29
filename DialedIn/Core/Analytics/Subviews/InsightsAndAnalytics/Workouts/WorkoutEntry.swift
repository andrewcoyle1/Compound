//
//  WorkoutEntry.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// Represents a completed workout session for list display.
struct WorkoutEntry: Identifiable {
    let id: String
    let date: Date
    let name: String
    let sets: Int
    let volumeKg: Double
}

extension WorkoutEntry: @MainActor MetricEntry {
    var displayLabel: String {
        "\(date.formatted(.dateTime.day().month().year()))"
    }

    var displayValue: String {
        if volumeKg > 0 {
            return String(localized: "\(String(describing: sets)) sets · \(volumeKg.formatted(.number.precision(.fractionLength(1)))) kg")
        }
        return String(localized: "\(sets) sets")
    }

    var systemImageName: String {
        "dumbbell.fill"
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [MetricTimeSeriesPoint(seriesName: "Sets", date: date, value: Double(sets))]
    }
}
