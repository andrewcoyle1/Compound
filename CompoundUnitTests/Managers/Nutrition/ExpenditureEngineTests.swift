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
/// Every case here is one of the fifteen in `docs/specs/adaptive-expenditure.md` §6, in order.
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
        prior: Double? = nil
    ) -> [ExpenditureEstimate] {
        engine.history(
            samples: samples,
            priorKcal: prior ?? self.prior,
            settings: settings ?? self.settings(),
            today: today,
            calendar: calendar
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
    }

    // MARK: - 2. Below the minimum window

    @Test("Test Thirteen Days Of Perfect Data Is Still Provisional")
    func testThirteenDaysOfPerfectDataIsStillProvisional() {
        let result = history(maintenanceDays(13))

        #expect(result.last?.isProvisional == true)
        #expect(result.last?.source == .prior)
        #expect(result.last?.kcal == prior)
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

    // MARK: - 6. Sparse logging

    @Test("Test Fewer Than Half The Window's Days Logged Stays Provisional")
    func testFewerThanHalfTheWindowsDaysLoggedStaysProvisional() {
        let sparse = days(28, intake: { $0 < 10 ? 2400 : nil }, weight: { _ in 80 })
        let enough = days(28, intake: { $0 < 15 ? 2400 : nil }, weight: { _ in 80 })

        #expect(history(sparse).last?.isProvisional == true)
        #expect(history(enough).last?.isProvisional == false)
        #expect(history(enough).last?.loggedDays == 15)
    }

    // MARK: - 7. Weigh-in span

    @Test("Test Weigh-Ins Must Span A Week Before The Estimate Adapts")
    func testWeighInsMustSpanAWeekBeforeTheEstimateAdapts() {
        let wideEnough = days(28, intake: { _ in 2400 }, weight: { $0 >= 20 ? 80 : nil })
        let tooNarrow = days(28, intake: { _ in 2400 }, weight: { $0 >= 24 ? 80 : nil })

        #expect(history(wideEnough).last?.isProvisional == false)
        #expect(history(tooNarrow).last?.isProvisional == true)
    }

    // MARK: - 8. Outlier

    @Test("Test One Wild Weigh-In Barely Moves The Trend Or The Estimate")
    func testOneWildWeighInBarelyMovesTheTrendOrTheEstimate() throws {
        let samples = days(60, intake: { _ in 2400 }, weight: { $0 == 40 ? 95 : 80 })
        let result = history(samples)

        // `trendWeightKg` on day D is the trend as at D - 1, so these two read days 39 and 40.
        let before = try #require(result[40].trendWeightKg)
        let after = try #require(result[41].trendWeightKg)
        #expect(abs(after - before) < 0.25)

        let last = try #require(result.last)
        #expect(abs(last.kcal - 2400) < 20)
    }

    // MARK: - 9. Prior bound

    @Test("Test Garbage Logging Cannot Push The Estimate Below The Prior Band")
    func testGarbageLoggingCannotPushTheEstimateBelowThePriorBand() {
        let result = history(days(60, intake: { _ in 200 }, weight: { _ in 80 }))
        let floor = prior * ExpenditureEngine.Constants.priorBoundLow

        #expect(result.allSatisfy { $0.kcal >= floor })
        #expect(result.last?.kcal == floor)
    }

    // MARK: - 10. Daily step cap

    @Test("Test The Running Estimate Moves At Most One Cap Per Day")
    func testTheRunningEstimateMovesAtMostOneCapPerDay() throws {
        // Flat weight, so the raw estimate is the mean intake: 1000 above the prior.
        let result = history(maintenanceDays(20, intake: 3500))

        #expect(result[13].kcal == prior)
        #expect(result[13].isProvisional == true)
        #expect(result[14].isProvisional == false)
        #expect(result[14].kcal == prior + ExpenditureEngine.Constants.maxDailyStepKcal)
    }

    // MARK: - 11. Calculation start date

    @Test("Test A Start Date Restarts The Replay And The Sufficiency Count")
    func testAStartDateRestartsTheReplayAndTheSufficiencyCount() throws {
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
        let trend = try #require(result.last?.trendWeightKg)
        #expect(trend == 80)
    }

    // MARK: - 13. Step nowcast

    /// The spec's worked example reads the baseline as the 8,000-step stretch alone and lands on
    /// 160 kcal. The rule it is worked from compares the recent week against the **whole** window,
    /// which here already contains that week: 21 days at 8,000 and 7 at 12,000 average 9,000, so
    /// the gap is 3,000 steps and the nowcast is 120. The rule is what shipped; the arithmetic in
    /// the spec is what slipped.
    @Test("Test A Busier Week Than The Window Adds A Capped Step Nowcast")
    func testABusierWeekThanTheWindowAddsACappedStepNowcast() throws {
        let samples = days(
            60,
            intake: { _ in 2400 },
            weight: { _ in 80 },
            steps: { index in index >= 53 ? 12_000 : 8_000 }
        )

        let enabled = try #require(history(samples, settings: settings(stepInformedUpdates: true)).last)
        #expect(abs(enabled.stepAdjustmentKcal - 120) < 0.001)

        let disabled = try #require(history(samples).last)
        #expect(disabled.stepAdjustmentKcal == 0)
        #expect(enabled.kcal == (disabled.kcal + 120))
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

    // MARK: - Excluded, fasting and broken-off days

    /// Rebuilds `samples` with `isExcluded` set on the days `shouldExclude` picks out.
    private func excluding(_ samples: [DailySample], where shouldExclude: (Int) -> Bool) -> [DailySample] {
        samples.enumerated().map { index, sample in
            DailySample(
                day: sample.day,
                intakeKcal: sample.intakeKcal,
                weightKg: sample.weightKg,
                steps: sample.steps,
                isExcluded: shouldExclude(index)
            )
        }
    }

    /// A partially logged day is evidence we do not have, so its intake is not read at all —
    /// however wild the figure on it happens to be.
    @Test("Test Excluded Days With Wild Intake Do Not Move The Estimate")
    func testExcludedDaysWithWildIntakeDoNotMoveTheEstimate() throws {
        let base = days(60, intake: { index in index >= 50 ? 6000 : 2400 }, weight: { _ in 80 })
        let excluded = excluding(base) { $0 >= 50 }

        let last = try #require(history(excluded).last)

        #expect(last.source == .adaptive)
        #expect(abs(last.kcal - 2400) < 15)
        // The same data without the exclusions is what the guard is saving the estimate from.
        let unguarded = try #require(history(base).last)
        #expect(unguarded.kcal > last.kcal + 100)
    }

    /// The scale did not stop being true because the food log did: an excluded day is unlogged
    /// for the mean, and still a weigh-in for the trend.
    @Test("Test An Excluded Day Still Counts As A Weigh In")
    func testAnExcludedDayStillCountsAsAWeighIn() throws {
        let excluded = excluding(maintenanceDays(60)) { $0 >= 53 }

        let last = try #require(history(excluded).last)

        #expect(last.loggedDays == 21)
        #expect(last.weighInCount == 28)
        #expect(last.trendWeightKg != nil)
    }

    /// A fasting day is evidence we do have. It is a logged zero, not an absence, so it pulls the
    /// mean down rather than being imputed at the mean it is supposed to lower.
    @Test("Test Fasting Days Pull The Mean Down")
    func testFastingDaysPullTheMeanDown() throws {
        let fasted = days(60, intake: { index in index >= 53 ? 0 : 2400 }, weight: { _ in 80 })

        let last = try #require(history(fasted).last)

        #expect(last.source == .adaptive)
        #expect(last.loggedDays == 28)
        #expect(last.kcal < 2350)
        // And it is the zeros doing it, not the days going missing.
        let unlogged = days(60, intake: { index in index >= 53 ? nil : 2400 }, weight: { _ in 80 })
        let imputed = try #require(history(unlogged).last)
        #expect(imputed.kcal > last.kcal)
    }

    /// A week-long break on top of a half-logged fortnight takes the window under the
    /// logged-fraction guard, and the estimate goes back to carrying the prior forward.
    @Test("Test A Week Long Break Can Make The Window Insufficient")
    func testAWeekLongBreakCanMakeTheWindowInsufficient() throws {
        let halfLogged = days(60, intake: { index in index >= 45 ? 2400 : nil }, weight: { _ in 80 })

        // Fifteen logged days out of twenty-eight clears the guard on its own.
        let before = try #require(history(halfLogged).last)
        #expect(before.loggedDays == 15)
        #expect(before.isProvisional == false)

        let withBreak = excluding(halfLogged) { $0 >= 53 }
        let after = try #require(history(withBreak).last)

        #expect(after.loggedDays == 8)
        #expect(after.isProvisional == true)
        #expect(after.source == .prior)
    }

    /// The flag defaults to false, so every sample built without it reads exactly as before.
    @Test("Test Exclusion Defaults To Off")
    func testExclusionDefaultsToOff() {
        #expect(DailySample(day: today).isExcluded == false)
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
