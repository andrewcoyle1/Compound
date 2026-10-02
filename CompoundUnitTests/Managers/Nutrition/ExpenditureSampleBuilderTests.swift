//
//  ExpenditureSampleBuilderTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The gathering half of adaptive expenditure: three logs in, one sample per day out.
///
/// Driven through real managers rather than arrays, because the interesting failures are in the
/// join — a meal whose `dayKey` disagrees with its `date`, a deleted weigh-in still in the
/// collection, two step records for one day — and those only exist once the data has been through
/// a sync engine.
@MainActor
struct ExpenditureSampleBuilderTests {

    // MARK: - Fixtures

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: Date()) }

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    }

    private func meal(daysAgo: Int, calories: Double) -> MealLogModel {
        let date = day(daysAgo)
        return MealLogModel(
            authorId: "author-1",
            dayKey: date.dayKey,
            date: date,
            items: [
                MealItemModel(
                    itemId: UUID().uuidString,
                    sourceType: .ingredient,
                    sourceId: "source-1",
                    displayName: "Anything",
                    amount: 100,
                    unit: "g",
                    resolvedGrams: 100,
                    nutrients: NutrientMap([.calories: calories])
                )
            ]
        )
    }

    private func weighIn(daysAgo: Int, weightKg: Double?, deleted: Bool = false) -> BodyMeasurementEntry {
        BodyMeasurementEntry(
            authorId: "author-1",
            weightKg: weightKg,
            date: day(daysAgo),
            deletedAt: deleted ? Date() : nil
        )
    }

    private func steps(daysAgo: Int, number: Int, deleted: Bool = false) -> StepsModel {
        StepsModel(
            authorId: "author-1",
            number: number,
            date: day(daysAgo),
            deletedAt: deleted ? Date() : nil
        )
    }

    private func samples(
        meals: [MealLogModel] = [],
        entries: [BodyMeasurementEntry] = [],
        stepRecords: [StepsModel] = []
    ) async -> [DailySample] {
        let mealLogs = await TestManagers.signedInMealLogManager(meals: meals)
        let body = await TestManagers.signedInBodyMeasurementsManager(entries: entries)
        let stepsManager = await TestManagers.signedInStepsManager(entries: stepRecords)

        return ExpenditureSampleBuilder.samples(
            mealLogs: mealLogs.userMeals,
            measurements: body.bodyMeasurements,
            steps: stepsManager.stepsHistory,
            today: Date(),
            calendar: calendar
        )
    }

    // MARK: - Tests

    @Test("Test Meal Calories Are Summed Per Day")
    func testMealCaloriesAreSummedPerDay() async throws {
        let result = await samples(meals: [
            meal(daysAgo: 2, calories: 600),
            meal(daysAgo: 2, calories: 400),
            meal(daysAgo: 1, calories: 1800)
        ])

        #expect(result.count == 2)
        #expect(result.first?.intakeKcal == 1000)
        #expect(result.last?.intakeKcal == 1800)
    }

    @Test("Test A Day With No Meal Log Is Unlogged Rather Than Zero")
    func testADayWithNoMealLogIsUnloggedRatherThanZero() async throws {
        let result = await samples(meals: [
            meal(daysAgo: 3, calories: 2000),
            meal(daysAgo: 1, calories: 2000)
        ])

        #expect(result.count == 3)
        #expect(result[1].intakeKcal == nil)
    }

    @Test("Test A Meal Logging Zero Calories Still Counts As Logged")
    func testAMealLoggingZeroCaloriesStillCountsAsLogged() async throws {
        let result = await samples(meals: [meal(daysAgo: 1, calories: 0)])

        #expect(result.count == 1)
        #expect(result.first?.intakeKcal == 0)
    }

    @Test("Test Several Weigh-Ins In One Day Are Averaged")
    func testSeveralWeighInsInOneDayAreAveraged() async throws {
        let result = await samples(entries: [
            weighIn(daysAgo: 1, weightKg: 80),
            weighIn(daysAgo: 1, weightKg: 82)
        ])

        #expect(result.first?.weightKg == 81)
    }

    @Test("Test Deleted And Weightless Entries Are Skipped")
    func testDeletedAndWeightlessEntriesAreSkipped() async throws {
        let result = await samples(entries: [
            weighIn(daysAgo: 2, weightKg: 80),
            weighIn(daysAgo: 1, weightKg: 99, deleted: true),
            weighIn(daysAgo: 1, weightKg: nil)
        ])

        #expect(result.count == 2)
        #expect(result[0].weightKg == 80)
        #expect(result[1].weightKg == nil)
    }

    @Test("Test The Largest Steps Record For A Day Wins")
    func testTheLargestStepsRecordForADayWins() async throws {
        let result = await samples(stepRecords: [
            steps(daysAgo: 1, number: 4_000),
            steps(daysAgo: 1, number: 11_000),
            steps(daysAgo: 1, number: 90_000, deleted: true)
        ])

        #expect(result.first?.steps == 11_000)
    }

    @Test("Test Today Is Never A Sample")
    func testTodayIsNeverASample() async throws {
        let result = await samples(
            meals: [meal(daysAgo: 0, calories: 5000), meal(daysAgo: 1, calories: 2000)],
            entries: [weighIn(daysAgo: 0, weightKg: 120)]
        )

        #expect(result.count == 1)
        #expect(result.first?.day == day(1))
        #expect(result.first?.intakeKcal == 2000)
    }

    @Test("Test No Data At All Gives No Samples")
    func testNoDataAtAllGivesNoSamples() async throws {
        let result = await samples()

        #expect(result.isEmpty)
    }
}
