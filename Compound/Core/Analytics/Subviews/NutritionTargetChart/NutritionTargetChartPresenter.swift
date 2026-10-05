//
//  NutritionTargetChartPresenter.swift
//  Compound
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

    /// The grid used to assume Monday, whatever the user's own calendar starts on.
    var startOfCurrentWeek: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // Sunday=1
        let daysFromStart = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysFromStart, to: today) ?? today
    }

    var dayAbbrevs: [String] {
        reorderedFromFirstWeekday(Calendar.current.veryShortWeekdaySymbols)
    }

    /// Full weekday names in the grid's day order, for VoiceOver.
    var dayNames: [String] {
        reorderedFromFirstWeekday(Calendar.current.weekdaySymbols)
    }

    /// `symbols` is Sunday-first, as every `Calendar` weekday-symbols array is. Rotates it to start
    /// at `firstWeekday` instead, so a calendar that starts on Sunday or Saturday isn't shown as if
    /// it started on Monday.
    private func reorderedFromFirstWeekday(_ symbols: [String]) -> [String] {
        let startIndex = Calendar.current.firstWeekday - 1 // 0-based
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    /// Today's index in the grid's day order (0 = the first column).
    var todayIndexInWeek: Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date()) // Sunday=1
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    /// The day whose figures the last column shows; nil shows the week's totals. Opens on today.
    private(set) var selectedDayIndex: Int?

    init(
        interactor: NutritionTargetChartInteractor,
        router: NutritionTargetChartRouter
    ) {
        self.interactor = interactor
        self.router = router
        selectedDayIndex = todayIndexInWeek
    }

    /// Tapping a day shows it in the last column; tapping it again goes back to the week.
    func onDayPressed(_ index: Int) {
        selectedDayIndex = selectedDayIndex == index ? nil : index
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.dayPressed(isWeek: selectedDayIndex == nil))
    }

    /// The last column's figures for one metric: the selected day's, or the week's.
    func summary(logged: [Double], targets: [Double]) -> (logged: Double, target: Double) {
        if let selectedDayIndex, logged.indices.contains(selectedDayIndex), targets.indices.contains(selectedDayIndex) {
            return (logged[selectedDayIndex], targets[selectedDayIndex])
        }
        return (logged.reduce(0, +), targets.reduce(0, +))
    }

    func value(for metric: Metric, day: DailyMacroTarget) -> Double {
        switch metric {
        case .calories: return day.calories
        case .protein: return day.proteinGrams
        case .carbs: return day.carbGrams
        case .fats: return day.fatGrams
        }
    }

    /// "15,210 kcal" for calories, "1,150 g" for a macro.
    func amountText(_ value: Double, for metric: Metric) -> String {
        metric == .calories ? Format.kcal(value) : Format.grams(value)
    }

    /// What VoiceOver reads for one day's cell: "48 g of 150 g, over target".
    func cellAccessibilityValue(logged: Double, target: Double, metric: Metric) -> String {
        let amounts = String(localized: "\(amountText(logged, for: metric)) of \(amountText(target, for: metric))")
        guard target > 0, logged > target else { return amounts }
        return String(localized: "\(amounts), over target")
    }

    func loadCurrentWeekLoggedTotals() async {
        let start = startOfCurrentWeek
        var totals: [DailyMacroTarget] = []
        totals.reserveCapacity(Self.daysInWeek)
        for offset in 0..<Self.daysInWeek {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: start) ?? start
            let key = date.dayKey
            // Local read for a chart; a missing day is a gap, so a failure is logged but not shown.
            do {
                totals.append(try interactor.getDailyTotals(dayKey: key))
            } catch {
                interactor.trackEvent(event: Event.loadWeekFail(error: error))
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

        var systemImage: String {
            switch self {
            case .calories: return Symbol.calories
            case .protein: return Symbol.protein
            case .carbs: return Symbol.carbs
            case .fats: return Symbol.fat
            }
        }

        var title: String {
            switch self {
            case .calories: return String(localized: "Calories")
            case .protein: return String(localized: "Protein")
            case .carbs: return String(localized: "Carbs")
            case .fats: return String(localized: "Fat")
            }
        }
        /// The macro colours used everywhere else. This chart had its own, with carbs and fat
        /// swapped and protein in the blue that means calories.
        var colour: Color {
            switch self {
            case .calories: return Macro.cals.colour
            case .protein: return Macro.protein.colour
            case .carbs: return Macro.carbs.colour
            case .fats: return Macro.fat.colour
            }
        }
    }

    enum Event: LoggableEvent {
        case createPlanPressed
        case dayPressed(isWeek: Bool)
        case loadWeekFail(error: Error)

        var eventName: String {
            switch self {
            case .createPlanPressed: return "NutritionTargetChart_CreatePlan_Pressed"
            case .dayPressed: return "NutritionTargetChart_Day_Pressed"
            case .loadWeekFail: return "NutritionTargetChartView_LoadWeek_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .loadWeekFail(let error): return error.eventParameters
            case .dayPressed(let isWeek): return ["is_week": isWeek]
            default: return nil
            }
        }

        var type: LogType {
            switch self {
            case .loadWeekFail: return .warning
            default: return .analytic
            }
        }
    }
}
