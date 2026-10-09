//
//  WeightTrendCalculatorTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The Kalman trend behind the Weight Trend chart.
///
/// The whole point of the trend line is that it ignores the day-to-day swings a scale shows from
/// water and food timing, while still following a real change in weight. Those two properties pull
/// against each other, so both are pinned here, along with the rules for odd readings and for
/// readings that are days apart.
@MainActor
struct WeightTrendCalculatorTests {

    private let day: TimeInterval = 86400
    private let start = Date(timeIntervalSince1970: 0)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    /// `values` on consecutive days, or `gapDays` apart.
    private func series(_ values: [Double], gapDays: Double = 1) -> [(date: Date, value: Double)] {
        values.enumerated().map { (date: start.addingTimeInterval(Double($0.offset) * day * gapDays), value: $0.element) }
    }

    private func trend(_ data: [(date: Date, value: Double)]) -> [Double] {
        WeightTrendCalculator.trend(data: data, calendar: calendar).map(\.value)
    }

    private func isClose(_ lhs: Double, _ rhs: Double, within tolerance: Double = 0.0001) -> Bool {
        abs(lhs - rhs) < tolerance
    }

    // MARK: - Shape

    @Test("Test No Readings Give No Trend")
    func testNoReadingsGiveNoTrend() {
        #expect(WeightTrendCalculator.trend(data: []).isEmpty)
    }

    @Test("Test A Single Reading Is Its Own Trend")
    func testASingleReadingIsItsOwnTrend() {
        let result = trend(series([72.4]))

        #expect(result.count == 1)
        #expect(result.first == 72.4)
    }

    @Test("Test One Trend Point Per Reading At The Reading's Date")
    func testOneTrendPointPerReadingAtTheReadingsDate() {
        let readings = series([72.0, 72.5, 71.8, 72.2])
        let result = WeightTrendCalculator.trend(data: readings, calendar: calendar)

        #expect(result.count == readings.count)
        #expect(result.map(\.date) == readings.map(\.date))
    }

    /// The old name still answers, with the new trend, for the callers written against it.
    @Test("Test The Old Entry Point Returns The Same Trend")
    func testTheOldEntryPointReturnsTheSameTrend() {
        let readings = series([80.4, 80.9, 80.1, 79.8, 80.6, 79.5])

        #expect(WeightTrendCalculator.exponentialMovingAverage(data: readings).map(\.value)
            == WeightTrendCalculator.trend(data: readings).map(\.value))
    }

    // MARK: - Smoothing

    @Test("Test A Flat Weight Gives A Flat Trend")
    func testAFlatWeightGivesAFlatTrend() {
        let result = trend(series(Array(repeating: 72.0, count: 10)))

        #expect(result.allSatisfy { isClose($0, 72.0) })
    }

    /// The trend starts at the median of the first three readings, so one odd first reading does
    /// not anchor it.
    @Test("Test The Trend Starts From The Median Of The First Readings")
    func testTheTrendStartsFromTheMedianOfTheFirstReadings() {
        let result = trend(series([75.0, 72.0, 72.2, 72.1, 72.0]))

        #expect(abs(result[0] - 72.2) < 0.5)
    }

    /// Daily swings of a kilogram either side of a steady weight — more than twice the noise the
    /// filter expects — still leave the trend within about half a kilogram of it.
    @Test("Test Day To Day Swings Are Smoothed Out")
    func testDayToDaySwingsAreSmoothedOut() {
        let values = (0..<28).map { 80.0 + ($0 % 2 == 0 ? 1.0 : -1.0) }
        let result = trend(series(values))

        #expect(result.allSatisfy { abs($0 - 80) < 0.6 })
    }

    @Test("Test A Steady Loss Is Followed")
    func testASteadyLossIsFollowed() {
        let losing = (0..<42).map { 90.0 - 0.1 * Double($0) }
        let result = trend(series(losing))

        // A smoother, not a lagging average: the end of the line sits on the readings.
        #expect(abs(result[41] - losing[41]) < 0.3)
        #expect(result[41] < result[0])
    }

    // MARK: - Odd readings

    /// 90 among 72s is more than max(3 kg, 4%) from the trend and nothing confirms it: ignored.
    @Test("Test A Reading Far Off The Trend Is Ignored Unless Confirmed")
    func testAReadingFarOffTheTrendIsIgnoredUnlessConfirmed() {
        let result = trend(series([72, 72, 72, 90, 72, 72]))

        #expect(result.allSatisfy { isClose($0, 72) })
    }

    @Test("Test Two Readings Off The Same Way Confirm A Real Shift")
    func testTwoReadingsOffTheSameWayConfirmARealShift() {
        let result = trend(series([80, 80, 80, 84, 84.1, 84]))

        #expect(result[5] > 83.5)
        // And the smoother does not drag the readings before the step up with it.
        #expect(result[1] < 80.5)
    }

    /// 82.5 among 80s is within the gross-error band: it counts, down-weighted rather than clamped.
    @Test("Test A Smaller Spike Is Down Weighted")
    func testASmallerSpikeIsDownWeighted() {
        let result = trend(series([80, 80, 80, 80, 82.5, 80, 80, 80]))

        #expect(result[4] > 80)
        #expect(result[4] - 80 < 0.5)
    }

    // MARK: - Time

    /// Only the first weigh-in of a day moves the trend; later ones that day share its value.
    @Test("Test Only The First Weigh-In Of A Day Counts")
    func testOnlyTheFirstWeighInOfADayCounts() {
        let readings: [(date: Date, value: Double)] = [
            (date: start.addingTimeInterval(7 * 3600), value: 80),
            (date: start.addingTimeInterval(20 * 3600), value: 85),
            (date: start.addingTimeInterval(day + 7 * 3600), value: 80),
            (date: start.addingTimeInterval(2 * day + 7 * 3600), value: 80)
        ]
        let result = trend(readings)

        #expect(result.count == 4)
        #expect(result.allSatisfy { isClose($0, 80) })
    }

    /// The filter works in days, not readings: weekly weigh-ins follow a change no worse than daily
    /// ones do, where a per-reading average smoothed weekly data seven times as hard.
    @Test("Test Weekly Weigh-Ins Are Not Over Smoothed")
    func testWeeklyWeighInsAreNotOverSmoothed() {
        let values = [80.0, 79.5, 79.0, 78.5, 78.0]
        let daily = trend(series(values))
        let weekly = trend(series(values, gapDays: 7))

        #expect(abs(weekly[4] - 78) <= abs(daily[4] - 78) + 1e-9)
    }

    // MARK: - Noise model

    @Test("Test The Smoothing Constants")
    func testTheSmoothingConstants() {
        #expect(WeighInNoise.noiseFraction == 0.005)
        #expect(WeighInNoise.noiseFloorKg == 0.3)
        #expect(WeighInNoise.huberThreshold == 2.5)
        #expect(WeightTrendCalculator.slopeNoiseKgPerDay == 0.004)
    }
}
