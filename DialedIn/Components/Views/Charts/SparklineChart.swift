import SwiftUI
import Charts

struct SparklineConfiguration {
    var lineColor: Color = .accentColor
    var lineWidth: CGFloat = 2
    var fillColor: Color?
    var height: CGFloat = 40
    var showsPoints: Bool = false
}

struct SparklineChart: View {
    let data: [(date: Date, value: Double)]
    var configuration: SparklineConfiguration = SparklineConfiguration()

    /// Chart needs at least 2 points for LineMark. Single point gets a synthetic prior point.
    ///
    /// Sorted once, in `init`, rather than on each body evaluation. The Analytics tab shows up to a
    /// dozen of these at once, so a sort per card per render was paid on every scroll of the list.
    private let chartData: [(date: Date, value: Double)]

    init(
        data: [(date: Date, value: Double)],
        configuration: SparklineConfiguration = SparklineConfiguration()
    ) {
        self.data = data
        self.configuration = configuration

        let sorted = data.sorted { $0.date < $1.date }
        if sorted.count == 1,
           let first = sorted.first,
           let priorDate = Calendar.current.date(byAdding: .day, value: -1, to: first.date) {
            self.chartData = [(date: priorDate, value: first.value), first]
        } else {
            self.chartData = sorted
        }
    }

    var body: some View {
        Group {
            if data.isEmpty {
                emptyPlaceholder
            } else {
                Chart {
                    let points = chartData
                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: configuration.lineWidth))
                        .foregroundStyle(configuration.lineColor)

                        if configuration.showsPoints {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(configuration.lineColor)
                        }
                    }

                    if let fillColor = configuration.fillColor {
                        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [fillColor.opacity(0.35), fillColor.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
            }
        }
        .frame(height: configuration.height)
        .accessibilityElement()
        .accessibilityLabel(Text("Trend"))
        .accessibilityValue(accessibilitySummary)
    }

    /// "From 82.3 to 82.7". The card around the chart names the metric and its unit.
    private var accessibilitySummary: String {
        guard let first = data.min(by: { $0.date < $1.date }), let last = data.max(by: { $0.date < $1.date }) else {
            return String(localized: "No data")
        }
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        return String(localized: "From \(first.value.formatted(format)) to \(last.value.formatted(format))")
    }

    private var emptyPlaceholder: some View {
        GeometryReader { geo in
            Path { path in
                let yVal = geo.size.height * 0.5
                path.move(to: CGPoint(x: 0, y: yVal))
                path.addLine(to: CGPoint(x: geo.size.width, y: yVal))
            }
            .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [Spacing.xs, Spacing.xs]))
        }
    }
}

#Preview("Full data") {
    SparklineChart(
        data: [
            (date: Date.now.addingTimeInterval(-86400 * 6), value: 82.3),
            (date: Date.now.addingTimeInterval(-86400 * 5), value: 82.1),
            (date: Date.now.addingTimeInterval(-86400 * 4), value: 82.4),
            (date: Date.now.addingTimeInterval(-86400 * 3), value: 82.2),
            (date: Date.now.addingTimeInterval(-86400 * 2), value: 82.6),
            (date: Date.now.addingTimeInterval(-86400 * 1), value: 82.5),
            (date: Date.now, value: 82.7)
        ],
        configuration: SparklineConfiguration(fillColor: .accentColor)
    )
    .frame(height: 36)
    .padding()
}

#Preview("Single point") {
    SparklineChart(
        data: [(date: Date.now, value: 82.5)],
        configuration: SparklineConfiguration(fillColor: .accentColor)
    )
    .frame(height: 36)
    .padding()
}

#Preview("Empty") {
    SparklineChart(data: [], configuration: SparklineConfiguration(fillColor: .accentColor))
        .frame(height: 36)
        .padding()
}
