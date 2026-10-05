//
//  FoodLoggingConsistencyPresenter.swift
//  Compound
//

import SwiftUI

@Observable
@MainActor
final class FoodLoggingConsistencyPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = NutritionMetricEntry

    private let interactor: NutritionAnalyticsInteractor
    private let router: NutritionAnalyticsRouter
    private let calendar = Calendar.current

    private(set) var entries: [NutritionMetricEntry] = []

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

    func onAppear() async {
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .year, value: -1, to: endDate) else { return }
        let startDayKey = calendar.startOfDay(for: startDate).dayKey
        let endDayKey = calendar.startOfDay(for: endDate).dayKey

        // Local read for a chart; no data draws an empty grid, so a failure is logged but not shown.
        let totalsData: [(dayKey: String, totals: DailyMacroTarget)]
        do {
            totalsData = try interactor.getDailyTotals(startDayKey: startDayKey, endDayKey: endDayKey)
        } catch {
            interactor.trackEvent(event: Event.loadFail(error: error))
            totalsData = []
        }
        var newEntries: [NutritionMetricEntry] = []
        for item in totalsData {
            let total = item.totals.proteinGrams + item.totals.carbGrams + item.totals.fatGrams
            guard total > 0, let date = Date(dayKey: item.dayKey) else { continue }
            newEntries.append(NutritionMetricEntry(
                id: item.dayKey,
                date: date,
                value: item.totals.calories,
                metric: .calories
            ))
        }
        entries = newEntries.sorted { $0.date < $1.date }
    }

    var timeSeries: [TimeSeries] { [] }

    /// One point per day with food logged, over every entry there is.
    var contributionSeries: TimeSeries? {
        guard !entries.isEmpty else { return nil }
        return TimeSeries(
            name: "Days Logged",
            data: entries.map { TimeSeriesDatapoint(id: $0.id, date: $0.date, value: 1) }
        )
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Food Logging"),
            analyticsName: "FoodLoggingConsistencyView",
            yAxisSuffix: " kcal",
            seriesNames: ["Food Logged"],
            showsAddButton: true,
            sectionHeader: "Days Logged",
            emptyStateMessage: "No food logged. Log meals to see your consistency.",
            chartColor: Color.Metric.habits,
            addActionTitle: "Log Meal",
            addActionSystemImage: "plus"
        )
    }

    /// These values are derived from logged meals, so the action is to log one. Mirrors
    /// `SearchPresenter.onLogMealPressed`: an existing draft is offered rather than silently
    /// replaced.
    func onAddPressed() {
        guard let userId = interactor.userId else { return }
        if let draft = interactor.draftMeal {
            router.showAddMealView(delegate: AddMealDelegate(mealLog: draft))
            return
        }
        router.showAddMealView(
            delegate: AddMealDelegate(
                mealLog: MealLogModel(
                    authorId: userId,
                    dayKey: Date().dayKey,
                    date: Date(),
                    items: []
                )
            )
        )
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

}

extension FoodLoggingConsistencyPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case loadFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear: return "FoodLoggingConsistencyView_Appear"
            case .onDisappear: return "FoodLoggingConsistencyView_Disappear"
            case .loadFail: return "FoodLoggingConsistencyView_Load_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .loadFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .loadFail: return .warning
            default: return .analytic
            }
        }
    }
}
