//
//  SaveFailureAlertTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Every settings screen saves the whole document when a control changes. The save used to be a
/// `try?`, so a rejected write left the control showing a value that was never stored and told
/// nobody. Each screen now raises exactly one alert and tracks exactly one `_Save_Fail` event.
@MainActor
struct SaveFailureAlertTests {

    private struct SaveFailed: Error { }

    /// One double serves every settings screen: each save throws.
    private final class Interactor: SpyGlobalInteractor,
                                    UnitsInteractor,
                                    ShortcutsInteractor,
                                    CustomiseAnalyticsInteractor,
                                    StrategySettingsInteractor,
                                    ExpenditureSettingsInteractor,
                                    FoodLogSettingsInteractor,
                                    TimelineFoodTilesInteractor,
                                    LoggerFoodTilesInteractor,
                                    LoggerBannerInteractor,
                                    TimeSelectionInteractor,
                                    FavouriteMeasurementsInteractor,
                                    OptimisationInteractor,
                                    WorkoutSettingsInteractor,
                                    SmartProgressionSettingsInteractor,
                                    RestTimerSettingsInteractor,
                                    PrevWORefSettingsInteractor,
                                    TimelineActionsInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var shortcutSettings = ShortcutSettings(authorId: "user-1")
        var analyticsSettings = AnalyticsSettings(authorId: "user-1")
        var nutritionStrategySettings = NutritionStrategySettings(authorId: "user-1")
        var currentExpenditure = ExpenditureEstimate.stub
        var foodLogSettings = FoodLogSettings(authorId: "user-1")
        var workoutSettings = WorkoutSettings(authorId: "user-1")

        func updateUnitPreferences(
            length: LengthUnitPreference,
            weight: WeightUnitPreference,
            distance: DistanceUnitPreference
        ) async throws { throw SaveFailed() }
        func saveShortcutSettings(_ settings: ShortcutSettings) async throws { throw SaveFailed() }
        func saveAnalyticsSettings(_ settings: AnalyticsSettings) async throws { throw SaveFailed() }
        func saveNutritionStrategySettings(_ settings: NutritionStrategySettings) async throws { throw SaveFailed() }
        func saveFoodLogSettings(_ settings: FoodLogSettings) async throws { throw SaveFailed() }
        func saveWorkoutSettings(_ workoutSettings: WorkoutSettings) async throws { throw SaveFailed() }

        func getMeals(for dayKey: String) throws -> [MealLogModel] { [] }
        func saveMeal(_ meal: MealLogModel) async throws { }
        func deleteMealAndSync(id: String, dayKey: String, authorId: String) async throws { }
    }

    private final class Router: UnitsRouter,
                                ShortcutsRouter,
                                CustomiseAnalyticsRouter,
                                StrategySettingsRouter,
                                ExpenditureSettingsRouter,
                                FoodLogSettingsRouter,
                                TimelineFoodTilesRouter,
                                LoggerFoodTilesRouter,
                                LoggerBannerRouter,
                                TimeSelectionRouter,
                                FavouriteMeasurementsRouter,
                                OptimisationRouter,
                                WorkoutSettingsRouter,
                                SmartProgressionSettingsRouter,
                                RestTimerSettingsRouter,
                                PreviousWorkoutReferenceSettingsRouter,
                                TimelineActionsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []

        func showAlert(error: Error) { alertTitles.append("error") }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }

        func showDevSettingsView() { }
        func showTimelineFoodTilesView(delegate: TimelineFoodTilesDelegate) { }
        func showLoggerFoodTilesView(delegate: LoggerFoodTilesDelegate) { }
        func showLoggerBannerView(delegate: LoggerBannerDelegate) { }
        func showTimeSelectionView(delegate: TimeSelectionDelegate) { }
        func showFavouriteMeasurementsView(delegate: FavouriteMeasurementsDelegate) { }
        func showOptimisationView(delegate: OptimisationDelegate) { }
        func showRestTimerSettingsView(delegate: RestTimerSettingsDelegate) { }
        func showSmartProgressionSettingsView(delegate: SmartProgressionSettingsDelegate) { }
        func showPreviousWorkoutReferenceSettingsView(delegate: PrevWORefSettingsDelegate) { }
        func showExerciseAssessmentView(delegate: ExerciseAssessmentDelegate) { }
        func showTimerDurationView(delegate: TimerDurationDelegate) { }
    }

    /// Runs `change` and waits for the failed save to report, then asserts it reported once.
    private func expectOneFailure(
        _ eventName: String,
        _ change: (Interactor, Router) -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        let interactor = Interactor()
        let router = Router()
        change(interactor, router)

        #expect(await TestManagers.eventually(timeout: .seconds(5)) { !router.alertTitles.isEmpty }, sourceLocation: sourceLocation)
        for _ in 0..<10 { await Task.yield() }
        #expect(router.alertTitles == ["Unable to Save Settings"], sourceLocation: sourceLocation)
        #expect(interactor.trackedEventNames.filter { $0.hasSuffix("_Fail") } == [eventName], sourceLocation: sourceLocation)
    }

    @Test("Test Units Reports A Failed Save")
    func testUnitsReportsAFailedSave() async {
        await expectOneFailure("UnitsView_Save_Fail") { interactor, router in
            UnitsPresenter(interactor: interactor, router: router).weightUnit = .pounds
        }
    }

    @Test("Test Shortcuts Reports A Failed Save")
    func testShortcutsReportsAFailedSave() async {
        await expectOneFailure("ShortcutsView_Save_Fail") { interactor, router in
            ShortcutsPresenter(interactor: interactor, router: router).onRestoreDefaultsPressed()
        }
    }

    @Test("Test Customise Analytics Reports A Failed Save")
    func testCustomiseAnalyticsReportsAFailedSave() async {
        await expectOneFailure("CustomiseAnalyticsView_Save_Fail") { interactor, router in
            CustomiseAnalyticsPresenter(interactor: interactor, router: router).onShowAllPressed()
        }
    }

    @Test("Test Strategy Settings Reports A Failed Save")
    func testStrategySettingsReportsAFailedSave() async {
        await expectOneFailure("StrategySettingsView_Save_Fail") { interactor, router in
            StrategySettingsPresenter(interactor: interactor, router: router).fastCheckInEnabled.toggle()
        }
    }

    @Test("Test Expenditure Settings Reports A Failed Save")
    func testExpenditureSettingsReportsAFailedSave() async {
        await expectOneFailure("ExpenditureSettingsView_Save_Fail") { interactor, router in
            ExpenditureSettingsPresenter(interactor: interactor, router: router).stepInformedUpdates.toggle()
        }
    }

    @Test("Test Food Log Settings Reports A Failed Save")
    func testFoodLogSettingsReportsAFailedSave() async {
        await expectOneFailure("FoodLogSettingsView_Save_Fail") { interactor, router in
            FoodLogSettingsPresenter(interactor: interactor, router: router).showOverages.toggle()
        }
    }

    @Test("Test Timeline Food Tiles Reports A Failed Save")
    func testTimelineFoodTilesReportsAFailedSave() async {
        await expectOneFailure("TimelineFoodTilesView_Save_Fail") { interactor, router in
            TimelineFoodTilesPresenter(interactor: interactor, router: router).showFoodImageInTimeline.toggle()
        }
    }

    @Test("Test Logger Food Tiles Reports A Failed Save")
    func testLoggerFoodTilesReportsAFailedSave() async {
        await expectOneFailure("LoggerFoodTilesView_Save_Fail") { interactor, router in
            LoggerFoodTilesPresenter(interactor: interactor, router: router).showPortionInLogger.toggle()
        }
    }

    @Test("Test Logger Banner Reports A Failed Save")
    func testLoggerBannerReportsAFailedSave() async {
        await expectOneFailure("LoggerBannerView_Save_Fail") { interactor, router in
            LoggerBannerPresenter(interactor: interactor, router: router).showProteinRing.toggle()
        }
    }

    @Test("Test Time Selection Reports A Failed Save")
    func testTimeSelectionReportsAFailedSave() async {
        await expectOneFailure("TimeSelectionView_Save_Fail") { interactor, router in
            TimeSelectionPresenter(interactor: interactor, router: router).autoSetCurrentTime.toggle()
        }
    }

    @Test("Test Favourite Measurements Reports A Failed Save")
    func testFavouriteMeasurementsReportsAFailedSave() async {
        await expectOneFailure("FavouriteMeasurementsView_Save_Fail") { interactor, router in
            FavouriteMeasurementsPresenter(interactor: interactor, router: router).toggleMeasurement("tbsp")
        }
    }

    @Test("Test Optimisation Reports A Failed Save")
    func testOptimisationReportsAFailedSave() async {
        await expectOneFailure("OptimisationView_Save_Fail") { interactor, router in
            OptimisationPresenter(interactor: interactor, router: router).quickAddEnabled.toggle()
        }
    }

    @Test("Test Workout Settings Reports A Failed Save")
    func testWorkoutSettingsReportsAFailedSave() async {
        await expectOneFailure("WorkoutSettingsView_Save_Fail") { interactor, router in
            WorkoutSettingsPresenter(interactor: interactor, router: router).rirTracking.toggle()
        }
    }

    @Test("Test Smart Progression Settings Reports A Failed Save")
    func testSmartProgressionSettingsReportsAFailedSave() async {
        await expectOneFailure("SmartProgressionSettingsView_Save_Fail") { interactor, router in
            SmartProgressionSettingsPresenter(interactor: interactor, router: router).applyInSession.toggle()
        }
    }

    @Test("Test Rest Timer Settings Reports A Failed Save")
    func testRestTimerSettingsReportsAFailedSave() async {
        await expectOneFailure("RestTimerSettingsView_Save_Fail") { interactor, router in
            RestTimerSettingsPresenter(interactor: interactor, router: router).restBetweenExercises.toggle()
        }
    }

    @Test("Test Previous Workout Reference Settings Reports A Failed Save")
    func testPreviousWorkoutReferenceSettingsReportsAFailedSave() async {
        await expectOneFailure("PreviousWorkoutReferenceSettingsView_Save_Fail") { interactor, router in
            let presenter = PrevWORefSettingsPresenter(interactor: interactor, router: router)
            presenter.previousWorkoutReference = PreviousWorkoutReferenceOption.allCases.last ?? presenter.previousWorkoutReference
        }
    }

    @Test("Test Timeline Actions Reports A Failed Save")
    func testTimelineActionsReportsAFailedSave() async {
        await expectOneFailure("TimelineActionsView_Save_Fail") { interactor, router in
            TimelineActionsPresenter(interactor: interactor, router: router).hideEmptyHours.toggle()
        }
    }
}
