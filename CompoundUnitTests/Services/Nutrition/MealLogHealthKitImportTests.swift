//
//  MealLogHealthKitImportTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 02/10/2026.
//

import Testing
import Foundation
@testable import Compound

#if canImport(HealthKit)

/// `MealLogManager`'s Apple Health import: one entry per day holding that day's energy and macro
/// totals, kept current as Health changes, and left out of the day when a meal is logged here.
///
/// The import's anchor is kept in UserDefaults per user, so each test signs in as a user of its own.
@MainActor
struct MealLogHealthKitImportTests {

    private static let today = Calendar.current.startOfDay(for: .now)
    private static let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

    private func food(_ calories: Double, protein: Double = 0, on day: Date, hour: Double = 12) -> MockNutritionSample {
        MockNutritionSample(nutrients: [.calories: calories, .protein: protein], date: day.addingTimeInterval(hour * 3600))
    }

    private func signedIn(_ health: MockHealthKitNutritionService, userId: String = UUID().uuidString) async -> MealLogManager {
        let manager = TestManagers.mealLogManager(healthKitService: health)
        await manager.signIn(userId: userId)
        return manager
    }

    private func calories(_ manager: MealLogManager, on day: Date) -> Double? {
        let meals = manager.getMeals(for: day.dayKey)
        return meals.isEmpty ? nil : meals.reduce(0) { $0 + $1.totalCalories }
    }

    @Test("Test Signing In Imports One Total Per Day")
    func testSigningInImportsOneTotalPerDay() async {
        let health = MockHealthKitNutritionService(samples: [
            food(500, protein: 30, on: Self.yesterday, hour: 8), food(700, protein: 40, on: Self.yesterday, hour: 19),
            food(400, on: Self.today)
        ])
        let manager = await signedIn(health)

        #expect(await TestManagers.eventually { manager.userMeals.count == 2 })
        #expect(calories(manager, on: Self.yesterday) == 1_200)
        #expect(manager.getDailyTotals(dayKey: Self.yesterday.dayKey).proteinGrams == 70)
        #expect(calories(manager, on: Self.today) == 400)
        #expect(manager.userMeals.allSatisfy { $0.isHealthKitImport })
    }

    @Test("Test More Food In Apple Health Updates The Day")
    func testMoreFoodInAppleHealthUpdatesTheDay() async {
        let health = MockHealthKitNutritionService(samples: [food(400, on: Self.today)])
        let manager = await signedIn(health)
        _ = await TestManagers.eventually { calories(manager, on: Self.today) == 400 }

        health.add(food(600, on: Self.today, hour: 18))

        #expect(await TestManagers.eventually { calories(manager, on: Self.today) == 1_000 })
        #expect(manager.userMeals.count == 1)
    }

    @Test("Test Food Deleted From Apple Health Leaves The Day")
    func testFoodDeletedFromAppleHealthLeavesTheDay() async {
        let lunch = food(400, on: Self.today)
        let health = MockHealthKitNutritionService(samples: [lunch])
        let manager = await signedIn(health)
        _ = await TestManagers.eventually { manager.userMeals.count == 1 }

        health.delete(lunch.uuid)

        #expect(await TestManagers.eventually { manager.userMeals.isEmpty })
    }

    /// Compound's own log wins, so food mirrored into Health by another app is not counted twice.
    /// The imported total is only hidden: deleting the meal logged here brings it back.
    @Test("Test A Meal Logged Here Hides The Day's Apple Health Total")
    func testAMealLoggedHereHidesTheDaysAppleHealthTotal() async throws {
        let userId = UUID().uuidString
        let health = MockHealthKitNutritionService(samples: [food(900, on: Self.today)])
        let manager = await signedIn(health, userId: userId)
        _ = await TestManagers.eventually { calories(manager, on: Self.today) == 900 }

        let logged = MealLogModel(authorId: userId, dayKey: Self.today.dayKey, date: .now, items: [MealItemModel.mock])
        try await manager.saveMeal(logged)

        #expect(await TestManagers.eventually { manager.userMeals.map(\.mealId) == [logged.mealId] })
        #expect(calories(manager, on: Self.today) == logged.totalCalories)

        try await manager.deleteMeal(id: logged.mealId)

        #expect(await TestManagers.eventually { calories(manager, on: Self.today) == 900 })
    }
}

#endif
