//
//  MetricChart.swift
//  DialedIn
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// The chart at the top of `MetricDetailView`, drawn with QuickCharts: a D/W/M/6M/Y picker, a
/// summary header, paged scrolling and press-and-hold selection.
struct MetricChart: View {
    let series: [TimeSeries]
    let configuration: MetricConfiguration
    /// Overrides `configuration.chartColor`, as `MetricDetailView`'s theme colour does.
    var color: Color?

    var body: some View {
        let chartConfiguration = configuration.quickChartsConfiguration(color: color)

        switch configuration.chartType ?? .line {
        case .line:
            LineChart(data: series, configuration: chartConfiguration)
        case .bar:
            BarChart(data: series, configuration: chartConfiguration)
        case .stackedBar:
            StackedBarChart(data: series, configuration: chartConfiguration)
        case .combo:
            ComboChart(data: series, lineSeries: configuration.lineSeriesNames, configuration: chartConfiguration)
        }
    }
}

/// The rows under `MetricChart`, like the ones under Health's charts. Tapping one marks its day's
/// readings on the chart. The screen shows `latest`; the Show More sheet shows every row.
struct MetricChartRows: View {
    let readings: MetricChartReadings
    /// Adds Highest, Lowest and Average to Latest, for the Show More sheet.
    var showsAll = false

    var body: some View {
        if let latest = readings.latest {
            row("Latest: \(latest.dateText)", day: latest)
        }
        if showsAll {
            // With every day alike, these would only repeat Latest.
            if readings.hasSpread {
                if let highest = readings.highest {
                    row("Highest: \(highest.dateText)", day: highest)
                }
                if let lowest = readings.lowest {
                    row("Lowest: \(lowest.dateText)", day: lowest)
                }
            }
            if let average = readings.average {
                ChartValueRow(
                    readings.isTotal ? "Daily Average" : "Average",
                    value: average.formatted(readings.valueFormat),
                    unit: readings.unit
                )
            }
        }
    }

    private func row(_ title: LocalizedStringKey, day: MetricChartReadings.Day) -> some View {
        ChartValueRow(
            title,
            value: day.value.formatted(readings.valueFormat),
            unit: readings.unit,
            highlight: ChartHighlight(points: day.points, color: readings.highlightColor)
        )
    }
}

/// A metric's readings by day, for `MetricChartRows`. Every metric has at most one reading a day per
/// series, so a day's readings are exactly what the chart plots at its W and M ranges.
///
/// A day's value is its total across the series for bars (the macros' grams), and the first series'
/// reading for lines, whose other series are derived from it (Weight Trend's trend line), so
/// averaging them together would describe neither.
struct MetricChartReadings {
    struct Day {
        let date: Date
        /// The day's total across the series, or the first series' reading.
        let value: Double
        /// The readings making up `value`, by series, for the chart to mark.
        let points: [String: [TimeSeriesDatapoint]]

        /// "Today", "Yesterday", "12 Sep", or "12 Sep 2025" outside this year.
        var dateText: String {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) { return String(localized: "Today") }
            if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
            if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
                return date.formatted(.dateTime.day().month(.abbreviated))
            }
            return date.formatted(.dateTime.day().month(.abbreviated).year())
        }
    }

    /// Oldest first.
    let days: [Day]
    let isTotal: Bool
    let unit: String
    let valueFormat: FloatingPointFormatStyle<Double>
    /// The selected row's fill: the chart's (first) series colour.
    let highlightColor: Color

    var latest: Day? { days.last }
    /// Ties go to the most recent day.
    var highest: Day? { days.last { $0.value == days.map(\.value).max() } }
    var lowest: Day? { days.last { $0.value == days.map(\.value).min() } }
    /// Whether the days differ at all, so Highest and Lowest say something Latest doesn't.
    var hasSpread: Bool { Set(days.map(\.value)).count > 1 }
    var average: Double? {
        days.isEmpty ? nil : days.map(\.value).reduce(0, +) / Double(days.count)
    }

    @MainActor
    init(series: [TimeSeries], configuration: MetricConfiguration, color: Color?) {
        let chartConfiguration = configuration.quickChartsConfiguration(color: color)
        let isTotal = configuration.isTotalChart
        let calendar = Calendar.current

        var readingsByDay: [Date: [String: [TimeSeriesDatapoint]]] = [:]
        for timeSeries in series {
            for point in timeSeries.data {
                readingsByDay[calendar.startOfDay(for: point.date), default: [:]][timeSeries.name, default: []].append(point)
            }
        }
        let primary = series.first?.name
        self.days = readingsByDay.compactMap { date, points in
            if isTotal {
                return Day(date: date, value: points.values.joined().map(\.value).reduce(0, +), points: points)
            }
            // A day with only derived readings isn't a reading day.
            guard let primary, let readings = points[primary], !readings.isEmpty else { return nil }
            return Day(date: date, value: readings.map(\.value).reduce(0, +) / Double(readings.count), points: points)
        }
        .sorted { $0.date < $1.date }
        self.isTotal = isTotal
        self.unit = chartConfiguration.unit
        self.valueFormat = configuration.valueFormat
        self.highlightColor = chartConfiguration.seriesColors.first ?? .accentColor
    }
}

@MainActor
extension MetricConfiguration {
    /// Bars and stacked bars are daily totals; lines are readings. A combo chart's bars are a daily
    /// total too, but its line is the level they are compared against, so bucketing them apart would
    /// put the two on different footings: both are averaged into a daily rate instead.
    fileprivate var isTotalChart: Bool { chartType == .bar || chartType == .stackedBar }

    /// Totals are whole numbers, as are the combo chart's calories; readings keep one decimal place.
    fileprivate var valueFormat: FloatingPointFormatStyle<Double> {
        .number.precision(.fractionLength(isTotalChart || chartType == .combo ? 0 : 1))
    }

    /// Bars are daily totals — steps, sets, calories — so a week or month bucket adds them up and the
    /// header shows the daily average, as Health does for steps. Lines are readings such as weight or
    /// a one-rep max, so buckets average them.
    fileprivate func quickChartsConfiguration(color: Color?) -> ChartConfiguration {
        let isTotal = isTotalChart
        let unit = isMacrosChart ? (macrosYAxisSuffix ?? " g") : yAxisSuffix

        return ChartConfiguration(
            aggregation: isTotal ? .sum : .average,
            summary: isTotal ? .dailyAverage : .combined,
            unit: unit.trimmingCharacters(in: .whitespaces),
            valueFormat: valueFormat,
            // Every metric here has at most a reading or total a day, so D would show one point.
            availableScales: [.week, .month, .sixMonths, .year],
            seriesColors: seriesColors(color: color ?? chartColor),
            height: 220,
            accessibilityTitle: title
        )
    }

    /// A single colour paints every series. The macros chart keeps the
    /// protein, carbs and fat colours used everywhere else in the app.
    private func seriesColors(color: Color?) -> [Color] {
        // The bars first, then the line, matching the order a combo chart's series are given in.
        if chartType == .combo, let lineSeriesColor {
            return [color ?? ChartConfiguration().seriesColors.first ?? .accentColor, lineSeriesColor]
        }
        if isMacrosChart {
            return [MacroProgressChart.proteinColor, MacroProgressChart.carbsColor, MacroProgressChart.fatColor]
        }
        if let color {
            return [color]
        }
        return ChartConfiguration().seriesColors
    }
}
