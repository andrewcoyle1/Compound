//
//  OnboardingGoalSummaryPresenterTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The last screen of goal setting: it restates the goal, saves it, and hands the user back to
/// whatever step of onboarding comes next — or, opened on its own from the profile, dismisses.
///
/// The timeline arithmetic this screen also does has its own suite in
/// `OnboardingGoalSummaryEstimateTests`; this one is everything else.
@MainActor
struct OnboardingGoalSummaryPresenterTests {

    private final class Interactor: SpyGlobalInteractor, GoalSummaryInteractor {
        var currentUser: UserModel?
        var saveGoalError: Error?
        var updateGoalIdError: Error?
        private(set) var savedGoals: [WeightGoal] = []
        private(set) var savedGoalIds: [String?] = []

        init(currentUser: UserModel?) {
            self.currentUser = currentUser
        }

        func saveGoal(_ goal: WeightGoal) async throws {
            if let saveGoalError { throw saveGoalError }
            savedGoals.append(goal)
        }

        func updateCurrentGoalId(goalId: String?) async throws {
            if let updateGoalIdError { throw updateGoalIdError }
            savedGoalIds.append(goalId)
        }
    }

    /// `GoalSummaryRouter` refines `OnboardingStepRouter`, so this subclasses `SpyOnboardingRouter`
    /// for the nine onboarding destinations and the alert interception, and adds only what this
    /// screen has of its own.
    private final class Router: SpyOnboardingRouter, GoalSummaryRouter {
        private(set) var gymProfileDelegate: CreateGymProfileDelegate?
        private(set) var programDelegate: CreateProgramDelegate?

        func showDevSettingsView() { record("devSettings") }

        override func showCreateGymProfileView(delegate: CreateGymProfileDelegate) {
            gymProfileDelegate = delegate
            super.showCreateGymProfileView(delegate: delegate)
        }

        override func showOnboardingTrainingProgramView(delegate: CreateProgramDelegate) {
            programDelegate = delegate
            super.showOnboardingTrainingProgramView(delegate: delegate)
        }
    }

    /// Counts the dismissals of the flow this screen was pushed into. A box rather than a captured
    /// local, because `onDismiss` is stored on the presenter and outlives the statement that set it.
    private final class DismissCounter {
        var count = 0
    }

    private struct Screen {
        let presenter: GoalSummaryPresenter
        let interactor: Interactor
        let router: Router
    }

    /// The user as they are once account setup is done: everything the profile needs, the health
    /// disclaimer accepted, and no goal yet — which is exactly the state this screen is reached in.
    private func summaryUser(
        weightKg: Double? = 80,
        weightUnit: WeightUnitPreference? = .kilograms,
        goalId: String? = nil,
        gymProfileId: String? = nil
    ) -> UserModel {
        UserModel(
            userId: "user-1",
            submittedDateOfBirth: Calendar.current.date(from: DateComponents(year: 1988, month: 3, day: 14)),
            submittedGender: .male,
            submittedHeightCentimeters: 180,
            submittedWeightKilograms: weightKg,
            submittedExerciseFrequency: .threeToFour,
            submittedDailyActivityLevel: .moderate,
            submittedCardioFitnessLevel: .intermediate,
            submittedWeightUnitPreference: weightUnit,
            submittedCurrentGoalId: goalId,
            submittedFavouriteGymProfileId: gymProfileId,
            acceptedHealthDisclaimerVersion: UserModel.currentHealthDisclaimerVersion
        )
    }

    private func makeScreen(user: UserModel? = nil, isStandaloneMode: Bool = false) -> Screen {
        let interactor = Interactor(currentUser: user ?? summaryUser())
        let router = Router()
        return Screen(
            presenter: GoalSummaryPresenter(
                interactor: interactor,
                router: router,
                isStandaloneMode: isStandaloneMode
            ),
            interactor: interactor,
            router: router
        )
    }

    private func delegate(
        _ objective: OverarchingObjective = .loseWeight,
        target: Double = 70,
        rate: Double = 0.5
    ) -> GoalSummaryDelegate {
        GoalSummaryDelegate(overarchingObjective: objective, targetWeight: target, weightChangeRate: rate)
    }

    // MARK: - The distance to the goal

    /// Losing is a negative difference and gaining a positive one. The sign is what the rest of the
    /// app reads to decide whether to put the user in a deficit or a surplus, so inverting it here
    /// would have someone trying to lose weight eating to gain it.
    @Test("The difference is signed towards the target")
    func testTheDifferenceIsSignedTowardsTheTarget() {
        let screen = makeScreen(user: summaryUser(weightKg: 80))

        #expect(screen.presenter.weightDifference(targetWeight: 70) == -10)
        #expect(screen.presenter.weightDifference(targetWeight: 90) == 10)
        #expect(screen.presenter.weightDifference(targetWeight: 80) == 0)
    }

    /// The summary shows the change with an arrow as well as a colour, so the direction and sign
    /// have to agree; no change shows no row at all.
    @Test("The written change carries its sign and direction")
    func testTheWrittenChangeCarriesItsSignAndDirection() {
        let screen = makeScreen(user: summaryUser(weightKg: 80))

        let loss = screen.presenter.weightChange(targetWeight: 70)
        #expect(loss?.text == "\u{2212}10 kg")
        #expect(loss?.isGain == false)

        let gain = screen.presenter.weightChange(targetWeight: 82.5)
        #expect(gain?.text == "+2.5 kg")
        #expect(gain?.isGain == true)

        #expect(screen.presenter.weightChange(targetWeight: 80) == nil)
    }

    /// With no weight on file there is no difference to state — better a zero than a number
    /// measured from nothing.
    @Test("No current weight and no target both mean no difference")
    func testNoCurrentWeightMeansNoDifference() {
        let unweighed = makeScreen(user: summaryUser(weightKg: nil))
        #expect(unweighed.presenter.weightDifference(targetWeight: 70) == 0)
        #expect(unweighed.presenter.currentWeight == nil)

        let weighed = makeScreen(user: summaryUser(weightKg: 80))
        #expect(weighed.presenter.weightDifference(targetWeight: nil) == 0)
    }

    // MARK: - How it is written

    @Test("Weights are written in the user's own unit")
    func testWeightsAreWrittenInTheUsersOwnUnit() {
        let metric = makeScreen(user: summaryUser(weightKg: 80))
        #expect(metric.presenter.weightUnit == .kilograms)
        #expect(metric.presenter.formatWeight(80, unit: .kilograms) == "80 kg")

        let imperial = makeScreen(user: summaryUser(weightKg: 80, weightUnit: .pounds))
        #expect(imperial.presenter.weightUnit == .pounds)
        #expect(imperial.presenter.formatWeight(80, unit: .pounds) == "176.4 lb")
    }

    /// A profile that never chose a unit is shown kilograms rather than nothing.
    @Test("A user with no unit preference is shown kilograms")
    func testAUserWithNoUnitPreferenceIsShownKilograms() {
        let screen = makeScreen(user: summaryUser(weightUnit: nil))

        #expect(screen.presenter.weightUnit == .kilograms)
    }

    /// The icon and the message are picked per objective; maintaining must not be given the
    /// language of losing.
    @Test("Each objective gets its own icon and message")
    func testEachObjectiveGetsItsOwnIconAndMessage() {
        let screen = makeScreen()

        #expect(screen.presenter.objectiveIcon(objective: .loseWeight) == "arrow.down.circle.fill")
        #expect(screen.presenter.objectiveIcon(objective: .maintain) == "equal.circle.fill")
        #expect(screen.presenter.objectiveIcon(objective: .gainWeight) == "arrow.up.circle.fill")

        let messages = OverarchingObjective.allCases.map { screen.presenter.motivationalMessage(objective: $0) }
        #expect(Set(messages).count == OverarchingObjective.allCases.count)
    }

    // MARK: - Saving the goal

    /// The goal freezes the weight the user started at, so later progress is measured from where
    /// they actually began rather than from wherever they happen to be when they next weigh in.
    @Test("The saved goal freezes the starting weight")
    func testTheSavedGoalFreezesTheStartingWeight() async {
        let screen = makeScreen(user: summaryUser(weightKg: 82.4, goalId: "goal-1"))

        screen.presenter.onContinuePressed(delegate: delegate(target: 70, rate: 0.5))
        await TestManagers.eventually { !screen.interactor.savedGoals.isEmpty }

        let goal = screen.interactor.savedGoals.first
        #expect(goal?.userId == "user-1")
        #expect(goal?.startingWeightKg == 82.4)
        #expect(goal?.targetWeightKg == 70)
        #expect(goal?.weeklyChangeKg == 0.5)
        #expect(goal?.objective == .loseWeight)
        #expect(goal?.status == .active)
    }

    /// Maintaining reaches this screen by the other route — no target screen, no rate screen — and
    /// has to produce a goal that is coherent rather than one with a missing target.
    @Test("Maintaining saves a goal at the current weight with no weekly change")
    func testMaintainingSavesAGoalAtTheCurrentWeight() async {
        let screen = makeScreen(user: summaryUser(weightKg: 72.5, goalId: "goal-1"))

        screen.presenter.onContinuePressed(delegate: delegate(.maintain, target: 72.5, rate: 0))
        await TestManagers.eventually { !screen.interactor.savedGoals.isEmpty }

        let goal = screen.interactor.savedGoals.first
        #expect(goal?.objective == .maintain)
        #expect(goal?.startingWeightKg == 72.5)
        #expect(goal?.targetWeightKg == 72.5)
        #expect(goal?.weeklyChangeKg == 0)
        #expect(goal?.isMaintaining == true)
    }

    /// The goal is also pointed at from the profile. Without that reference the user has a goal
    /// saved and an app that cannot find it, and onboarding sends them back to set another.
    @Test("The profile is pointed at the new goal")
    func testTheProfileIsPointedAtTheNewGoal() async {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1"))

        screen.presenter.onContinuePressed(delegate: delegate())
        await TestManagers.eventually { !screen.interactor.savedGoalIds.isEmpty }

        #expect(screen.interactor.savedGoalIds == [screen.interactor.savedGoals.first?.id])
        #expect(screen.interactor.trackedEventNames.first == "Onboarding_Goal_Save_Start")
        #expect(screen.interactor.trackedEventNames.contains("Onboarding_Goal_Save_Success"))
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// Without a starting weight the goal would be unmeasurable, so it is refused with an
    /// explanation rather than saved as something that can never be progressed.
    @Test("A goal without a starting weight is refused with an alert")
    func testAGoalWithoutAStartingWeightIsRefused() async {
        let screen = makeScreen(user: summaryUser(weightKg: nil))

        screen.presenter.onContinuePressed(delegate: delegate())
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.router.alertTitles == ["Unable to save your Goal"])
        #expect(screen.interactor.savedGoals.isEmpty)
        #expect(screen.interactor.savedGoalIds.isEmpty)
        #expect(screen.router.shown.isEmpty)
    }

    /// A failed write must not look like a success: onboarding would move on and the user would
    /// come back to an app with no goal in it.
    @Test("A failed save is reported and goes nowhere")
    func testAFailedSaveIsReportedAndGoesNowhere() async {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1"))
        screen.interactor.saveGoalError = URLError(.notConnectedToInternet)

        screen.presenter.onContinuePressed(delegate: delegate())
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.router.alertTitles == ["Unable to save your Goal"])
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames.contains("Onboarding_Goal_Save_Fail"))
        #expect(screen.interactor.trackedEventNames.contains("Onboarding_Goal_Save_Success") == false)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    /// The goal saves and the pointer to it does not. The user must be told, rather than moved on
    /// to a profile that cannot find the goal it just wrote.
    @Test("A goal saved but never pointed at is reported as a failure")
    func testAFailedGoalIdUpdateIsAlsoReported() async {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1"))
        screen.interactor.updateGoalIdError = URLError(.timedOut)

        screen.presenter.onContinuePressed(delegate: delegate())
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.interactor.savedGoals.count == 1)
        #expect(screen.router.alertTitles == ["Unable to save your Goal"])
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames.contains("Onboarding_Goal_Save_Fail"))
    }

    // MARK: - Where it goes next

    /// Once the goal is saved the next step is read off the profile. The user in this test has a
    /// goal and no gym profile, so that is where they land.
    @Test("Saving resumes onboarding at the next missing step")
    func testSavingResumesOnboardingAtTheNextMissingStep() async {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1"))

        screen.presenter.onContinuePressed(delegate: delegate())
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.router.shown == ["gymProfileSetup"])
        #expect(screen.interactor.trackedEventNames.contains("Onboarding_Goal_Navigation"))
    }

    /// A profile with a gym but no program goes one step further along.
    @Test("A profile with a gym already set goes on to the training program")
    func testAProfileWithAGymGoesOnToTheProgram() {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1", gymProfileId: "gym-1"))

        screen.presenter.handleNavigation()

        #expect(screen.router.shown == ["trainingProgramSetup"])
    }

    /// A profile with no goal yet sends the user back to goal setting rather than forward, which
    /// is what makes the save above load-bearing.
    @Test("A profile still missing a goal goes back to goal setting")
    func testAProfileStillMissingAGoalGoesBackToGoalSetting() {
        let screen = makeScreen(user: summaryUser(goalId: nil))

        screen.presenter.handleNavigation()

        #expect(screen.router.shown == ["goalSetting"])
    }

    /// Nothing to route from without a signed-in user, and in particular no step to infer.
    @Test("No signed-in user navigates nowhere")
    func testNoSignedInUserNavigatesNowhere() {
        let screen = makeScreen(user: nil)
        screen.interactor.currentUser = nil

        screen.presenter.handleNavigation()

        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames.isEmpty)
    }

    /// The gym-profile step hands back a callback so the flow can re-read the profile and carry on;
    /// firing it must ask the question again rather than dead-end.
    @Test("Finishing the gym profile step asks where to go next again")
    func testFinishingTheGymProfileStepAsksWhereToGoNextAgain() {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1"))

        screen.presenter.handleNavigation()
        screen.router.gymProfileDelegate?.onComplete?()

        #expect(screen.router.shown == ["gymProfileSetup", "gymProfileSetup"])
    }

    /// The training-program callback is `@Sendable` and may fire off the main actor, so the router
    /// hops it — which means the re-ask lands on a later turn rather than immediately.
    @Test("Finishing the training program step asks where to go next again")
    func testFinishingTheProgramStepAsksWhereToGoNextAgain() async {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1", gymProfileId: "gym-1"))

        screen.presenter.handleNavigation()
        screen.router.programDelegate?.onComplete?()

        await TestManagers.eventually { screen.router.shown.count == 2 }
        #expect(screen.router.shown == ["trainingProgramSetup", "trainingProgramSetup"])
    }

    // MARK: - Standalone mode

    /// Opened from the profile rather than from onboarding, this screen is the whole flow, so it
    /// reports which it is and the view swaps Continue for Complete on the strength of it.
    @Test("The screen knows whether it was opened standalone")
    func testTheScreenKnowsWhetherItWasOpenedStandalone() {
        #expect(makeScreen().presenter.isStandaloneMode == false)
        #expect(makeScreen(isStandaloneMode: true).presenter.isStandaloneMode)
    }

    /// Completing from the standalone flow saves the goal and then closes the flow, rather than
    /// pushing the user further into onboarding they are not in.
    @Test("Completing standalone saves the goal and dismisses the flow")
    func testCompletingDismissesTheFlowItWasOpenedFrom() async {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1"), isStandaloneMode: true)
        let dismissals = DismissCounter()
        screen.presenter.onDismiss = { dismissals.count += 1 }

        screen.presenter.onCompletePressed(delegate: delegate())
        await TestManagers.eventually { dismissals.count == 1 }

        #expect(screen.interactor.savedGoals.count == 1)
        #expect(screen.interactor.savedGoalIds.count == 1)
        #expect(dismissals.count == 1)
        // Standalone is its own flow, so it closes rather than pushing on into onboarding.
        #expect(screen.router.shown.isEmpty)
    }

    /// The flow closes only once the goal is written. Dismissing first would take the user back to
    /// their profile while the write was still in flight, and leave the alert nowhere to appear.
    @Test("A failed standalone save keeps the flow open to show the alert")
    func testAFailedCompleteDoesNotDismissTheFlow() async {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1"), isStandaloneMode: true)
        screen.interactor.saveGoalError = URLError(.notConnectedToInternet)
        let dismissals = DismissCounter()
        screen.presenter.onDismiss = { dismissals.count += 1 }

        screen.presenter.onCompletePressed(delegate: delegate())
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(dismissals.count == 0)
        #expect(screen.router.alertTitles == ["Unable to save your Goal"])
    }

    /// Both buttons are disabled while the save is in flight, and the view also required
    /// `goalCreated` of Complete — which only a successful save sets, and only that button could
    /// have triggered. Standalone goal setting could therefore never be completed at all.
    @Test("The save flag is raised while writing, lowered after, and records the goal exists")
    func testTheSaveFlagsTrackTheWriteRatherThanNothing() async {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1"), isStandaloneMode: true)

        #expect(screen.presenter.isLoading == false)
        #expect(screen.presenter.goalCreated == false)

        screen.presenter.onCompletePressed(delegate: delegate())
        await TestManagers.eventually { screen.presenter.goalCreated }

        #expect(screen.presenter.goalCreated)
        await TestManagers.eventually { screen.presenter.isLoading == false }
        #expect(screen.presenter.isLoading == false)
    }

    /// A failed save leaves the screen usable: the button has to come back so the user can retry.
    @Test("A failed save re-enables the button rather than leaving it spinning")
    func testAFailedSaveLeavesTheScreenUsable() async {
        let screen = makeScreen(user: summaryUser(goalId: "goal-1"))
        screen.interactor.saveGoalError = URLError(.notConnectedToInternet)

        screen.presenter.onContinuePressed(delegate: delegate())
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.presenter.isLoading == false)
        #expect(screen.presenter.goalCreated == false)
    }
}
