//
//  NutritionTargetChartPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

@Observable
@MainActor
class NutritionTargetChartPresenter {
    private let interactor: NutritionTargetChartInteractor
    private let router: NutritionTargetChartRouter

    /// The grid is a Monday-start week, so both rows it draws have to be exactly this long.
    static let daysInWeek = 7

    /// What was actually eaten each day this week, or nil until the week has been read.
    ///
    /// This used to start as seven zeroed days. Zero logged and nothing logged are not the same
    /// claim: the first says the user ate nothing on Monday, the second only says we have not
    /// looked yet. The grid waits rather than making the stronger claim on the user's behalf.
    private(set) var loggedDays: [DailyMacroTarget]?

    /// The user's own seven daily targets, or nil when there is no plan to draw.
    ///
    /// This used to fall back to `Array(repeating: .mock, count: 7)` — preview scaffolding
    /// rendered identically to a real plan. In a nutrition app people act on these numbers, so an
    /// invented target is worse than no target: nothing on screen marks it as unreal.
    ///
    /// A plan of any other length cannot be laid over a seven-column Monday-start week without
    /// assigning somebody's Tuesday target to their Friday, so it is treated as no plan too.
    /// Every path that builds a plan produces exactly seven days, so this only catches a
    /// malformed stored document.
    var planDays: [DailyMacroTarget]? {
        guard let days = interactor.currentDietPlan?.days, days.count == Self.daysInWeek else {
            return nil
        }
        return days
    }

    var mondayStartOfCurrentWeek: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // Sunday=1
        let daysFromMonday = (weekday + 5) % 7 // Monday=0 .. Sunday=6
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
    }

    var dayAbbrevs: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols // [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
        // Reorder to start with Monday: [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
        // Safe: a calendar always has seven weekday symbols.
        return Array(symbols[1...] + [symbols[0]])
    }

    // Monday-start day index for today (Mon=0 .. Sun=6)
    var todayIndexMondayStart: Int {
        let weekday = Calendar.current.component(.weekday, from: Date()) // Sunday=1
        return (weekday + 5) % 7
    }

    init(
        interactor: NutritionTargetChartInteractor,
        router: NutritionTargetChartRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    func value(for metric: Metric, day: DailyMacroTarget) -> Double {
        switch metric {
        case .calories: return day.calories
        case .protein: return day.proteinGrams
        case .carbs: return day.carbGrams
        case .fats: return day.fatGrams
        }
    }

    func unit(for metric: Metric) -> String {
        switch metric {
        case .calories: return "kcal"
        default: return "g"
        }
    }

    func loadCurrentWeekLoggedTotals() async {
        let start = mondayStartOfCurrentWeek
        var totals: [DailyMacroTarget] = []
        totals.reserveCapacity(Self.daysInWeek)
        for offset in 0..<Self.daysInWeek {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: start) ?? start
            let key = date.dayKey
            // Silent: local read for a chart; a missing day is a gap.
            if let dayTotals = try? interactor.getDailyTotals(dayKey: key) {
                totals.append(dayTotals)
            } else {
                totals.append(DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
            }
        }
        loggedDays = totals
    }

    func onCreatePlanPressed() {
        interactor.trackEvent(event: Event.createPlanPressed)
        router.showPreferredDietView(isFromSettings: true)
    }

    enum Metric: String, CaseIterable, Hashable {
        case calories = "Calories"
        case protein = "Protein"
        case carbs = "Carbohydrates"
        case fats = "Fats"

        var initial: String {
            switch self {
            case .calories:
                return "Cal"
            case .protein:
                return "P"
            case .carbs:
                return "C"
            case .fats:
                return "F"
            }
        }
        var colour: Color {
            switch self {
            case .calories: return .red
            case .protein: return .blue
            case .carbs: return .yellow
            case .fats: return .green
            }
        }
    }

    enum Event: LoggableEvent {
        case createPlanPressed

        var eventName: String {
            switch self {
            case .createPlanPressed: return "NutritionTargetChart_CreatePlan_Pressed"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
