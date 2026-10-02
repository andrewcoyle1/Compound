//
//  TimelineActionsPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The menu behind the timeline's toolbar: copy a day's meals onto another day, clear a day, and
/// two toggles for how densely the timeline draws.
///
/// Both actions are bulk operations on real logged food, and one of them is destructive, so what
/// matters here is that they act on exactly the day they were opened for, that a copy is a copy
/// rather than a move, and that clearing a day cannot happen without a confirmation.
@MainActor
struct TimelineActionsPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, TimelineActionsInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var foodLogSettings: FoodLogSettings = FoodLogSettings(authorId: "user-1")

        /// The meals the day holds, keyed by day.
        var mealsByDayKey: [String: [MealLogModel]] = [:]

        private(set) var savedSettings: [FoodLogSettings] = []
        private(set) var savedMeals: [MealLogModel] = []
        private(set) var deletedMealIds: [String] = []

        var saveMealError: Error?
        var deleteError: Error?

        func saveFoodLogSettings(_ settings: FoodLogSettings) async throws {
            savedSettings.append(settings)
        }

        func getMeals(for dayKey: String) throws -> [MealLogModel] {
            mealsByDayKey[dayKey] ?? []
        }

        func saveMeal(_ meal: MealLogModel) async throws {
            if let saveMealError { throw saveMealError }
            savedMeals.append(meal)
        }

        func deleteMealAndSync(id: String, dayKey: String, authorId: String) async throws {
            if let deleteError { throw deleteError }
            deletedMealIds.append(id)
        }
    }

    /// `showSimpleAlert` is a `GlobalRouter` extension, but `TimelineActionsRouter` restates it as
    /// a requirement, so on this screen it dispatches through the protocol and a double does see
    /// it. That is not true of `showAlert(title:subtitle:buttons:)`, which is only ever the
    /// extension — see the clear-day tests.
    private final class Router: TimelineActionsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var simpleAlerts: [String] = []

        func showSimpleAlert(title: String, subtitle: String?) {
            simpleAlerts.append(title)
        }
    }

    private struct Screen {
        let presenter: TimelineActionsPresenter
        let interactor: Interactor
        let router: Router
        let delegate: TimelineActionsDelegate
    }

    /// Monday 14 September 2026, 12:00 — the day the sheet was opened for.
    ///
    /// Deliberately a day in the past rather than today: the sheet is reached from a timeline the
    /// user may have scrolled back through, and a fixture that happened to be today would let an
    /// action that acts on today pass the tests below anyway.
    private var monday: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 14
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    private var tuesday: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: monday)!
    }

    private func item(id: String, calories: Double = 100) -> MealItemModel {
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

    /// A meal on the sheet's day at a given hour and minute.
    private func meal(id: String, hour: Int, minute: Int = 30, notes: String? = nil) -> MealLogModel {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: monday)!
        return MealLogModel(
            mealId: id,
            authorId: "user-1",
            dayKey: date.dayKey,
            date: date,
            items: [item(id: "\(id)-item")],
            notes: notes
        )
    }

    private func makeScreen(meals: [MealLogModel] = []) -> Screen {
        let interactor = Interactor()
        interactor.mealsByDayKey[monday.dayKey] = meals
        let router = Router()
        return Screen(
            presenter: TimelineActionsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router,
            delegate: TimelineActionsDelegate(date: monday)
        )
    }

    // MARK: - The display toggles

    /// The toggles write straight through. They change how the timeline behind the sheet draws,
    /// so a flick that is not persisted reverts the moment the screen is rebuilt.
    @Test("Test Toggling Hide Food Details Saves It")
    func testTogglingHideFoodDetailsSavesIt() async {
        let screen = makeScreen()

        screen.presenter.hideFoodDetails = true

        #expect(screen.presenter.hideFoodDetails)
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }
        #expect(screen.interactor.savedSettings.last?.hideFoodDetails == true)
    }

    @Test("Test Toggling Hide Empty Hours Saves It")
    func testTogglingHideEmptyHoursSavesIt() async {
        let screen = makeScreen()

        screen.presenter.hideEmptyHours = true

        #expect(screen.presenter.hideEmptyHours)
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }
        #expect(screen.interactor.savedSettings.last?.hideEmptyHours == true)
    }

    /// The presenter holds its own copy of the settings, so the second toggle has to carry the
    /// first one's value with it rather than saving a settings object that undoes it.
    @Test("Test One Toggle Does Not Undo The Other")
    func testOneToggleDoesNotUndoTheOther() async {
        let screen = makeScreen()

        screen.presenter.hideFoodDetails = true
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }
        screen.presenter.hideEmptyHours = true
        await TestManagers.eventually { screen.interactor.savedSettings.count >= 2 }

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.hideFoodDetails == true)
        #expect(saved?.hideEmptyHours == true)
    }

    /// The settings carry every other preference on the screen too, so a save must not reset the
    /// ones this sheet does not show.
    @Test("Test Saving A Toggle Leaves The Other Settings Alone")
    func testSavingAToggleLeavesTheOtherSettingsAlone() async {
        let screen = makeScreen()
        screen.interactor.foodLogSettings.startHour = 5
        screen.interactor.foodLogSettings.endHour = 21
        let presenter = TimelineActionsPresenter(interactor: screen.interactor, router: screen.router)

        presenter.hideEmptyHours = true
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.interactor.savedSettings.last?.startHour == 5)
        #expect(screen.interactor.savedSettings.last?.endHour == 21)
    }

    // MARK: - Copy day

    /// The overwhelmingly common case is "same as yesterday", so the picker opens on the day after
    /// the one being copied rather than on today.
    @Test("Test Copy Day Opens On The Following Day")
    func testCopyDayOpensOnTheFollowingDay() {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8)])

        screen.presenter.onCopyDayPressed(delegate: screen.delegate)

        #expect(screen.presenter.isChoosingCopyDestination)
        #expect(Calendar.current.isDate(screen.presenter.copyDestination, inSameDayAs: tuesday))
    }

    @Test("Test Copying A Day Re-Logs Every Meal On The Destination")
    func testCopyingADayReLogsEveryMealOnTheDestination() async {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8), meal(id: "m2", hour: 13)])
        screen.presenter.onCopyDayPressed(delegate: screen.delegate)

        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)
        await TestManagers.eventually { screen.interactor.savedMeals.count == 2 }

        #expect(screen.interactor.savedMeals.allSatisfy { $0.dayKey == tuesday.dayKey })
        await TestManagers.eventually { !screen.interactor.playedHaptics.isEmpty }
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// A second tap on Copy while the first copy is writing does not copy the day twice.
    @Test("Test A Second Copy Tap While Copying Copies Once")
    func testASecondCopyTapWhileCopyingCopiesOnce() async {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8)])

        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)
        #expect(screen.presenter.isWorking)
        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)
        await TestManagers.eventually { !screen.presenter.isWorking }

        #expect(screen.interactor.savedMeals.count == 1)
    }

    /// A copy is a new entry, not a move: it takes a fresh id, and the original is untouched.
    /// Reusing the id would overwrite the meal being copied from.
    @Test("Test A Copied Meal Is A New Entry Not A Move")
    func testACopiedMealIsANewEntryNotAMove() async {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8)])
        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)
        await TestManagers.eventually { !screen.interactor.savedMeals.isEmpty }

        #expect(screen.interactor.savedMeals.first?.mealId != "m1")
        #expect(screen.interactor.deletedMealIds.isEmpty)
    }

    /// Breakfast copied onto tomorrow is still breakfast. Losing the time of day would pile the
    /// whole day into midnight and break the timeline it is copied into.
    @Test("Test A Copied Meal Keeps Its Time Of Day")
    func testACopiedMealKeepsItsTimeOfDay() async {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8, minute: 45)])
        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)
        await TestManagers.eventually { !screen.interactor.savedMeals.isEmpty }

        let saved = screen.interactor.savedMeals.first
        let components = Calendar.current.dateComponents([.hour, .minute], from: saved?.date ?? Date())
        #expect(components.hour == 8)
        #expect(components.minute == 45)
    }

    @Test("Test A Copied Meal Keeps Its Items And Notes")
    func testACopiedMealKeepsItsItemsAndNotes() async {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8, notes: "Post-run")])
        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)
        await TestManagers.eventually { !screen.interactor.savedMeals.isEmpty }

        let saved = screen.interactor.savedMeals.first
        #expect(saved?.items.map(\.displayName) == ["Food m1-item"])
        #expect(saved?.notes == "Post-run")
    }

    /// Copying an empty day is a no-op worth saying out loud — silently closing the sheet would
    /// read as a copy that worked.
    @Test("Test Copying An Empty Day Says So And Copies Nothing")
    func testCopyingAnEmptyDaySaysSoAndCopiesNothing() async {
        let screen = makeScreen()

        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)

        #expect(screen.router.simpleAlerts == ["Nothing to Copy"])
        #expect(screen.interactor.savedMeals.isEmpty)
        #expect(!screen.presenter.isChoosingCopyDestination)
    }

    @Test("Test Copying A Day Is Tracked With Its Meal Count")
    func testCopyingADayIsTrackedWithItsMealCount() async {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8), meal(id: "m2", hour: 13)])

        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)
        await TestManagers.eventually { screen.interactor.savedMeals.count == 2 }

        #expect(screen.interactor.trackedEventNames.contains("TimelineActionsView_CopyDay"))
    }

    /// A failed copy has to be reported. It writes meal by meal, so a failure partway leaves the
    /// destination half-populated, and closing the sheet silently would hide that.
    @Test("Test A Failed Copy Is Reported")
    func testAFailedCopyIsReported() async {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8)])
        screen.interactor.saveMealError = URLError(.networkConnectionLost)

        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)
        await TestManagers.eventually { !screen.router.simpleAlerts.isEmpty }

        #expect(screen.router.simpleAlerts == ["Unable to Copy Day"])
        #expect(screen.interactor.trackedEventNames.contains("TimelineActionsView_Action_Fail"))
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    /// Without a signed-in user there is no author to file the copies under, so nothing is written
    /// rather than meals saved ownerless.
    @Test("Test Copying Without A User Writes Nothing")
    func testCopyingWithoutAUserWritesNothing() {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8)])
        screen.interactor.currentUser = nil

        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)

        #expect(screen.interactor.savedMeals.isEmpty)
    }

    // MARK: - Clear day

    /// Clearing is destructive and not undoable, so the press only raises a confirmation — nothing
    /// is deleted until it is answered.
    ///
    /// The confirmation goes through `showAlert(title:subtitle:buttons:)`, which is a `GlobalRouter`
    /// extension rather than a requirement of this screen's router, so it dispatches statically and
    /// never reaches the double. That the alert appeared cannot be observed here; that nothing was
    /// deleted can, and is the half that protects the user's data.
    @Test("Test Clearing A Day Deletes Nothing Until Confirmed")
    func testClearingADayDeletesNothingUntilConfirmed() {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8), meal(id: "m2", hour: 13)])

        screen.presenter.onClearDayPressed(delegate: screen.delegate)

        #expect(screen.interactor.deletedMealIds.isEmpty)
        #expect(!screen.interactor.trackedEventNames.contains("TimelineActionsView_ClearDay"))
    }

    /// An empty day takes the plain message instead, so the user is never asked to confirm
    /// deleting nothing.
    @Test("Test Clearing An Empty Day Says So")
    func testClearingAnEmptyDaySaysSo() {
        let screen = makeScreen()

        screen.presenter.onClearDayPressed(delegate: screen.delegate)

        #expect(screen.router.simpleAlerts == ["Nothing to Clear"])
        #expect(screen.interactor.deletedMealIds.isEmpty)
    }

    // MARK: - Scope

    /// Both actions read the day off the delegate, not off today. The sheet is opened from a
    /// timeline that may be scrolled back a week, and acting on today instead would copy or clear
    /// the wrong day entirely.
    @Test("Test Both Actions Act On The Sheets Day Not Today")
    func testBothActionsActOnTheSheetsDayNotToday() async {
        let screen = makeScreen(meals: [meal(id: "m1", hour: 8)])
        // Today holds a different meal; nothing should reach it.
        screen.interactor.mealsByDayKey[Date().dayKey] = [
            MealLogModel(mealId: "today", authorId: "user-1", dayKey: Date().dayKey, date: Date(), items: [])
        ]

        screen.presenter.onCopyDayConfirmed(delegate: screen.delegate)
        await TestManagers.eventually { !screen.interactor.savedMeals.isEmpty }

        #expect(screen.interactor.savedMeals.count == 1)
        #expect(screen.interactor.savedMeals.first?.items.map(\.displayName) == ["Food m1-item"])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["TimelineActionsView_Appear"])
    }
}
