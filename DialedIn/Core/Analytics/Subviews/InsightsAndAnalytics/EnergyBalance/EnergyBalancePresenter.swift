//
//  EnergyBalancePresenter.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@Observable
@MainActor
class EnergyBalancePresenter {

    private let interactor: EnergyBalanceInteractor
    private let router: EnergyBalanceRouter
    private let calendar = Calendar.current

    private(set) var cachedEntries: [EnergyBalanceEntry] = []
    private(set) var cachedExpenditure: TimeSeries = TimeSeries(name: "Expenditure", data: [])
    private(set) var cachedIntake: TimeSeries = TimeSeries(name: "Intake", data: [])

    var currentUser: UserModel? {
        interactor.currentUser
    }
    
    var draftMeal: MealLogModel? {
        interactor.draftMeal
    }
    
    init(interactor: EnergyBalanceInteractor, router: EnergyBalanceRouter) {
        self.interactor = interactor
        self.router = router
        rebuildCaches()
    }

    func loadData() {
        rebuildCaches()
    }

    func onAddMealPressed() {
        guard let userId = currentUser?.userId else { return }
        if let meal = interactor.draftMeal {
            router.showAlert(
                title: String(localized: "Unable to add new meal"),
                subtitle: String(localized: "You already have an draft meal."),
                buttons: {
                    AnyView(
                        VStack {
                            Button("Continue editing") {
                                self.router.showAddMealView(
                                    delegate: AddMealDelegate(mealLog: meal)
                                )
                            }
                            Button("Delete drafted meal", role: .destructive) {
                                self.router.showAddMealView(
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
                            Button("Cancel", role: .cancel) { }
                        }
                    )
                }
            )
        } else {
            self.router.showAddMealView(
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
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    private func rebuildCaches() {
        let tdee = interactor.estimateTDEE(user: interactor.currentUser)
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -89, to: startOfToday) else {
            return
        }
        let startDayKey = startDate.dayKey
        let endDayKey = startOfToday.dayKey

        // Silent: local read for a chart; no data draws an empty chart.
        let totalsData = (try? interactor.getDailyTotals(startDayKey: startDayKey, endDayKey: endDayKey)) ?? []

        var entries: [EnergyBalanceEntry] = []
        var expenditureData: [TimeSeriesDatapoint] = []
        var intakeData: [TimeSeriesDatapoint] = []

        let dateKeys = Date.dayKeys(from: startDate, to: startOfToday)
        for (index, dayKey) in dateKeys.enumerated() {
            guard let date = Date(dayKey: dayKey) else { continue }

            // Expenditure is known for every day: it is the user's TDEE, so the line runs unbroken
            // across the whole range.
            expenditureData.append(TimeSeriesDatapoint(id: "exp-\(index)", date: date, value: tdee))

            // `getDailyTotals` answers for every day in the range, totalling zero where nothing was
            // logged, so a day only counts as eaten on if it has calories against it. Without this
            // every unlogged day was an intake of 0 kcal: a bar at the floor of the chart, a row in
            // All Recorded Data reading "3,180 deficit", and a daily average near zero.
            let totals = totalsData.first { $0.dayKey == dayKey }?.totals
            guard let intake = totals?.calories, intake > 0 else { continue }

            entries.append(
                EnergyBalanceEntry(id: dayKey, date: date, expenditure: tdee, intake: intake)
            )
            intakeData.append(TimeSeriesDatapoint(id: "intake-\(index)", date: date, value: intake))
        }

        cachedEntries = entries.reversed()
        cachedExpenditure = TimeSeries(name: "Expenditure", data: expenditureData)
        cachedIntake = TimeSeries(name: "Intake", data: intakeData)
    }
}

extension EnergyBalancePresenter: @MainActor MetricDetailPresenter {
    typealias Entry = EnergyBalanceEntry

    var entries: [EnergyBalanceEntry] {
        cachedEntries
    }

    /// Intake first: it is the series the chart's bars and its Latest row describe, and the combo
    /// chart draws the bar series before the line.
    var timeSeries: [TimeSeries] {
        [cachedIntake, cachedExpenditure]
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Energy Balance"),
            analyticsName: "EnergyBalanceView",
            yAxisSuffix: " kcal",
            seriesNames: ["Intake", "Expenditure"],
            showsAddButton: true,
            sectionHeader: "Daily Balance",
            emptyStateMessage: "No data for the last 90 days",
            chartColor: EnergyBalanceChart.intakeColor,
            chartType: .combo,
            lineSeriesNames: ["Expenditure"],
            lineSeriesColor: EnergyBalanceChart.expenditureColor
        )
    }

    func onAppear() async {
        loadData()
    }

    func onAddPressed() {
        onAddMealPressed()
    }

}
