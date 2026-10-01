//
//  MealLogManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// Reading a day's food out of the logged meals.
///
/// Everything nutrition shows — the rings, the daily totals, the Energy Balance chart — comes from
/// these few filters and sums. The day key is a plain string compared with `>=` and `<=`, which
/// works only because `dayKey` is zero-padded; that is the quiet dependency between this manager
/// and `Date+EXT` worth pinning from both sides.
@MainActor
struct MealLogManagerTests {

    private func item(calories: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0) -> MealItemModel {
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: "source-1",
            displayName: "Food",
            amount: 100,
            unit: "g",
            nutrients: [.calories: calories, .protein: protein, .carbs: carbs, .fatTotal: fat]
        )
    }

    private func meal(id: String, dayKey: String, items: [MealItemModel]) -> MealLogModel {
        MealLogModel(
            mealId: id,
            authorId: "author-1",
            dayKey: dayKey,
            date: Date(dayKey: dayKey) ?? Date(),
            items: items
        )
    }

    private var threeDays: [MealLogModel] {
        [
            meal(id: "m1", dayKey: "2026-09-18", items: [item(calories: 500, protein: 30)]),
            meal(id: "m2", dayKey: "2026-09-19", items: [item(calories: 600, protein: 40)]),
            meal(id: "m3", dayKey: "2026-09-19", items: [item(calories: 400, protein: 20)]),
            meal(id: "m4", dayKey: "2026-09-20", items: [item(calories: 700, protein: 50)])
        ]
    }

    // MARK: - Reading a day

    @Test("Test Meals Are Empty Until Signed In")
    func testMealsAreEmptyUntilSignedIn() {
        #expect(TestManagers.mealLogManager(meals: threeDays).userMeals.isEmpty)
    }

    @Test("Test A Day Returns Only Its Own Meals")
    func testADayReturnsOnlyItsOwnMeals() async {
        let manager = await TestManagers.signedInMealLogManager(meals: threeDays)

        #expect(manager.getMeals(for: "2026-09-19").map(\.id).sorted() == ["m2", "m3"])
        #expect(manager.getMeals(for: "2026-09-20").map(\.id) == ["m4"])
    }

    @Test("Test A Day With Nothing Logged Has No Meals")
    func testADayWithNothingLoggedHasNoMeals() async {
        let manager = await TestManagers.signedInMealLogManager(meals: threeDays)

        #expect(manager.getMeals(for: "2026-09-17").isEmpty)
        #expect(manager.getMeals(for: "2027-01-01").isEmpty)
    }

    // MARK: - Reading a range

    @Test("Test A Range Includes Both Ends")
    func testARangeIncludesBothEnds() async {
        let manager = await TestManagers.signedInMealLogManager(meals: threeDays)

        let meals = manager.getMeals(startDayKey: "2026-09-18", endDayKey: "2026-09-19")

        #expect(meals.map(\.id).sorted() == ["m1", "m2", "m3"])
    }

    @Test("Test A Single Day Range")
    func testASingleDayRange() async {
        let manager = await TestManagers.signedInMealLogManager(meals: threeDays)

        #expect(manager.getMeals(startDayKey: "2026-09-20", endDayKey: "2026-09-20").map(\.id) == ["m4"])
    }

    @Test("Test A Backwards Range Is Empty")
    func testABackwardsRangeIsEmpty() async {
        let manager = await TestManagers.signedInMealLogManager(meals: threeDays)

        #expect(manager.getMeals(startDayKey: "2026-09-20", endDayKey: "2026-09-18").isEmpty)
    }

    /// The range is a string comparison, which is only correct because day keys are zero-padded and
    /// year-first. A range crossing a month or year boundary is where an unpadded key would break.
    @Test("Test A Range Crosses Month And Year Boundaries")
    func testARangeCrossesMonthAndYearBoundaries() async {
        let meals = [
            meal(id: "dec", dayKey: "2025-12-31", items: [item(calories: 100)]),
            meal(id: "jan", dayKey: "2026-01-01", items: [item(calories: 200)]),
            meal(id: "feb", dayKey: "2026-02-01", items: [item(calories: 300)])
        ]
        let manager = await TestManagers.signedInMealLogManager(meals: meals)

        #expect(manager.getMeals(startDayKey: "2025-12-31", endDayKey: "2026-01-01").map(\.id).sorted() == ["dec", "jan"])
        #expect(manager.getMeals(startDayKey: "2026-01-01", endDayKey: "2026-12-31").map(\.id).sorted() == ["feb", "jan"])
    }

    // MARK: - Daily totals

    @Test("Test A Day's Totals Sum Its Meals")
    func testADaysTotalsSumItsMeals() async {
        let manager = await TestManagers.signedInMealLogManager(meals: threeDays)

        let totals = manager.getDailyTotals(dayKey: "2026-09-19")

        #expect(totals.calories == 1000)
        #expect(totals.proteinGrams == 60)
    }

    /// A day with nothing logged totals zero, which is what lets the rings show an empty day
    /// rather than nothing at all.
    @Test("Test A Day With Nothing Logged Totals Zero")
    func testADayWithNothingLoggedTotalsZero() async {
        let manager = await TestManagers.signedInMealLogManager(meals: threeDays)

        let totals = manager.getDailyTotals(dayKey: "2026-09-17")

        #expect(totals.calories == 0)
        #expect(totals.proteinGrams == 0)
        #expect(totals.carbGrams == 0)
        #expect(totals.fatGrams == 0)
    }

    // The zero-filled range of daily totals that Energy Balance reads lives on `CoreInteractor`,
    // not here — this manager only answers for one day at a time.

    // MARK: - Writing

    @Test("Test Saving A Meal Adds It")
    func testSavingAMealAddsIt() async throws {
        let manager = await TestManagers.signedInMealLogManager(meals: [])

        try await manager.saveMeal(meal(id: "new", dayKey: "2026-09-20", items: [item(calories: 300)]))

        let added = await TestManagers.eventually { manager.getMeals(for: "2026-09-20").count == 1 }
        #expect(added)
        #expect(manager.getDailyTotals(dayKey: "2026-09-20").calories == 300)
    }

    @Test("Test Deleting A Meal Removes It From Its Day")
    func testDeletingAMealRemovesItFromItsDay() async throws {
        let manager = await TestManagers.signedInMealLogManager(meals: threeDays)

        try await manager.deleteMeal(id: "m2")

        let removed = await TestManagers.eventually { manager.getMeals(for: "2026-09-19").count == 1 }
        #expect(removed)
        #expect(manager.getDailyTotals(dayKey: "2026-09-19").calories == 400)
    }

    // MARK: - The draft meal

    /// A meal being built is held apart from the logged ones, so an unfinished plate never counts
    /// towards the day.
    @Test("Test A Draft Meal Starts Empty And Does Not Count")
    func testADraftMealStartsEmptyAndDoesNotCount() async {
        let manager = await TestManagers.signedInMealLogManager(meals: threeDays)

        #expect(manager.draftMeal == nil)
        #expect(manager.getDailyTotals(dayKey: "2026-09-20").calories == 700)
    }

    @Test("Test A Draft Meal Is Kept Without Being Logged")
    func testADraftMealIsKeptWithoutBeingLogged() async throws {
        let manager = await TestManagers.signedInMealLogManager(meals: [])
        let draft = meal(id: "draft", dayKey: "2026-09-20", items: [item(calories: 900)])

        try manager.updateDraftMeal(draft)

        #expect(manager.draftMeal?.id == "draft")
        #expect(manager.getMeals(for: "2026-09-20").isEmpty)
        #expect(manager.getDailyTotals(dayKey: "2026-09-20").calories == 0)
    }

    @Test("Test Discarding A Draft Clears It")
    func testDiscardingADraftClearsIt() async throws {
        let manager = await TestManagers.signedInMealLogManager(meals: [])
        try manager.updateDraftMeal(meal(id: "draft", dayKey: "2026-09-20", items: []))
        #expect(manager.draftMeal != nil)

        try manager.deleteDraftMeal()

        #expect(manager.draftMeal == nil)
    }
}
