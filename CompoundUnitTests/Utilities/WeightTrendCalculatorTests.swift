//
//  WeightTrendCalculatorTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The exponential moving average behind the Weight Trend chart.
///
/// The whole point of the trend line is that it ignores the day-to-day swings a scale shows from
/// water and food timing, while still following a real change in weight. Those two properties pull
/// against each other, so both are pinned here.
@MainActor
struct WeightTrendCalculatorTests {

    private let day: TimeInterval = 86400
    private let start = Date(timeIntervalSince1970: 0)

    /// `values` on consecutive days.
    private func series(_ values: [Double]) -> [(date: Date, value: Double)] {
        values.enumerated().map { (date: start.addingTimeInterval(Double($0.offset) * day), value: $0.element) }
    }

    private func isClose(_ lhs: Double, _ rhs: Double, within tolerance: Double = 0.0001) -> Bool {
        abs(lhs - rhs) < tolerance
    }

    // MARK: - Shape

    @Test("Test No Readings Give No Trend")
    func testNoReadingsGiveNoTrend() {
        #expect(WeightTrendCalculator.exponentialMovingAverage(data: []).isEmpty)
    }

    @Test("Test One Reading Is Its Own Trend")
    func testOneReadingIsItsOwnTrend() {
        let trend = WeightTrendCalculator.exponentialMovingAverage(data: series([72.4]))

        #expect(trend.count == 1)
        #expect(trend[0].value == 72.4)
        #expect(trend[0].date == start)
    }

    @Test("Test The Trend Has A Point Per Reading, On The Same Days")
    func testTheTrendHasAPointPerReadingOnTheSameDays() {
        let readings = series([72.0, 72.4, 71.8, 72.1, 71.9])
        let trend = WeightTrendCalculator.exponentialMovingAverage(data: readings)

        #expect(trend.count == readings.count)
        #expect(trend.map(\.date) == readings.map(\.date))
    }

    /// It has no earlier reading to smooth against, so the line starts on the scale rather than
    /// somewhere above or below it.
    @Test("Test The Trend Starts At The First Reading")
    func testTheTrendStartsAtTheFirstReading() {
        let trend = WeightTrendCalculator.exponentialMovingAverage(data: series([72.0, 80.0, 90.0]))

        #expect(trend[0].value == 72.0)
    }

    // MARK: - Smoothing

    @Test("Test A Flat Weight Gives A Flat Trend")
    func testAFlatWeightGivesAFlatTrend() {
        let trend = WeightTrendCalculator.exponentialMovingAverage(data: series(Array(repeating: 72.0, count: 10)))

        for point in trend {
            #expect(isClose(point.value, 72.0))
        }
    }

    /// The reason the chart draws a trend at all: a single heavy day after a holiday meal should
    /// barely move the line.
    @Test("Test One Spike Barely Moves The Trend")
    func testOneSpikeBarelyMovesTheTrend() throws {
        let steady = Array(repeating: 72.0, count: 10)
        let withSpike = steady + [78.0]
        let trend = WeightTrendCalculator.exponentialMovingAverage(data: series(withSpike))
        let last = try #require(trend.last).value

        // The reading jumped 6 kg; the trend follows by alpha (a quarter) of it.
        #expect(last > 72.0)
        #expect(last < 74.0)
        #expect(isClose(last, 72.0 + 6.0 * WeightTrendCalculator.defaultAlpha))
    }

    /// And the other half of the bargain: a real, sustained change must be followed, not filtered
    /// out, or the chart would tell someone losing weight that nothing was happening.
    @Test("Test A Sustained Change Is Followed")
    func testASustainedChangeIsFollowed() throws {
        let losing = (0..<30).map { 80.0 - Double($0) * 0.1 }
        let trend = WeightTrendCalculator.exponentialMovingAverage(data: series(losing))
        let last = try #require(trend.last).value

        // Within a tenth of a kilo of the reading by the end: lagging, but tracking.
        #expect(isClose(last, losing[losing.count - 1], within: 0.4))
        #expect(last < trend[0].value)
    }

    @Test("Test The Trend Stays Within The Readings")
    func testTheTrendStaysWithinTheReadings() throws {
        let values = [72.0, 75.0, 70.0, 73.0, 71.0, 74.0]
        let trend = WeightTrendCalculator.exponentialMovingAverage(data: series(values))
        let lowest = try #require(values.min())
        let highest = try #require(values.max())

        for point in trend {
            #expect(point.value >= lowest)
            #expect(point.value <= highest)
        }
    }

    // MARK: - Alpha

    @Test("Test The Default Alpha Smooths Over Roughly A Week")
    func testTheDefaultAlphaSmoothsOverRoughlyAWeek() {
        // 2/(n+1) with n = 7.
        #expect(WeightTrendCalculator.defaultAlpha == 0.25)
    }

    @Test("Test A Higher Alpha Follows The Readings More Closely")
    func testAHigherAlphaFollowsTheReadingsMoreClosely() {
        let readings = series([72.0, 78.0])
        let responsive = WeightTrendCalculator.exponentialMovingAverage(data: readings, alpha: 0.9)
        let smooth = WeightTrendCalculator.exponentialMovingAverage(data: readings, alpha: 0.1)

        #expect(responsive[1].value > smooth[1].value)
        #expect(isClose(responsive[1].value, 72.0 + 6.0 * 0.9))
        #expect(isClose(smooth[1].value, 72.0 + 6.0 * 0.1))
    }

    @Test("Test An Alpha Of One Is The Readings Themselves")
    func testAnAlphaOfOneIsTheReadingsThemselves() {
        let values = [72.0, 75.0, 70.0]
        let trend = WeightTrendCalculator.exponentialMovingAverage(data: series(values), alpha: 1)

        #expect(trend.map(\.value) == values)
    }
}
