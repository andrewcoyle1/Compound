//
//  EnergyBalanceEntry.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// Represents a daily energy balance for list display.
struct EnergyBalanceEntry: Identifiable {
    let id: String
    let date: Date
    let expenditure: Double
    let intake: Double

    var balance: Double { expenditure - intake }

    var balanceLabel: String {
        let value = Int(balance.rounded())
        if value > 0 {
            return String(localized: "\(String(describing: value)) deficit")
        } else if value < 0 {
            return String(localized: "\(String(describing: -value)) surplus")
        }
        return String(localized: "Balanced")
    }
}

extension EnergyBalanceEntry: @MainActor MetricEntry {
    var displayLabel: String {
        "\(date.formatted(.dateTime.day().month().year()))"
    }

    var displayValue: String {
        balanceLabel
    }

    var systemImageName: String {
        balance >= 0 ? "flame.fill" : "plus.circle.fill"
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [
            MetricTimeSeriesPoint(seriesName: "Expenditure", date: date, value: expenditure),
            MetricTimeSeriesPoint(seriesName: "Intake", date: date, value: intake)
        ]
    }
}
