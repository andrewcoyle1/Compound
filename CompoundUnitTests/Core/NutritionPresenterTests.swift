//
//  NutritionPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The Nutrition tab — the day's timeline, its macro rings and the calendar strip above it.
///
/// Almost everything on this screen is derived rather than stored: the totals are a sum over the
/// day's items, the target is a lookup into a seven-day plan, and the timeline is built from the
/// user's own hour window. Each of those quietly returns something empty when its input is
/// missing, so the tests below pin what the screen shows when there is nothing to show as closely
/// as what it shows when there is.
@MainActor
struct NutritionPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, NutritionInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var userMeals: [MealLogModel] = []
        var draftMeal: MealLogModel?
        var currentDietPlan: DietPlan?
        var userImageUrl: String?
        var foodLogSettings = FoodLogSettings(authorId: "user-1")
        var foods: [FoodModel] = []
        var userRecipeTemplates: [RecipeTemplateModel] = []

        func canRequestHealthDataAuthorisation() -> Bool { false }
        func requestHealthKitAuthorisation(for scope: HealthDataScope) async throws { }
        func syncNutritionFromHealthKit() async { }

        /// Keyed by day, the way `MealLogManager` serves the screen.
        var mealsByDayKey: [String: [MealLogModel]] = [:]
        var totalsByDayKey: [String: DailyMacroTarget] = [:]

        private(set) var addedMeals: [MealLogModel] = []
        private(set) var deletedMealIds: [String] = []
        var writeError: Error?

        // MARK: ReminderOfferInteractor — the meal-reminder offer on this screen's first appear.
        var privateUserSettings = PrivateUserSettings()
        var weeklyStreak = WeeklyStreak.fixture(weeks: 0)
        func canRequestNotificationAuthorisation() async -> Bool { false }
        func requestPushAuthorisation() async throws -> Bool { true }
        func setMealReminders(isEnabled: Bool) async throws { }
        func setStreakReminder(isEnabled: Bool) async throws { }

        func getMeals(for dayKey: String) throws -> [MealLogModel] {
            mealsByDayKey[dayKey] ?? []
        }

        func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
            guard let totals = totalsByDayKey[dayKey] else { throw URLError(.fileDoesNotExist) }
            return totals
        }

        func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget? { nil }

        func addMeal(_ meal: MealLogModel) async throws {
            if let writeError { throw writeError }
            addedMeals.append(meal)
        }

        func deleteDraftMeal() throws { }

        func deleteMealAndSync(id: String, dayKey: String, authorId: String) async throws {
            if let writeError { throw writeError }
            deletedMealIds.append(id)
        }
    }

    private final class Router: NutritionRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var amountDelegates: [MealItemAmountViewDelegate] = []

        // The test target builds without -DDEV, so this cannot be wrapped in the same `#if` the
        // protocol declares it under — the conformance would be missing a requirement the app
        // module compiled in.
        func showDevSettingsView() { shown.append("devSettings") }

        func showMealDetailView(delegate: MealDetailDelegate) { shown.append("mealDetail") }
        func showMealItemAmountViewView(delegate: MealItemAmountViewDelegate) {
            shown.append("mealItemAmount")
            amountDelegates.append(delegate)
        }
        func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID) { shown.append("profile") }
        func showTimelineActionsView(delegate: TimelineActionsDelegate) { shown.append("timelineActions") }
        func showFoodLogSettingsView(delegate: FoodLogSettingsDelegate) { shown.append("foodLogSettings") }
        func showNutritionOverviewView(delegate: NutritionOverviewDelegate) { shown.append("nutritionOverview") }
        func showFoodsView() { shown.append("foods") }
        func showRecipesView() { shown.append("recipes") }
        func showFoodDetailView(delegate: FoodDetailDelegate) { shown.append("foodDetail") }
        func showRecipeDetailView(delegate: RecipeDetailDelegate) { shown.append("recipeDetail") }
        private(set) var addMealDelegates: [AddMealDelegate] = []
        func showAddMealView(delegate: AddMealDelegate) {
            shown.append("addMeal")
            addMealDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: NutritionPresenter
        let interactor: Interactor
        let router: Router
    }

    // MARK: - Fixtures

    /// Monday 21 September 2026, 12:00 UTC. A fixed weekday matters: the plan is indexed by one.
    private var monday: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 21
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    private func item(id: String, calories: Double) -> MealItemModel {
        MealItemModel(
            itemId: id,
            sourceType: .ingredient,
            sourceId: "source-1",
            displayName: "Food \(id)",
            amount: 100,
            unit: "g",
            resolvedGrams: 100,
            nutrients: NutrientMap([.calories: calories])
        )
    }

    private func meal(id: String, at date: Date, items: [MealItemModel]) -> MealLogModel {
        MealLogModel(mealId: id, authorId: "author-1", dayKey: date.dayKey, date: date, items: items)
    }

    /// A meal on the selected day at a given hour, carrying one item.
    private func meal(id: String, hour: Int, calories: Double = 100) -> MealLogModel {
        let date = Calendar.current.date(bySettingHour: hour, minute: 30, second: 0, of: monday)!
        return meal(id: id, at: date, items: [item(id: "\(id)-item", calories: calories)])
    }

    private func plan(days: [DailyMacroTarget]) -> DietPlan {
        DietPlan(
            planId: "plan-1",
            userId: "user-1",
            createdAt: monday,
            tdeeEstimate: 2500,
            preferredDiet: "Balanced",
            calorieFloor: "1800",
            trainingType: "Strength",
            calorieDistribution: "40/30/30",
            proteinIntake: "High",
            days: days
        )
    }

    /// Seven distinguishable days, so an off-by-one in the weekday lookup names the wrong one.
    private var weekOfTargets: [DailyMacroTarget] {
        var targets: [DailyMacroTarget] = []
        for index in 0..<7 {
            let offset = Double(index)
            targets.append(
                DailyMacroTarget(
                    calories: 2000 + offset,
                    proteinGrams: 100 + offset,
                    carbGrams: 200 + offset,
                    fatGrams: 50 + offset
                )
            )
        }
        return targets
    }

    private func makeScreen(
        date: Date? = nil,
        meals: [MealLogModel] = [],
        totals: DailyMacroTarget? = nil,
        plan: DietPlan? = nil,
        settings: FoodLogSettings? = nil
    ) -> Screen {
        let interactor = Interactor()
        let day = date ?? monday
        interactor.mealsByDayKey[day.dayKey] = meals
        interactor.userMeals = meals
        if let totals { interactor.totalsByDayKey[day.dayKey] = totals }
        interactor.currentDietPlan = plan
        if let settings { interactor.foodLogSettings = settings }

        let router = Router()
        let presenter = NutritionPresenter(interactor: interactor, router: router)
        presenter.selectedDate = day
        return Screen(presenter: presenter, interactor: interactor, router: router)
    }

    // MARK: - The plan's weekday lookup

    /// The plan holds seven days starting Monday, but `Calendar` numbers weekdays from Sunday.
    /// Every day has to land on its own target — an off-by-one here shows the user the wrong
    /// calorie goal all day and is invisible unless the targets differ.
    @Test("Test Each Weekday Reads Its Own Target")
    func testEachWeekdayReadsItsOwnTarget() {
        let targets = weekOfTargets
        let calendar = Calendar.current

        // Monday through Sunday, in plan order.
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: monday)!
            let screen = makeScreen(date: day, plan: plan(days: targets))

            #expect(
                screen.presenter.dailyTarget == targets[offset],
                "day \(offset) after Monday read target \(String(describing: screen.presenter.dailyTarget?.calories))"
            )
        }
    }

    /// Without a plan there is no target, so the rings have nothing to fill toward.
    @Test("Test No Plan Means No Target")
    func testNoPlanMeansNoTarget() {
        let screen = makeScreen(plan: nil)

        #expect(screen.presenter.dailyTarget == nil)
    }

    /// A plan short of seven days must not index past its own array.
    @Test("Test A Short Plan Does Not Overrun")
    func testAShortPlanDoesNotOverrun() {
        let calendar = Calendar.current
        // Sunday is index 6, the last slot — a two-day plan has nothing there.
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
        let screen = makeScreen(date: sunday, plan: plan(days: Array(weekOfTargets.prefix(2))))

        #expect(screen.presenter.dailyTarget == nil)
    }

    // MARK: - Macro rings

    /// Each ring reports its own macro against its own target.
    @Test("Test Rings Report Their Own Macro")
    func testRingsReportTheirOwnMacro() {
        let target = DailyMacroTarget(calories: 2000, proteinGrams: 100, carbGrams: 200, fatGrams: 50)
        let logged = DailyMacroTarget(calories: 1000, proteinGrams: 25, carbGrams: 100, fatGrams: 25)
        let screen = makeScreen(totals: logged, plan: plan(days: Array(repeating: target, count: 7)))

        #expect(screen.presenter.caloriePercentage == 0.5)
        #expect(screen.presenter.proteinPercentage == 0.25)
        #expect(screen.presenter.carbsPercentage == 0.5)
        #expect(screen.presenter.fatPercentage == 0.5)
    }

    /// With no target, a ring reads 0 rather than dividing by zero.
    @Test("Test Rings Read Zero Without A Target")
    func testRingsReadZeroWithoutATarget() {
        let screen = makeScreen(totals: DailyMacroTarget(calories: 500, proteinGrams: 20, carbGrams: 50, fatGrams: 10))

        #expect(screen.presenter.caloriePercentage == 0)
        #expect(screen.presenter.proteinPercentage == 0)
        #expect(screen.presenter.carbsPercentage == 0)
        #expect(screen.presenter.fatPercentage == 0)
    }

    /// A target of zero is not a division — it is a day with no goal set.
    @Test("Test A Zero Target Does Not Divide")
    func testAZeroTargetDoesNotDivide() {
        let zero = DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)
        let screen = makeScreen(
            totals: DailyMacroTarget(calories: 500, proteinGrams: 20, carbGrams: 50, fatGrams: 10),
            plan: plan(days: Array(repeating: zero, count: 7))
        )

        #expect(screen.presenter.caloriePercentage == 0)
        #expect(screen.presenter.proteinPercentage == 0)
    }

    /// Logging past the goal keeps counting, so the ring can report an overage.
    @Test("Test Going Over The Target Reports Over One")
    func testGoingOverTheTargetReportsOverOne() {
        let target = DailyMacroTarget(calories: 2000, proteinGrams: 100, carbGrams: 200, fatGrams: 50)
        let logged = DailyMacroTarget(calories: 2500, proteinGrams: 100, carbGrams: 200, fatGrams: 50)
        let screen = makeScreen(totals: logged, plan: plan(days: Array(repeating: target, count: 7)))

        #expect(screen.presenter.caloriePercentage == 1.25)
    }

    /// A day whose totals cannot be read shows nothing logged rather than failing.
    @Test("Test A Day With No Totals Reads Empty")
    func testADayWithNoTotalsReadsEmpty() {
        let target = DailyMacroTarget(calories: 2000, proteinGrams: 100, carbGrams: 200, fatGrams: 50)
        let screen = makeScreen(totals: nil, plan: plan(days: Array(repeating: target, count: 7)))

        #expect(screen.presenter.dailyTotals == nil)
        #expect(screen.presenter.caloriePercentage == 0)
    }

    /// The header is handed the setting rather than reaching for it, so this is the one place it
    /// can be dropped on the way through.
    @Test("Test Show Overages Reaches The Macro Header")
    func testShowOveragesReachesTheMacroHeader() {
        #expect(makeScreen().presenter.showOverages == false)

        var settings = FoodLogSettings(authorId: "user-1")
        settings.showOverages = true
        #expect(makeScreen(settings: settings).presenter.showOverages)
    }

    // MARK: - The timeline

    /// The timeline spans the user's own window, one row per hour, ends included.
    @Test("Test The Timeline Spans The Configured Hours")
    func testTheTimelineSpansTheConfiguredHours() {
        var settings = FoodLogSettings(authorId: "user-1")
        settings.startHour = 8
        settings.endHour = 11
        settings.hideEmptyHours = false
        let screen = makeScreen(settings: settings)

        let hours = screen.presenter.timelineHours

        #expect(hours.count == 4)
        #expect(hours.map { Calendar.current.component(.hour, from: $0.hour) } == [8, 9, 10, 11])
    }

    /// A meal lands in the hour it was logged in, not the one before or after.
    @Test("Test A Meal Lands In Its Own Hour")
    func testAMealLandsInItsOwnHour() {
        var settings = FoodLogSettings(authorId: "user-1")
        settings.startHour = 8
        settings.endHour = 11
        let screen = makeScreen(meals: [meal(id: "m1", hour: 9)], settings: settings)

        let hours = screen.presenter.timelineHours
        let nine = hours.first { Calendar.current.component(.hour, from: $0.hour) == 9 }

        #expect(nine?.meals.map(\.mealId) == ["m1"])
        #expect(hours.filter { !$0.meals.isEmpty }.count == 1)
    }

    /// Several meals in one hour share its row.
    @Test("Test Meals In The Same Hour Share A Row")
    func testMealsInTheSameHourShareARow() {
        var settings = FoodLogSettings(authorId: "user-1")
        settings.startHour = 8
        settings.endHour = 11
        let screen = makeScreen(meals: [meal(id: "m1", hour: 9), meal(id: "m2", hour: 9)], settings: settings)

        let nine = screen.presenter.timelineHours.first { Calendar.current.component(.hour, from: $0.hour) == 9 }

        #expect(nine?.meals.count == 2)
    }

    /// With empty hours hidden, only the hours that hold something are drawn.
    @Test("Test Hiding Empty Hours Leaves Only Logged Ones")
    func testHidingEmptyHoursLeavesOnlyLoggedOnes() {
        var settings = FoodLogSettings(authorId: "user-1")
        settings.startHour = 8
        settings.endHour = 20
        settings.hideEmptyHours = true
        let screen = makeScreen(meals: [meal(id: "m1", hour: 9), meal(id: "m2", hour: 13)], settings: settings)

        let hours = screen.presenter.timelineHours

        #expect(hours.count == 2)
        #expect(hours.map { Calendar.current.component(.hour, from: $0.hour) } == [9, 13])
    }

    /// A window that ends before it starts has no hours in it, rather than looping forever.
    @Test("Test An Inverted Window Produces No Hours")
    func testAnInvertedWindowProducesNoHours() {
        var settings = FoodLogSettings(authorId: "user-1")
        settings.startHour = 20
        settings.endHour = 8
        let screen = makeScreen(settings: settings)

        #expect(screen.presenter.timelineHours.isEmpty)
    }

    /// A meal logged outside the configured window is still shown, in its own hour.
    ///
    /// It counts toward the day's totals and marks the calendar either way, so leaving it off the
    /// timeline made it unreachable: a 2am snack under the default 7–23 window could not be
    /// edited or deleted from this screen.
    @Test("Test A Meal Outside The Window Is Still Shown")
    func testAMealOutsideTheWindowIsStillShown() {
        var settings = FoodLogSettings(authorId: "user-1")
        settings.startHour = 7
        settings.endHour = 23
        let snack = meal(id: "snack", hour: 2, calories: 400)
        let screen = makeScreen(meals: [snack], settings: settings)

        let hours = screen.presenter.timelineHours
        let snackHour = hours.first { Calendar.current.component(.hour, from: $0.hour) == 2 }

        #expect(snackHour?.meals.map(\.mealId) == ["snack"])
        // It sorts ahead of the configured window rather than being appended after it.
        #expect(hours.first?.id == snackHour?.id)
        #expect(screen.presenter.mealsForSelectedDate.map(\.mealId) == ["snack"])
    }

    /// Out-of-window meals are shown with empty hours hidden too — that setting drops empty hours,
    /// not logged ones.
    @Test("Test Hiding Empty Hours Still Shows An Out Of Window Meal")
    func testHidingEmptyHoursStillShowsAnOutOfWindowMeal() {
        var settings = FoodLogSettings(authorId: "user-1")
        settings.startHour = 7
        settings.endHour = 23
        settings.hideEmptyHours = true
        let screen = makeScreen(meals: [meal(id: "snack", hour: 2), meal(id: "lunch", hour: 13)], settings: settings)

        let hours = screen.presenter.timelineHours

        #expect(hours.map { Calendar.current.component(.hour, from: $0.hour) } == [2, 13])
    }

    /// The window still governs the empty scaffolding: an hour with nothing in it outside the
    /// window is not drawn.
    @Test("Test Empty Hours Outside The Window Are Not Drawn")
    func testEmptyHoursOutsideTheWindowAreNotDrawn() {
        var settings = FoodLogSettings(authorId: "user-1")
        settings.startHour = 8
        settings.endHour = 10
        let screen = makeScreen(meals: [meal(id: "snack", hour: 2)], settings: settings)

        let hours = screen.presenter.timelineHours.map { Calendar.current.component(.hour, from: $0.hour) }

        #expect(hours == [2, 8, 9, 10])
    }

    /// Only the selected day is shown; yesterday's meals belong to yesterday's timeline.
    @Test("Test Another Days Meals Are Not Shown")
    func testAnotherDaysMealsAreNotShown() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: monday)!
        let screen = makeScreen(meals: [meal(id: "today", hour: 9)])
        screen.interactor.mealsByDayKey[yesterday.dayKey] = [meal(id: "yesterday", at: yesterday, items: [])]

        #expect(screen.presenter.mealsForSelectedDate.map(\.mealId) == ["today"])
    }

    // MARK: - Row style

    /// Only a meal's first item prints a time, so items logged together read as one block.
    @Test("Test Only The First Item In A Meal Carries A Time")
    func testOnlyTheFirstItemInAMealCarriesATime() {
        let first = item(id: "a", calories: 100)
        let second = item(id: "b", calories: 200)
        let logged = meal(id: "m1", at: monday, items: [first, second])
        let screen = makeScreen()

        #expect(screen.presenter.timestamp(for: first, in: logged) == logged.date)
        #expect(screen.presenter.timestamp(for: second, in: logged) == nil)
    }

    /// Hiding food details collapses the row whatever the individual toggles say — otherwise the
    /// master switch would be overridden by the settings beneath it.
    @Test("Test Hiding Details Overrides The Individual Toggles")
    func testHidingDetailsOverridesTheIndividualToggles() {
        var settings = FoodLogSettings(authorId: "user-1")
        settings.hideFoodDetails = true
        settings.showFoodImageInTimeline = true
        settings.showCaloriesInTimeline = true
        settings.showMacrosInTimeline = true
        let screen = makeScreen(settings: settings)

        #expect(screen.presenter.showFoodImageInTimeline == false)
        #expect(screen.presenter.showCaloriesInTimeline == false)
        #expect(screen.presenter.showMacrosInTimeline == false)
        #expect(screen.presenter.mealItemRowStyle.showsImage == false)
    }

    // MARK: - Deleting

    /// Removing one item of several rewrites the meal and keeps the rest.
    @Test("Test Deleting One Item Keeps The Meal")
    func testDeletingOneItemKeepsTheMeal() async {
        let first = item(id: "a", calories: 100)
        let second = item(id: "b", calories: 200)
        let logged = meal(id: "m1", at: monday, items: [first, second])
        let screen = makeScreen(meals: [logged])

        screen.presenter.deleteMealItem(first, from: logged)
        await TestManagers.eventually { !screen.interactor.addedMeals.isEmpty }

        #expect(screen.interactor.deletedMealIds.isEmpty)
        #expect(screen.interactor.addedMeals.first?.items.map(\.itemId) == ["b"])
    }

    /// Removing the last item removes the meal — an empty meal is not a thing to keep.
    @Test("Test Deleting The Last Item Deletes The Meal")
    func testDeletingTheLastItemDeletesTheMeal() async {
        let only = item(id: "a", calories: 100)
        let logged = meal(id: "m1", at: monday, items: [only])
        let screen = makeScreen(meals: [logged])

        screen.presenter.deleteMealItem(only, from: logged)
        await TestManagers.eventually { !screen.interactor.deletedMealIds.isEmpty }

        #expect(screen.interactor.deletedMealIds == ["m1"])
        #expect(screen.interactor.addedMeals.isEmpty)
    }

    /// Deleting a whole meal removes it outright.
    @Test("Test Deleting A Meal Removes It")
    func testDeletingAMealRemovesIt() async {
        let logged = meal(id: "m1", hour: 9)
        let screen = makeScreen(meals: [logged])

        screen.presenter.deleteMeal(logged)
        await TestManagers.eventually { !screen.interactor.deletedMealIds.isEmpty }

        #expect(screen.interactor.deletedMealIds == ["m1"])
    }

    /// A failed delete is reported rather than swallowed, and the meal stays put.
    ///
    /// The alert itself is not observable from here: `showAlert(error:)` is a `GlobalRouter`
    /// extension rather than a protocol requirement, so the presenter's call dispatches
    /// statically to the extension and never reaches a double that redeclares it. The severe
    /// event logged alongside it is the signal this pins.
    @Test("Test A Failed Delete Is Reported")
    func testAFailedDeleteIsReported() async {
        let logged = meal(id: "m1", hour: 9)
        let screen = makeScreen(meals: [logged])
        screen.interactor.writeError = URLError(.notConnectedToInternet)

        screen.presenter.deleteMeal(logged)
        await TestManagers.eventually { screen.interactor.trackedEventNames.contains("NutritionView_SaveMeal_Fail") }

        #expect(screen.interactor.trackedEventNames.contains("NutritionView_SaveMeal_Fail"))
        #expect(screen.interactor.trackedEventNames.contains("NutritionView_SaveMeal_Success") == false)
        #expect(screen.interactor.deletedMealIds.isEmpty)
    }

    // MARK: - Editing

    /// The pencil on a timeline row opens the amount screen, and what that screen confirms has to
    /// be written into the meal. The closure handed over used to be empty: Save played the success
    /// haptic, closed the screen and left the meal as it was.
    @Test("Test Editing A Logged Item Saves The New Amount")
    func testEditingALoggedItemSavesTheNewAmount() async {
        let first = item(id: "a", calories: 100)
        let second = item(id: "b", calories: 200)
        let logged = meal(id: "m1", at: monday, items: [first, second])
        let screen = makeScreen(meals: [logged])

        screen.presenter.onEditMealItem(second, in: logged)
        let corrected = MealItemModel(
            itemId: second.itemId,
            sourceType: second.sourceType,
            sourceId: second.sourceId,
            displayName: second.displayName,
            amount: 250,
            unit: second.unit,
            resolvedGrams: 250,
            nutrients: NutrientMap([.calories: 500])
        )
        screen.router.amountDelegates.first?.onConfirm(corrected)
        await TestManagers.eventually { !screen.interactor.addedMeals.isEmpty }

        let saved = screen.interactor.addedMeals.first
        #expect(saved?.mealId == "m1")
        #expect(saved?.items.map(\.itemId) == ["a", "b"])
        #expect(saved?.items.map(\.amount) == [100, 250])
    }

    /// A failed save is reported, not swallowed.
    @Test("Test A Failed Edit Is Reported")
    func testAFailedEditIsReported() async {
        let only = item(id: "a", calories: 100)
        let logged = meal(id: "m1", at: monday, items: [only])
        let screen = makeScreen(meals: [logged])
        screen.interactor.writeError = URLError(.badServerResponse)

        screen.presenter.onEditMealItem(only, in: logged)
        screen.router.amountDelegates.first?.onConfirm(only)
        await TestManagers.eventually { screen.interactor.trackedEventNames.contains("NutritionView_SaveMeal_Fail") }

        #expect(screen.interactor.trackedEventNames.contains("NutritionView_SaveMeal_Fail"))
        #expect(screen.interactor.addedMeals.isEmpty)
    }

    // MARK: - Calendar markers

    /// A day with a goal is marked with progress toward it, so the calendar cell fills.
    @Test("Test A Day With A Goal Is Marked With Progress")
    func testADayWithAGoalIsMarkedWithProgress() {
        let target = DailyMacroTarget(calories: 2000, proteinGrams: 100, carbGrams: 200, fatGrams: 50)
        let screen = makeScreen(
            meals: [meal(id: "m1", hour: 9, calories: 500), meal(id: "m2", hour: 13, calories: 300)],
            plan: plan(days: Array(repeating: target, count: 7))
        )

        let markers = screen.presenter.calorieMarkersByDay()
        let day = Calendar.current.startOfDay(for: monday)

        #expect(markers[day] == .goalProgress(value: 800, goal: 2000, grace: NutritionPresenter.calorieGrace))
    }

    /// Without a goal for that day the cell falls back to "something was logged" — a ring with
    /// nothing to fill toward would read as 0% and look like a day the user missed.
    @Test("Test A Day Without A Goal Falls Back To A Count")
    func testADayWithoutAGoalFallsBackToACount() {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 9, calories: 500)], plan: nil)

        let markers = screen.presenter.calorieMarkersByDay()
        let day = Calendar.current.startOfDay(for: monday)

        #expect(markers[day] == .count(1))
    }

    /// Days with nothing logged carry no marker at all.
    @Test("Test Unlogged Days Carry No Marker")
    func testUnloggedDaysCarryNoMarker() {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 9, calories: 500)], plan: nil)

        let markers = screen.presenter.calorieMarkersByDay()

        #expect(markers.count == 1)
    }

    // MARK: - Navigation

    /// The overview and timeline actions are opened for the day being looked at, not today.
    @Test("Test Navigation Opens The Expected Screens")
    func testNavigationOpensTheExpectedScreens() {
        let screen = makeScreen()

        screen.presenter.onNutritionOverviewPressed()
        screen.presenter.onTimelineActionsPressed()
        screen.presenter.onCustomiseFoodLogPressed()
        screen.presenter.onViewMealPressed(meal(id: "m1", hour: 9))

        #expect(screen.router.shown == ["nutritionOverview", "timelineActions", "foodLogSettings", "mealDetail"])
    }

    // MARK: - Log meal, library and search

    /// The toolbar's Log Meal opens a meal on the day being looked at: now on today, midday on
    /// another day.
    @Test("Test Log Meal Opens A Meal On The Selected Day")
    func testLogMealOpensAMealOnTheSelectedDay() {
        let screen = makeScreen()
        screen.presenter.selectedDate = monday

        screen.presenter.onLogMealPressed()

        #expect(screen.router.shown == ["addMeal"])
        #expect(screen.router.addMealDelegates.first?.mealLog.dayKey == monday.dayKey)
        #expect(Calendar.current.component(.hour, from: screen.router.addMealDelegates.first?.mealLog.date ?? .distantPast) == 12)

        screen.presenter.selectedDate = Date()
        screen.presenter.onLogMealPressed()
        #expect(screen.router.addMealDelegates.last?.mealLog.dayKey == Date().dayKey)
    }

    /// Log Again copies a meal from any day to now, as a new meal with the same foods.
    @Test("Test Log Again Logs A Copy Of The Meal Now")
    func testLogAgainLogsACopyOfTheMealNow() async {
        let screen = makeScreen()
        let original = meal(id: "breakfast", hour: 8, calories: 300)

        screen.presenter.onLogAgainPressed(original)
        await TestManagers.eventually { !screen.interactor.addedMeals.isEmpty }

        let copy = screen.interactor.addedMeals.first
        #expect(copy?.mealId != original.mealId)
        #expect(copy?.dayKey == Date().dayKey)
        #expect(copy?.items.map(\.itemId) == original.items.map(\.itemId))
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// From another day the copy lands on today, out of sight, so a toast says where it went.
    /// Logged again from today, the meal appears on screen and needs none.
    @Test("Test Log Again From Another Day Says Where The Meal Went")
    func testLogAgainFromAnotherDaySaysWhereTheMealWent() async {
        let past = makeScreen()
        past.presenter.selectedDate = monday
        past.presenter.onLogAgainPressed(meal(id: "breakfast", hour: 8, calories: 300))
        await TestManagers.eventually { !past.interactor.addedMeals.isEmpty }

        let today = makeScreen()
        today.presenter.selectedDate = Date()
        today.presenter.onLogAgainPressed(meal(id: "breakfast", hour: 8, calories: 300))
        await TestManagers.eventually { !today.interactor.addedMeals.isEmpty }

        #expect(past.interactor.shownToasts.map(\.message) == ["Logged again today."])
        #expect(today.interactor.shownToasts.isEmpty)
    }

    @Test("Test The Library Rows Open Foods And Recipes")
    func testTheLibraryRowsOpenFoodsAndRecipes() {
        let screen = makeScreen()

        screen.presenter.onFoodsPressed()
        screen.presenter.onRecipesPressed()

        #expect(screen.router.shown == ["foods", "recipes"])
    }

    /// Foods and recipes match on name ignoring case and punctuation; recipes also on ingredients.
    @Test("Test Search Matches Foods And Recipes")
    func testSearchMatchesFoodsAndRecipes() {
        let screen = makeScreen()
        let oats = FoodModel(ingredientId: "oats", name: "Rolled Oats")
        screen.interactor.foods = [oats, FoodModel(ingredientId: "egg", name: "Egg")]
        screen.interactor.userRecipeTemplates = [
            RecipeTemplateModel(id: "porridge", authorId: "user-1", name: "Porridge", dateCreated: .now, dateModified: .now)
        ]

        #expect(screen.presenter.isSearching == false)
        screen.presenter.searchString = "  OATS! "

        #expect(screen.presenter.isSearching)
        #expect(screen.presenter.filteredFoods.map(\.id) == ["oats"])
        #expect(screen.presenter.filteredRecipes.isEmpty)

        screen.presenter.onFoodResultPressed(oats)
        #expect(screen.router.shown == ["foodDetail"])
    }
}
