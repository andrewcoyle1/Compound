import SwiftUI

@MainActor
protocol MetricDetailPresenter {
    associatedtype Entry: MetricEntry

    var entries: [Entry] { get }
    var timeSeries: [TimeSeries] { get }
    var configuration: MetricConfiguration { get }
    /// When non-nil, this view is used instead of the default `MetricChart` (e.g. for Energy Balance's line+bar chart).
    var customChartView: AnyView? { get }
    /// When non-nil, a contribution grid is shown instead of the default chart. Give it every day
    /// there is, not a fixed window: the grid scrolls back through whatever it's handed.
    var contributionSeries: TimeSeries? { get }
    /// Whether the entry rows offer a Delete swipe. Defaults to false: most of these screens show
    /// values derived from meals, workouts or the user profile, and their `onDeleteEntry` is a
    /// documented no-op — the swipe action was offered on every one of them regardless, so
    /// "Delete" appeared to work and silently did nothing.
    var supportsDeletion: Bool { get }
    /// The value shown in an entry row, for screens whose stored unit differs from the displayed
    /// one. Weight is stored in kilograms and body circumferences in centimetres, so a screen whose
    /// `Entry` is the stored model has to convert somewhere. Defaults to the entry's own
    /// `displayValue`.
    func displayValue(for entry: Entry) -> String

    func onAppear() async
    func onAddPressed()
    func onDismissPressed()
    func onDeleteEntry(_ entry: Entry) async
}

extension MetricDetailPresenter {
    var customChartView: AnyView? { nil }
    var contributionSeries: TimeSeries? { nil }
    var supportsDeletion: Bool { false }

    func displayValue(for entry: Entry) -> String {
        entry.displayValue
    }

    func onDeleteEntry(_ entry: Entry) async {
        // Default no-op for presenters that don't support deletion
    }
}

struct MetricDetailView<Presenter: MetricDetailPresenter>: View {

    @State var presenter: Presenter
    var themeColor: Color?

    init(presenter: Presenter, themeColor: Color? = nil) {
        _presenter = State(initialValue: presenter)
        self.themeColor = themeColor
    }

    var body: some View {
        let configuration = presenter.configuration
        let timeSeries = presenter.timeSeries
        let entries = presenter.entries
        let readings = MetricChartReadings(series: timeSeries, configuration: configuration, color: themeColor)

        // A Health-style screen: the chart edge to edge at the top, its background carried up behind
        // the navigation bar, and the entries in inset sections below. `ChartScreen` sets the title.
        Group {
            // Only QuickCharts' own charts can mark a row's readings, so the contribution grid and
            // the custom charts go without rows.
            if usesMetricChart, !readings.days.isEmpty {
                ChartScreen(title: configuration.title) {
                    chart(configuration: configuration, series: timeSeries)
                } accessories: {
                    MetricChartRows(readings: readings)
                } moreRows: {
                    MetricChartRows(readings: readings, showsAll: true)
                } sections: {
                    listSection(configuration: configuration, entries: entries)
                }
            } else {
                ChartScreen(title: configuration.title) {
                    chart(configuration: configuration, series: timeSeries)
                } sections: {
                    listSection(configuration: configuration, entries: entries)
                }
            }
        }
        .scrollIndicators(.hidden)
        .toolbar {
            toolbarContent
        }
        .onFirstTask {
            await presenter.onAppear()
        }
    }
    
    /// Whether the chart is `MetricChart`, rather than the contribution grid or a custom chart.
    private var usesMetricChart: Bool {
        presenter.contributionSeries == nil && presenter.customChartView == nil
    }

    @ViewBuilder
    private func chart(configuration: MetricConfiguration, series: [TimeSeries]) -> some View {
        if let contributionSeries = presenter.contributionSeries {
            // A week per column, seven weekdays down the rows, scrolling back through every week
            // there is data for. No frame: the chart's height follows from its square size.
            ContributionChart(
                data: [contributionSeries],
                configuration: ChartConfiguration(
                    aggregation: .sum,
                    unit: configuration.contributionUnit,
                    seriesColors: [themeColor ?? configuration.chartColor ?? .green],
                    goal: 1,
                    accessibilityTitle: configuration.title
                )
            )
            .padding(.vertical)
        } else if let customChart = presenter.customChartView {
            customChart
                .frame(minHeight: 300)
                .padding(.vertical)
        } else {
            MetricChart(series: series, configuration: configuration, color: themeColor)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }

        if presenter.configuration.showsAddButton {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presenter.onAddPressed()
                } label: {
                    Image(systemName: presenter.configuration.addActionSystemImage)
                }
                .accessibilityLabel(presenter.configuration.addActionTitle)
            }
        }
    }
    
    /// The entries themselves live one push away, on All Recorded Data, as in Health: listing them
    /// all here buried everything below the chart under months of rows.
    @ViewBuilder
    private func listSection(configuration: MetricConfiguration, entries: [Presenter.Entry]) -> some View {
        if entries.isEmpty {
            emptySection(configuration: configuration)
        } else {
            Section {
                // Pushed with the sheet's own router rather than through each of the thirty-odd
                // presenters that share this view, which would each need the same route.
                RouterReader { router in
                    ListRowButton(title: String(localized: "Show All Data")) {
                        router.showScreen(.push) { _ in
                            MetricAllDataView(presenter: presenter)
                        }
                    }
                }
            }
        }
    }

    /// An empty metric screen offers the same Add action as the toolbar, so it is not a dead end.
    private func emptySection(configuration: MetricConfiguration) -> some View {
        Section {
            ContentUnavailableView {
                Label(configuration.title, systemImage: Symbol.analytics)
            } description: {
                Text(configuration.emptyStateMessage)
            } actions: {
                if configuration.showsAddButton {
                    Button(configuration.addActionTitle) {
                        presenter.onAddPressed()
                    }
                }
            }
        } header: {
            Text(configuration.sectionHeader)
        }
    }
}
