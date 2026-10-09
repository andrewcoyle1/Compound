//
//  ExpenditureEngineTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The adaptive expenditure engine, tested the way it was built to be tested: a fixed calendar, a
/// fixed today, samples handed in as data, and no manager anywhere near it.
///
/// The cases follow `docs/specs/adaptive-expenditure.md` §6. Expected figures were worked out by
/// running the same data through `functions/coach-maths.js`, the engine's JavaScript port.
struct ExpenditureEngineTests {

    // MARK: - Fixtures

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private let calendar = ExpenditureEngineTests.calendar
    /// A fixed day, so nothing here depends on when it runs.
    private let today = ExpenditureEngineTests.calendar.startOfDay(
        for: Date(timeIntervalSince1970: 1_750_000_000)
    )
    private let prior: Double = 2500
    private let engine = ExpenditureEngine()

    private func day(_ index: Int, of count: Int) -> Date {
        calendar.date(byAdding: .day, value: index - count, to: today) ?? today
    }

    /// `n` consecutive days ending yesterday. Index 0 is the oldest, `n - 1` is yesterday.
    private func days(
        _ count: Int,
        intake: (Int) -> Double?,
        weight: (Int) -> Double?,
        steps: (Int) -> Int? = { _ in nil }
    ) -> [DailySample] {
        (0..<count).map { index in
            DailySample(
                day: day(index, of: count),
                intakeKcal: intake(index),
                weightKg: weight(index),
                steps: steps(index)
            )
        }
    }

    private func settings(
        mode: ExpenditureCalculationMode = .dynamic,
        startDate: Date? = nil,
        stepInformedUpdates: Bool = false
    ) -> NutritionStrategySettings {
        var settings = NutritionStrategySettings(authorId: "user-1")
        settings.calculationMode = mode
        settings.calculationStartDate = startDate
        settings.stepInformedUpdates = stepInformedUpdates
        return settings
    }

    private func history(
        _ samples: [DailySample],
        settings: NutritionStrategySettings? = nil,
        prior: Double? = nil,
        kcalPerKg: Double = EnergyDensity.conventionalKcalPerKg
    ) -> [ExpenditureEstimate] {
        engine.history(
            samples: samples,
            priorKcal: prior ?? self.prior,
            settings: settings ?? self.settings(),
            today: today,
            calendar: calendar,
            kcalPerKg: kcalPerKg
        )
    }

    /// Flat maintenance: the same intake and the same weight every day.
    private func maintenanceDays(_ count: Int, intake: Double = 2400, weight: Double = 80) -> [DailySample] {
        days(count, intake: { _ in intake }, weight: { _ in weight })
    }

    // MARK: - 1. No samples

    @Test("Test No Samples Returns One Provisional Estimate At The Prior")
    func testNoSamplesReturnsOneProvisionalEstimateAtThePrior() {
        let result = history([])

        #expect(result.count == 1)
        #expect(result.first?.kcal == prior)
        #expect(result.first?.source == .prior)
        #expect(result.first?.isProvisional == true)
        #expect(result.first?.day == today)
        #expect(result.first?.sdKcal == nil)
    }

    // MARK: - 2. Calibrating

    @Test("Test Twenty Days Of Perfect Data Is Still Calibrating")
    func testTwentyDaysOfPerfectDataIsStillCalibrating() {
        let result = history(maintenanceDays(20))

        #expect(result.last?.isProvisional == true)
        #expect(result.last?.source == .prior)
        #expect(result.last?.kcal == prior)
        // The filter has been learning all along; it is only the figure shown that waits.
        #expect(result.last?.sdKcal != nil)
    }

    /// 21 days of data and 14 weigh-ins, an SD under 200 kcal and 80% of the window logged: the
    /// day all four first hold is the day the estimate switches from the formula.
    @Test("Test The Estimate Calibrates On Day Twenty One")
    func testTheEstimateCalibratesOnDayTwentyOne() throws {
        let result = history(maintenanceDays(30))

        #expect(result[20].isProvisional == true)
        #expect(result[21].isProvisional == false)
        #expect(result[21].source == .adaptive)
        let deviation = try #require(result[21].sdKcal)
        #expect(deviation < ExpenditureEngine.Constants.maxCalibratedSDKcal)
    }

    // MARK: - 3. Maintenance

    @Test("Test Flat Intake And Flat Weight Converge On The Intake")
    func testFlatIntakeAndFlatWeightConvergeOnTheIntake() throws {
        let result = history(maintenanceDays(60))
        let last = try #require(result.last)

        #expect(last.source == .adaptive)
        #expect(last.isProvisional == false)
        #expect(abs(last.kcal - 2400) < 15)
        let weekly = try #require(last.weeklyTrendChangeKg)
        #expect(abs(weekly) < 0.01)
        let deviation = try #require(last.sdKcal)
        #expect(deviation < 120)
        #expect(last.confidence == .high)
        #expect(last.likelyRange != nil)
    }

    // MARK: - 4. Deficit

    @Test("Test A Steady Deficit Reads As Intake Plus The Energy Lost")
    func testASteadyDeficitReadsAsIntakePlusTheEnergyLost() throws {
        let samples = days(
            60,
            intake: { _ in 2000 },
            weight: { index in 80 - 0.5 * Double(index) / 7 }
        )
        let last = try #require(history(samples).last)

        #expect(last.source == .adaptive)
        #expect(abs(last.kcal - 2550) < 40)
        let weekly = try #require(last.weeklyTrendChangeKg)
        #expect(abs(weekly - (-0.5)) < 0.05)
        #expect(last.weeklyTrendChangeSDKg != nil)
    }

    /// The same loss priced at a lean person's energy density (`EnergyDensity`) reads as less spent.
    @Test("Test A Leaner Energy Density Reads The Same Loss As Less Spent")
    func testALeanerEnergyDensityReadsTheSameLossAsLessSpent() throws {
        let samples = days(60, intake: { _ in 2000 }, weight: { index in 80 - 0.5 * Double(index) / 7 })
        let last = try #require(history(samples, kcalPerKg: 6300).last)

        // 2,000 + 0.5 · 6,300 / 7 = 2,450.
        #expect(abs(last.kcal - 2450) < 40)
    }

    // MARK: - 5. Surplus

    @Test("Test A Steady Surplus Reads As Intake Minus The Energy Stored")
    func testASteadySurplusReadsAsIntakeMinusTheEnergyStored() throws {
        let samples = days(
            60,
            intake: { _ in 3000 },
            weight: { index in 80 + 0.5 * Double(index) / 7 }
        )
        let last = try #require(history(samples).last)

        #expect(last.source == .adaptive)
        #expect(abs(last.kcal - 2450) < 40)
        let weekly = try #require(last.weeklyTrendChangeKg)
        #expect(abs(weekly - 0.5) < 0.05)
    }

    // MARK: - Noise

    /// A deterministic Gaussian source, so the noisy case is the same every run.
    private struct Gaussians {
        var state: Int
        mutating func uniform() -> Double {
            state = (state * 16_807) % 2_147_483_647
            return Double(state) / 2_147_483_647
        }
        mutating func next() -> Double {
            let first = uniform()
            let second = uniform()
            return (-2 * log(first)).squareRoot() * cos(2 * Double.pi * second)
        }
    }

    /// The filter's reason to exist: through realistic noise on both the scale and the food log, it
    /// finds the true expenditure, and its own interval says how close it is.
    @Test("Test The Filter Converges On The True Expenditure Through Noise")
    func testTheFilterConvergesOnTheTrueExpenditureThroughNoise() throws {
        var noise = Gaussians(state: 7)
        // True expenditure 2,700: eating 2,200 ± 400 and losing 500/7700 kg a day; the scale reads
        // 0.5% either side. The prior is 400 kcal low.
        var samples: [DailySample] = []
        for index in 0..<90 {
            let intake = 2200 + 400 * noise.next()
            let weight = 85 - (500.0 / 7700) * Double(index) + 0.005 * 85 * noise.next()
            samples.append(DailySample(day: day(index, of: 90), intakeKcal: intake, weightKg: weight))
        }
        let last = try #require(history(samples, prior: 2300).last)
        let deviation = try #require(last.sdKcal)

        #expect(last.source == .adaptive)
        #expect(deviation < 150)
        #expect(abs(last.kcal - 2700) < 1.28 * deviation + 50)
    }

    // MARK: - 6. Logging

    @Test("Test Under Eighty Percent Of The Window Logged Stays Calibrating")
    func testUnderEightyPercentOfTheWindowLoggedStaysCalibrating() {
        let sparse = days(28, intake: { $0 < 20 ? 2400 : nil }, weight: { _ in 80 })
        let enough = days(28, intake: { $0 < 23 ? 2400 : nil }, weight: { _ in 80 })

        #expect(history(sparse).last?.isProvisional == true)
        #expect(history(enough).last?.isProvisional == false)
        #expect(history(enough).last?.loggedDays == 23)
    }

    /// Weigh-ins alone tell the filter the slope, E − T, but never E and T apart. Someone who only
    /// weighs in gets a trend and a rate, and the formula for expenditure.
    @Test("Test Weigh-Ins Without Food Logs Give A Rate But Never Calibrate")
    func testWeighInsWithoutFoodLogsGiveARateButNeverCalibrate() throws {
        let result = history(days(60, intake: { _ in nil }, weight: { 80 - 0.05 * Double($0) }))

        #expect(result.allSatisfy { $0.isProvisional })
        let weekly = try #require(result.last?.weeklyTrendChangeKg)
        #expect(weekly < -0.2)
    }

    /// Nothing logged and nothing weighed: the filter predicts through the days and its SD grows
    /// every one of them. Nothing is imputed.
    @Test("Test Days With No Data Only Widen The Uncertainty")
    func testDaysWithNoDataOnlyWidenTheUncertainty() throws {
        let silent = days(40, intake: { $0 >= 33 ? nil : 2400 }, weight: { $0 >= 33 ? nil : 80 })
        let result = history(silent)

        for index in 35...40 {
            let previous = try #require(result[index - 1].sdKcal)
            let current = try #require(result[index].sdKcal)
            #expect(current > previous)
        }
        let logged = try #require(history(maintenanceDays(40)).last?.sdKcal)
        let gap = try #require(result.last?.sdKcal)
        #expect(gap > logged)
    }

    // MARK: - 7. Weigh-ins

    @Test("Test Fewer Than Fourteen Weigh-Ins Stays Calibrating")
    func testFewerThanFourteenWeighInsStaysCalibrating() {
        let tooFew = days(28, intake: { _ in 2400 }, weight: { $0 >= 20 ? 80 : nil })
        let enough = days(28, intake: { _ in 2400 }, weight: { _ in 80 })

        #expect(history(tooFew).last?.isProvisional == true)
        #expect(history(enough).last?.isProvisional == false)
    }

    // MARK: - 8. Outliers

    /// 95 kg among 80s is more than max(3 kg, 4%) off the trend and the next weigh-in does not
    /// agree, so it is held and then dropped: the trend does not move at all.
    @Test("Test A Wild Weigh-In Is Held And Dropped")
    func testAWildWeighInIsHeldAndDropped() throws {
        let result = history(days(60, intake: { _ in 2400 }, weight: { $0 == 40 ? 95 : 80 }))

        // `trendWeightKg` on day D is the trend as at D - 1, so these two read days 39 and 40.
        let before = try #require(result[40].trendWeightKg)
        let after = try #require(result[41].trendWeightKg)
        #expect(abs(after - before) < 0.01)
        let last = try #require(result.last)
        #expect(abs(last.kcal - 2400) < 20)
    }

    /// 81.5 kg is within the gross-error band, so it counts — down-weighted, not clamped.
    @Test("Test An Odd Weigh-In Is Down Weighted")
    func testAnOddWeighInIsDownWeighted() throws {
        let result = history(days(60, intake: { _ in 2400 }, weight: { $0 == 40 ? 81.5 : 80 }))

        let before = try #require(result[40].trendWeightKg)
        let after = try #require(result[41].trendWeightKg)
        #expect(after > before)
        #expect(after - before < 0.25)
    }

    // MARK: - 9. Prior bound

    @Test("Test The Shown Figure Stays Inside The Prior Band")
    func testTheShownFigureStaysInsideThePriorBand() {
        let result = history(days(60, intake: { _ in 1300 }, weight: { _ in 80 }))
        let floor = prior * ExpenditureEngine.Constants.priorBoundLow

        #expect(result.allSatisfy { $0.kcal >= floor })
        #expect(result.last?.kcal == floor)
    }

    // MARK: - 11. Calculation start date

    @Test("Test A Start Date Restarts The Replay And The Calibration")
    func testAStartDateRestartsTheReplayAndTheCalibration() throws {
        let samples = days(
            60,
            intake: { _ in 2000 },
            weight: { index in 80 - 0.5 * Double(index) / 7 }
        )
        let startDate = day(50, of: 60)
        let last = try #require(history(samples, settings: settings(startDate: startDate)).last)

        #expect(last.isProvisional == true)
        #expect(last.source == .prior)
        #expect(last.kcal == prior)
    }

    // MARK: - 12. Fixed mode

    @Test("Test Fixed Mode Holds The Prior And Still Draws The Trend")
    func testFixedModeHoldsThePriorAndStillDrawsTheTrend() throws {
        let result = history(maintenanceDays(60), settings: settings(mode: .fixed))

        #expect(result.allSatisfy { $0.kcal == prior })
        #expect(result.allSatisfy { $0.source == .fixed })
        #expect(result.allSatisfy { !$0.isProvisional })
        #expect(result.allSatisfy { $0.sdKcal == nil })
        let trend = try #require(result.last?.trendWeightKg)
        #expect(abs(trend - 80) < 0.05)
    }

    // MARK: - 13. Step nowcast

    /// The recent week (12,000) against the whole window, which already contains it: 21 days at
    /// 8,000 and 7 at 12,000 average 9,000, a gap of 3,000 steps, priced at the net 0.0004 kcal per
    /// step per kg at the trend weight of about 80 kg: ≈96 kcal.
    @Test("Test A Busier Week Than The Window Adds A Capped Step Nowcast")
    func testABusierWeekThanTheWindowAddsACappedStepNowcast() throws {
        let samples = days(
            60,
            intake: { _ in 2400 },
            weight: { _ in 80 },
            steps: { index in index >= 53 ? 12_000 : 8_000 }
        )

        let enabled = try #require(history(samples, settings: settings(stepInformedUpdates: true)).last)
        #expect(abs(enabled.stepAdjustmentKcal - 96) < 0.5)

        let disabled = try #require(history(samples).last)
        #expect(disabled.stepAdjustmentKcal == 0)
        #expect(abs(enabled.kcal - disabled.kcal - 96) <= 1)
    }

    @Test("Test The Step Nowcast Is Capped In Either Direction")
    func testTheStepNowcastIsCappedInEitherDirection() throws {
        let samples = days(
            60,
            intake: { _ in 2400 },
            weight: { _ in 80 },
            steps: { index in index >= 53 ? 100_000 : 2_000 }
        )
        let last = try #require(history(samples, settings: settings(stepInformedUpdates: true)).last)

        #expect(last.stepAdjustmentKcal == ExpenditureEngine.Constants.maxStepNowcastKcal)
    }

    // MARK: - 14. Today excluded

    @Test("Test A Sample Dated Today Is Ignored")
    func testASampleDatedTodayIsIgnored() {
        let base = maintenanceDays(60)
        let withToday = base + [DailySample(day: today, intakeKcal: 999_999, weightKg: 120, steps: 90_000)]

        #expect(history(withToday) == history(base))
    }

    // MARK: - 15. Determinism

    @Test("Test The Same Inputs Give The Same History Twice")
    func testTheSameInputsGiveTheSameHistoryTwice() {
        let samples = days(
            60,
            intake: { index in index % 3 == 0 ? nil : 2300 + Double(index) },
            weight: { index in index % 2 == 0 ? 80 - Double(index) / 100 : nil },
            steps: { index in 7_000 + index * 40 }
        )

        #expect(history(samples) == history(samples))
    }

    // MARK: - Malformed input

    /// `history(samples:...)` takes a plain array from whoever calls it. Two samples for one day
    /// is not something `ExpenditureSampleBuilder` can produce, but a trap is not an acceptable
    /// answer to a bad argument on a public entry point — the later sample wins and the replay
    /// carries on.
    @Test("Test Two Samples For One Day Do Not Trap")
    func testTwoSamplesForOneDayDoNotTrap() throws {
        let base = maintenanceDays(60)
        let duplicated = base + [
            DailySample(day: day(30, of: 60), intakeKcal: 2400, weightKg: 80, steps: nil)
        ]

        let last = try #require(history(duplicated).last)

        #expect(history(duplicated).count == 61)
        #expect(last.source == .adaptive)
        #expect(abs(last.kcal - 2400) < 15)
    }

    /// The later of two samples for a day is the one that counts, so a corrected reading wins over
    /// the one it corrects.
    @Test("Test The Later Of Two Samples For A Day Wins")
    func testTheLaterOfTwoSamplesForADayWins() throws {
        let base = maintenanceDays(30)
        let overridden = base + [DailySample(day: day(29, of: 30), intakeKcal: nil, weightKg: nil, steps: nil)]

        let last = try #require(history(overridden).last)

        // The window holds 28 days; yesterday's sample was replaced by an empty one, so 27 of
        // them are logged rather than all 28.
        #expect(last.loggedDays == 27)
    }

    // MARK: - Excluded, partial, fasting and broken-off days

    /// Rebuilds `samples` with `isExcluded` set on the days `shouldExclude` picks out.
    private func excluding(_ samples: [DailySample], where shouldExclude: (Int) -> Bool) -> [DailySample] {
        samples.enumerated().map { index, sample in
            DailySample(
                day: sample.day,
                intakeKcal: sample.intakeKcal,
                weightKg: sample.weightKg,
                steps: sample.steps,
                isExcluded: shouldExclude(index),
                isFastingDay: sample.isFastingDay
            )
        }
    }

    /// A partially logged day is evidence we do not have, so its intake is not read at all —
    /// however wild the figure on it happens to be.
    @Test("Test Excluded Days With Wild Intake Do Not Move The Estimate")
    func testExcludedDaysWithWildIntakeDoNotMoveTheEstimate() throws {
        let base = days(60, intake: { index in index >= 55 ? 6000 : 2400 }, weight: { _ in 80 })
        let excluded = excluding(base) { $0 >= 55 }

        let last = try #require(history(excluded).last)

        #expect(last.source == .adaptive)
        #expect(abs(last.kcal - 2400) < 15)
        // The same data without the exclusions is what the flag is saving the estimate from.
        let unguarded = try #require(history(base).last)
        #expect(unguarded.kcal > last.kcal + 100)
    }

    /// The scale did not stop being true because the food log did: an excluded day is unlogged
    /// for the intake, and still a weigh-in for the trend.
    @Test("Test An Excluded Day Still Counts As A Weigh In")
    func testAnExcludedDayStillCountsAsAWeighIn() throws {
        let excluded = excluding(maintenanceDays(60)) { $0 >= 53 }

        let last = try #require(history(excluded).last)

        #expect(last.loggedDays == 21)
        #expect(last.weighInCount == 28)
        #expect(last.trendWeightKg != nil)
    }

    /// A logged day under half the estimate looks like a forgotten meal, not a real intake, so the
    /// filter skips it — the same estimate as without it.
    @Test("Test A Day Logged Under Half The Estimate Is Read As Partial")
    func testADayLoggedUnderHalfTheEstimateIsReadAsPartial() throws {
        let base = maintenanceDays(40)
        let partial = days(40, intake: { $0 == 35 ? 300 : 2400 }, weight: { _ in 80 })

        let withPartial = try #require(history(partial).last)
        let without = try #require(history(base).last)
        #expect(withPartial.kcal == without.kcal)
        #expect(withPartial.loggedDays == without.loggedDays - 1)
    }

    /// A fasting day is evidence we do have. Marked as a fast, its zero is read and pulls the
    /// estimate down; unmarked, the same zero is read as a partly logged day and skipped.
    @Test("Test Marked Fasting Days Pull The Estimate Down")
    func testMarkedFastingDaysPullTheEstimateDown() throws {
        let marked = days(60, intake: { $0 >= 53 ? 0 : 2400 }, weight: { _ in 80 }).enumerated().map { index, sample in
            DailySample(day: sample.day, intakeKcal: sample.intakeKcal, weightKg: sample.weightKg, isFastingDay: index >= 53)
        }
        let fasted = try #require(history(marked).last)

        #expect(fasted.source == .adaptive)
        #expect(fasted.loggedDays == 28)
        #expect(fasted.kcal < 2350)

        let unmarked = try #require(history(days(60, intake: { $0 >= 53 ? 0 : 2400 }, weight: { _ in 80 })).last)
        #expect(unmarked.loggedDays == 21)
    }

    /// A week-long break takes a fully logged window under the 80% gate, and the estimate goes
    /// back to the formula until the logs catch up.
    @Test("Test A Week Long Break Can Send The Estimate Back To Calibrating")
    func testAWeekLongBreakCanSendTheEstimateBackToCalibrating() throws {
        let logged = maintenanceDays(60)
        let before = try #require(history(logged).last)
        #expect(before.isProvisional == false)

        let withBreak = excluding(logged) { $0 >= 53 }
        let after = try #require(history(withBreak).last)

        #expect(after.loggedDays == 21)
        #expect(after.isProvisional == true)
        #expect(after.source == .prior)
    }

    /// The flags default to false, so every sample built without them reads exactly as before.
    @Test("Test Exclusion And Fasting Default To Off")
    func testExclusionAndFastingDefaultToOff() {
        #expect(DailySample(day: today).isExcluded == false)
        #expect(DailySample(day: today).isFastingDay == false)
    }

    // MARK: - Adherence input

    @Test("Test Recent Intake Averages The Last Week's Complete Days")
    func testRecentIntakeAveragesTheLastWeeksCompleteDays() throws {
        let samples = days(40, intake: { $0 >= 33 ? 3000 : 2400 }, weight: { _ in 80 })
        let last = try #require(history(samples).last)

        #expect(last.recentIntakeKcal == 3000)
    }

    // MARK: - current(...)

    @Test("Test Current Is The Last Day Of The History")
    func testCurrentIsTheLastDayOfTheHistory() {
        let samples = maintenanceDays(60)
        let current = engine.current(
            samples: samples,
            priorKcal: prior,
            settings: settings(),
            today: today,
            calendar: calendar
        )

        #expect(current == history(samples).last)
    }
}
