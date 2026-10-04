//
//  AddMealPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The screen that builds a meal before it is logged.
///
/// The plate is a draft: every change to it is written straight back to the draft store, so
/// closing the app mid-meal does not lose it. The summary above the plate can read either the
/// plate alone or the whole day, and the nutrient breakdown beneath it reads the same scope
/// through a different path — the macros come from a stored daily total, the micronutrients from
/// the day's meals themselves.
@MainActor
struct AddMealPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, AddMealInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var draftMeal: MealLogModel?
        var currentDietPlan: DietPlan?

        var mealsByDayKey: [String: [MealLogModel]] = [:]
        var totalsByDayKey: [String: DailyMacroTarget] = [:]

        private(set) var draftWrites: [MealLogModel] = []
        private(set) var draftDeletes = 0
        private(set) var savedMeals: [MealLogModel] = []
        var saveError: Error?
        var draftWriteError: Error?
        var draftDeleteError: Error?

        func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
            guard let totals = totalsByDayKey[dayKey] else { throw URLError(.fileDoesNotExist) }
            return totals
        }

        func getMeals(for dayKey: String) throws -> [MealLogModel] {
            mealsByDayKey[dayKey] ?? []
        }

        func updateDraftMeal(_ draftMeal: MealLogModel) throws {
            if let draftWriteError { throw draftWriteError }
            draftWrites.append(draftMeal)
        }

        func deleteDraftMeal() throws {
            draftDeletes += 1
            if let draftDeleteError { throw draftDeleteError }
        }

        func saveMeal(_ meal: MealLogModel) async throws {
            if let saveError { throw saveError }
            savedMeals.append(meal)
        }
    }

    private final class Router: AddMealRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        /// The alert witnesses have to be bound on the class declaring the conformance, or the
        /// protocol's default implementation runs and the alert escapes to the real router unseen.
        private(set) var alerts: [(title: String, subtitle: String?)] = []

        func showAlert(error: Error) { alerts.append((title: "Error", subtitle: error.localizedDescription)) }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alerts.append((title: title, subtitle: subtitle))
        }
        func showSimpleAlert(title: String, subtitle: String?) { alerts.append((title: title, subtitle: subtitle)) }

        func showNutritionLibraryPickerView(delegate: NutritionLibraryPickerDelegate) { shown.append("picker") }
        func showMealItemAmountViewView(delegate: MealItemAmountViewDelegate) { shown.append("itemAmount") }
    }

    private struct Screen {
        let presenter: AddMealPresenter
        let interactor: Interactor
        let router: Router
    }

    // MARK: - Fixtures

    /// Monday 21 September 2026, 12:00. The plan is indexed by weekday, so a fixed one matters.
    private var monday: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 21
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    private func item(id: String, nutrients: NutrientMap) -> MealItemModel {
        MealItemModel(
            itemId: id,
            sourceType: .ingredient,
            sourceId: "source-\(id)",
            displayName: "Food \(id)",
            amount: 100,
            unit: "g",
            resolvedGrams: 100,
            nutrients: nutrients
        )
    }

    /// An item carrying only the four macros.
    private func item(id: String, calories: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0) -> MealItemModel {
        item(id: id, nutrients: NutrientMap([.calories: calories, .protein: protein, .carbs: carbs, .fatTotal: fat]))
    }

    private func meal(id: String = "meal-1", date: Date? = nil, items: [MealItemModel], notes: String? = nil) -> MealLogModel {
        let day = date ?? monday
        return MealLogModel(mealId: id, authorId: "user-1", dayKey: day.dayKey, date: day, items: items, notes: notes)
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
        meal mealLog: MealLogModel? = nil,
        plan dietPlan: DietPlan? = nil,
        dayMeals: [MealLogModel] = [],
        dayTotals: DailyMacroTarget? = nil
    ) -> Screen {
        let interactor = Interactor()
        let logged = mealLog ?? meal(items: [])
        interactor.currentDietPlan = dietPlan
        interactor.mealsByDayKey[logged.dayKey] = dayMeals
        if let dayTotals { interactor.totalsByDayKey[logged.dayKey] = dayTotals }

        let router = Router()
        return Screen(
            presenter: AddMealPresenter(
                interactor: interactor,
                router: router,
                delegate: AddMealDelegate(mealLog: logged),
                pickerOpenDelay: .zero
            ),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - The plate

    /// The plate totals its own items, whatever the day around it holds.
    @Test("Test The Plate Totals Its Own Items")
    func testThePlateTotalsItsOwnItems() {
        let screen = makeScreen(
            meal: meal(items: [
                item(id: "a", calories: 300, protein: 20, carbs: 30, fat: 10),
                item(id: "b", calories: 200, protein: 10, carbs: 20, fat: 5)
            ]),
            dayTotals: DailyMacroTarget(calories: 1000, proteinGrams: 50, carbGrams: 100, fatGrams: 30)
        )

        #expect(screen.presenter.plateCalories == 500)
        #expect(screen.presenter.plateProtein == 30)
        #expect(screen.presenter.plateCarbs == 50)
        #expect(screen.presenter.plateFat == 15)
    }

    /// At plate scope the summary is the plate alone — what is about to be added.
    @Test("Test Plate Scope Shows Only The Plate")
    func testPlateScopeShowsOnlyThePlate() {
        let screen = makeScreen(
            meal: meal(items: [item(id: "a", calories: 500, protein: 30, carbs: 50, fat: 15)]),
            dayTotals: DailyMacroTarget(calories: 1000, proteinGrams: 50, carbGrams: 100, fatGrams: 30)
        )
        screen.presenter.nutritionScope = .plate

        #expect(screen.presenter.displayCalories == 500)
        #expect(screen.presenter.displayProtein == 30)
        #expect(screen.presenter.scopeLabel == "in plate")
    }

    /// At day scope the plate is added to what the day already holds — what the day will read
    /// once this meal is logged.
    @Test("Test Day Scope Adds The Plate To The Day")
    func testDayScopeAddsThePlateToTheDay() {
        let screen = makeScreen(
            meal: meal(items: [item(id: "a", calories: 500, protein: 30, carbs: 50, fat: 15)]),
            dayTotals: DailyMacroTarget(calories: 1000, proteinGrams: 50, carbGrams: 100, fatGrams: 30)
        )
        screen.presenter.nutritionScope = .day

        #expect(screen.presenter.displayCalories == 1500)
        #expect(screen.presenter.displayProtein == 80)
        #expect(screen.presenter.displayCarbs == 150)
        #expect(screen.presenter.displayFat == 45)
        #expect(screen.presenter.scopeLabel == "today")
    }

    /// A day with nothing logged yet reads as the plate alone rather than failing.
    @Test("Test Day Scope Without Totals Reads The Plate")
    func testDayScopeWithoutTotalsReadsThePlate() {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 500)]))
        screen.presenter.nutritionScope = .day

        #expect(screen.presenter.displayCalories == 500)
    }

    // MARK: - Targets

    /// The plan holds seven days from Monday while `Calendar` counts from Sunday. The target
    /// follows the meal's own date, not today's.
    @Test("Test Each Weekday Reads Its Own Target")
    func testEachWeekdayReadsItsOwnTarget() {
        let targets = weekOfTargets
        let calendar = Calendar.current

        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: monday)!
            let screen = makeScreen(meal: meal(date: day, items: []), plan: plan(days: targets))

            #expect(screen.presenter.dailyTarget == targets[offset], "day \(offset) after Monday read the wrong target")
        }
    }

    /// Without a plan the rings still need something to measure against, so the screen falls back
    /// to a standard day rather than showing no target at all.
    @Test("Test Missing Plan Falls Back To Standard Targets")
    func testMissingPlanFallsBackToStandardTargets() {
        let screen = makeScreen(plan: nil)

        #expect(screen.presenter.dailyTarget == nil)
        #expect(screen.presenter.targetCalories == 2000)
        #expect(screen.presenter.targetProtein == 150)
        #expect(screen.presenter.targetCarbs == 200)
        #expect(screen.presenter.targetFat == 65)
    }

    /// A plan too short to hold the meal's weekday falls back rather than indexing past its end.
    @Test("Test A Short Plan Does Not Overrun")
    func testAShortPlanDoesNotOverrun() {
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday)!
        let screen = makeScreen(meal: meal(date: sunday, items: []), plan: plan(days: Array(weekOfTargets.prefix(2))))

        #expect(screen.presenter.dailyTarget == nil)
        #expect(screen.presenter.targetCalories == 2000)
    }

    /// The label pairs what is shown with what is aimed at, both whole.
    @Test("Test The Calorie Label Pairs Shown With Target")
    func testTheCalorieLabelPairsShownWithTarget() {
        let target = DailyMacroTarget(calories: 2200, proteinGrams: 150, carbGrams: 250, fatGrams: 70)
        let screen = makeScreen(
            meal: meal(items: [item(id: "a", calories: 499.6)]),
            plan: plan(days: Array(repeating: target, count: 7))
        )

        #expect(screen.presenter.calorieLabel == "499/2200")
    }

    // MARK: - The draft

    /// Every change to the plate is written back, so a meal survives the app closing mid-build.
    @Test("Test Changing The Plate Saves The Draft")
    func testChangingThePlateSavesTheDraft() {
        let screen = makeScreen(meal: meal(items: []))

        screen.presenter.mealLog.items.append(item(id: "a", calories: 100))

        #expect(screen.interactor.draftWrites.count == 1)
        #expect(screen.interactor.draftWrites.last?.items.map(\.itemId) == ["a"])
    }

    /// Emptying the plate does not write an empty draft — `dismissScreen` clears it instead, so
    /// the draft is either a meal worth resuming or gone.
    @Test("Test Emptying The Plate Does Not Write An Empty Draft")
    func testEmptyingThePlateDoesNotWriteAnEmptyDraft() {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))

        screen.presenter.deleteItems(at: IndexSet(integer: 0))

        #expect(screen.presenter.mealLog.items.isEmpty)
        #expect(screen.interactor.draftWrites.isEmpty)
    }

    /// Removing one of several keeps the rest and records the shorter plate.
    @Test("Test Removing One Item Keeps The Others")
    func testRemovingOneItemKeepsTheOthers() {
        let screen = makeScreen(meal: meal(items: [
            item(id: "a", calories: 100),
            item(id: "b", calories: 200)
        ]))

        screen.presenter.deleteItems(at: IndexSet(integer: 0))

        #expect(screen.presenter.mealLog.items.map(\.itemId) == ["b"])
        #expect(screen.interactor.draftWrites.last?.items.map(\.itemId) == ["b"])
    }

    /// Closing an empty plate throws the draft away; there is nothing to come back to.
    @Test("Test Closing An Empty Plate Clears The Draft")
    func testClosingAnEmptyPlateClearsTheDraft() {
        let screen = makeScreen(meal: meal(items: []))

        screen.presenter.dismissScreen()

        #expect(screen.interactor.draftDeletes == 1)
    }

    /// Closing a plate with food in it keeps the draft, so it can be resumed.
    @Test("Test Closing A Full Plate Keeps The Draft")
    func testClosingAFullPlateKeepsTheDraft() {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))

        screen.presenter.dismissScreen()

        #expect(screen.interactor.draftDeletes == 0)
    }

    // MARK: - Saving

    /// A logged meal is written, and its draft cleared so it cannot be resumed as well.
    @Test("Test Saving Logs The Meal And Clears The Draft")
    func testSavingLogsTheMealAndClearsTheDraft() async {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))

        screen.presenter.saveMeal()
        await TestManagers.eventually { !screen.interactor.savedMeals.isEmpty }

        #expect(screen.interactor.savedMeals.map(\.mealId) == ["meal-1"])
        #expect(screen.interactor.draftDeletes == 1)
        #expect(screen.interactor.trackedEventNames.contains("AddMealView_SaveMeal_Success"))
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// The meal is logged once it saves. A draft that then fails to delete used to report the save
    /// as failed and leave the screen open, so a second tap on Log saved the meal twice.
    @Test("Test A Draft That Will Not Delete Does Not Fail The Save")
    func testADraftThatWillNotDeleteDoesNotFailTheSave() async {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))
        screen.interactor.draftDeleteError = CocoaError(.fileWriteUnknown)

        screen.presenter.saveMeal()
        await TestManagers.eventually { screen.interactor.trackedEventNames.contains("AddMealView_SaveMeal_Success") }

        #expect(screen.interactor.savedMeals.count == 1)
        #expect(screen.router.alerts.isEmpty)
        #expect(!screen.interactor.trackedEventNames.contains("AddMealView_SaveMeal_Fail"))
    }

    /// A failed save keeps the draft, so the meal is still there to try again with.
    @Test("Test A Failed Save Keeps The Draft")
    func testAFailedSaveKeepsTheDraft() async {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        screen.presenter.saveMeal()
        await TestManagers.eventually { screen.interactor.trackedEventNames.contains("AddMealView_SaveMeal_Fail") }

        #expect(screen.interactor.savedMeals.isEmpty)
        #expect(screen.interactor.draftDeletes == 0)
        #expect(screen.interactor.trackedEventNames.contains("AddMealView_SaveMeal_Success") == false)
    }

    /// Saving is also what closes this screen, so a failure that says nothing reads as a dead
    /// button on the meal the user just built.
    @Test("Test A Failed Save Tells The User The Meal Was Not Logged")
    func testAFailedSaveTellsTheUserTheMealWasNotLogged() async {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        screen.presenter.saveMeal()
        await TestManagers.eventually { !screen.router.alerts.isEmpty }

        #expect(screen.router.alerts.map(\.title) == ["Unable to Save Meal"])
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    @Test("Test Deleting A Plate Item Removes Only That Item")
    func testDeletingAPlateItemRemovesOnlyThatItem() {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100), item(id: "b", calories: 50)]))

        screen.presenter.onDeleteMealItem(screen.presenter.mealLog.items[0])

        #expect(screen.presenter.mealLog.items.map(\.itemId) == ["b"])
    }

    @Test("Test Changing Scope Plays A Selection Haptic")
    func testChangingScopePlaysASelectionHaptic() {
        let screen = makeScreen()

        screen.presenter.nutritionScope = .day
        screen.presenter.onNutritionScopeChanged()

        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection"])
    }

    /// The draft failure alert used to talk about a workout on the meal screen.
    @Test("Test A Failed Draft Write Talks About The Meal")
    func testAFailedDraftWriteTalksAboutTheMeal() {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))
        screen.interactor.draftWriteError = URLError(.notConnectedToInternet)

        screen.presenter.saveDraftMeal()

        #expect(screen.router.alerts.first?.subtitle?.contains("workout") == false)
    }

    // MARK: - Moving the meal

    /// Moving a meal changes when it was eaten, not what was in it — and takes its day with it,
    /// since `dayKey` is what every per-day lookup reads.
    @Test("Test Moving A Meal Keeps Its Contents And Takes Its Day")
    func testMovingAMealKeepsItsContentsAndTakesItsDay() {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)], notes: "post-gym"))
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: monday)!

        screen.presenter.updateMealTime(tomorrow)

        #expect(screen.presenter.mealLog.date == tomorrow)
        #expect(screen.presenter.mealLog.dayKey == tomorrow.dayKey)
        #expect(screen.presenter.mealLog.mealId == "meal-1")
        #expect(screen.presenter.mealLog.authorId == "user-1")
        #expect(screen.presenter.mealLog.items.map(\.itemId) == ["a"])
        #expect(screen.presenter.mealLog.notes == "post-gym")
    }

    /// The time picker applies each change as it is made, so Cancel has to put the old time back.
    @Test("Test Cancelling The Time Picker Restores The Time")
    func testCancellingTheTimePickerRestoresTheTime() {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))
        let original = screen.presenter.mealLog.date
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: original)!

        screen.presenter.onEditMealTimePressed()
        screen.presenter.updateMealTime(tomorrow)
        screen.presenter.onMealTimeCancelled()

        #expect(screen.presenter.mealLog.date == original)
        #expect(!screen.presenter.isEditingMealTime)
    }

    // MARK: - Nutrient breakdown

    /// A nutrient the food's source never recorded is left out rather than printed as zero — a
    /// food with no iron figure is not a food containing no iron.
    @Test("Test Unrecorded Nutrients Are Left Out")
    func testUnrecordedNutrientsAreLeftOut() {
        let screen = makeScreen(meal: meal(items: [
            item(id: "a", nutrients: NutrientMap([.calories: 100, .ironMg: 2.5]))
        ]))

        let minerals = screen.presenter.breakdown(for: .minerals)

        #expect(minerals.map(\.key) == [.ironMg])
        #expect(minerals.first?.value == 2.5)
    }

    /// A category with nothing recorded yields nothing, and the view says so in words.
    @Test("Test A Category With Nothing Recorded Is Empty")
    func testACategoryWithNothingRecordedIsEmpty() {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))

        #expect(screen.presenter.breakdown(for: .vitamins).isEmpty)
    }

    /// At day scope the breakdown adds the day's other meals, which is the only way to reach
    /// micronutrients — the stored daily total carries the four macros alone.
    @Test("Test Day Scope Adds Other Meals Micronutrients")
    func testDayScopeAddsOtherMealsMicronutrients() {
        let plate = meal(id: "meal-1", items: [item(id: "a", nutrients: NutrientMap([.ironMg: 2]))])
        let earlier = meal(id: "meal-0", items: [item(id: "b", nutrients: NutrientMap([.ironMg: 3]))])
        let screen = makeScreen(meal: plate, dayMeals: [earlier])
        screen.presenter.nutritionScope = .day

        #expect(screen.presenter.breakdown(for: .minerals).first?.value == 5)
    }

    /// The plate is not counted twice when the day's meals already include it.
    @Test("Test The Plate Is Not Double Counted At Day Scope")
    func testThePlateIsNotDoubleCountedAtDayScope() {
        let plate = meal(id: "meal-1", items: [item(id: "a", nutrients: NutrientMap([.ironMg: 2]))])
        let screen = makeScreen(meal: plate, dayMeals: [plate])
        screen.presenter.nutritionScope = .day

        #expect(screen.presenter.breakdown(for: .minerals).first?.value == 2)
    }

    // MARK: - Formatting

    /// Calories are whole — a tenth of a kilocalorie is noise.
    @Test("Test Calories Are Printed Whole")
    func testCaloriesArePrintedWhole() {
        let screen = makeScreen()
        let amount = AddMealPresenter.NutrientAmount(key: .calories, value: 499.6)

        #expect(screen.presenter.formatted(amount) == "500 kcal")
    }

    /// Below ten, a tenth of a gram is a meaningful share of the amount, so it is kept.
    ///
    /// The value is one a `Double` holds exactly enough to round predictably — 2.45 is stored
    /// just under its decimal and formats as 2.4, which is the formatter being right about the
    /// number it was given rather than the rule being wrong.
    @Test("Test Small Amounts Keep A Decimal")
    func testSmallAmountsKeepADecimal() {
        let screen = makeScreen()
        let amount = AddMealPresenter.NutrientAmount(key: .protein, value: 3.7)

        #expect(screen.presenter.formatted(amount).hasPrefix("3.7"))
    }

    /// Above ten it is not, so it is dropped.
    @Test("Test Large Amounts Drop The Decimal")
    func testLargeAmountsDropTheDecimal() {
        let screen = makeScreen()
        let amount = AddMealPresenter.NutrientAmount(key: .protein, value: 24.6)

        #expect(screen.presenter.formatted(amount).hasPrefix("25"))
    }

    // MARK: - Navigation

    /// Editing an item and adding one open their own screens.
    @Test("Test Navigation Opens The Expected Screens")
    func testNavigationOpensTheExpectedScreens() {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))

        screen.presenter.onEditMealItem(item(id: "a", calories: 100))
        screen.presenter.onShowPickerPressed()

        #expect(screen.router.shown == ["itemAmount", "picker"])
    }

    /// A new meal's empty plate opens the picker by itself, once: closing it on an empty plate and
    /// coming back does not open it again.
    @Test("Test An Empty Plate Opens The Picker Once")
    func testAnEmptyPlateOpensThePickerOnce() async {
        let screen = makeScreen(meal: meal(items: []))

        screen.presenter.onViewAppear()
        let opened = await TestManagers.eventually(timeout: .seconds(5)) { screen.router.shown == ["picker"] }
        screen.presenter.onViewAppear()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(opened)
        #expect(screen.router.shown == ["picker"])
    }

    /// A draft that already has food opens on its plate.
    @Test("Test A Plate With Food Does Not Open The Picker")
    func testAPlateWithFoodDoesNotOpenThePicker() async {
        let screen = makeScreen(meal: meal(items: [item(id: "a", calories: 100)]))

        screen.presenter.onViewAppear()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(screen.router.shown.isEmpty)
    }
}
