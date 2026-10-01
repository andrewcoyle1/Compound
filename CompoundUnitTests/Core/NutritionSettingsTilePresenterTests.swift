//
//  NutritionSettingsTilePresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The six sub-screens behind Food Log Settings. Each one edits a handful of fields of the single
/// food-log settings document and writes the whole document back on every change.
///
/// They share one hazard, so they share one double: because the whole document is written, a
/// sub-screen that saved the copy it opened with would reset everything the parent screen and the
/// other five sub-screens had changed. Every suite below pins that.
@MainActor
enum NutritionSettingsTileSupport {

    @MainActor
    final class Interactor: SpyGlobalInteractor,
                            TimelineFoodTilesInteractor,
                            LoggerFoodTilesInteractor,
                            LoggerBannerInteractor,
                            TimeSelectionInteractor,
                            FavouriteMeasurementsInteractor,
                            OptimisationInteractor {
        var foodLogSettings = FoodLogSettings(authorId: "user-1")
        private(set) var savedSettings: [FoodLogSettings] = []

        func saveFoodLogSettings(_ settings: FoodLogSettings) async throws {
            savedSettings.append(settings)
            foodLogSettings = settings
        }
    }

    /// None of the six routers declares a requirement of its own, so a double is just the
    /// `AnyRouter` `GlobalRouter` needs.
    @MainActor
    final class Router: TimelineFoodTilesRouter,
                        LoggerFoodTilesRouter,
                        LoggerBannerRouter,
                        TimeSelectionRouter,
                        FavouriteMeasurementsRouter,
                        OptimisationRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    /// The fields none of these screens shows. Whatever a sub-screen saves has to still carry them,
    /// or the parent screen's preferences and the user's favourites are lost.
    static func untouchedFields(_ settings: inout FoodLogSettings) {
        settings.startHour = 5
        settings.endHour = 21
        settings.showsFoodTimestamps = false
        settings.favouriteFoodIds = ["food-1"]
    }

    static func expectUntouchedFieldsSurvived(_ settings: FoodLogSettings?) {
        #expect(settings?.startHour == 5)
        #expect(settings?.endHour == 21)
        #expect(settings?.showsFoodTimestamps == false)
        #expect(settings?.favouriteFoodIds == ["food-1"])
    }
}

// MARK: - Timeline Food Tiles

/// What each logged food shows on the timeline: its picture, its calories, its macros.
@MainActor
struct NutritionSettingsTimelineTilesTests {

    private typealias Support = NutritionSettingsTileSupport

    private func makePresenter(
        _ configure: (inout FoodLogSettings) -> Void = { _ in }
    ) -> (TimelineFoodTilesPresenter, Support.Interactor) {
        let interactor = Support.Interactor()
        configure(&interactor.foodLogSettings)
        return (TimelineFoodTilesPresenter(interactor: interactor, router: Support.Router()), interactor)
    }

    /// Three toggles, one document. Turning the picture off and then the macros off has to leave
    /// both off — the second save carrying the first change rather than the opening snapshot.
    @Test("Test Turning Off One Tile Detail Does Not Bring Back Another")
    func testTurningOffOneTileDetailDoesNotBringBackAnother() async {
        let (presenter, interactor) = makePresenter()

        presenter.showFoodImageInTimeline = false
        presenter.showCaloriesInTimeline = false
        presenter.showMacrosInTimeline = false
        await TestManagers.eventually { interactor.savedSettings.count == 3 }

        let saved = interactor.savedSettings.last
        #expect(saved?.showFoodImageInTimeline == false)
        #expect(saved?.showCaloriesInTimeline == false)
        #expect(saved?.showMacrosInTimeline == false)
    }

    @Test("Test Saving Keeps The Settings This Screen Does Not Show")
    func testSavingKeepsTheSettingsThisScreenDoesNotShow() async {
        let (presenter, interactor) = makePresenter(Support.untouchedFields)

        presenter.showCaloriesInTimeline = false
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }

        Support.expectUntouchedFieldsSurvived(interactor.savedSettings.last)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let (presenter, interactor) = makePresenter()

        presenter.onViewAppear()

        #expect(interactor.trackedScreenEventNames == ["TimelineFoodTilesView_Appear"])
    }
}

// MARK: - Logger Food Tiles

/// The same four details, but on the rows in the food picker rather than on the timeline. They are
/// separate settings deliberately, so changing one set must not move the other.
@MainActor
struct NutritionSettingsLoggerTilesTests {

    private typealias Support = NutritionSettingsTileSupport

    private func makePresenter(
        _ configure: (inout FoodLogSettings) -> Void = { _ in }
    ) -> (LoggerFoodTilesPresenter, Support.Interactor) {
        let interactor = Support.Interactor()
        configure(&interactor.foodLogSettings)
        return (LoggerFoodTilesPresenter(interactor: interactor, router: Support.Router()), interactor)
    }

    @Test("Test Turning Off One Tile Detail Does Not Bring Back Another")
    func testTurningOffOneTileDetailDoesNotBringBackAnother() async {
        let (presenter, interactor) = makePresenter()

        presenter.showFoodImageInLogger = false
        presenter.showCaloriesInLogger = false
        presenter.showMacrosInLogger = false
        presenter.showPortionInLogger = false
        await TestManagers.eventually { interactor.savedSettings.count == 4 }

        let saved = interactor.savedSettings.last
        #expect(saved?.showFoodImageInLogger == false)
        #expect(saved?.showCaloriesInLogger == false)
        #expect(saved?.showMacrosInLogger == false)
        #expect(saved?.showPortionInLogger == false)
    }

    /// The logger and the timeline have their own copies of the picture, calories and macros
    /// switches. Hiding calories in the picker must leave them on the timeline.
    @Test("Test The Logger Tiles Are Separate From The Timeline Tiles")
    func testTheLoggerTilesAreSeparateFromTheTimelineTiles() async {
        let (presenter, interactor) = makePresenter()

        presenter.showCaloriesInLogger = false
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }

        #expect(interactor.savedSettings.last?.showCaloriesInLogger == false)
        #expect(interactor.savedSettings.last?.showCaloriesInTimeline == true)
    }

    @Test("Test Saving Keeps The Settings This Screen Does Not Show")
    func testSavingKeepsTheSettingsThisScreenDoesNotShow() async {
        let (presenter, interactor) = makePresenter(Support.untouchedFields)

        presenter.showPortionInLogger = false
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }

        Support.expectUntouchedFieldsSurvived(interactor.savedSettings.last)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let (presenter, interactor) = makePresenter()

        presenter.onViewAppear()

        #expect(interactor.trackedScreenEventNames == ["LoggerFoodTilesView_Appear"])
    }
}

// MARK: - Logger Banner

/// The four macro rings above the food log. Each can be hidden independently.
@MainActor
struct NutritionSettingsLoggerBannerTests {

    private typealias Support = NutritionSettingsTileSupport

    private func makePresenter(
        _ configure: (inout FoodLogSettings) -> Void = { _ in }
    ) -> (LoggerBannerPresenter, Support.Interactor) {
        let interactor = Support.Interactor()
        configure(&interactor.foodLogSettings)
        return (LoggerBannerPresenter(interactor: interactor, router: Support.Router()), interactor)
    }

    /// Hiding the fat ring should not bring the protein ring back. Four writes of one document is
    /// exactly where that goes wrong.
    @Test("Test Hiding One Ring Does Not Bring Back Another")
    func testHidingOneRingDoesNotBringBackAnother() async {
        let (presenter, interactor) = makePresenter()

        presenter.showProteinRing = false
        presenter.showFatRing = false
        presenter.showCarbsRing = false
        await TestManagers.eventually { interactor.savedSettings.count == 3 }

        let saved = interactor.savedSettings.last
        #expect(saved?.showProteinRing == false)
        #expect(saved?.showFatRing == false)
        #expect(saved?.showCarbsRing == false)
        #expect(saved?.showCaloriesRing == true)
    }

    /// Every ring can be switched off, including the calorie one. Nothing stops that, which is
    /// worth stating: the banner is allowed to be empty.
    @Test("Test Every Ring Can Be Hidden")
    func testEveryRingCanBeHidden() async {
        let (presenter, interactor) = makePresenter()

        presenter.showCaloriesRing = false
        presenter.showProteinRing = false
        presenter.showFatRing = false
        presenter.showCarbsRing = false
        await TestManagers.eventually { interactor.savedSettings.count == 4 }

        let saved = interactor.savedSettings.last
        #expect(saved?.showCaloriesRing == false)
        #expect(saved?.showProteinRing == false)
        #expect(saved?.showFatRing == false)
        #expect(saved?.showCarbsRing == false)
    }

    @Test("Test Saving Keeps The Settings This Screen Does Not Show")
    func testSavingKeepsTheSettingsThisScreenDoesNotShow() async {
        let (presenter, interactor) = makePresenter(Support.untouchedFields)

        presenter.showFatRing = false
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }

        Support.expectUntouchedFieldsSurvived(interactor.savedSettings.last)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let (presenter, interactor) = makePresenter()

        presenter.onViewAppear()

        #expect(interactor.trackedScreenEventNames == ["LoggerBannerView_Appear"])
    }
}

// MARK: - Time Selection

/// A single switch: whether logging a food defaults to the current time.
@MainActor
struct NutritionSettingsTimeSelectionTests {

    private typealias Support = NutritionSettingsTileSupport

    private func makePresenter(
        _ configure: (inout FoodLogSettings) -> Void = { _ in }
    ) -> (TimeSelectionPresenter, Support.Interactor) {
        let interactor = Support.Interactor()
        configure(&interactor.foodLogSettings)
        return (TimeSelectionPresenter(interactor: interactor, router: Support.Router()), interactor)
    }

    @Test("Test The Switch Is Saved Both Ways")
    func testTheSwitchIsSavedBothWays() async {
        let (presenter, interactor) = makePresenter()

        presenter.autoSetCurrentTime = true
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }
        #expect(interactor.savedSettings.last?.autoSetCurrentTime == true)

        presenter.autoSetCurrentTime = false
        await TestManagers.eventually { interactor.savedSettings.count == 2 }
        #expect(interactor.savedSettings.last?.autoSetCurrentTime == false)
        #expect(presenter.autoSetCurrentTime == false)
    }

    @Test("Test Saving Keeps The Settings This Screen Does Not Show")
    func testSavingKeepsTheSettingsThisScreenDoesNotShow() async {
        let (presenter, interactor) = makePresenter(Support.untouchedFields)

        presenter.autoSetCurrentTime = true
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }

        Support.expectUntouchedFieldsSurvived(interactor.savedSettings.last)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let (presenter, interactor) = makePresenter()

        presenter.onViewAppear()

        #expect(interactor.trackedScreenEventNames == ["TimeSelectionView_Appear"])
    }
}

// MARK: - Favourite Measurements

/// The units offered first when entering an amount. A list, so the hazard is the usual one for a
/// list of selections: removing one losing the others.
@MainActor
struct NutritionSettingsFavouriteUnitsTests {

    private typealias Support = NutritionSettingsTileSupport

    private func makePresenter(
        _ configure: (inout FoodLogSettings) -> Void = { _ in }
    ) -> (FavouriteMeasurementsPresenter, Support.Interactor) {
        let interactor = Support.Interactor()
        configure(&interactor.foodLogSettings)
        return (FavouriteMeasurementsPresenter(interactor: interactor, router: Support.Router()), interactor)
    }

    /// The defaults have to come up already ticked, or the screen reads as though the user has
    /// never chosen anything and the list they actually get is a mystery.
    @Test("Test The Stored Favourites Come Up Selected")
    func testTheStoredFavouritesComeUpSelected() {
        let (presenter, _) = makePresenter()

        #expect(presenter.isSelected("g"))
        #expect(presenter.isSelected("serving"))
        #expect(!presenter.isSelected("tbsp"))
    }

    /// Every unit offered by the screen has to be one the list can hold — an option that cannot be
    /// ticked is a dead row.
    @Test("Test Every Offered Unit Can Be Selected")
    func testEveryOfferedUnitCanBeSelected() async {
        let (presenter, interactor) = makePresenter()

        for measurement in presenter.allMeasurements where !presenter.isSelected(measurement) {
            presenter.toggleMeasurement(measurement)
        }
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }

        #expect(presenter.allMeasurements.allSatisfy { presenter.isSelected($0) })
    }

    /// Removing one unit must leave the rest of the list exactly as it was. This is the list
    /// equivalent of one toggle undoing another.
    @Test("Test Removing One Unit Keeps The Others")
    func testRemovingOneUnitKeepsTheOthers() async {
        let (presenter, interactor) = makePresenter()
        let before = presenter.favouriteMeasurements

        presenter.toggleMeasurement("oz")
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }

        #expect(!presenter.isSelected("oz"))
        #expect(presenter.favouriteMeasurements == before.filter { $0 != "oz" })
        #expect(interactor.savedSettings.last?.favouriteMeasurements == before.filter { $0 != "oz" })
    }

    /// Unticking and re-ticking is how someone corrects a mistap, so it has to end where it
    /// started rather than leaving a duplicate or a hole.
    @Test("Test Unticking And Re-Ticking A Unit Restores The List")
    func testUntickingAndReTickingAUnitRestoresTheList() async {
        let (presenter, interactor) = makePresenter()
        let before = presenter.favouriteMeasurements

        presenter.toggleMeasurement("ml")
        presenter.toggleMeasurement("ml")
        await TestManagers.eventually { interactor.savedSettings.count == 2 }

        #expect(presenter.favouriteMeasurements.sorted() == before.sorted())
        #expect(Set(presenter.favouriteMeasurements).count == presenter.favouriteMeasurements.count)
    }

    @Test("Test Saving Keeps The Settings This Screen Does Not Show")
    func testSavingKeepsTheSettingsThisScreenDoesNotShow() async {
        let (presenter, interactor) = makePresenter(Support.untouchedFields)

        presenter.toggleMeasurement("tbsp")
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }

        Support.expectUntouchedFieldsSurvived(interactor.savedSettings.last)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let (presenter, interactor) = makePresenter()

        presenter.onViewAppear()

        #expect(interactor.trackedScreenEventNames == ["FavouriteMeasurementsView_Appear"])
    }
}

// MARK: - Optimisation

/// A single switch for the Quick Add shortcut.
@MainActor
struct NutritionSettingsOptimisationTests {

    private typealias Support = NutritionSettingsTileSupport

    private func makePresenter(
        _ configure: (inout FoodLogSettings) -> Void = { _ in }
    ) -> (OptimisationPresenter, Support.Interactor) {
        let interactor = Support.Interactor()
        configure(&interactor.foodLogSettings)
        return (OptimisationPresenter(interactor: interactor, router: Support.Router()), interactor)
    }

    @Test("Test The Switch Is Saved Both Ways")
    func testTheSwitchIsSavedBothWays() async {
        let (presenter, interactor) = makePresenter()

        presenter.quickAddEnabled = true
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }
        #expect(interactor.savedSettings.last?.quickAddEnabled == true)

        presenter.quickAddEnabled = false
        await TestManagers.eventually { interactor.savedSettings.count == 2 }
        #expect(interactor.savedSettings.last?.quickAddEnabled == false)
    }

    @Test("Test Saving Keeps The Settings This Screen Does Not Show")
    func testSavingKeepsTheSettingsThisScreenDoesNotShow() async {
        let (presenter, interactor) = makePresenter(Support.untouchedFields)

        presenter.quickAddEnabled = true
        await TestManagers.eventually { !interactor.savedSettings.isEmpty }

        Support.expectUntouchedFieldsSurvived(interactor.savedSettings.last)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let (presenter, interactor) = makePresenter()

        presenter.onViewAppear()

        #expect(interactor.trackedScreenEventNames == ["OptimisationView_Appear"])
    }
}
