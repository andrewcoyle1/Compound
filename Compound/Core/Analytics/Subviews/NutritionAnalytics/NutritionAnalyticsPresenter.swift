import SwiftUI

@Observable
@MainActor
class NutritionAnalyticsPresenter {
    
    private let interactor: NutritionAnalyticsInteractor
    private let router: NutritionAnalyticsRouter
    private let calendar = Calendar.current
    
    var selectedDate: Date = Date()
    private(set) var dailyTotals: DailyMacroTarget?
    private(set) var dailyTarget: DailyMacroTarget?
    private(set) var dailyBreakdown: DailyNutritionBreakdown?
    private(set) var macrosLast7Days: [DailyMacroTarget] = []
    
    init(interactor: NutritionAnalyticsInteractor, router: NutritionAnalyticsRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    var dayKey: String {
        selectedDate.dayKey
    }
    
    func loadData() async {
        // Load today's totals
        do {
            dailyTotals = try interactor.getDailyTotals(dayKey: dayKey)
        } catch {
            dailyTotals = nil
        }
        
        // Load today's target (if user has diet plan)
        if let userId = interactor.userId {
            do {
                dailyTarget = try await interactor.getDailyTarget(for: selectedDate, userId: userId)
            } catch {
                dailyTarget = nil
            }
        } else {
            dailyTarget = nil
        }
        
        // Load last 7 days for macros chart
        loadMacrosLast7Days()
        
        // Load detailed nutrition breakdown (from meal items + ingredient templates)
        do {
            dailyBreakdown = try interactor.getDailyNutritionBreakdown(dayKey: dayKey)
        } catch {
            dailyBreakdown = nil
        }
    }
    
    private func loadMacrosLast7Days() {
        let startOfSelected = calendar.startOfDay(for: selectedDate)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfSelected) else { return }
        
        var totals: [DailyMacroTarget] = []
        totals.reserveCapacity(7)
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let key = date.dayKey
            do {
                let dayTotals = try interactor.getDailyTotals(dayKey: key)
                totals.append(dayTotals)
            } catch {
                totals.append(DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
            }
        }
        macrosLast7Days = totals
    }
    
    // MARK: - Chart values (current, target, max for MacroProgressChart)
    
    var caloriesCurrent: Double { dailyTotals?.calories ?? 0 }
    var caloriesTarget: Double? { dailyTarget?.calories }
    var caloriesMax: Double {
        let target = dailyTarget?.calories ?? 2000
        return max(caloriesCurrent, target * 1.2)
    }
    
    var proteinCurrent: Double { dailyTotals?.proteinGrams ?? 0 }
    var proteinTarget: Double? { dailyTarget?.proteinGrams }
    var proteinMax: Double {
        let target = dailyTarget?.proteinGrams ?? 150
        return max(proteinCurrent, target * 1.2)
    }
    
    var fatCurrent: Double { dailyTotals?.fatGrams ?? 0 }
    var fatTarget: Double? { dailyTarget?.fatGrams }
    var fatMax: Double {
        let target = dailyTarget?.fatGrams ?? 80
        return max(fatCurrent, target * 1.2)
    }
    
    var carbsCurrent: Double { dailyTotals?.carbGrams ?? 0 }
    var carbsTarget: Double? { dailyTarget?.carbGrams }
    var carbsMax: Double {
        let target = dailyTarget?.carbGrams ?? 250
        return max(carbsCurrent, target * 1.2)
    }
    
    /// Average daily calories over last 7 days (the Macros card's value)
    var macrosAverageCalories: Double {
        guard !macrosLast7Days.isEmpty else { return 0 }
        return macrosLast7Days.map(\.calories).reduce(0, +) / Double(macrosLast7Days.count)
    }
    
    // MARK: - Breakdown helpers (for cards without targets)
    
    func formatBreakdown(_ value: Double?, unit: String) -> String {
        // `isFinite` as well as `> 0`: this runs from the view body and an amount of 100 or more
        // is printed through `Int(_:)`, which traps on an infinity. A NaN was already caught, but
        // only by accident — `.nan > 0` is false, as every comparison against NaN is. Nothing can
        // log a non-finite nutrient any more, but meals written before that was true can still be
        // read back, and the breakdown reads whatever the document holds.
        guard let value, value.isFinite, value > 0 else { return Format.placeholder }
        if value >= 100 || value == floor(value) {
            return Int(value).formatted()
        }
        return value.formatted(.number.precision(.fractionLength(1)))
    }
    
    func breakdownChartMax(current: Double?, defaultMax: Double) -> Double {
        let curr = current ?? 0
        return max(curr * 1.2, defaultMax)
    }

    // MARK: - Navigation

    func onMacrosPressed(themeColor: Color?) {
        router.showNutritionMetricDetailView(metric: .macros, delegate: NutritionMetricDetailDelegate(), themeColor: themeColor)
    }

    func onCaloriesPressed(themeColor: Color?) {
        router.showNutritionMetricDetailView(metric: .calories, delegate: NutritionMetricDetailDelegate(), themeColor: themeColor)
    }

    func onProteinPressed(themeColor: Color?) {
        router.showNutritionMetricDetailView(metric: .protein, delegate: NutritionMetricDetailDelegate(), themeColor: themeColor)
    }

    func onFatPressed(themeColor: Color?) {
        router.showNutritionMetricDetailView(metric: .fat, delegate: NutritionMetricDetailDelegate(), themeColor: themeColor)
    }

    func onCarbsPressed(themeColor: Color?) {
        router.showNutritionMetricDetailView(metric: .carbs, delegate: NutritionMetricDetailDelegate(), themeColor: themeColor)
    }

    func onBreakdownMetricPressed(_ metric: NutritionMetric, themeColor: Color?) {
        router.showNutritionMetricDetailView(metric: metric, delegate: NutritionMetricDetailDelegate(), themeColor: themeColor)
    }
}

extension NutritionAnalyticsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:    return "NutritionAnalyticsView_Appear"
            case .onDisappear: return "NutritionAnalyticsView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
                
            }
        }
    }
}
