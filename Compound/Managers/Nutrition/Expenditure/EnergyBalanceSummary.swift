//
//  EnergyBalanceSummary.swift
//  Compound
//

import Foundation

/// The energy-balance figures the Progress cards and the Energy Balance screen share: what the
/// body spent on a day, and how a week's eating compares with it.
///
/// Expenditure is the adaptive estimate (`ExpenditureEngine`), not the static formula; intake is
/// averaged over the days that were logged, never divided by seven regardless. A day with nothing
/// logged is a day we know nothing about, not a day of eating nothing.
enum EnergyBalanceSummary {

    /// Each day's expenditure: the engine's estimate for that day where it has one (which is the
    /// formula while it calibrates), the last estimate after its history stops (a logging break
    /// freezes it there), and the formula before it starts.
    static func expenditureLookup(
        history: [ExpenditureEstimate],
        formulaKcal: Double,
        calendar: Calendar
    ) -> (Date) -> Double {
        let byDay = Dictionary(
            history.map { (calendar.startOfDay(for: $0.day), $0.kcal) },
            uniquingKeysWith: { _, later in later }
        )
        let last = history.last.map { (day: calendar.startOfDay(for: $0.day), kcal: $0.kcal) }
        return { date in
            let day = calendar.startOfDay(for: date)
            if let kcal = byDay[day] { return kcal }
            if let last, day > last.day { return last.kcal }
            return formulaKcal
        }
    }

    /// Today's expenditure: the latest estimate, or the formula with no history.
    static func currentExpenditure(history: [ExpenditureEstimate], formulaKcal: Double) -> Double {
        history.last?.kcal ?? formulaKcal
    }

    /// Mean intake over the logged days (any calories at all) and how many there were, or nil when
    /// none was logged.
    static func loggedAverage(_ dailyCalories: [Double]) -> (meanKcal: Double, days: Int)? {
        let logged = dailyCalories.filter { $0 > 0 }
        guard !logged.isEmpty else { return nil }
        return (logged.reduce(0, +) / Double(logged.count), logged.count)
    }

    /// "350 kcal deficit", "120 kcal surplus" or "Balanced".
    static func balanceText(expenditureKcal: Double, intakeKcal: Double) -> String {
        let value = Int((expenditureKcal - intakeKcal).rounded())
        if value > 0 {
            return String(localized: "\(value.formatted()) kcal deficit")
        } else if value < 0 {
            return String(localized: "\((-value).formatted()) kcal surplus")
        }
        return String(localized: "Balanced")
    }

    /// "Last 7 Days · 5 logged": the count the average was taken over.
    static func loggedDaysSubtitle(days: Int?) -> String {
        guard let days else { return String(localized: "Last 7 Days") }
        return String(localized: "Last 7 Days \u{00B7} \(days) logged")
    }
}
