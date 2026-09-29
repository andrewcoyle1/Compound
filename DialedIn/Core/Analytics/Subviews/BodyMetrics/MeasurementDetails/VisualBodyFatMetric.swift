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

    var entries: [VisualBodyFatEntry]

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
            chartColor: .green,
            addActionTitle: "Sync from Health",
            addActionSystemImage: "arrow.clockwise"
        )
    }

    init(
        interactor: BodyMetricsInteractor,
        router: BodyMetricsRouter,
        entries: [VisualBodyFatEntry] = []
    ) {
        self.interactor = interactor
        self.router = router
        self.entries = entries.sorted { $0.date < $1.date }
    }

    func onAppear() async {
        await interactor.backfillBodyFatFromHealthKit()
        entries = Self.bodyFatEntries(from: interactor.bodyMeasurements)
    }

    /// There is no manual body-fat entry flow in the app — the value comes from HealthKit, via the
    /// same backfill `onAppear` runs. So the action is to fetch it again rather than nothing: an
    /// empty screen previously offered no way forward at all.
    func onAddPressed() {
        Task {
            await interactor.backfillBodyFatFromHealthKit()
            entries = Self.bodyFatEntries(from: interactor.bodyMeasurements)
        }
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    var supportsDeletion: Bool { true }

    func onDeleteEntry(_ entry: VisualBodyFatEntry) async {
        guard let baseEntry = interactor.bodyMeasurements.first(where: { $0.id == entry.id }) else { return }
        let updatedEntry = baseEntry.withCleared(.bodyFatPercentage)
        do {
            try await interactor.saveBodyMeasurement(bodyMeasurement: updatedEntry)
        } catch {
            // Was `try?`. The refresh below re-reads unchanged data, so a failed delete put the row
            // straight back with nothing said about why.
            router.showSimpleAlert(title: String(localized: "Unable to Delete Entry"), subtitle: String(localized: "Please try again."))
            return
        }
        entries = Self.bodyFatEntries(from: interactor.bodyMeasurements)
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
        router.showScreen(.sheet) { router in
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
