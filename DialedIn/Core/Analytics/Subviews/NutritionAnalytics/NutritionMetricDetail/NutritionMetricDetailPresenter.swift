//
//  NutritionMetricDetailPresenter.swift
//  DialedIn
//
//  Created by Cursor on 06/02/2026.
//

import SwiftUI

struct NutritionMetricDetailDelegate {}

@Observable
@MainActor
final class NutritionMetricDetailPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = NutritionMetricEntry

    private let interactor: NutritionAnalyticsInteractor
    private let router: NutritionAnalyticsRouter
    private let metric: NutritionMetric
    private let calendar = Calendar.current

    private(set) var entries: [NutritionMetricEntry] = []

    /// Nutrition metrics use a bar or stacked bar chart, not the contribution chart.
    var contributionSeries: TimeSeries? { nil }

    var timeSeries: [TimeSeries] {
        if metric == .macros {
            let proteinData = entries.compactMap { entry -> TimeSeriesDatapoint? in
                guard let protein = entry.proteinGrams else { return nil }
                return TimeSeriesDatapoint(id: "\(entry.id)-p", date: entry.date, value: protein)
            }
            let carbsData = entries.compactMap { entry -> TimeSeriesDatapoint? in
                guard let carbs = entry.carbGrams else { return nil }
                return TimeSeriesDatapoint(id: "\(entry.id)-c", date: entry.date, value: carbs)
            }
            let fatData = entries.compactMap { entry -> TimeSeriesDatapoint? in
                guard let fats = entry.fatGrams else { return nil }
                return TimeSeriesDatapoint(id: "\(entry.id)-f", date: entry.date, value: fats)
            }
            return [
                TimeSeries(name: "Protein", data: proteinData),
                TimeSeries(name: "Carbs", data: carbsData),
                TimeSeries(name: "Fat", data: fatData)
            ]
        }
        let data = entries.map { TimeSeriesDatapoint(id: $0.id, date: $0.date, value: $0.value) }
        return [TimeSeries(name: metric.title, data: data)]
    }

    var configuration: MetricConfiguration {
        if metric == .macros {
            return MetricConfiguration(
                title: metric.title,
                analyticsName: "NutritionMetricDetail_Macros",
                yAxisSuffix: "",
                seriesNames: ["Protein", "Carbs", "Fat"],
                showsAddButton: true,
                sectionHeader: "Daily Values",
                emptyStateMessage: "No macro data. Log meals to see your nutrition over time.",
                chartColor: nil,
                chartType: .stackedBar,
                isMacrosChart: true,
                macrosYAxisSuffix: " g",
                addActionTitle: "Log Meal",
                addActionSystemImage: "plus"
            )
        }
        return MetricConfiguration(
            title: metric.title,
            analyticsName: "NutritionMetricDetail_\(metric.title.replacingOccurrences(of: " ", with: ""))",
            yAxisSuffix: metric.yAxisSuffix,
            seriesNames: [metric.title],
            showsAddButton: true,
            sectionHeader: "Daily Values",
            emptyStateMessage: "No \(metric.title.lowercased()) data. Log meals to see your nutrition over time.",
            chartColor: metric.chartColor,
            chartType: .bar,
            addActionTitle: "Log Meal",
            addActionSystemImage: "plus"
        )
    }

    init(interactor: NutritionAnalyticsInteractor, router: NutritionAnalyticsRouter, metric: NutritionMetric) {
        self.interactor = interactor
        self.router = router
        self.metric = metric
    }

    func onAppear() async {
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .year, value: -1, to: endDate) else { return }
        let startDayKey = calendar.startOfDay(for: startDate).dayKey
        let endDayKey = calendar.startOfDay(for: endDate).dayKey

        var newEntries: [NutritionMetricEntry] = []

        if metric == .macros {
            // Silent: local reads for a chart; no data draws an empty chart.
            let totalsData = (try? interactor.getDailyTotals(startDayKey: startDayKey, endDayKey: endDayKey)) ?? []
            for item in totalsData {
                guard let date = Date(dayKey: item.dayKey) else { continue }
                let totals = item.totals
                let total = totals.proteinGrams + totals.carbGrams + totals.fatGrams
                guard total > 0 else { continue }
                newEntries.append(NutritionMetricEntry(
                    date: date,
                    value: totals.calories,
                    metric: metric,
                    proteinGrams: totals.proteinGrams,
                    carbGrams: totals.carbGrams,
                    fatGrams: totals.fatGrams
                ))
            }
        } else if metric.usesTotals {
            let totalsData = (try? interactor.getDailyTotals(startDayKey: startDayKey, endDayKey: endDayKey)) ?? []
            for item in totalsData {
                guard let date = Date(dayKey: item.dayKey),
                      let value = metric.extractValue(totals: item.totals, breakdown: nil),
                      value > 0 else { continue }
                newEntries.append(NutritionMetricEntry(date: date, value: value, metric: metric))
            }
        } else {
            let breakdownData = (try? interactor.getDailyNutritionBreakdown(startDayKey: startDayKey, endDayKey: endDayKey)) ?? []
            for item in breakdownData {
                guard let date = Date(dayKey: item.dayKey),
                      let value = metric.extractValue(totals: nil, breakdown: item.breakdown),
                      value > 0 else { continue }
                newEntries.append(NutritionMetricEntry(date: date, value: value, metric: metric))
            }
        }

        entries = newEntries.sorted { $0.date < $1.date }
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

extension CoreRouter {
    func showNutritionMetricDetailView(metric: NutritionMetric, delegate: NutritionMetricDetailDelegate, themeColor: Color? = nil) {
        router.showScreen(.sheet) { router in
            builder.nutritionMetricDetailView(router: router, metric: metric, delegate: delegate, themeColor: themeColor)
        }
    }
}

extension CoreBuilder {
    func nutritionMetricDetailView(router: AnyRouter, metric: NutritionMetric, delegate: NutritionMetricDetailDelegate, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: NutritionMetricDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                metric: metric
            ),
            themeColor: themeColor
        )
    }
}
