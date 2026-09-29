//
//  FoodLoggingConsistencyPresenter.swift
//  DialedIn
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

    func onAppear() async {
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .year, value: -1, to: endDate) else { return }
        let startDayKey = calendar.startOfDay(for: startDate).dayKey
        let endDayKey = calendar.startOfDay(for: endDate).dayKey

        // Silent: local read for a chart; no data draws an empty grid.
        let totalsData = (try? interactor.getDailyTotals(startDayKey: startDayKey, endDayKey: endDayKey)) ?? []
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
            chartColor: .orange,
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
