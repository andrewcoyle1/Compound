//
//  TimeSeries+Mocks.swift
//  Compound
//
//  Created by Andrew Coyle on 05/02/2026.
//

import SwiftUI

/// Preview data for `EnergyBalanceChart`, the last chart drawn here rather than by QuickCharts.
/// `TimeSeries` itself, and its `mock(…)`, come from the package (see `QuickCharts+Alias.swift`),
/// which is what the other charts' previews use. The `lastYear` and `last6Years` series that lived
/// here went with the charts that showed them.
extension TimeSeries {
    /// A fortnight around today, waving up a gentle trend.
    static let last14Days: TimeSeries = {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let data = (0..<14).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
            let wave = sin(Double(dayOffset) / 14.0) * 18
            let value = max(0, 85 + wave + Double(dayOffset) * 4)
            return TimeSeriesDatapoint(date: date, value: value)
        }
        return TimeSeries(name: "Bench Press", data: data)
    }()
}
