//
//  CheckInPresenterTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The weekly check-in flow: which steps it builds, and what finishing one writes.
///
/// The step list is the whole of the feature's judgement — a step whose setting is on but which
/// has nothing to ask is a screen that exists to be tapped past — so most of these cases are
/// about what is *not* in the list.
@MainActor
struct CheckInPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, CheckInInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var nutritionStrategySettings = NutritionStrategySettings(authorId: "user-1")
        var bodyMeasurements: [BodyMeasurementEntry] = []
        var currentExpenditure: ExpenditureEstimate = .stub
        var targetProposal: TargetProposal?
        var loggingBreak: LoggingBreak?
        var openLoggingBreak: LoggingBreak?

        var mealsByDayKey: [String: [MealLogModel]] = [:]
        var annotationsByDayKey: [String: NutritionDayAnnotation] = [:]

        private(set) var savedAnnotations: [[NutritionDayAnnotation]] = []
        private(set) var savedMeasurements: [BodyMeasurementEntry] = []
        private(set) var completedWeekStarts: [Date] = []
        private(set) var startedBreakCount = 0
        private(set) var endedBreakCount = 0
        private(set) var acceptCount = 0
        /// Set to make the next write fail, which is the case the flow must not walk past.
        var saveError: Error?

        func getMeals(for dayKey: String) throws -> [MealLogModel] {
            mealsByDayKey[dayKey] ?? []
        }

        func nutritionDayAnnotation(dayKey: String) -> NutritionDayAnnotation? {
            annotationsByDayKey[dayKey]
        }

        func saveNutritionDayAnnotations(_ annotations: [NutritionDayAnnotation]) async throws {
            if let saveError { throw saveError }
            savedAnnotations.append(annotations)
        }

        func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
            if let saveError { throw saveError }
            savedMeasurements.append(bodyMeasurement)
        }

        func updateWeight(userId: String, weight: Double, weightUnitPreference: WeightUnitPreference) async throws { }

        func startLoggingBreak() async throws {
            if let saveError { throw saveError }
            startedBreakCount += 1
        }

        func endLoggingBreak() async throws {
            endedBreakCount += 1
        }

        func acceptTargetProposal() async throws {
            acceptCount += 1
        }

        var completeError: Error?

        func markCheckInCompleted(weekStart: Date) async throws {
            if let completeError { throw completeError }
            completedWeekStarts.append(weekStart)
        }
    }

    private final class Router: CheckInRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shownErrors: [Error] = []

        func showAlert(error: Error) {
            shownErrors.append(error)
        }

        private(set) var alertTitles: [String] = []
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    // MARK: - Fixtures

    private let calendar = Calendar.current
    private let weekStart = Date(timeIntervalSince1970: 1_789_948_800)

    /// The seven day keys the presenter reviews: the days ending yesterday.
    private var reviewedDayKeys: [String] {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) ?? Date()
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 6, to: yesterday)?.dayKey
        }
    }

    private func meal(dayKey: String, calories: Double) -> MealLogModel {
        MealLogModel(
            mealId: UUID().uuidString,
            authorId: "user-1",
            dayKey: dayKey,
            date: Date(dayKey: dayKey) ?? Date(),
            items: [
                MealItemModel(
                    itemId: UUID().uuidString,
                    sourceType: .ingredient,
                    sourceId: "source-1",
                    displayName: "Rice",
                    amount: 100,
                    unit: "g",
                    resolvedGrams: 100,
                    nutrients: NutrientMap([.calories: calories])
                )
            ]
        )
    }

    /// Five logged days and two with nothing at all, so both list steps have something to ask.
    private func makeInteractor() -> Interactor {
        let interactor = Interactor()
        for (index, dayKey) in reviewedDayKeys.enumerated() where index < 5 {
            interactor.mealsByDayKey[dayKey] = [meal(dayKey: dayKey, calories: 2000)]
        }
        return interactor
    }

    private func makePresenter(_ interactor: Interactor) -> (CheckInPresenter, Router) {
        let router = Router()
        return (CheckInPresenter(interactor: interactor, router: router), router)
    }

    private func start(_ interactor: Interactor) -> CheckInPresenter {
        let (presenter, _) = makePresenter(interactor)
        presenter.onViewAppear(delegate: CheckInDelegate(weekStart: weekStart))
        return presenter
    }

    private func settings(
        fast: Bool = false,
        partial: Bool = true,
        weighIn: Bool = true,
        fasting: Bool = true,
        loggingBreak: Bool = true
    ) -> NutritionStrategySettings {
        var settings = NutritionStrategySettings(authorId: "user-1")
        settings.fastCheckIn = fast
        settings.partialLoggingEnabled = partial
        settings.weighInEnabled = weighIn
        settings.fastingEnabled = fasting
        settings.loggingBreakEnabled = loggingBreak
        return settings
    }

    // MARK: - The step list

    /// All four toggles on, with a week that has something for each of them.
    @Test("Test Every Step Is Built When Every Toggle Is On")
    func testEveryStepIsBuiltWhenEveryToggleIsOn() {
        let interactor = makeInteractor()
        interactor.nutritionStrategySettings = settings()

        let presenter = start(interactor)

        #expect(presenter.steps == [.introduction, .partialLogging, .weighIn, .fasting, .loggingBreak, .programUpdate])
        #expect(presenter.currentStep == .introduction)
    }

    /// The four strategy toggles, as one argument so the case below can be a table.
    struct Toggles: Sendable, CustomStringConvertible {
        let partial: Bool
        let weighIn: Bool
        let fasting: Bool
        let loggingBreak: Bool

        /// All sixteen combinations, built rather than typed out.
        static let all: [Toggles] = (0..<16).map { bits in
            Toggles(
                partial: bits & 1 != 0,
                weighIn: bits & 2 != 0,
                fasting: bits & 4 != 0,
                loggingBreak: bits & 8 != 0
            )
        }

        var description: String {
            "partial: \(partial), weighIn: \(weighIn), fasting: \(fasting), loggingBreak: \(loggingBreak)"
        }
    }

    /// Every combination of the four toggles, with the same week of fixture data.
    @Test("Test The Step List Follows The Four Toggles", arguments: Toggles.all)
    func testTheStepListFollowsTheFourToggles(toggles: Toggles) {
        let interactor = makeInteractor()
        interactor.nutritionStrategySettings = settings(
            partial: toggles.partial,
            weighIn: toggles.weighIn,
            fasting: toggles.fasting,
            loggingBreak: toggles.loggingBreak
        )

        let presenter = start(interactor)

        var expected: [CheckInStep] = [.introduction]
        if toggles.partial { expected.append(.partialLogging) }
        if toggles.weighIn { expected.append(.weighIn) }
        if toggles.fasting { expected.append(.fasting) }
        if toggles.loggingBreak { expected.append(.loggingBreak) }
        expected.append(.programUpdate)

        #expect(presenter.steps == expected)
    }

    /// A fast check-in drops the introduction, and with nothing suspicious in the week it drops
    /// the partial-logging list too: two taps, which is what "fast" was supposed to mean.
    @Test("Test A Fast Check In Drops The Introduction")
    func testAFastCheckInDropsTheIntroduction() {
        let interactor = makeInteractor()
        interactor.nutritionStrategySettings = settings(fast: true)

        let presenter = start(interactor)

        #expect(!presenter.steps.contains(.introduction))
        #expect(!presenter.steps.contains(.partialLogging))
        #expect(presenter.currentStep == .weighIn)
    }

    /// A day well under expenditure is the one a fast check-in still asks about.
    @Test("Test A Fast Check In Keeps The Suspicious Days")
    func testAFastCheckInKeepsTheSuspiciousDays() {
        let interactor = makeInteractor()
        interactor.nutritionStrategySettings = settings(fast: true)
        let suspicious = reviewedDayKeys[0]
        interactor.mealsByDayKey[suspicious] = [meal(dayKey: suspicious, calories: 400)]

        let presenter = start(interactor)

        #expect(presenter.steps.contains(.partialLogging))
        #expect(presenter.partialRows.map(\.dayKey) == [suspicious])
    }

    /// No unlogged days, nothing to ask about fasting.
    @Test("Test The Fasting Step Is Absent With A Fully Logged Week")
    func testTheFastingStepIsAbsentWithAFullyLoggedWeek() {
        let interactor = Interactor()
        interactor.nutritionStrategySettings = settings()
        for dayKey in reviewedDayKeys {
            interactor.mealsByDayKey[dayKey] = [meal(dayKey: dayKey, calories: 2200)]
        }

        let presenter = start(interactor)

        #expect(!presenter.steps.contains(.fasting))
        #expect(presenter.steps.contains(.partialLogging))
    }

    /// A weigh-in two days old is recent enough; the step is not asked for.
    @Test("Test The Weigh In Step Is Absent When A Weigh In Is Two Days Old")
    func testTheWeighInStepIsAbsentWhenAWeighInIsTwoDaysOld() {
        let interactor = makeInteractor()
        interactor.nutritionStrategySettings = settings()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        interactor.bodyMeasurements = [
            BodyMeasurementEntry(authorId: "user-1", weightKg: 80, date: twoDaysAgo)
        ]

        let presenter = start(interactor)

        #expect(!presenter.steps.contains(.weighIn))
    }

    /// Five days old is not recent, so the step comes back.
    @Test("Test The Weigh In Step Returns When The Last One Is Old")
    func testTheWeighInStepReturnsWhenTheLastOneIsOld() {
        let interactor = makeInteractor()
        interactor.nutritionStrategySettings = settings()
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        interactor.bodyMeasurements = [
            BodyMeasurementEntry(authorId: "user-1", weightKg: 80, date: fiveDaysAgo)
        ]

        let presenter = start(interactor)

        #expect(presenter.steps.contains(.weighIn))
    }

    // MARK: - Content

    /// The introduction counts the week rather than the whole log.
    @Test("Test The Introduction Counts The Week")
    func testTheIntroductionCountsTheWeek() {
        let interactor = makeInteractor()

        let presenter = start(interactor)

        #expect(presenter.weekDays.count == 7)
        #expect(presenter.loggedDayCount == 5)
    }

    /// Existing annotations pre-set the toggles, so a check-in confirms rather than re-asks.
    @Test("Test Existing Annotations Pre Set The Toggles")
    func testExistingAnnotationsPreSetTheToggles() {
        let interactor = makeInteractor()
        let logged = reviewedDayKeys[0]
        let unlogged = reviewedDayKeys[6]
        interactor.annotationsByDayKey[logged] = NutritionDayAnnotation(
            dayKey: logged, authorId: "user-1", isPartiallyLogged: true
        )
        interactor.annotationsByDayKey[unlogged] = NutritionDayAnnotation(
            dayKey: unlogged, authorId: "user-1", isFastingDay: true
        )

        let presenter = start(interactor)

        #expect(presenter.partialRows.first { $0.dayKey == logged }?.isOn == true)
        #expect(presenter.fastingRows.first { $0.dayKey == unlogged }?.isOn == true)
    }

    /// The program update shows the proposal when there is one.
    @Test("Test The Program Update Shows The Proposal")
    func testTheProgramUpdateShowsTheProposal() {
        let interactor = makeInteractor()
        interactor.targetProposal = TargetProposal(
            expenditureKcal: 2800,
            currentTargetKcal: 2000,
            proposedTargetKcal: 2250,
            weeklyTrendChangeKg: -0.4,
            goalWeeklyChangeKg: -0.5,
            reason: .expenditureMoved
        )

        let presenter = start(interactor)

        #expect(presenter.proposalSummary == "2250 kcal a day, up from 2000.")
    }

    /// And the unchanged copy when there is not.
    @Test("Test The Program Update Says Nothing Changed Without A Proposal")
    func testTheProgramUpdateSaysNothingChangedWithoutAProposal() {
        let presenter = start(makeInteractor())

        #expect(presenter.proposalSummary == nil)
        #expect(presenter.expenditureDescription == "2500 kcal a day")
        #expect(presenter.trendChangeDescription == "holding steady")
    }

    // MARK: - Walking the flow

    /// Walks to the last step by continuing past everything in between.
    private func advanceToEnd(_ presenter: CheckInPresenter) async {
        while presenter.currentStep != .programUpdate {
            switch presenter.currentStep {
            case .weighIn: presenter.onSkipWeighInPressed()
            default:       presenter.onContinuePressed()
            }
            await TestManagers.eventually { !presenter.isSaving }
        }
    }

    /// Continuing past the partial-logging step writes the rows it showed.
    @Test("Test Continuing Saves The Partial Logging Rows")
    func testContinuingSavesThePartialLoggingRows() async {
        let interactor = makeInteractor()
        let presenter = start(interactor)
        presenter.onContinuePressed()
        #expect(presenter.currentStep == .partialLogging)
        presenter.partialRows[0].isOn = true

        presenter.onContinuePressed()

        #expect(await TestManagers.eventually { interactor.savedAnnotations.count == 1 })
        let saved = interactor.savedAnnotations.first ?? []
        #expect(saved.count == 7)
        #expect(saved.first { $0.dayKey == reviewedDayKeys[0] }?.isPartiallyLogged == true)
    }

    /// A save that does not land keeps the step on screen, with the alert — walking on would tell
    /// the user their last answer was recorded when it was not.
    @Test("Test A Failed Save Does Not Advance")
    func testAFailedSaveDoesNotAdvance() async {
        let interactor = makeInteractor()
        interactor.saveError = URLError(.notConnectedToInternet)
        let (presenter, router) = makePresenter(interactor)
        presenter.onViewAppear(delegate: CheckInDelegate(weekStart: weekStart))
        presenter.onContinuePressed()

        presenter.onContinuePressed()

        #expect(await TestManagers.eventually { !router.shownErrors.isEmpty })
        #expect(presenter.currentStep == .partialLogging)
    }

    /// Completing the last step records the week.
    @Test("Test Completing Writes The Week Start")
    func testCompletingWritesTheWeekStart() async {
        let interactor = makeInteractor()
        let presenter = start(interactor)

        await advanceToEnd(presenter)
        presenter.onDonePressed()

        #expect(await TestManagers.eventually { interactor.completedWeekStarts == [self.weekStart] })
        #expect(presenter.isCompleted)
    }

    /// Accepting the proposal finishes the flow as well as applying it.
    @Test("Test Accepting The Proposal Completes The Check In")
    func testAcceptingTheProposalCompletesTheCheckIn() async {
        let interactor = makeInteractor()
        interactor.targetProposal = TargetProposal(
            expenditureKcal: 2800,
            currentTargetKcal: 2000,
            proposedTargetKcal: 2250,
            weeklyTrendChangeKg: -0.4,
            goalWeeklyChangeKg: -0.5,
            reason: .expenditureMoved
        )
        let presenter = start(interactor)

        await advanceToEnd(presenter)
        presenter.onAcceptProposalPressed()

        #expect(await TestManagers.eventually { interactor.acceptCount == 1 })
        #expect(await TestManagers.eventually { interactor.completedWeekStarts == [self.weekStart] })
    }

    /// Dismissing part-way keeps the annotations already saved and leaves the week unrecorded, so
    /// the card stays on the overview.
    @Test("Test Dismissing Mid Flow Does Not Complete")
    func testDismissingMidFlowDoesNotComplete() async {
        let interactor = makeInteractor()
        let presenter = start(interactor)
        presenter.onContinuePressed()
        presenter.onContinuePressed()
        #expect(await TestManagers.eventually { interactor.savedAnnotations.count == 1 })

        presenter.onDismissPressed()

        #expect(interactor.completedWeekStarts.isEmpty)
        #expect(presenter.isCompleted == false)
        #expect(interactor.savedAnnotations.count == 1)
        #expect(interactor.trackedEventNames.contains("CheckInView_Dismissed"))
    }

    // MARK: - Logging break step

    @Test("Test Starting A Break From The Flow")
    func testStartingABreakFromTheFlow() async {
        let interactor = makeInteractor()
        let presenter = start(interactor)
        while presenter.currentStep != .loggingBreak {
            if presenter.currentStep == .weighIn {
                presenter.onSkipWeighInPressed()
            } else {
                presenter.onContinuePressed()
            }
            await TestManagers.eventually { !presenter.isSaving }
        }

        presenter.onStartLoggingBreakPressed()

        #expect(await TestManagers.eventually { interactor.startedBreakCount == 1 })
        #expect(presenter.currentStep == .programUpdate)
    }

    /// With a break already open the step offers to end it instead.
    @Test("Test An Open Break Is Offered For Ending")
    func testAnOpenBreakIsOfferedForEnding() {
        let interactor = makeInteractor()
        interactor.openLoggingBreak = LoggingBreak(authorId: "user-1", startDate: weekStart)

        let presenter = start(interactor)

        #expect(presenter.hasOpenLoggingBreak)
    }

    // MARK: - Events

    @Test("Test Each Step Shown Is Recorded")
    func testEachStepShownIsRecorded() async {
        let interactor = makeInteractor()
        let presenter = start(interactor)

        await advanceToEnd(presenter)

        let shown = interactor.trackedEventNames.filter { $0 == "CheckInView_Step_Shown" }
        #expect(shown.count == presenter.steps.count)
        #expect(interactor.trackedScreenEventNames == ["CheckInView_Appear"])
    }

    // MARK: - Completing

    /// Finishing used to `try?` the completion record and dismiss anyway, so a failed write closed
    /// the sheet as if the week were done. It now stays open with one alert and one fail event.
    @Test("Test A Failed Completion Alerts Once And Stays Open")
    func testAFailedCompletionAlertsOnceAndStaysOpen() async {
        let interactor = makeInteractor()
        interactor.nutritionStrategySettings.fastCheckIn = true
        interactor.nutritionStrategySettings.partialLoggingEnabled = false
        interactor.nutritionStrategySettings.weighInEnabled = false
        interactor.nutritionStrategySettings.fastingEnabled = false
        interactor.nutritionStrategySettings.loggingBreakEnabled = false
        interactor.completeError = URLError(.notConnectedToInternet)
        let (presenter, router) = makePresenter(interactor)
        presenter.onViewAppear(delegate: CheckInDelegate(weekStart: weekStart))
        #expect(presenter.steps == [.programUpdate])

        presenter.onContinuePressed()

        #expect(await TestManagers.eventually(timeout: .seconds(5)) { !router.alertTitles.isEmpty })
        #expect(router.alertTitles == ["Unable to Complete Check-In"])
        #expect(interactor.trackedEventNames.filter { $0.hasSuffix("_Fail") } == ["CheckInView_Complete_Fail"])
        #expect(!presenter.isCompleted)
    }

}
