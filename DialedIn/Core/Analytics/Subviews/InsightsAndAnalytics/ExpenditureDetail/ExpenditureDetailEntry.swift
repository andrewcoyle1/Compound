//
//  ExpenditureDetailEntry.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// Represents daily energy expenditure (TDEE) for list display.
struct ExpenditureDetailEntry: Identifiable {
    let id: String
    let date: Date
    let expenditure: Double
}

extension ExpenditureDetailEntry: @MainActor MetricEntry {
    var displayLabel: String {
        "\(date.formatted(.dateTime.day().month().year()))"
    }

    var displayValue: String {
        String(localized: "\(String(describing: Int(expenditure.rounded()))) kcal")
    }

    var systemImageName: String {
        "flame.fill"
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [MetricTimeSeriesPoint(seriesName: "Expenditure", date: date, value: expenditure)]
    }
}
