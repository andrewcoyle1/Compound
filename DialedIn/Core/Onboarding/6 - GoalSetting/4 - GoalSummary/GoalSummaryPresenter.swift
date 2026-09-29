//
//  GoalSummaryPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class GoalSummaryPresenter {
    private let interactor: GoalSummaryInteractor
    private let router: GoalSummaryRouter

    let isStandaloneMode: Bool

    var isLoading: Bool = false
    var goalCreated: Bool = false
    var onDismiss: (() -> Void)?
        
    init(
        interactor: GoalSummaryInteractor,
        router: GoalSummaryRouter,
        isStandaloneMode: Bool = false
    ) {
        self.interactor = interactor
        self.router = router
        self.isStandaloneMode = isStandaloneMode
    }
    
    /// Standalone mode, where this screen is the whole flow rather than a step of onboarding.
    ///
    /// The goal is saved first and the flow closed only once it is, so a user whose save fails
    /// sees the alert on the screen they were on rather than back where they started.
    func onCompletePressed(delegate: GoalSummaryDelegate) {
        Task {
            await saveGoal(delegate: delegate, onSuccess: { [weak self] in self?.onDismiss?() })
        }
    }

    func onContinuePressed(delegate: GoalSummaryDelegate) {
        Task {
            await saveGoal(delegate: delegate, onSuccess: { [weak self] in self?.handleNavigation() })
        }
    }

    /// Writes the goal, then does whatever the screen it was pressed from does next.
    ///
    /// `isLoading` gates both buttons, so it has to be set before the write and cleared on every
    /// way out of it — including the two that alert. It used to be cleared by a `defer` in the
    /// synchronous caller, which ran before the write had even started.
    private func saveGoal(delegate: GoalSummaryDelegate, onSuccess: @MainActor () -> Void) async {
        interactor.trackEvent(event: Event.goalSaveStart)
        isLoading = true
        defer { isLoading = false }

        guard let user = interactor.currentUser,
              let startingWeight = user.submittedWeightKilograms else {
            router.showSimpleAlert(
                title: String(localized: "Unable to save your Goal"),
                subtitle: "Current weight not available."
            )
            return
        }

        do {
            // Create goal in subcollection with frozen starting weight
            let goal = WeightGoal(
                userId: user.userId,
                objective: delegate.overarchingObjective,
                startingWeightKg: startingWeight,
                targetWeightKg: delegate.targetWeight,
                weeklyChangeKg: delegate.weightChangeRate,
            )
            try await interactor.saveGoal(goal)

            // Update user's currentGoalId reference
            try await interactor.updateCurrentGoalId(goalId: goal.id)

            goalCreated = true
            interactor.trackEvent(event: Event.goalSaveSuccess)

            onSuccess()
        } catch {
            interactor.trackEvent(event: Event.goalSaveFail(error: error))
            router.showSimpleAlert(
                title: String(localized: "Unable to save your Goal"),
                subtitle: "Please check your internet connection and try again."
            )
        }
    }
    
    // MARK: Handle Navigation
    func handleNavigation() {
        // Navigate based on user's inferred onboarding step
        if let currentUser = interactor.currentUser {
            let step = currentUser.inferredOnboardingStep
            interactor.trackEvent(event: Event.navigate)
            route(to: step)
        }
    }

    private func route(to step: OnboardingStep) {
        router.routeToOnboardingStep(step, onComplete: handleNavigation)
    }

    // MARK: - Computed Properties
    
    var currentWeight: Double? {
        interactor.currentUser?.submittedWeightKilograms
    }
    
    var weightUnit: WeightUnitPreference {
        interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
    }
    
    func weightDifference(targetWeight: Double?) -> Double {
        guard let current = currentWeight else { return 0 }
        guard let target = targetWeight else { return 0 }
        return target - current
    }
    
    /// Zero when there is no journey to estimate.
    ///
    /// "Maintain" reaches this screen with the current weight as its own target and a weekly rate
    /// of zero, so the division is 0 / 0 — NaN, which traps when converted to an `Int` and took the
    /// screen down as it drew. A rate of zero towards a different target is infinite for the same
    /// reason. The view already reads zero as "maintaining current weight", so that is the answer.
    func estimatedWeeks(delegate: GoalSummaryDelegate) -> Int {
        let weeks = ceil(abs(weightDifference(targetWeight: delegate.targetWeight)) / delegate.weightChangeRate)
        guard weeks.isFinite, weeks > 0 else { return 0 }
        return Int(weeks)
    }
    
    func estimatedMonths(delegate: GoalSummaryDelegate) -> Int {
        Int(ceil(Double(estimatedWeeks(delegate: delegate)) / 4.33))
    }
    
    func formatWeight(_ weight: Double, unit: WeightUnitPreference) -> String {
        switch unit {
        case .kilograms:
            return String(format: "%.1f kg", weight)
        case .pounds:
            return String(format: "%.1f lbs", UnitConversion.kgToLbs(weight))
        }
    }
    
    func objectiveIcon(objective: OverarchingObjective) -> String {
        let objective = objective.description.lowercased()
        if objective.contains("lose") { return "arrow.down.circle.fill" }
        if objective.contains("maintain") { return "equal.circle.fill" }
        return "arrow.up.circle.fill"
    }
    
    func motivationalMessage(objective: OverarchingObjective) -> String {
        let objective = objective.description.lowercased()
        if objective.contains("lose") {
            return String(localized: "Every step you take towards your goal is progress. Stay consistent with your nutrition and exercise, and you'll reach your target weight. Remember, sustainable changes lead to lasting results.")
        } else if objective.contains("maintain") {
            return String(localized: "Maintaining your current weight is a fantastic goal! Focus on balanced nutrition and regular activity to keep your body healthy and strong. Consistency is key to long-term success.")
        } else {
            return String(localized: "Building healthy weight takes time and dedication. Focus on nutrient-dense foods and progressive strength training. Your body will thank you for the consistent effort.")
        }
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    enum Event: LoggableEvent {
        case goalSaveStart
        case goalSaveSuccess
        case goalSaveFail(error: Error)
        case navigate

        var eventName: String {
            switch self {
            case .goalSaveStart:    return "Onboarding_Goal_Save_Start"
            case .goalSaveSuccess:  return "Onboarding_Goal_Save_Success"
            case .goalSaveFail:     return "Onboarding_Goal_Save_Fail"
            case .navigate:         return "Onboarding_Goal_Navigation"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case let .goalSaveFail(error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .goalSaveFail:
                return .severe
            case .navigate:
                return .info
            default:
                return .analytic
            }
        }
    }
}
