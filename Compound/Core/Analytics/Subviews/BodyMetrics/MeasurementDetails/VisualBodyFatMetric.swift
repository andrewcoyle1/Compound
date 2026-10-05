import SwiftUI

struct VisualBodyFatDelegate {

}

struct VisualBodyFatEntry: @MainActor MetricEntry {
    let id: String
    let date: Date
    let bodyFatPercent: Double

    init(
        id: String = UUID().uuidString,
        date: Date,
        bodyFatPercent: Double
    ) {
        self.id = id
        self.date = date
        self.bodyFatPercent = bodyFatPercent
    }

    var displayLabel: String {
        "\(date.formatted(.dateTime.day().month().year()))"
    }

    var displayValue: String {
        bodyFatPercent.formatted(.number.precision(.fractionLength(1)))
    }

    var systemImageName: String {
        "percent"
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [MetricTimeSeriesPoint(seriesName: "Body Fat", date: date, value: bodyFatPercent)]
    }
}

@Observable
@MainActor
final class VisualBodyFatPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = VisualBodyFatEntry

    private let interactor: BodyMetricsInteractor
    private let router: BodyMetricsRouter

    /// Read live, so readings imported from Apple Health appear while the screen is open.
    var entries: [VisualBodyFatEntry] {
        Self.bodyFatEntries(from: interactor.bodyMeasurements)
    }

    var timeSeries: [TimeSeries] {
        let data = entries.map { TimeSeriesDatapoint(id: $0.id, date: $0.date, value: $0.bodyFatPercent) }
        return [TimeSeries(name: "Body Fat", data: data)]
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Visual Body Fat"),
            analyticsName: "VisualBodyFatView",
            yAxisSuffix: " %",
            seriesNames: ["Body Fat"],
            showsAddButton: true,
            sectionHeader: "Entries",
            emptyStateMessage: "No body fat entries",
            chartColor: Color.Metric.bodyFat,
            addActionTitle: "Sync from Apple Health",
            addActionSystemImage: "arrow.clockwise"
        )
    }

    init(interactor: BodyMetricsInteractor, router: BodyMetricsRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onAppear() async {
        await interactor.syncWeightFromHealthKit()
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    /// There is no manual body-fat entry flow in the app — the value comes from HealthKit. So the
    /// action re-reads all of Apple Health, which also picks up history from before body fat
    /// access was granted: an empty screen previously offered no way forward at all.
    func onAddPressed() {
        Task {
            await interactor.backfillBodyFatFromHealthKit()
        }
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    var supportsDeletion: Bool { true }

    func onDeleteEntry(_ entry: VisualBodyFatEntry) async {
        guard let baseEntry = interactor.bodyMeasurements.first(where: { $0.id == entry.id }) else { return }
        let updatedEntry = baseEntry.withCleared(.bodyFatPercentage)
        interactor.trackEvent(event: Event.deleteEntryStart)
        do {
            try await interactor.saveBodyMeasurement(bodyMeasurement: updatedEntry)
            interactor.trackEvent(event: Event.deleteEntrySuccess)
        } catch {
            interactor.trackEvent(event: Event.deleteEntryFail(error: error))
            // Was `try?`. The refresh below re-reads unchanged data, so a failed delete put the row
            // straight back with nothing said about why.
            router.showSimpleAlert(title: String(localized: "Unable to Delete Entry"), subtitle: String(localized: "Please try again."))
            return
        }
    }

    private static func bodyFatEntries(from weightEntries: [BodyMeasurementEntry]) -> [VisualBodyFatEntry] {
        weightEntries
            .filter { $0.deletedAt == nil }
            .compactMap { entry in
                guard let bodyFatPercentage = entry.bodyFatPercentage else { return nil }
                return VisualBodyFatEntry(
                    id: entry.id,
                    date: entry.date,
                    bodyFatPercent: bodyFatPercentage
                )
            }
            .sorted { $0.date < $1.date }
    }
}

extension VisualBodyFatPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case deleteEntryStart
        case deleteEntrySuccess
        case deleteEntryFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:           return "VisualBodyFatView_Appear"
            case .onDisappear:        return "VisualBodyFatView_Disappear"
            case .deleteEntryStart:   return "VisualBodyFatView_DeleteEntry_Start"
            case .deleteEntrySuccess: return "VisualBodyFatView_DeleteEntry_Success"
            case .deleteEntryFail:    return "VisualBodyFatView_DeleteEntry_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .deleteEntryFail(let error): return error.eventParameters
            default:                          return nil
            }
        }

        var type: LogType {
            switch self {
            case .deleteEntryFail: return .severe
            default:               return .analytic
            }
        }
    }
}

extension VisualBodyFatEntry {
    static let mocks: [VisualBodyFatEntry] = [
        VisualBodyFatEntry(date: Date.now.addingTimeInterval(-86400 * 6), bodyFatPercent: 15.6),
        VisualBodyFatEntry(date: Date.now.addingTimeInterval(-86400 * 5), bodyFatPercent: 15.4),
        VisualBodyFatEntry(date: Date.now.addingTimeInterval(-86400 * 4), bodyFatPercent: 15.2),
        VisualBodyFatEntry(date: Date.now.addingTimeInterval(-86400 * 3), bodyFatPercent: 15.1),
        VisualBodyFatEntry(date: Date.now.addingTimeInterval(-86400 * 2), bodyFatPercent: 15.0),
        VisualBodyFatEntry(date: Date.now.addingTimeInterval(-86400 * 1), bodyFatPercent: 14.9),
        VisualBodyFatEntry(date: Date.now, bodyFatPercent: 14.8)
    ]
}

extension CoreRouter {
    func showVisualBodyFatView(delegate: VisualBodyFatDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
            builder.visualBodyFatView(router: router, delegate: delegate, themeColor: themeColor)
        }
    }
}

extension CoreBuilder {
    func visualBodyFatView(router: AnyRouter, delegate: VisualBodyFatDelegate, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: VisualBodyFatPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            themeColor: themeColor
        )
    }
}
