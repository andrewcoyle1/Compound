//
//  StepsPresenter.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@Observable
@MainActor
class StepsPresenter {

    private let interactor: StepsInteractor
    private let router: StepsRouter
    private let calendar = Calendar.current

    init(interactor: StepsInteractor, router: StepsRouter) {
        self.interactor = interactor
        self.router = router
    }

    func loadData() async {
        if interactor.canRequestHealthDataAuthorisation() {
            do {
                try await interactor.requestHealthKitAuthorisation(for: .steps)
            } catch {
                // User denied or failed - continue to load; will show empty if no access
                interactor.trackEvent(event: Event.loadAuthorisationFail(error: error))
            }
        }
        await interactor.syncStepsFromHealthKit(fromScratch: false)
    }

    /// The last 90 days, one per day. Read live, so steps imported from Apple Health appear
    /// while the screen is open.
    private var last90Days: [StepsModel] {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        // Up to the end of today, not its start. A steps sample keeps the time it was recorded at,
        // so `<= startOfToday` compared every reading against midnight and dropped today's
        // altogether — the screen was always a day behind.
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        guard let startDate = calendar.date(byAdding: .day, value: -89, to: startOfToday) else { return [] }
        let userId = interactor.userId
        let last90 = interactor.stepsHistory
            .filter { $0.deletedAt == nil && $0.date >= startDate && $0.date < endOfToday && (userId == nil || $0.authorId == userId) }
        return Self.consolidateStepsByDay(last90)
    }

    private static func consolidateStepsByDay(_ entries: [StepsModel]) -> [StepsModel] {
        let byDay = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
        return byDay.compactMap { (_, dayEntries) in
            dayEntries.max { $0.number < $1.number }
        }.sorted { $0.date < $1.date }
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}

extension StepsPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = StepsEntry

    var entries: [StepsEntry] {
        last90Days.map { StepsEntry(id: $0.id, date: $0.date, steps: $0.number) }.reversed()
    }

    var timeSeries: [TimeSeries] {
        [TimeSeries(name: "Steps", data: last90Days.map { TimeSeriesDatapoint(id: $0.id, date: $0.date, value: Double($0.number)) })]
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Steps"),
            analyticsName: "StepsView",
            yAxisSuffix: "",
            seriesNames: ["Steps"],
            showsAddButton: true,
            sectionHeader: "Daily Steps",
            emptyStateMessage: "No step data",
            chartType: .bar,
            addActionTitle: "Sync from Apple Health",
            addActionSystemImage: "arrow.clockwise"
        )
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onAppear() async {
        await loadData()
    }

    /// Steps cannot be typed in, but they can be fetched again — `syncStepsFromHealthKit` and
    /// the authorisation request were already on the interactor with no caller on this screen, so
    /// an empty step history had nothing the user could do about it.
    func onAddPressed() {
        Task {
            interactor.trackEvent(event: Event.syncStart)
            if interactor.canRequestHealthDataAuthorisation() {
                do {
                    try await interactor.requestHealthKitAuthorisation(for: .steps)
                } catch {
                    interactor.trackEvent(event: Event.syncFail(error: error))
                    router.showSimpleAlert(
                        title: String(localized: "Unable to Access Apple Health"),
                        subtitle: String(localized: "Allow step access in the Apple Health app to sync your steps.")
                    )
                    return
                }
            }
            await interactor.syncStepsFromHealthKit(fromScratch: true)
            interactor.trackEvent(event: Event.syncSuccess)
        }
    }

}

extension StepsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case loadAuthorisationFail(error: Error)
        case syncStart
        case syncSuccess
        case syncFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear: return "StepsView_Appear"
            case .onDisappear: return "StepsView_Disappear"
            case .loadAuthorisationFail: return "StepsView_LoadAuthorisation_Fail"
            case .syncStart: return "StepsView_Sync_Start"
            case .syncSuccess: return "StepsView_Sync_Success"
            case .syncFail: return "StepsView_Sync_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .loadAuthorisationFail(let error), .syncFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .syncFail: return .severe
            case .loadAuthorisationFail: return .warning
            default: return .analytic
            }
        }
    }
}
