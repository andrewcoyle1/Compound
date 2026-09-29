//
//  ExpenditureDetailPresenter.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@Observable
@MainActor
class ExpenditureDetailPresenter {

    private let interactor: ExpenditureDetailInteractor
    private let router: ExpenditureDetailRouter
    private let calendar = Calendar.current

    private(set) var cachedEntries: [ExpenditureDetailEntry] = []
    private(set) var cachedTimeSeries: [TimeSeries] = []

    init(interactor: ExpenditureDetailInteractor, router: ExpenditureDetailRouter) {
        self.interactor = interactor
        self.router = router
        rebuildCaches()
    }

    func loadData() {
        rebuildCaches()
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    /// The last ninety days of the adaptive estimate.
    ///
    /// This drew a flat line off `estimateTDEE` for as long as there was no engine to draw
    /// anything else. `expenditureHistory` gives one figure per day, so the chart now moves with
    /// what was actually logged. A user with no history at all still gets the formula figure, as a
    /// flat line, which is the honest picture of what the app knows about them.
    private func rebuildCaches() {
        let history = interactor.expenditureHistory.suffix(90)
        guard !history.isEmpty else {
            rebuildFlatCaches(kcal: interactor.estimateTDEE(user: interactor.currentUser))
            return
        }

        var entries: [ExpenditureDetailEntry] = []
        var data: [TimeSeriesDatapoint] = []
        for estimate in history {
            let dayKey = estimate.day.dayKey
            entries.append(ExpenditureDetailEntry(id: dayKey, date: estimate.day, expenditure: estimate.kcal))
            data.append(TimeSeriesDatapoint(id: dayKey, date: estimate.day, value: estimate.kcal))
        }

        cachedEntries = entries.reversed()
        cachedTimeSeries = [TimeSeries(name: "Expenditure", data: data)]
    }

    /// Ninety flat days, for the account that has logged nothing yet.
    private func rebuildFlatCaches(kcal: Double) {
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -89, to: startOfToday) else {
            cachedEntries = []
            cachedTimeSeries = []
            return
        }

        var entries: [ExpenditureDetailEntry] = []
        var data: [TimeSeriesDatapoint] = []
        for offset in 0..<90 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            let dayKey = date.dayKey
            entries.append(ExpenditureDetailEntry(id: dayKey, date: date, expenditure: kcal))
            data.append(TimeSeriesDatapoint(id: dayKey, date: date, value: kcal))
        }

        cachedEntries = entries.reversed()
        cachedTimeSeries = [TimeSeries(name: "Expenditure", data: data)]
    }
}

extension ExpenditureDetailPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = ExpenditureDetailEntry

    var entries: [ExpenditureDetailEntry] {
        cachedEntries
    }

    var timeSeries: [TimeSeries] {
        cachedTimeSeries
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Expenditure"),
            analyticsName: "ExpenditureDetailView",
            yAxisSuffix: "",
            seriesNames: ["Expenditure"],
            showsAddButton: true,
            sectionHeader: "Daily Expenditure",
            emptyStateMessage: "No expenditure data",
            chartType: .line,
            addActionTitle: "Edit Profile",
            addActionSystemImage: "person.crop.circle"
        )
    }

    func onAppear() async {
        loadData()
    }

    func onAddPressed() {
        // TDEE is estimated from height, weight, age and activity level — all of which live on
        // the account screen, which is where this now goes.
        router.showAccountView(delegate: AccountDelegate())
    }

}
