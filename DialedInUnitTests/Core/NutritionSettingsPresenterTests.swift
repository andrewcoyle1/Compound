//
//  NutritionSettingsPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

// MARK: - Food Log Settings

/// The Food Log Settings screen: eleven preferences edited in place, plus six rows that push a
/// sub-screen editing the *same* settings document.
///
/// Every one of these presenters holds a copy of the stored settings and writes the whole document
/// back on each change, so the failure to watch for is not "did the toggle save" but "did saving
/// this toggle undo something else". That is what most of these tests are about.
@MainActor
struct NutritionSettingsFoodLogTests {

    private final class Interactor: SpyGlobalInteractor, FoodLogSettingsInteractor {
        var foodLogSettings = FoodLogSettings(authorId: "user-1")
        private(set) var savedSettings: [FoodLogSettings] = []

        func saveFoodLogSettings(_ settings: FoodLogSettings) async throws {
            savedSettings.append(settings)
            foodLogSettings = settings
        }
    }

    /// `FoodLogSettingsRouter` requires only the six sub-screen destinations, so those are the only
    /// calls a double sees. The alignment picker goes out through `showAlert(title:subtitle:buttons:)`,
    /// a `GlobalRouter` extension that dispatches statically — see the alignment test.
    private final class Router: FoodLogSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showTimelineFoodTilesView(delegate: TimelineFoodTilesDelegate) { shown.append("timelineFoodTiles") }
        func showLoggerFoodTilesView(delegate: LoggerFoodTilesDelegate) { shown.append("loggerFoodTiles") }
        func showLoggerBannerView(delegate: LoggerBannerDelegate) { shown.append("loggerBanner") }
        func showTimeSelectionView(delegate: TimeSelectionDelegate) { shown.append("timeSelection") }
        func showFavouriteMeasurementsView(delegate: FavouriteMeasurementsDelegate) { shown.append("favouriteMeasurements") }
        func showOptimisationView(delegate: OptimisationDelegate) { shown.append("optimisation") }
    }

    private struct Screen {
        let presenter: FoodLogSettingsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(_ configure: (inout FoodLogSettings) -> Void = { _ in }) -> Screen {
        let interactor = Interactor()
        configure(&interactor.foodLogSettings)
        let router = Router()
        return Screen(
            presenter: FoodLogSettingsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: Toggles

    @Test("Test Each Toggle Is Saved As It Is Flicked")
    func testEachToggleIsSavedAsItIsFlicked() async {
        let screen = makeScreen()

        screen.presenter.showsFoodTimestamps = false
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.presenter.showsFoodTimestamps == false)
        #expect(screen.interactor.savedSettings.last?.showsFoodTimestamps == false)
    }

    /// The screen has no Save button, so every change writes the whole document. The second write
    /// has to carry the first one's value with it rather than the value the screen opened with.
    @Test("Test One Toggle Does Not Undo Another")
    func testOneToggleDoesNotUndoAnother() async {
        let screen = makeScreen()

        screen.presenter.showsFoodTimestamps = false
        screen.presenter.showHourlyMacroTotals = false
        screen.presenter.showCalendarWeekBanner = false
        screen.presenter.showAddFoodsButton = false
        await TestManagers.eventually { screen.interactor.savedSettings.count == 4 }

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.showsFoodTimestamps == false)
        #expect(saved?.showHourlyMacroTotals == false)
        #expect(saved?.showCalendarWeekBanner == false)
        #expect(saved?.showAddFoodsButton == false)
    }

    /// The document also holds the user's favourited foods and recipes, written from the nutrition
    /// tab rather than from here. A settings save must not wipe them.
    @Test("Test Saving A Toggle Keeps The Favourites In The Document")
    func testSavingAToggleKeepsTheFavouritesInTheDocument() async {
        let screen = makeScreen { settings in
            settings.favouriteFoodIds = ["food-1", "food-2"]
            settings.favouriteRecipeIds = ["recipe-1"]
        }

        screen.presenter.showOverages = true
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.interactor.savedSettings.last?.favouriteFoodIds == ["food-1", "food-2"])
        #expect(screen.interactor.savedSettings.last?.favouriteRecipeIds == ["recipe-1"])
    }

    /// The Show Overages row described the opposite of its own state: on, it said no negative
    /// numbers would be used. Each half now says what that state actually does.
    @Test("Test The Show Overages Subtitle Describes The State It Is In")
    func testTheShowOveragesSubtitleDescribesTheStateItIsIn() {
        let screen = makeScreen()

        #expect(screen.presenter.showOverages == false)
        #expect(screen.presenter.showOveragesSubtitle.hasPrefix("No negative numbers"))

        screen.presenter.showOverages = true
        #expect(screen.presenter.showOveragesSubtitle.hasPrefix("Negative numbers will be used"))
    }

    /// Six rows on this screen push a sub-screen that edits the same document. Coming back and
    /// flicking a toggle here used to save the copy taken when this screen was first opened, so the
    /// tile and ring choices just made in the sub-screen silently reverted.
    @Test("Test Returning From A Sub Screen Does Not Undo Its Changes")
    func testReturningFromASubScreenDoesNotUndoItsChanges() async {
        let screen = makeScreen()
        screen.presenter.onViewAppear()

        // The sub-screen is pushed, turns two things off, and is popped.
        screen.presenter.onTimelineFoodTilesPressed()
        screen.interactor.foodLogSettings.showCaloriesInTimeline = false
        screen.interactor.foodLogSettings.showCaloriesRing = false
        screen.presenter.onViewAppear()

        screen.presenter.showsFoodTimestamps = false
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.showCaloriesInTimeline == false)
        #expect(saved?.showCaloriesRing == false)
        #expect(saved?.showsFoodTimestamps == false)
    }

    // MARK: Timeline hours

    /// The hour range is what the timeline draws between, so both ends have to persist. Saving only
    /// one would leave the timeline half-moved.
    @Test("Test Both Ends Of The Hour Range Are Saved")
    func testBothEndsOfTheHourRangeAreSaved() async {
        let screen = makeScreen()

        screen.presenter.startHour = 5
        screen.presenter.endHour = 21
        await TestManagers.eventually { screen.interactor.savedSettings.count == 2 }

        #expect(screen.interactor.savedSettings.last?.startHour == 5)
        #expect(screen.interactor.savedSettings.last?.endHour == 21)
    }

    /// The row's subtitle is the only place the chosen range is shown, and midnight and midday are
    /// where a naive 12-hour conversion produces "0 AM" and "0 PM".
    @Test("Test The Hour Range Subtitle Reads In Twelve Hour Time")
    func testTheHourRangeSubtitleReadsInTwelveHourTime() {
        let screen = makeScreen { settings in
            settings.startHour = 0
            settings.endHour = 12
        }

        #expect(screen.presenter.hourRangeSubtitle == "12 AM – 12 PM")

        let evening = makeScreen { settings in
            settings.startHour = 7
            settings.endHour = 23
        }
        #expect(evening.presenter.hourRangeSubtitle == "7 AM – 11 PM")
    }

    @Test("Test The Hour Range Picker Opens On Request")
    func testTheHourRangePickerOpensOnRequest() {
        let screen = makeScreen()

        screen.presenter.onEditHourRangePressed()

        #expect(screen.presenter.isShowingHourRangePicker)
    }

    // MARK: Alignment

    /// The side the timestamp sits on. The picker itself is raised through a `GlobalRouter`
    /// extension, so its buttons cannot be pressed from here — what is checked is that the stored
    /// value and the subtitle that reports it agree, which is what the user sees on the row.
    @Test("Test The Timestamp Side Is Saved And Reported")
    func testTheTimestampSideIsSavedAndReported() async {
        let screen = makeScreen()
        #expect(screen.presenter.alignmentSubtitle == "Left")

        screen.presenter.timestampSide = .right
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.presenter.alignmentSubtitle == "Right")
        #expect(screen.interactor.savedSettings.last?.timestampSide == .right)
    }

    // MARK: Search sources

    /// Both food-source filters are read by the food search, so switching one off must not switch
    /// the other back on — that would put branded results back in front of someone who removed them.
    @Test("Test The Two Food Source Filters Are Independent")
    func testTheTwoFoodSourceFiltersAreIndependent() async {
        let screen = makeScreen()

        screen.presenter.showBrandedFoods = false
        screen.presenter.showOpenFoodFactsFoods = false
        await TestManagers.eventually { screen.interactor.savedSettings.count == 2 }

        #expect(screen.interactor.savedSettings.last?.showBrandedFoods == false)
        #expect(screen.interactor.savedSettings.last?.showOpenFoodFactsFoods == false)
    }

    // MARK: Navigation

    @Test("Test Every Sub Screen Can Be Reached")
    func testEverySubScreenCanBeReached() {
        let screen = makeScreen()

        screen.presenter.onLoggedBannerPressed()
        screen.presenter.onTimelineFoodTilesPressed()
        screen.presenter.onLoggerFoodTilesPressed()
        screen.presenter.onTimeSelectionPressed()
        screen.presenter.onFavouriteMeasurementsPressed()
        screen.presenter.onOptimisationPressed()

        #expect(screen.router.shown == [
            "loggerBanner", "timelineFoodTiles", "loggerFoodTiles",
            "timeSelection", "favouriteMeasurements", "optimisation"
        ])
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["FoodLogSettingsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["FoodLogSettingsView_Disappear"])
    }
}

// MARK: - Expenditure Settings

/// How the app estimates what the user burns. Only `bmrEquation` currently changes a number — the
/// rest record a choice an adaptive engine will read later — so the tests here are about the
/// choices being stored faithfully rather than about arithmetic.
@MainActor
struct NutritionSettingsExpenditureTests {

    private final class Interactor: SpyGlobalInteractor, ExpenditureSettingsInteractor {
        var nutritionStrategySettings = NutritionStrategySettings(authorId: "user-1")
        var currentExpenditure = ExpenditureEstimate.stub
        private(set) var savedSettings: [NutritionStrategySettings] = []

        func saveNutritionStrategySettings(_ settings: NutritionStrategySettings) async throws {
            savedSettings.append(settings)
            nutritionStrategySettings = settings
        }
    }

    private final class Router: ExpenditureSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: ExpenditureSettingsPresenter
        let interactor: Interactor
    }

    private func makeScreen(_ configure: (inout NutritionStrategySettings) -> Void = { _ in }) -> Screen {
        let interactor = Interactor()
        configure(&interactor.nutritionStrategySettings)
        return Screen(
            presenter: ExpenditureSettingsPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    /// The BMR equation is the one setting here that moves the calorie target, so it has to reach
    /// the stored document exactly as picked.
    @Test("Test The BMR Equation Is Saved")
    func testTheBMREquationIsSaved() async {
        let screen = makeScreen()

        screen.presenter.bmrEquation = .katchMcArdle
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.interactor.savedSettings.last?.bmrEquation == .katchMcArdle)
        #expect(screen.presenter.bmrEquation == .katchMcArdle)
    }

    /// This screen and the Strategy screen write the same document. Saving one field here must
    /// carry the rest of it, including the strategy fields this screen never shows.
    @Test("Test Saving One Choice Keeps The Others")
    func testSavingOneChoiceKeepsTheOthers() async {
        let screen = makeScreen { settings in
            settings.checkInWeekday = 6
            settings.fastingEnabled = false
        }

        screen.presenter.estimationMethod = .bodyFatAware
        screen.presenter.calculationMode = .fixed
        screen.presenter.stepInformedUpdates = true
        screen.presenter.predictiveGoalAdjustments = false
        await TestManagers.eventually { screen.interactor.savedSettings.count == 4 }

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.estimationMethod == .bodyFatAware)
        #expect(saved?.calculationMode == .fixed)
        #expect(saved?.stepInformedUpdates == true)
        #expect(saved?.predictiveGoalAdjustments == false)
        #expect(saved?.checkInWeekday == 6)
        #expect(saved?.fastingEnabled == false)
    }

    /// Unset means "since you started logging". The row says "Default" rather than showing today's
    /// date, which would read as a start date the user had chosen.
    @Test("Test An Unset Start Date Reads As Default")
    func testAnUnsetStartDateReadsAsDefault() {
        let screen = makeScreen()

        #expect(screen.presenter.calculationStartDateLabel == "Default")
    }

    @Test("Test Choosing A Start Date Saves And Shows It")
    func testChoosingAStartDateSavesAndShowsIt() async {
        let screen = makeScreen()
        let chosen = Date(timeIntervalSince1970: 1_700_000_000)

        screen.presenter.calculationStartDate = chosen
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.interactor.savedSettings.last?.calculationStartDate == chosen)
        #expect(screen.presenter.calculationStartDateLabel != "Default")
    }

    /// Clearing has to write the cleared document, not just close the picker — otherwise the date
    /// is back the next time the screen is opened.
    @Test("Test Clearing The Start Date Saves The Cleared Value")
    func testClearingTheStartDateSavesTheClearedValue() async {
        let screen = makeScreen { settings in
            settings.calculationStartDate = Date(timeIntervalSince1970: 1_700_000_000)
        }
        screen.presenter.onEditStartDatePressed()

        screen.presenter.onClearStartDatePressed()
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.interactor.savedSettings.last?.calculationStartDate == nil)
        #expect(screen.presenter.calculationStartDateLabel == "Default")
        #expect(!screen.presenter.isChoosingStartDate)
    }

    // MARK: - Today's estimate

    /// "2,480 kcal" on its own cannot tell a month of logging apart from a guess off the user's
    /// height, so the line under it says which it is.
    @Test("Test An Adaptive Estimate Says How Much Was Logged")
    func testAnAdaptiveEstimateSaysHowMuchWasLogged() {
        let interactor = Interactor()
        interactor.currentExpenditure = .stub.with(kcal: 2480, source: .adaptive, loggedDays: 21, windowDays: 28)
        let presenter = ExpenditureSettingsPresenter(interactor: interactor, router: Router())

        #expect(presenter.expenditureValueText == "2480 kcal")
        #expect(presenter.expenditureStatusText == "Adaptive \u{00B7} 21 of 28 days logged")
    }

    @Test("Test A Provisional Estimate Says It Is Still The Profile Figure")
    func testAProvisionalEstimateSaysItIsStillTheProfileFigure() {
        let interactor = Interactor()
        interactor.currentExpenditure = .stub.with(source: .prior, isProvisional: true)
        let presenter = ExpenditureSettingsPresenter(interactor: interactor, router: Router())

        #expect(presenter.expenditureStatusText == "Estimated from your profile until 14 days are logged")
    }

    @Test("Test A Fixed Estimate Says Fixed")
    func testAFixedEstimateSaysFixed() {
        let interactor = Interactor()
        interactor.currentExpenditure = .stub.with(source: .fixed)
        let presenter = ExpenditureSettingsPresenter(interactor: interactor, router: Router())

        #expect(presenter.expenditureStatusText == "Fixed")
    }

    /// The nowcast is an adjustment on top of the measurement, so it is named separately rather
    /// than folded silently into the figure.
    @Test("Test A Step Nowcast Is Called Out Separately")
    func testAStepNowcastIsCalledOutSeparately() {
        let interactor = Interactor()
        interactor.currentExpenditure = .stub.with(stepAdjustmentKcal: 120)
        let presenter = ExpenditureSettingsPresenter(interactor: interactor, router: Router())

        #expect(presenter.stepAdjustmentText == "Includes +120 kcal from your recent step count")

        interactor.currentExpenditure = .stub.with(stepAdjustmentKcal: 0)
        presenter.onViewAppear()
        #expect(presenter.stepAdjustmentText == nil)
    }

    /// Every option the pickers offer has to be one the model can hold, or a choice silently does
    /// nothing when it comes back from storage.
    @Test("Test Every Offered Option Is A Storable Case")
    func testEveryOfferedOptionIsAStorableCase() {
        let screen = makeScreen()

        #expect(screen.presenter.estimationMethods == ExpenditureEstimationMethod.allCases)
        #expect(screen.presenter.bmrEquations == BMREquation.allCases)
        #expect(screen.presenter.calculationModes == ExpenditureCalculationMode.allCases)
        #expect(screen.presenter.algorithmVersions == ExpenditureAlgorithmVersion.allCases)
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["ExpenditureSettingsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["ExpenditureSettingsView_Disappear"])
    }
}

// MARK: - Strategy Settings

/// The weekly check-in and the four things the user is allowed to skip. Same document as the
/// Expenditure screen, so the sibling-clobbering test matters here too.
@MainActor
struct NutritionSettingsStrategyTests {

    private final class Interactor: SpyGlobalInteractor, StrategySettingsInteractor {
        var nutritionStrategySettings = NutritionStrategySettings(authorId: "user-1")
        private(set) var savedSettings: [NutritionStrategySettings] = []

        func saveNutritionStrategySettings(_ settings: NutritionStrategySettings) async throws {
            savedSettings.append(settings)
            nutritionStrategySettings = settings
        }
    }

    private final class Router: StrategySettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: StrategySettingsPresenter
        let interactor: Interactor
    }

    private func makeScreen(_ configure: (inout NutritionStrategySettings) -> Void = { _ in }) -> Screen {
        let interactor = Interactor()
        configure(&interactor.nutritionStrategySettings)
        return Screen(
            presenter: StrategySettingsPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    /// Five independent toggles written back as one document. Turning one off must not turn any of
    /// the others back on.
    @Test("Test One Toggle Does Not Undo Another")
    func testOneToggleDoesNotUndoAnother() async {
        let screen = makeScreen()

        screen.presenter.fastCheckInEnabled = true
        screen.presenter.partialLoggingEnabled = false
        screen.presenter.weighInEnabled = false
        screen.presenter.fastingEnabled = false
        screen.presenter.loggingBreakEnabled = false
        await TestManagers.eventually { screen.interactor.savedSettings.count == 5 }

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.fastCheckIn == true)
        #expect(saved?.partialLoggingEnabled == false)
        #expect(saved?.weighInEnabled == false)
        #expect(saved?.fastingEnabled == false)
        #expect(saved?.loggingBreakEnabled == false)
    }

    /// The expenditure choices live in the same document and are not shown on this screen, so a
    /// strategy toggle must not reset them.
    @Test("Test Saving A Toggle Keeps The Expenditure Choices")
    func testSavingAToggleKeepsTheExpenditureChoices() async {
        let screen = makeScreen { settings in
            settings.bmrEquation = .harrisBenedict
            settings.calculationMode = .fixed
        }

        screen.presenter.weighInEnabled = false
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.interactor.savedSettings.last?.bmrEquation == .harrisBenedict)
        #expect(screen.interactor.savedSettings.last?.calculationMode == .fixed)
    }

    /// `Calendar.weekdaySymbols` is Sunday-first and zero-indexed while a `weekday` component is
    /// one-based, so the option list and the name shown on the row have to agree about the offset.
    /// Off by one here and the check-in lands on the wrong day of the week.
    @Test("Test The Chosen Weekday Name Matches The Option Picked")
    func testTheChosenWeekdayNameMatchesTheOptionPicked() async {
        let screen = makeScreen()

        for option in screen.presenter.weekdayOptions {
            screen.presenter.checkInWeekday = option.weekday
            #expect(screen.presenter.checkInWeekdayName == option.name)
        }

        await TestManagers.eventually { screen.interactor.savedSettings.count == screen.presenter.weekdayOptions.count }
        #expect(screen.interactor.savedSettings.last?.checkInWeekday == 7)
    }

    @Test("Test Seven Weekdays Are Offered Starting At One")
    func testSevenWeekdaysAreOfferedStartingAtOne() {
        let screen = makeScreen()

        #expect(screen.presenter.weekdayOptions.count == 7)
        #expect(screen.presenter.weekdayOptions.map(\.weekday) == Array(1...7))
    }

    @Test("Test The Check In Day Picker Opens On Request")
    func testTheCheckInDayPickerOpensOnRequest() {
        let screen = makeScreen()

        screen.presenter.onEditCheckInDayPressed()

        #expect(screen.presenter.isChoosingCheckInDay)
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["StrategySettingsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["StrategySettingsView_Disappear"])
    }
}
