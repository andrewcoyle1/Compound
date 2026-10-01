//
//  MealLogModelTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// A logged meal and the items in it.
///
/// A meal's totals are derived, never stored, so every calorie the app shows for a day is this sum
/// run over whatever was logged. Each item carries a full nutrient snapshot taken when it was
/// logged, which is what keeps yesterday's total from changing when a food's data is later edited.
@MainActor
struct MealLogModelTests {

    private let date = Date(timeIntervalSince1970: 1_000_000)

    private func item(
        name: String = "Chicken Breast",
        nutrients: NutrientMap,
        amount: Double = 100,
        unit: String = "g"
    ) -> MealItemModel {
        MealItemModel(
            itemId: "item-\(name)",
            sourceType: .ingredient,
            sourceId: "source-1",
            displayName: name,
            amount: amount,
            unit: unit,
            resolvedGrams: amount,
            nutrients: nutrients
        )
    }

    private func meal(items: [MealItemModel]) -> MealLogModel {
        MealLogModel(
            mealId: "meal-1",
            authorId: "author-1",
            dayKey: "2026-09-20",
            date: date,
            items: items
        )
    }

    // MARK: - Totals

    @Test("Test A Meal Totals Its Items")
    func testAMealTotalsItsItems() {
        let meal = meal(items: [
            item(name: "Chicken", nutrients: [.calories: 165, .protein: 31, .carbs: 0, .fatTotal: 3.6]),
            item(name: "Rice", nutrients: [.calories: 130, .protein: 2.7, .carbs: 28, .fatTotal: 0.3])
        ])

        #expect(meal.totalCalories == 295)
        #expect(abs(meal.totalProteinGrams - 33.7) < 0.0001)
        #expect(meal.totalCarbGrams == 28)
        #expect(abs(meal.totalFatGrams - 3.9) < 0.0001)
    }

    @Test("Test One Item Is Its Own Total")
    func testOneItemIsItsOwnTotal() {
        let meal = meal(items: [item(nutrients: [.calories: 165, .protein: 31])])

        #expect(meal.totalCalories == 165)
        #expect(meal.totalProteinGrams == 31)
    }

    /// An empty meal is zero rather than nothing, so a draft meal shows "0 kcal" rather than a gap.
    @Test("Test An Empty Meal Totals Zero")
    func testAnEmptyMealTotalsZero() {
        let empty = meal(items: [])

        #expect(empty.totalCalories == 0)
        #expect(empty.totalProteinGrams == 0)
        #expect(empty.totalCarbGrams == 0)
        #expect(empty.totalFatGrams == 0)
    }

    /// A nutrient no item records totals zero through the macro accessors, but stays absent in the
    /// map itself — the meal has no data on it, which is not the same as containing none.
    @Test("Test An Unrecorded Nutrient Totals Zero But Stays Absent")
    func testAnUnrecordedNutrientTotalsZeroButStaysAbsent() {
        let meal = meal(items: [item(nutrients: [.calories: 165])])

        #expect(meal.totalProteinGrams == 0)
        #expect(meal.totalNutrients[.protein] == nil)
    }

    /// Micronutrients ride along with the macros, since each item carries a full snapshot.
    @Test("Test Micronutrients Total Too")
    func testMicronutrientsTotalToo() {
        let meal = meal(items: [
            item(name: "Spinach", nutrients: [.calories: 23, .ironMg: 2.7]),
            item(name: "Lentils", nutrients: [.calories: 116, .ironMg: 3.3])
        ])

        #expect(abs((meal.totalNutrients[.ironMg] ?? 0) - 6.0) < 0.0001)
    }

    /// The order items were added in must not change the total.
    @Test("Test The Total Does Not Depend On Item Order")
    func testTheTotalDoesNotDependOnItemOrder() {
        let chicken = item(name: "Chicken", nutrients: [.calories: 165, .protein: 31])
        let rice = item(name: "Rice", nutrients: [.calories: 130, .carbs: 28])

        #expect(meal(items: [chicken, rice]).totalCalories == meal(items: [rice, chicken]).totalCalories)
    }

    @Test("Test Adding An Item Changes The Total")
    func testAddingAnItemChangesTheTotal() {
        var meal = meal(items: [item(name: "Chicken", nutrients: [.calories: 165])])
        #expect(meal.totalCalories == 165)

        meal.items.append(item(name: "Rice", nutrients: [.calories: 130]))

        #expect(meal.totalCalories == 295)
    }

    // MARK: - Identity

    /// The meal is stored under its own id, and the day key is what a day's query matches on.
    @Test("Test A Meal Is Identified By Its Meal Id")
    func testAMealIsIdentifiedByItsMealId() {
        let meal = meal(items: [])

        #expect(meal.id == "meal-1")
        #expect(meal.id == meal.mealId)
        #expect(meal.dayKey == "2026-09-20")
    }

    @Test("Test A Meal Gets An Id When None Is Given")
    func testAMealGetsAnIdWhenNoneIsGiven() {
        let first = MealLogModel(authorId: "a", dayKey: "2026-09-20", date: date, items: [])
        let second = MealLogModel(authorId: "a", dayKey: "2026-09-20", date: date, items: [])

        #expect(!first.id.isEmpty)
        #expect(first.id != second.id)
    }

    // MARK: - Codable

    @Test("Test A Meal Round Trips With Its Items")
    func testAMealRoundTripsWithItsItems() throws {
        let original = meal(items: [
            item(name: "Chicken", nutrients: [.calories: 165, .protein: 31]),
            item(name: "Rice", nutrients: [.calories: 130, .carbs: 28])
        ])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(MealLogModel.self, from: data)

        #expect(decoded.mealId == original.mealId)
        #expect(decoded.dayKey == original.dayKey)
        #expect(decoded.items.count == 2)
        #expect(decoded.totalCalories == original.totalCalories)
        #expect(decoded.totalProteinGrams == original.totalProteinGrams)
    }

    @Test("Test The Encoded Keys Are Snake Case")
    func testTheEncodedKeysAreSnakeCase() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(meal(items: []))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["meal_id"] as? String == "meal-1")
        #expect(json?["author_id"] as? String == "author-1")
        #expect(json?["day_key"] as? String == "2026-09-20")
    }
}

/// A single food in a meal.
@MainActor
struct MealItemModelTests {

    private func item(nutrients: NutrientMap = [.calories: 165, .protein: 31]) -> MealItemModel {
        MealItemModel(
            itemId: "item-1",
            sourceType: .ingredient,
            sourceId: "source-1",
            displayName: "Chicken Breast",
            amount: 150,
            unit: "g",
            resolvedGrams: 150,
            nutrients: nutrients
        )
    }

    @Test("Test An Item Is Identified By Its Item Id")
    func testAnItemIsIdentifiedByItsItemId() {
        #expect(item().id == "item-1")
    }

    /// The amount the user typed is kept alongside the resolved grams, so the meal still reads
    /// "1 serving" rather than "150 g" when they open it again.
    @Test("Test An Item Keeps Both What Was Typed And What It Resolved To")
    func testAnItemKeepsBothWhatWasTypedAndWhatItResolvedTo() {
        let serving = MealItemModel(
            itemId: "item-1",
            sourceType: .recipe,
            sourceId: "recipe-1",
            displayName: "Porridge",
            amount: 1,
            unit: "serving",
            resolvedGrams: 250
        )

        #expect(serving.amount == 1)
        #expect(serving.unit == "serving")
        #expect(serving.resolvedGrams == 250)
    }

    @Test("Test The Macro Accessors Read The Snapshot")
    func testTheMacroAccessorsReadTheSnapshot() {
        let item = item(nutrients: [.calories: 165, .protein: 31, .carbs: 0, .fatTotal: 3.6])

        #expect(item.calories == 165)
        #expect(item.proteinGrams == 31)
        #expect(item.carbGrams == 0)
        #expect(item.fatGrams == 3.6)
    }

    @Test("Test An Item With No Nutrients Reads As Unrecorded")
    func testAnItemWithNoNutrientsReadsAsUnrecorded() {
        let item = item(nutrients: NutrientMap())

        #expect(item.calories == nil)
        #expect(item.proteinGrams == nil)
    }

    @Test("Test An Item Round Trips")
    func testAnItemRoundTrips() throws {
        let original = item()
        let decoded = try JSONDecoder().decode(MealItemModel.self, from: try JSONEncoder().encode(original))

        #expect(decoded.itemId == original.itemId)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.amount == original.amount)
        #expect(decoded.unit == original.unit)
        #expect(decoded.resolvedGrams == original.resolvedGrams)
        #expect(decoded.calories == original.calories)
        #expect(decoded.sourceType == original.sourceType)
    }
}
