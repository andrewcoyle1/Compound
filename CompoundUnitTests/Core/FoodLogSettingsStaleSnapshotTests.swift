//
//  FoodLogSettingsStaleSnapshotTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The six screens that share the `FoodLogSettings` document.
///
/// Each one edits a copy of the whole document and writes the whole thing back, so the copy has to
/// be the current one. Taken at init and never refreshed, it silently reverts whatever a sibling
/// screen saved in the meantime — and the favourite food and recipe ids, which the nutrition tab
/// writes into this same document, go with it.
@MainActor
struct FoodLogSettingsStaleSnapshotTests {

    /// Food Log Settings and its four sub-screens all declare the same two requirements, so one
    /// double serves them all. Timeline Actions needs more, and gets its own below.
    private final class Interactor: SpyGlobalInteractor,
                                    TimelineFoodTilesInteractor,
                                    LoggerFoodTilesInteractor,
                                    LoggerBannerInteractor,
                                    FavouriteMeasurementsInteractor,
                                    FoodLogSettingsInteractor {
        var foodLogSettings = FoodLogSettings(authorId: "user-1")

        func saveFoodLogSettings(_ settings: FoodLogSettings) async throws {
            foodLogSettings = settings
        }
    }

    private final class Router: TimelineFoodTilesRouter,
                                LoggerFoodTilesRouter,
                                LoggerBannerRouter,
                                FavouriteMeasurementsRouter,
                                FoodLogSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showTimelineFoodTilesView(delegate: TimelineFoodTilesDelegate) { }
        func showLoggerFoodTilesView(delegate: LoggerFoodTilesDelegate) { }
        func showLoggerBannerView(delegate: LoggerBannerDelegate) { }
        func showFavouriteMeasurementsView(delegate: FavouriteMeasurementsDelegate) { }

        func showAlert(error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    /// A favourite added from the nutrition tab after the screen was built, which every toggle
    /// below has to leave alone.
    private func interactorWithChangeMadeElsewhere() -> Interactor {
        let interactor = Interactor()
        var changedElsewhere = interactor.foodLogSettings
        changedElsewhere.favouriteFoodIds = ["food-1"]
        changedElsewhere.startHour = 5
        interactor.foodLogSettings = changedElsewhere
        return interactor
    }

    @Test("Test Timeline Food Tiles Does Not Revert Settings Changed Elsewhere")
    func testTimelineFoodTilesDoesNotRevertSettingsChangedElsewhere() async {
        let interactor = Interactor()
        let presenter = TimelineFoodTilesPresenter(interactor: interactor, router: Router())

        var changedElsewhere = interactor.foodLogSettings
        changedElsewhere.favouriteFoodIds = ["food-1"]
        interactor.foodLogSettings = changedElsewhere

        presenter.onViewAppear()
        presenter.showFoodImageInTimeline = false

        #expect(await TestManagers.eventually { interactor.foodLogSettings.showFoodImageInTimeline == false })
        #expect(interactor.foodLogSettings.favouriteFoodIds == ["food-1"])
    }

    @Test("Test Logger Food Tiles Does Not Revert Settings Changed Elsewhere")
    func testLoggerFoodTilesDoesNotRevertSettingsChangedElsewhere() async {
        let interactor = interactorWithChangeMadeElsewhere()
        let presenter = LoggerFoodTilesPresenter(interactor: interactor, router: Router())

        presenter.onViewAppear()
        presenter.showPortionInLogger = false

        #expect(await TestManagers.eventually { interactor.foodLogSettings.showPortionInLogger == false })
        #expect(interactor.foodLogSettings.favouriteFoodIds == ["food-1"])
        #expect(interactor.foodLogSettings.startHour == 5)
    }

    @Test("Test Logger Banner Does Not Revert Settings Changed Elsewhere")
    func testLoggerBannerDoesNotRevertSettingsChangedElsewhere() async {
        let interactor = interactorWithChangeMadeElsewhere()
        let presenter = LoggerBannerPresenter(interactor: interactor, router: Router())

        presenter.onViewAppear()
        presenter.showProteinRing = false

        #expect(await TestManagers.eventually { interactor.foodLogSettings.showProteinRing == false })
        #expect(interactor.foodLogSettings.favouriteFoodIds == ["food-1"])
        #expect(interactor.foodLogSettings.startHour == 5)
    }

    @Test("Test Auto-set Current Time Does Not Revert Settings Changed Elsewhere")
    func testAutoSetCurrentTimeDoesNotRevertSettingsChangedElsewhere() async {
        let interactor = interactorWithChangeMadeElsewhere()
        let presenter = FoodLogSettingsPresenter(interactor: interactor, router: Router())

        presenter.onViewAppear()
        presenter.autoSetCurrentTime = true

        #expect(await TestManagers.eventually { interactor.foodLogSettings.autoSetCurrentTime })
        #expect(interactor.foodLogSettings.favouriteFoodIds == ["food-1"])
        #expect(interactor.foodLogSettings.startHour == 5)
    }

    @Test("Test Favourite Measurements Does Not Revert Settings Changed Elsewhere")
    func testFavouriteMeasurementsDoesNotRevertSettingsChangedElsewhere() async {
        let interactor = interactorWithChangeMadeElsewhere()
        let presenter = FavouriteMeasurementsPresenter(interactor: interactor, router: Router())

        presenter.onViewAppear()
        presenter.toggleMeasurement("tbsp")

        #expect(await TestManagers.eventually {
            interactor.foodLogSettings.favouriteMeasurements.contains("tbsp")
        })
        #expect(interactor.foodLogSettings.favouriteFoodIds == ["food-1"])
        #expect(interactor.foodLogSettings.startHour == 5)
    }

    @Test("Test Quick Add Does Not Revert Settings Changed Elsewhere")
    func testQuickAddDoesNotRevertSettingsChangedElsewhere() async {
        let interactor = interactorWithChangeMadeElsewhere()
        let presenter = FoodLogSettingsPresenter(interactor: interactor, router: Router())

        presenter.onViewAppear()
        presenter.quickAddEnabled = true

        #expect(await TestManagers.eventually { interactor.foodLogSettings.quickAddEnabled })
        #expect(interactor.foodLogSettings.favouriteFoodIds == ["food-1"])
        #expect(interactor.foodLogSettings.startHour == 5)
    }

    /// And a re-read must not undo the user's own choice when the screen appears again after
    /// saving it.
    @Test("Test A Saved Choice Survives The Screen Reappearing")
    func testASavedChoiceSurvivesTheScreenReappearing() async {
        let interactor = Interactor()
        let presenter = FoodLogSettingsPresenter(interactor: interactor, router: Router())
        presenter.quickAddEnabled = true
        #expect(await TestManagers.eventually { interactor.foodLogSettings.quickAddEnabled })

        presenter.onViewAppear()

        #expect(presenter.quickAddEnabled)
    }
}

/// Timeline Actions lives on the nutrition tab rather than in settings, but writes the same
/// document from its own snapshot, so it carries the same hazard.
@MainActor
struct TimelineActionsStaleSnapshotTests {

    private final class Interactor: SpyGlobalInteractor, TimelineActionsInteractor {
        var currentUser: UserModel?
        var foodLogSettings = FoodLogSettings(authorId: "user-1")

        func saveFoodLogSettings(_ settings: FoodLogSettings) async throws {
            foodLogSettings = settings
        }

        func getMeals(for dayKey: String) throws -> [MealLogModel] { [] }
        func saveMeal(_ meal: MealLogModel) async throws { }
        func deleteMealAndSync(id: String, dayKey: String, authorId: String) async throws { }
    }

    private final class Router: TimelineActionsRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showAlert(error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    @Test("Test Hiding Empty Hours Does Not Revert Settings Changed Elsewhere")
    func testHidingEmptyHoursDoesNotRevertSettingsChangedElsewhere() async {
        let interactor = Interactor()
        let presenter = TimelineActionsPresenter(interactor: interactor, router: Router())

        var changedElsewhere = interactor.foodLogSettings
        changedElsewhere.favouriteFoodIds = ["food-1"]
        changedElsewhere.showCaloriesRing = false
        interactor.foodLogSettings = changedElsewhere

        presenter.onViewAppear(delegate: TimelineActionsDelegate())
        presenter.hideEmptyHours = true

        #expect(await TestManagers.eventually { interactor.foodLogSettings.hideEmptyHours })
        #expect(interactor.foodLogSettings.favouriteFoodIds == ["food-1"])
        #expect(interactor.foodLogSettings.showCaloriesRing == false)
    }
}
