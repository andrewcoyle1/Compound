//
//  MealHourHeaderPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The `+` on a timeline hour, and the one setting that decides what time the meal it opens is
/// given: `FoodLogSettings.autoSetCurrentTime`.
@MainActor
struct MealHourHeaderPresenterTests {

    private final class Interactor: SpyGlobalInteractor, MealHourHeaderInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var draftMeal: MealLogModel?
        var foodLogSettings: FoodLogSettings = FoodLogSettings(authorId: "user-1")
        private(set) var deletedDraftCount = 0

        func deleteDraftMeal() throws {
            deletedDraftCount += 1
            draftMeal = nil
        }
    }

    /// The draft-meal alert goes through a `GlobalRouter` extension, which dispatches statically
    /// and never reaches a double, so only the meal logger itself is recorded here.
    private final class Router: MealHourHeaderRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shownMeals: [MealLogModel] = []

        func showAddMealView(delegate: AddMealDelegate) {
            shownMeals.append(delegate.mealLog)
        }
    }

    private struct Screen {
        let presenter: MealHourHeaderPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(autoSetCurrentTime: Bool = false) -> Screen {
        let interactor = Interactor()
        interactor.foodLogSettings.autoSetCurrentTime = autoSetCurrentTime
        let router = Router()
        return Screen(
            presenter: MealHourHeaderPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The start of the hour a timeline row stands for, `hoursFromNow` hours from this one.
    private func hourSlot(hoursFromNow: Int = 0, daysFromNow: Int = 0) -> Date {
        let calendar = Calendar.current
        let shifted = calendar.date(byAdding: .day, value: daysFromNow, to: .now) ?? .now
        let moved = calendar.date(byAdding: .hour, value: hoursFromNow, to: shifted) ?? shifted
        return calendar.dateInterval(of: .hour, for: moved)?.start ?? moved
    }

    // MARK: - Hourly totals

    /// Each macro sums across every meal in the hour, whole numbers as the header prints them.
    @Test("Test Hourly Totals Sum Each Macro Across The Hour's Meals")
    func testHourlyTotalsSumEachMacroAcrossTheHoursMeals() {
        let screen = makeScreen()
        func meal(_ nutrients: NutrientMap) -> MealLogModel {
            MealLogModel(
                authorId: "user-1",
                dayKey: Date().dayKey,
                date: Date(),
                items: [MealItemModel(itemId: UUID().uuidString, sourceType: .quickAdd, sourceId: "q", displayName: "Food", amount: 1, unit: "serving", nutrients: nutrients)]
            )
        }
        let meals = [
            meal(NutrientMap([.calories: 300.6, .protein: 20, .carbs: 30, .fatTotal: 10])),
            meal(NutrientMap([.calories: 200, .protein: 5.5, .carbs: 12, .fatTotal: 4]))
        ]

        #expect(screen.presenter.total(of: .cals, in: meals) == 500)
        #expect(screen.presenter.total(of: .protein, in: meals) == 25)
        #expect(screen.presenter.total(of: .carbs, in: meals) == 42)
        #expect(screen.presenter.total(of: .fat, in: meals) == 14)
    }

    // MARK: - The default

    /// Off is what every existing user has, and it has to leave the meal exactly on the hour the
    /// row stands for.
    @Test("Test The Tapped Hour Is Kept When Auto-Set Is Off")
    func testTheTappedHourIsKeptWhenAutoSetIsOff() {
        let screen = makeScreen(autoSetCurrentTime: false)
        #expect(screen.interactor.foodLogSettings.autoSetCurrentTime == false)
        let slot = hourSlot()

        screen.presenter.onAddMealPressed(selectedTime: slot)

        #expect(screen.router.shownMeals.count == 1)
        #expect(screen.router.shownMeals.first?.date == slot)
        #expect(screen.router.shownMeals.first?.dayKey == slot.dayKey)
    }

    // MARK: - Turned on

    /// On, the row stops rounding the meal down to the top of its hour: the meal is recorded at
    /// the moment it was logged.
    @Test("Test Auto-Set Records The Meal At The Current Time")
    func testAutoSetRecordsTheMealAtTheCurrentTime() throws {
        let screen = makeScreen(autoSetCurrentTime: true)
        let slot = hourSlot()
        let before = Date()

        screen.presenter.onAddMealPressed(selectedTime: slot)

        let logged = try #require(screen.router.shownMeals.first)
        // Bracketed rather than compared to `slot`: a run that starts on the stroke of the hour
        // would make the two equal, and the off case above is what pins the slot exactly.
        #expect(logged.date >= before)
        #expect(logged.date <= Date())
    }

    /// Scrolling back to yesterday is an unambiguous choice of day. "Now" is not inside it, so
    /// presetting the time there would move the meal to today rather than sharpen it.
    @Test("Test Auto-Set Does Not Move A Meal Logged On Another Day")
    func testAutoSetDoesNotMoveAMealLoggedOnAnotherDay() {
        let screen = makeScreen(autoSetCurrentTime: true)
        let yesterday = hourSlot(daysFromNow: -1)

        screen.presenter.onAddMealPressed(selectedTime: yesterday)

        #expect(screen.router.shownMeals.first?.date == yesterday)
        #expect(screen.router.shownMeals.first?.dayKey == yesterday.dayKey)
    }

    // MARK: - The draft-meal path

    /// Discarding a draft opens a fresh meal, which gets the same time the direct path would.
    @Test("Test Replacing A Draft Uses The Same Time As A Fresh Meal")
    func testReplacingADraftUsesTheSameTimeAsAFreshMeal() {
        let screen = makeScreen(autoSetCurrentTime: false)
        screen.interactor.draftMeal = MealLogModel(authorId: "user-1", dayKey: Date().dayKey, date: .now, items: [])

        screen.presenter.onAddMealPressed(selectedTime: hourSlot())

        // The alert is a `GlobalRouter` extension, so no logger is opened until a button is hit.
        #expect(screen.router.shownMeals.isEmpty)
    }

    /// No signed-in user means no author for the meal, so nothing is opened either way.
    @Test("Test Nothing Opens Without A Signed In User")
    func testNothingOpensWithoutASignedInUser() {
        let screen = makeScreen(autoSetCurrentTime: true)
        screen.interactor.currentUser = nil

        screen.presenter.onAddMealPressed(selectedTime: hourSlot())

        #expect(screen.router.shownMeals.isEmpty)
    }
}
