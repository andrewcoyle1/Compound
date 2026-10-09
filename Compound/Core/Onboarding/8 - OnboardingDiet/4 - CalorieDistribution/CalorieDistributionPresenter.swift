//
//  CalorieDistributionPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class CalorieDistributionPresenter {
    private let interactor: CalorieDistributionInteractor
    private let router: CalorieDistributionRouter

    var selectedCalorieDistribution: CalorieDistribution?
    var trainingDaysPerWeek: Int?
    var hasMesocycle: Bool = false

    /// Picking an option row: record it and give the selection tick.
    func onDistributionSelected(_ value: CalorieDistribution) {
        selectedCalorieDistribution = value
        interactor.playHaptic(option: .selection)
    }

    init(
        interactor: CalorieDistributionInteractor,
        router: CalorieDistributionRouter
    ) {
        self.interactor = interactor
        self.router = router
        // Rebuilding a plan opens on the split it was built with.
        if let current = interactor.currentDietPlan.flatMap({ CalorieDistribution(rawValue: $0.calorieDistribution) }) {
            selectedCalorieDistribution = current
        }
        loadTrainingContext()
    }

    func onViewAppear(isFromSettings: Bool) {
        interactor.trackScreenEvent(event: Event.onAppear(isOnboarding: !isFromSettings))
    }

    func onViewDisappear(isFromSettings: Bool) {
        interactor.trackEvent(event: Event.onDisappear(isOnboarding: !isFromSettings))
    }
    
    /// The body of this was commented out against a `plan.weeks.first.scheduledWorkouts` shape that
    /// `Mesocycle` no longer has, so it did nothing: `hasMesocycle` stayed false,
    /// `trainingDaysPerWeek` stayed nil, and `prefillCalorieDistribution` was never reached.
    ///
    private func loadTrainingContext() {
        guard let mesocycle = interactor.activeMesocycle else { return }

        hasMesocycle = true
        let trainingDays = CalorieDistribution.trainingDays(in: mesocycle)
        trainingDaysPerWeek = trainingDays
        if selectedCalorieDistribution == nil {
            let recommended = CalorieDistribution.recommended(for: mesocycle)
            selectedCalorieDistribution = recommended
            interactor.trackEvent(event: Event.calorieDistributionPrefilled(
                distribution: recommended,
                reason: "training_days_\(trainingDays)"
            ))
        }
        interactor.trackEvent(event: Event.trainingContextLoaded(daysPerWeek: trainingDays))
    }
    
    func navigateToProteinIntake(delegate: CalorieDistributionDelegate) {
        if let calorieDistribution = selectedCalorieDistribution {
            interactor.trackEvent(event: Event.navigate)
            router.showProteinIntakeView(delegate: ProteinIntakeDelegate(delegate: delegate, calorieDistribution: calorieDistribution))
        }
    }

    enum Event: LoggableEvent {
        /// `isOnboarding` is false when the step was opened after onboarding, from Settings, Profile
        /// or Progress, so the onboarding funnel can leave those visits out.
        case onAppear(isOnboarding: Bool)
        case onDisappear(isOnboarding: Bool)
        case trainingContextLoaded(daysPerWeek: Int?)
        case calorieDistributionPrefilled(distribution: CalorieDistribution, reason: String)
        case navigate

        var eventName: String {
            switch self {
            case .onAppear: return "CalorieDistributionView_Appear"
            case .onDisappear: return "CalorieDistributionView_Disappear"
            case .trainingContextLoaded: return "Onboarding_CalDist_TrainingContextLoaded"
            case .calorieDistributionPrefilled: return "Onboarding_CalDist_Prefilled"
            case .navigate: return "Onboarding_CalDist_Navigate"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let isOnboarding), .onDisappear(let isOnboarding):
                return ["is_onboarding": isOnboarding]
            case .trainingContextLoaded(daysPerWeek: let days):
                return ["daysPerWeek": days as Any]
            case .calorieDistributionPrefilled(distribution: let dist, reason: let reason):
                return ["distribution": dist.rawValue, "reason": reason]
            case .navigate:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .onAppear, .onDisappear:
                return .analytic
            case .navigate, .trainingContextLoaded, .calorieDistributionPrefilled:
                return .info
            }
        }
    }
}

enum CalorieDistribution: String, CaseIterable, Identifiable {
    case even
    case varied
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .even:
            return String(localized: "Distribute Evenly")
        case .varied:
            return String(localized: "Vary By Day")
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .even:
            return String(localized: "Distribute calories evenly across all days of the week.")
        case .varied:
            return String(localized: "One higher day for each training day in your program, spread through the week, and lower days in between. The weekly total stays the same.")
        }
    }
}

extension CalorieDistribution {

    /// `workoutTemplates` is the mesocycle's weekly cycle — `SocialPresenter.todaysScheduledItem`
    /// indexes it by weekday, and a template with no exercises is a rest day — so the training days
    /// are the templates that have exercises.
    static func trainingDays(in mesocycle: Mesocycle) -> Int {
        mesocycle.workoutTemplates.filter { !$0.exercises.isEmpty }.count
    }

    /// Three training days a week or fewer: even. Four or more: varied, to bias carbs to training
    /// days. No mesocycle counts as no training days. Shared by this screen's prefill and the
    /// "Use Recommended Plan" shortcut, so the two cannot disagree.
    static func recommended(for mesocycle: Mesocycle?) -> CalorieDistribution {
        (mesocycle.map(trainingDays(in:)) ?? 0) <= 3 ? .even : .varied
    }
}
