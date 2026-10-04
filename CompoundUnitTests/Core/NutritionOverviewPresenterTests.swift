//
//  NutritionOverviewPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The day's nutrition summary, opened from the Nutrition tab.
///
/// Unlike the tab behind it, this screen's rings are clamped: they fill and stop. The tab shows
/// an overage because it is the live log and going over is information; this is a summary of a
/// day, where a ring drawn past full reads as a drawing error.
@MainActor
struct NutritionOverviewPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, NutritionOverviewInteractor {
        var userId: String? = "user-1"
        var currentUser: UserModel? = UserModel(userId: "user-1")

        var totalsByDayKey: [String: DailyMacroTarget] = [:]
        var breakdownByDayKey: [String: DailyNutritionBreakdown] = [:]
        var mealsByDayKey: [String: [MealLogModel]] = [:]
        var target: DailyMacroTarget?
        private(set) var targetRequests: [String] = []

        func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
            guard let totals = totalsByDayKey[dayKey] else { throw URLError(.fileDoesNotExist) }
            return totals
        }

        func getDailyNutritionBreakdown(dayKey: String) throws -> DailyNutritionBreakdown {
            guard let breakdown = breakdownByDayKey[dayKey] else { throw URLError(.fileDoesNotExist) }
            return breakdown
        }

        func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget? {
            targetRequests.append(userId)
            return target
        }

        func getMeals(for dayKey: String) throws -> [MealLogModel] {
            mealsByDayKey[dayKey] ?? []
        }

        var targetProposal: TargetProposal?
        /// Set to make the save fail, which is the case the card has to survive.
        var acceptError: Error?
        private(set) var acceptCount = 0
        private(set) var dismissCount = 0

        func acceptTargetProposal() async throws {
            acceptCount += 1
            if let acceptError { throw acceptError }
            targetProposal = nil
        }

        func dismissTargetProposal() {
            dismissCount += 1
            targetProposal = nil
        }

        var checkInState: CheckInState = .notDue
        /// Set to make the skip fail, which is the case the card has to survive.
        var skipError: Error?
        private(set) var skippedWeekStarts: [Date] = []

        func markCheckInSkipped(weekStart: Date) async throws {
            if let skipError { throw skipError }
            skippedWeekStarts.append(weekStart)
            checkInState = .notDue
        }
    }

    private final class Router: NutritionOverviewRouter {
        let router: AnyRouter = TestRouting.anyRouter

        /// `showAlert(error:)` is a `GlobalRouter` requirement with a default implementation, so
        /// unlike the button-carrying overload it can be intercepted here.
        private(set) var shownErrors: [Error] = []

        func showAlert(error: Error) {
            shownErrors.append(error)
        }

        private(set) var shownCheckIns: [CheckInDelegate] = []

        func showCheckInView(delegate: CheckInDelegate) {
            shownCheckIns.append(delegate)
        }
    }

    private struct Screen {
        let presenter: NutritionOverviewPresenter
        let interactor: Interactor
        let router: Router
        let delegate: NutritionOverviewDelegate
    }

    // MARK: - Fixtures

    private let dayKey = "2026-09-21"

    private func item(name: String, calories: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0) -> MealItemModel {
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: "source-1",
            displayName: name,
            amount: 100,
            unit: "g",
            resolvedGrams: 100,
            nutrients: NutrientMap([.calories: calories, .protein: protein, .carbs: carbs, .fatTotal: fat])
        )
    }

    private func meal(id: String, items: [MealItemModel]) -> MealLogModel {
        MealLogModel(
            mealId: id,
            authorId: "user-1",
            dayKey: dayKey,
            date: Date(timeIntervalSince1970: 1_000_000),
            items: items
        )
    }

    private func makeScreen(
        totals: DailyMacroTarget? = nil,
        target: DailyMacroTarget? = nil,
        meals: [MealLogModel] = [],
        breakdown: DailyNutritionBreakdown? = nil
    ) -> Screen {
        let interactor = Interactor()
        if let totals { interactor.totalsByDayKey[dayKey] = totals }
        if let breakdown { interactor.breakdownByDayKey[dayKey] = breakdown }
        interactor.mealsByDayKey[dayKey] = meals
        interactor.target = target

        let router = Router()
        return Screen(
            presenter: NutritionOverviewPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router,
            delegate: NutritionOverviewDelegate(dayKey: dayKey)
        )
    }

    /// Appears, then waits for the target's detached load to land.
    private func appear(_ screen: Screen, awaitingTarget: Bool = true) async {
        screen.presenter.onViewAppear(delegate: screen.delegate)
        if awaitingTarget {
            await TestManagers.eventually { screen.presenter.target != nil }
        }
    }

    // MARK: - Loading

    /// The day's stored totals are what the screen reports.
    @Test("Test The Day's Totals Are Loaded")
    func testTheDaysTotalsAreLoaded() async {
        let totals = DailyMacroTarget(calories: 1800, proteinGrams: 120, carbGrams: 200, fatGrams: 60)
        let screen = makeScreen(totals: totals, target: .mock)

        await appear(screen)

        #expect(screen.presenter.totals == totals)
    }

    /// A day the store cannot answer for reads as zeros rather than failing — a day with nothing
    /// logged and a day that could not be read look the same to the user, and both are empty.
    @Test("Test An Unreadable Day Reads As Zero")
    func testAnUnreadableDayReadsAsZero() async {
        let screen = makeScreen(totals: nil, target: .mock)

        await appear(screen)

        #expect(screen.presenter.totals.calories == 0)
        #expect(screen.presenter.totals.proteinGrams == 0)
    }

    /// A breakdown that cannot be read falls back to an empty one rather than stale detail.
    @Test("Test A Missing Breakdown Is Empty")
    func testAMissingBreakdownIsEmpty() async {
        let screen = makeScreen(totals: .mock, target: .mock)

        await appear(screen)

        #expect(screen.presenter.breakdown.fiberGrams == nil)
        #expect(screen.presenter.breakdown.sugarGrams == nil)
    }

    /// The target is fetched for the signed-in user.
    @Test("Test The Target Is Fetched For The Signed In User")
    func testTheTargetIsFetchedForTheSignedInUser() async {
        let target = DailyMacroTarget(calories: 2200, proteinGrams: 150, carbGrams: 250, fatGrams: 70)
        let screen = makeScreen(totals: .mock, target: target)

        await appear(screen)

        #expect(screen.presenter.target == target)
        #expect(screen.interactor.targetRequests == ["user-1"])
    }

    /// Signed out there is no target to fetch, so none is requested.
    @Test("Test No User Means No Target Is Requested")
    func testNoUserMeansNoTargetIsRequested() async {
        let screen = makeScreen(totals: .mock, target: .mock)
        screen.interactor.userId = nil

        await appear(screen, awaitingTarget: false)

        #expect(screen.interactor.targetRequests.isEmpty)
        #expect(screen.presenter.target == nil)
    }

    // MARK: - Progress rings

    /// Each ring measures its own macro against its own target.
    @Test("Test Each Ring Measures Its Own Macro")
    func testEachRingMeasuresItsOwnMacro() async {
        let screen = makeScreen(
            totals: DailyMacroTarget(calories: 1100, proteinGrams: 75, carbGrams: 50, fatGrams: 35),
            target: DailyMacroTarget(calories: 2200, proteinGrams: 150, carbGrams: 200, fatGrams: 70)
        )

        await appear(screen)

        #expect(screen.presenter.caloriesProgress == 0.5)
        #expect(screen.presenter.proteinProgress == 0.5)
        #expect(screen.presenter.carbsProgress == 0.25)
        #expect(screen.presenter.fatProgress == 0.5)
    }

    /// Going over fills the ring and stops. This is the summary of a day, where a ring drawn past
    /// full would read as a drawing error rather than as information — the live tab reports the
    /// overage instead.
    @Test("Test Going Over Fills The Ring And Stops")
    func testGoingOverFillsTheRingAndStops() async {
        let screen = makeScreen(
            totals: DailyMacroTarget(calories: 4400, proteinGrams: 300, carbGrams: 400, fatGrams: 140),
            target: DailyMacroTarget(calories: 2200, proteinGrams: 150, carbGrams: 200, fatGrams: 70)
        )

        await appear(screen)

        #expect(screen.presenter.caloriesProgress == 1)
        #expect(screen.presenter.proteinProgress == 1)
        #expect(screen.presenter.carbsProgress == 1)
        #expect(screen.presenter.fatProgress == 1)
    }

    /// With no target there is nothing to fill toward, so the rings sit empty rather than
    /// dividing by nothing.
    @Test("Test Rings Are Empty Without A Target")
    func testRingsAreEmptyWithoutATarget() async {
        let screen = makeScreen(totals: .mock, target: nil)

        await appear(screen, awaitingTarget: false)

        #expect(screen.presenter.caloriesProgress == 0)
        #expect(screen.presenter.proteinProgress == 0)
        #expect(screen.presenter.carbsProgress == 0)
        #expect(screen.presenter.fatProgress == 0)
    }

    /// A target of zero is a day with no goal, not a division.
    @Test("Test A Zero Target Does Not Divide")
    func testAZeroTargetDoesNotDivide() async {
        let screen = makeScreen(
            totals: .mock,
            target: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)
        )

        await appear(screen)

        #expect(screen.presenter.caloriesProgress == 0)
        #expect(screen.presenter.caloriesProgress.isNaN == false)
    }

    // MARK: - Top contributors

    /// The list is work, so it is only built when the section is open.
    @Test("Test Contributors Are Not Built While Collapsed")
    func testContributorsAreNotBuiltWhileCollapsed() async {
        let screen = makeScreen(totals: .mock, target: .mock, meals: [
            meal(id: "m1", items: [item(name: "Rice", calories: 400)])
        ])

        await appear(screen)

        #expect(screen.presenter.showsContributors == false)
        #expect(screen.presenter.topContributors.isEmpty)
    }

    /// The same food logged across several meals is one line, summed — a user wants to know how
    /// much rice they ate today, not that they ate rice three times.
    @Test("Test The Same Food Across Meals Is One Summed Line")
    func testTheSameFoodAcrossMealsIsOneSummedLine() async {
        let screen = makeScreen(totals: .mock, target: .mock, meals: [
            meal(id: "m1", items: [item(name: "Rice", calories: 200, protein: 4, carbs: 45, fat: 1)]),
            meal(id: "m2", items: [item(name: "Rice", calories: 300, protein: 6, carbs: 65, fat: 2)])
        ])
        screen.presenter.showsContributors = true

        await appear(screen)

        let contributors = screen.presenter.topContributors
        #expect(contributors.count == 1)
        #expect(contributors.first?.displayName == "Rice")
        #expect(contributors.first?.calories == 500)
        #expect(contributors.first?.proteinGrams == 10)
        #expect(contributors.first?.carbGrams == 110)
        #expect(contributors.first?.fatGrams == 3)
    }

    /// Biggest first — the point of the list is what dominated the day.
    @Test("Test Contributors Are Ordered By Calories")
    func testContributorsAreOrderedByCalories() async {
        let screen = makeScreen(totals: .mock, target: .mock, meals: [
            meal(id: "m1", items: [
                item(name: "Salad", calories: 90),
                item(name: "Pizza", calories: 800),
                item(name: "Yoghurt", calories: 150)
            ])
        ])
        screen.presenter.showsContributors = true

        await appear(screen)

        #expect(screen.presenter.topContributors.map(\.displayName) == ["Pizza", "Yoghurt", "Salad"])
    }

    /// An item whose source recorded no calories still counts as nothing rather than breaking the
    /// sum around it.
    @Test("Test Items Without Calories Contribute Zero")
    func testItemsWithoutCaloriesContributeZero() async {
        let bare = MealItemModel(
            itemId: "bare",
            sourceType: .ingredient,
            sourceId: "source-1",
            displayName: "Water",
            amount: 250,
            unit: "ml",
            resolvedGrams: nil,
            nutrients: NutrientMap()
        )
        let screen = makeScreen(totals: .mock, target: .mock, meals: [
            meal(id: "m1", items: [bare, item(name: "Rice", calories: 400)])
        ])
        screen.presenter.showsContributors = true

        await appear(screen)

        let contributors = screen.presenter.topContributors
        #expect(contributors.map(\.displayName) == ["Rice", "Water"])
        #expect(contributors.last?.calories == 0)
    }

    /// A day with nothing logged has nothing to attribute.
    @Test("Test An Empty Day Has No Contributors")
    func testAnEmptyDayHasNoContributors() async {
        let screen = makeScreen(totals: .mock, target: .mock, meals: [])
        screen.presenter.showsContributors = true

        await appear(screen)

        #expect(screen.presenter.topContributors.isEmpty)
    }

    // MARK: - Target proposal

    private func proposal(current: Double = 2000, proposed: Double = 2250) -> TargetProposal {
        TargetProposal(
            expenditureKcal: 2800,
            currentTargetKcal: current,
            proposedTargetKcal: proposed,
            weeklyTrendChangeKg: -0.4,
            goalWeeklyChangeKg: -0.5,
            reason: .expenditureMoved
        )
    }

    @Test("Test No Card Without A Proposal")
    func testNoCardWithoutAProposal() {
        let screen = makeScreen(totals: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.presenter.proposal == nil)
        #expect(screen.presenter.proposalSummary == nil)
    }

    @Test("Test The Card Says Which Way The Target Moves")
    func testTheCardSaysWhichWayTheTargetMoves() {
        let screen = makeScreen(totals: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
        screen.interactor.targetProposal = proposal(current: 2000, proposed: 2250)

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.presenter.proposalSummary == "2250 kcal a day, up from 2000.")
    }

    @Test("Test A Lower Proposal Reads As A Cut")
    func testALowerProposalReadsAsACut() {
        let screen = makeScreen(totals: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
        screen.interactor.targetProposal = proposal(current: 2400, proposed: 2150)

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.presenter.proposalSummary == "2150 kcal a day, down from 2400.")
    }

    /// Accepting takes the card off the screen straight away rather than waiting for the rewritten
    /// plan to come back from Firestore.
    @Test("Test Accepting Applies The Proposal And Clears The Card")
    func testAcceptingAppliesTheProposalAndClearsTheCard() async {
        let screen = makeScreen(totals: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
        screen.interactor.targetProposal = proposal()
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.presenter.onAcceptProposalPressed()

        #expect(screen.presenter.proposal == nil)
        #expect(await TestManagers.eventually { screen.interactor.acceptCount == 1 })
        #expect(screen.interactor.trackedEventNames.contains("NutritionOverviewView_Proposal_Accept"))
    }

    /// A swallowed save failure is the one outcome that looks exactly like success and is not:
    /// no card, and a plan that never changed. The card comes back so the accept can be retried.
    @Test("Test A Failed Accept Puts The Card Back And Says So")
    func testAFailedAcceptPutsTheCardBackAndSaysSo() async {
        let screen = makeScreen(totals: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
        let offered = proposal()
        screen.interactor.targetProposal = offered
        screen.interactor.acceptError = URLError(.notConnectedToInternet)
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.presenter.onAcceptProposalPressed()

        #expect(await TestManagers.eventually { screen.presenter.proposal == offered })
        #expect(screen.router.shownErrors.count == 1)
        #expect(screen.interactor.trackedEventNames.contains("NutritionOverviewView_Proposal_Accept_Fail"))
    }

    /// And the retry has to be possible: the in-flight guard must not latch after a failure.
    @Test("Test A Failed Accept Can Be Retried")
    func testAFailedAcceptCanBeRetried() async {
        let screen = makeScreen(totals: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
        screen.interactor.targetProposal = proposal()
        screen.interactor.acceptError = URLError(.notConnectedToInternet)
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.presenter.onAcceptProposalPressed()
        #expect(await TestManagers.eventually { screen.presenter.proposal != nil })

        screen.interactor.acceptError = nil
        screen.presenter.onAcceptProposalPressed()

        #expect(await TestManagers.eventually { screen.interactor.acceptCount == 2 })
        #expect(screen.presenter.proposal == nil)
    }

    @Test("Test Not Now Records The Dismissal And Clears The Card")
    func testNotNowRecordsTheDismissalAndClearsTheCard() {
        let screen = makeScreen(totals: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
        screen.interactor.targetProposal = proposal()
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.presenter.onDismissProposalPressed()

        #expect(screen.presenter.proposal == nil)
        #expect(screen.interactor.dismissCount == 1)
        #expect(screen.interactor.trackedEventNames.contains("NutritionOverviewView_Proposal_Dismiss"))
    }

    // MARK: - Weekly check-in card

    private static let weekStart = Date(timeIntervalSince1970: 1_758_412_800)

    private func dueScreen() -> Screen {
        let screen = makeScreen(totals: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
        screen.interactor.checkInState = .due(weekStart: Self.weekStart)
        return screen
    }

    /// The check-in card takes the proposal card's place: the proposal is the check-in's last
    /// step, and two cards offering the same decision is how a considered change becomes a
    /// stray tap.
    @Test("Test A Due Check In Replaces The Proposal Card")
    func testADueCheckInReplacesTheProposalCard() {
        let screen = dueScreen()
        screen.interactor.targetProposal = proposal()

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.presenter.dueCheckInWeekStart == Self.weekStart)
        #expect(screen.presenter.proposal != nil)
    }

    /// Outside a check-in there is no card and the proposal keeps its place.
    @Test("Test No Card When No Check In Is Due")
    func testNoCardWhenNoCheckInIsDue() {
        let screen = makeScreen(totals: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.presenter.dueCheckInWeekStart == nil)
    }

    /// Starting opens the sheet on the week the card was offering.
    @Test("Test Start Opens The Check In On That Week")
    func testStartOpensTheCheckInOnThatWeek() {
        let screen = dueScreen()
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.presenter.onStartCheckInPressed()

        #expect(screen.router.shownCheckIns.map(\.weekStart) == [Self.weekStart])
        #expect(screen.interactor.trackedEventNames.contains("NutritionOverviewView_CheckIn_Start"))
    }

    /// Skipping records the week and takes the card away.
    @Test("Test Skip Records The Week And Clears The Card")
    func testSkipRecordsTheWeekAndClearsTheCard() async {
        let screen = dueScreen()
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.presenter.onSkipCheckInPressed()

        #expect(screen.presenter.dueCheckInWeekStart == nil)
        #expect(await TestManagers.eventually { screen.interactor.skippedWeekStarts == [Self.weekStart] })
        #expect(screen.interactor.trackedEventNames.contains("NutritionOverviewView_CheckIn_Skip"))
    }

    /// A skip that does not land puts the card back, next to the alert — a card that vanished
    /// anyway would look exactly like a week that had been dealt with.
    @Test("Test A Failed Skip Puts The Card Back")
    func testAFailedSkipPutsTheCardBack() async {
        let screen = dueScreen()
        screen.interactor.skipError = URLError(.notConnectedToInternet)
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.presenter.onSkipCheckInPressed()

        #expect(await TestManagers.eventually { screen.presenter.dueCheckInWeekStart == Self.weekStart })
        #expect(screen.router.shownErrors.count == 1)
    }
}

/// The detail behind one logged meal.
///
/// Only the summary is reachable from here. The delete path runs through
/// `GlobalRouter.showAlert(title:subtitle:buttons:)`, whose buttons are an `AnyView` the router
/// presents — a double cannot press one, and the method is an extension rather than a protocol
/// requirement, so it cannot be intercepted either. What that leaves is the arithmetic.
@MainActor
struct MealDetailPresenterTests {

    private final class Interactor: SpyGlobalInteractor, MealDetailInteractor {
        private(set) var deletedMealIds: [String] = []
        var deleteError: Error?
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var draftMeal: MealLogModel?

        func deleteDraftMeal() throws { }

        func deleteMealAndSync(id: String, dayKey: String, authorId: String) async throws {
            if let deleteError { throw deleteError }
            deletedMealIds.append(id)
        }
    }

    private final class Router: MealDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var addMealDelegates: [AddMealDelegate] = []

        // Declared unguarded: the test target builds without -DDEV, so matching the protocol's
        // `#if` here would leave the conformance short of a requirement the app module compiled.
        func showDevSettingsView() { }

        func showAddMealView(delegate: AddMealDelegate) { addMealDelegates.append(delegate) }
    }

    private func item(name: String, calories: Double, protein: Double, carbs: Double, fat: Double) -> MealItemModel {
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: "source-1",
            displayName: name,
            amount: 100,
            unit: "g",
            resolvedGrams: 100,
            nutrients: NutrientMap([.calories: calories, .protein: protein, .carbs: carbs, .fatTotal: fat])
        )
    }

    private func meal(items: [MealItemModel]) -> MealLogModel {
        MealLogModel(
            mealId: "meal-1",
            authorId: "user-1",
            dayKey: "2026-09-21",
            date: Date(timeIntervalSince1970: 1_000_000),
            items: items
        )
    }

    private func makePresenter() -> MealDetailPresenter {
        MealDetailPresenter(interactor: Interactor(), router: Router())
    }

    /// Log Again opens Add Meal on a copy of the meal, now: a new meal id, the same items.
    @Test("Test Log Again Opens A Copy Of The Meal Now")
    func testLogAgainOpensACopyOfTheMealNow() throws {
        let router = Router()
        let presenter = MealDetailPresenter(interactor: Interactor(), router: router)
        let logged = meal(items: [item(name: "Rice", calories: 200, protein: 4, carbs: 45, fat: 1)])

        presenter.onLogAgainPressed(meal: logged)

        let copy = try #require(router.addMealDelegates.first?.mealLog)
        #expect(copy.mealId != logged.mealId)
        #expect(copy.items == logged.items)
        #expect(copy.dayKey == Date().dayKey)
    }

    /// Item nutrients are stored at the amount logged, so the meal's totals are a plain sum.
    @Test("Test The Summary Sums The Meal's Items")
    func testTheSummarySumsTheMealsItems() {
        let presenter = makePresenter()
        let logged = meal(items: [
            item(name: "Rice", calories: 200, protein: 4, carbs: 45, fat: 1),
            item(name: "Chicken", calories: 300, protein: 40, carbs: 0, fat: 8)
        ])

        let summary = presenter.macroSummary(for: logged)

        #expect(summary.map(\.label) == ["Calories", "Protein", "Carbs", "Fat"])
        #expect(summary.map(\.value) == ["500", "44g", "45g", "9g"])
    }

    /// The summary is whole numbers — a tenth of a gram across a plate is noise, and the figures
    /// are rounded rather than truncated so 9.6g does not read as 9g.
    @Test("Test The Summary Rounds Rather Than Truncates")
    func testTheSummaryRoundsRatherThanTruncates() {
        let presenter = makePresenter()
        let logged = meal(items: [item(name: "Oats", calories: 199.6, protein: 9.6, carbs: 0.4, fat: 0.5)])

        let summary = presenter.macroSummary(for: logged)

        #expect(summary.map(\.value) == ["200", "10g", "0g", "1g"])
    }

    /// A meal with nothing in it reads as zeros rather than as blanks.
    @Test("Test An Empty Meal Summarises As Zero")
    func testAnEmptyMealSummarisesAsZero() {
        let presenter = makePresenter()

        let summary = presenter.macroSummary(for: meal(items: []))

        #expect(summary.map(\.value) == ["0", "0g", "0g", "0g"])
    }

    /// Opening the screen records how much was in the meal.
    @Test("Test Appearing Records The Item Count")
    func testAppearingRecordsTheItemCount() {
        let interactor = Interactor()
        let presenter = MealDetailPresenter(interactor: interactor, router: Router())
        let logged = meal(items: [
            item(name: "Rice", calories: 200, protein: 4, carbs: 45, fat: 1),
            item(name: "Chicken", calories: 300, protein: 40, carbs: 0, fat: 8)
        ])

        presenter.onViewAppear(delegate: MealDetailDelegate(meal: logged))

        #expect(interactor.trackedScreenEventNames == ["MealDetailView_Appear"])
    }
}
