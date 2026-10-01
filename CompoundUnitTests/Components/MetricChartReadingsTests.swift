//
//  MetricChartReadingsTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The Latest, Highest, Lowest and Average rows under a metric chart.
///
/// A day's figure depends on what kind of chart it is: bars are daily totals across every series
/// (the macros' grams), while lines report the first series, because a line chart's other series
/// are derived from it — averaging Weight Trend's trend line together with its readings would
/// describe neither.
@MainActor
struct MetricChartReadingsTests {

    private let calendar = Calendar.current

    /// A date `daysAgo` days back, at midday so it cannot drift across a day boundary.
    private func day(_ daysAgo: Int) -> Date {
        let midday = calendar.startOfDay(for: .now).addingTimeInterval(12 * 3600)
        return calendar.date(byAdding: .day, value: -daysAgo, to: midday) ?? midday
    }

    private func series(_ name: String, _ values: [(daysAgo: Int, value: Double)]) -> TimeSeries {
        TimeSeries(name: name, data: values.map { TimeSeriesDatapoint(date: day($0.daysAgo), value: $0.value) })
    }

    private func configuration(chartType: MetricChartType) -> MetricConfiguration {
        MetricConfiguration(
            title: "Test",
            analyticsName: "Test",
            yAxisSuffix: " kg",
            seriesNames: [],
            showsAddButton: false,
            sectionHeader: "Test",
            emptyStateMessage: "None",
            chartType: chartType
        )
    }

    private func readings(
        _ series: [TimeSeries],
        chartType: MetricChartType = .line
    ) -> MetricChartReadings {
        MetricChartReadings(series: series, configuration: configuration(chartType: chartType), color: nil)
    }

    // MARK: - Days

    @Test("Test Readings Are Grouped Into Days, Oldest First")
    func testReadingsAreGroupedIntoDaysOldestFirst() {
        let readings = readings([series("Weight", [(2, 73.0), (1, 72.6), (0, 72.4)])])

        #expect(readings.days.count == 3)
        #expect(readings.days.map(\.value) == [73.0, 72.6, 72.4])
    }

    @Test("Test Several Readings In A Day Are Averaged")
    func testSeveralReadingsInADayAreAveraged() {
        let readings = readings([series("Weight", [(0, 72.0), (0, 73.0)])])

        #expect(readings.days.count == 1)
        #expect(readings.days[0].value == 72.5)
    }

    @Test("Test No Readings Give No Rows")
    func testNoReadingsGiveNoRows() {
        let readings = readings([])

        #expect(readings.days.isEmpty)
        #expect(readings.latest == nil)
        #expect(readings.highest == nil)
        #expect(readings.lowest == nil)
        #expect(readings.average == nil)
    }

    // MARK: - Latest, highest, lowest

    @Test("Test Latest Is The Most Recent Day")
    func testLatestIsTheMostRecentDay() {
        let readings = readings([series("Weight", [(2, 73.0), (0, 72.4)])])

        #expect(readings.latest?.value == 72.4)
    }

    @Test("Test Highest And Lowest Span The Days")
    func testHighestAndLowestSpanTheDays() {
        let readings = readings([series("Weight", [(3, 72.0), (2, 74.0), (1, 71.0), (0, 73.0)])])

        #expect(readings.highest?.value == 74.0)
        #expect(readings.lowest?.value == 71.0)
    }

    /// Two days at the same weight: the row should name the recent one, since "your lowest was
    /// today" is more useful than naming a day months ago with the same number.
    @Test("Test A Tie Goes To The More Recent Day")
    func testATieGoesToTheMoreRecentDay() throws {
        let readings = readings([series("Weight", [(5, 72.0), (0, 72.0), (2, 75.0)])])

        let lowest = try #require(readings.lowest)
        #expect(calendar.isDateInToday(lowest.date))
    }

    /// With every day the same, Highest and Lowest would only repeat Latest, so the rows are hidden.
    @Test("Test A Flat Metric Has No Spread")
    func testAFlatMetricHasNoSpread() {
        #expect(readings([series("Weight", [(2, 72.0), (1, 72.0), (0, 72.0)])]).hasSpread == false)
        #expect(readings([series("Weight", [(1, 72.0), (0, 72.5)])]).hasSpread == true)
    }

    @Test("Test One Day Has No Spread")
    func testOneDayHasNoSpread() {
        #expect(readings([series("Weight", [(0, 72.0)])]).hasSpread == false)
    }

    // MARK: - Average

    @Test("Test The Average Is Across Days, Not Readings")
    func testTheAverageIsAcrossDaysNotReadings() {
        // Two readings today and one yesterday: today counts once, as a day.
        let readings = readings([series("Weight", [(1, 70.0), (0, 72.0), (0, 74.0)])])

        #expect(readings.average == 71.5)
    }

    // MARK: - Bars against lines

    /// A bar chart's day is its total across every series — the macros chart adds protein, carbs
    /// and fat into one bar.
    @Test("Test A Bar Chart's Day Totals Every Series")
    func testABarChartsDayTotalsEverySeries() {
        let readings = readings(
            [series("Protein", [(0, 120)]), series("Carbs", [(0, 300)]), series("Fat", [(0, 70)])],
            chartType: .stackedBar
        )

        #expect(readings.isTotal)
        #expect(readings.days.first?.value == 490)
    }

    /// A line chart reports its first series. Weight Trend plots the readings and a trend line
    /// derived from them, and the rows should describe the readings.
    @Test("Test A Line Chart's Day Reports The First Series")
    func testALineChartsDayReportsTheFirstSeries() {
        let readings = readings([
            series("Weight", [(0, 72.4)]),
            series("Trend", [(0, 73.8)])
        ])

        #expect(!readings.isTotal)
        #expect(readings.days.first?.value == 72.4)
    }

    /// A day with only a derived reading on it is not a day the user weighed in.
    @Test("Test A Day With Only A Derived Series Is Not A Reading Day")
    func testADayWithOnlyADerivedSeriesIsNotAReadingDay() {
        let readings = readings([
            series("Weight", [(1, 72.4)]),
            series("Trend", [(1, 73.0), (0, 72.9)])
        ])

        #expect(readings.days.count == 1)
    }

    /// The highlight still marks every series on the chart, even though the row's figure came from
    /// the first — tapping "Latest" on Weight Trend dots both the reading and the trend.
    @Test("Test A Day Carries Every Series' Readings For The Chart To Mark")
    func testADayCarriesEverySeriesReadingsForTheChartToMark() throws {
        let readings = readings([
            series("Weight", [(0, 72.4)]),
            series("Trend", [(0, 73.8)])
        ])

        let latest = try #require(readings.latest)
        #expect(latest.points["Weight"]?.count == 1)
        #expect(latest.points["Trend"]?.count == 1)
    }

    // MARK: - Formatting

    /// Totals are whole numbers — nobody logs 300.4 g of carbs — while readings keep a decimal.
    @Test("Test Totals Are Whole And Readings Keep A Decimal")
    func testTotalsAreWholeAndReadingsKeepADecimal() {
        let bars = readings([series("Steps", [(0, 8214)])], chartType: .bar)
        let lines = readings([series("Weight", [(0, 72.45)])])

        // Away from a .x5 tie, which rounds by the formatter's rule rather than the obvious one.
        #expect(8214.4.formatted(bars.valueFormat) == 8214.0.formatted(bars.valueFormat))
        #expect(!8214.4.formatted(bars.valueFormat).contains("."))
        #expect(72.46.formatted(lines.valueFormat) == 72.5.formatted(lines.valueFormat))
        #expect(72.44.formatted(lines.valueFormat) == 72.4.formatted(lines.valueFormat))
    }

    @Test("Test The Unit Comes From The Configuration")
    func testTheUnitComesFromTheConfiguration() {
        #expect(readings([series("Weight", [(0, 72.0)])]).unit == "kg")
    }

    // MARK: - Dates

    @Test("Test Recent Days Are Named Rather Than Dated")
    func testRecentDaysAreNamedRatherThanDated() throws {
        let readings = readings([series("Weight", [(1, 72.0), (0, 72.4)])])

        #expect(try #require(readings.latest).dateText == "Today")
        #expect(readings.days.first?.dateText == "Yesterday")
    }

    @Test("Test Older Days Are Dated")
    func testOlderDaysAreDated() throws {
        let readings = readings([series("Weight", [(10, 72.0)])])

        let text = try #require(readings.latest).dateText
        #expect(text != "Today")
        #expect(text != "Yesterday")
        #expect(!text.isEmpty)
    }
}
