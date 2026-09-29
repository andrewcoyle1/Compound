//
//  SettingsSnapshotRefreshTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Strategy and Expenditure, the two screens that share the `NutritionStrategySettings` document.
///
/// Both edit a copy of the whole document and write the whole thing back, so a copy taken when the
/// screen was pushed and never refreshed reverts whatever the other one saved in between.
@MainActor
struct NutritionStrategyStaleSnapshotTests {

    private final class Interactor: SpyGlobalInteractor,
                                    StrategySettingsInteractor,
                                    ExpenditureSettingsInteractor {
        var nutritionStrategySettings = NutritionStrategySettings(authorId: "user-1")
        var currentExpenditure = ExpenditureEstimate.stub

        func saveNutritionStrategySettings(_ settings: NutritionStrategySettings) async throws {
            nutritionStrategySettings = settings
        }
    }

    private final class Router: StrategySettingsRouter, ExpenditureSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @Test("Test A Strategy Toggle Does Not Revert The Expenditure Screen")
    func testAStrategyToggleDoesNotRevertTheExpenditureScreen() async {
        let interactor = Interactor()
        let presenter = StrategySettingsPresenter(interactor: interactor, router: Router())

        // The Expenditure screen saves while this one is still on the stack behind it.
        var changedElsewhere = interactor.nutritionStrategySettings
        changedElsewhere.bmrEquation = .katchMcArdle
        changedElsewhere.stepInformedUpdates = true
        interactor.nutritionStrategySettings = changedElsewhere

        presenter.onViewAppear()
        presenter.fastCheckInEnabled = true

        #expect(await TestManagers.eventually { interactor.nutritionStrategySettings.fastCheckIn })
        #expect(interactor.nutritionStrategySettings.bmrEquation == .katchMcArdle)
        #expect(interactor.nutritionStrategySettings.stepInformedUpdates)
    }

    @Test("Test An Expenditure Choice Does Not Revert The Strategy Screen")
    func testAnExpenditureChoiceDoesNotRevertTheStrategyScreen() async {
        let interactor = Interactor()
        let presenter = ExpenditureSettingsPresenter(interactor: interactor, router: Router())

        var changedElsewhere = interactor.nutritionStrategySettings
        changedElsewhere.checkInWeekday = 5
        changedElsewhere.fastingEnabled = false
        interactor.nutritionStrategySettings = changedElsewhere

        presenter.onViewAppear()
        presenter.bmrEquation = .harrisBenedict

        #expect(await TestManagers.eventually {
            interactor.nutritionStrategySettings.bmrEquation == .harrisBenedict
        })
        #expect(interactor.nutritionStrategySettings.checkInWeekday == 5)
        #expect(interactor.nutritionStrategySettings.fastingEnabled == false)
    }

    @Test("Test A Saved Expenditure Choice Survives The Screen Reappearing")
    func testASavedExpenditureChoiceSurvivesTheScreenReappearing() async {
        let interactor = Interactor()
        let presenter = ExpenditureSettingsPresenter(interactor: interactor, router: Router())
        presenter.bmrEquation = .harrisBenedict
        #expect(await TestManagers.eventually {
            interactor.nutritionStrategySettings.bmrEquation == .harrisBenedict
        })

        presenter.onViewAppear()

        #expect(presenter.bmrEquation == .harrisBenedict)
    }
}

/// Customise Analytics and Shortcuts each own their document outright, so no sibling screen can
/// revert them — but the document is still a synced one, and a snapshot taken when the screen was
/// pushed reverts a change that arrived from another device while it sat there.
@MainActor
struct GeneralSettingsSnapshotRefreshTests {

    private final class Interactor: SpyGlobalInteractor,
                                    CustomiseAnalyticsInteractor,
                                    ShortcutsInteractor {
        var analyticsSettings = AnalyticsSettings(authorId: "user-1")
        var shortcutSettings = ShortcutSettings(authorId: "user-1")

        func saveAnalyticsSettings(_ settings: AnalyticsSettings) async throws {
            analyticsSettings = settings
        }

        func saveShortcutSettings(_ settings: ShortcutSettings) async throws {
            shortcutSettings = settings
        }
    }

    private final class Router: CustomiseAnalyticsRouter, ShortcutsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @Test("Test Customise Analytics Picks Up A Change Made Elsewhere")
    func testCustomiseAnalyticsPicksUpAChangeMadeElsewhere() async {
        let interactor = Interactor()
        let presenter = CustomiseAnalyticsPresenter(interactor: interactor, router: Router())

        var changedElsewhere = interactor.analyticsSettings
        changedElsewhere.setVisible(false, for: .habits)
        interactor.analyticsSettings = changedElsewhere

        presenter.onViewAppear()
        presenter.setVisible(false, for: .exercises)

        #expect(await TestManagers.eventually {
            interactor.analyticsSettings.isVisible(.exercises) == false
        })
        #expect(interactor.analyticsSettings.isVisible(.habits) == false)
    }

    @Test("Test Shortcuts Picks Up A Change Made Elsewhere")
    func testShortcutsPicksUpAChangeMadeElsewhere() async {
        let interactor = Interactor()
        let presenter = ShortcutsPresenter(interactor: interactor, router: Router())

        var changedElsewhere = interactor.shortcutSettings
        changedElsewhere.setQuickActions([.logMeal])
        interactor.shortcutSettings = changedElsewhere

        presenter.onViewAppear()
        presenter.onAddPressed(.browseRecipes)

        #expect(await TestManagers.eventually {
            interactor.shortcutSettings.quickActions == [.logMeal, .browseRecipes]
        })
    }
}
