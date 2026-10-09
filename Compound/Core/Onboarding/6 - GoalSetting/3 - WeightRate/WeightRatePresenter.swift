//
//  WeightRatePresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class WeightRatePresenter {
    private let interactor: WeightRateInteractor
    private let router: WeightRateRouter

    let isStandaloneMode: Bool
    
    var currentWeight: Double = 0
    var weightUnit: WeightUnitPreference = .kilograms
    var didInitialize: Bool = false
    var weightChangeRate: Double = 0.5 // kg/week
        
    enum WeightRateCategory {
        case conservative, standard, aggressive
        
        var title: String {
            switch self {
            case .conservative: return String(localized: "Conservative")
            case .standard: return String(localized: "Standard (Recommended)")
            case .aggressive: return String(localized: "Aggressive")
            }
        }
    }
    
    // MARK: - The range, as a share of body weight

    /// Losing or gaining: the two have different ranges. Set by `onAppear`.
    private(set) var objective: OverarchingObjective = .loseWeight
    /// Under a BMI of 25 (or no height known): the lower default and the earlier warning apply.
    private(set) var isLean: Bool = true

    /// The slider's step, which the range's ends are snapped to.
    static let rateStep: Double = 0.05
    /// The old fixed maximum, now only a ceiling for heavier people.
    static let absoluteMaxWeightChangeRate: Double = GoalTimeline.absoluteMaximumKg

    /// `percent` of the person's weight a week, in kilograms.
    private func kilograms(percent: Double) -> Double {
        currentWeight * percent / 100
    }

    /// The rate as a percentage of the person's weight a week.
    var weeklyPercentOfBodyWeight: Double {
        currentWeight > 0 ? weightChangeRate / currentWeight * 100 : 0
    }

    /// 0.25% of body weight a week for losing, 0.1% for gaining, snapped up to the slider's step.
    var minWeightChangeRate: Double {
        let percent = objective == .gainWeight ? GoalTimeline.gainMinimumPercent : GoalTimeline.lossMinimumPercent
        // The epsilon stops 0.2 / 0.05 = 4.000…1 snapping a whole step up.
        let snapped = (kilograms(percent: percent) / Self.rateStep - 1e-9).rounded(.up) * Self.rateStep
        return max(snapped, Self.rateStep)
    }

    /// At most 1% of the person's body weight a week, losing or gaining, and never above 1.5 kg.
    /// Snapped down to the slider's step so the last stop is on the grid, and kept one step above
    /// the minimum so the range never collapses.
    var maxWeightChangeRate: Double {
        let onePercent = min(kilograms(percent: GoalTimeline.maximumPercent), Self.absoluteMaxWeightChangeRate)
        // The epsilon stops 0.3 / 0.05 = 5.999… snapping a whole step down.
        let snapped = (onePercent / Self.rateStep + 1e-9).rounded(.down) * Self.rateStep
        return max(snapped, minWeightChangeRate + Self.rateStep)
    }

    /// Below this share of body weight the rate reads as conservative: 0.5% losing, 0.25% gaining.
    var conservativeThresholdPercent: Double {
        objective == .gainWeight ? GoalTimeline.gainDefaultPercent : GoalTimeline.leanLossDefaultPercent
    }

    /// Above this the rate reads as aggressive and the warning appears: 0.75% for a lean person
    /// losing, 1% (the top of the range, so never) for anyone else losing, 0.5% for gaining.
    var aggressiveThresholdPercent: Double {
        switch objective {
        case .gainWeight: return GoalTimeline.gainWarningPercent
        case .loseWeight, .maintain: return isLean ? GoalTimeline.leanLossWarningPercent : GoalTimeline.maximumPercent
        }
    }

    var currentRateCategory: WeightRateCategory {
        // A hair of tolerance so a rate snapped onto a threshold reads as that threshold.
        let percent = weeklyPercentOfBodyWeight
        if percent < conservativeThresholdPercent - 1e-6 {
            return .conservative
        } else if percent > aggressiveThresholdPercent + 1e-6 {
            return .aggressive
        } else {
            return .standard
        }
    }

    var canContinue: Bool { weightChangeRate > 0 }

    init(
        interactor: WeightRateInteractor,
        router: WeightRateRouter,
        isStandaloneMode: Bool = false
    ) {
        self.interactor = interactor
        self.router = router
        self.isStandaloneMode = isStandaloneMode
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(isOnboarding: !isStandaloneMode))
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear(isOnboarding: !isStandaloneMode))
    }

    func onAppear(delegate: WeightRateDelegate) {
        let user = interactor.currentUser
        currentWeight = interactor.currentWeightKilograms ?? 70
        weightUnit = user?.submittedWeightUnitPreference ?? .kilograms
        objective = delegate.overarchingObjective
        isLean = GoalTimeline.isLean(weightKg: currentWeight, heightCm: user?.submittedHeightCentimeters)

        // The default is a share of body weight: 0.5% a week for a lean person losing, 0.75% for
        // anyone else, and 0.25% for gaining.
        switch objective {
        case .maintain:
            weightChangeRate = 0
        case .loseWeight:
            weightChangeRate = snappedIntoRange(kilograms(percent: isLean ? GoalTimeline.leanLossDefaultPercent : GoalTimeline.lossDefaultPercent))
        case .gainWeight:
            weightChangeRate = snappedIntoRange(kilograms(percent: GoalTimeline.gainDefaultPercent))
        }
        // Editing a goal toward the same objective keeps its rate.
        if let editing = delegate.editingGoal, editing.objective == objective, editing.weeklyChangeKg > 0 {
            weightChangeRate = editing.weeklyChangeKg
        }

        didInitialize = true
    }

    /// The nearest stop on the slider, inside its range.
    private func snappedIntoRange(_ kilograms: Double) -> Double {
        let snapped = (kilograms / Self.rateStep).rounded() * Self.rateStep
        return min(max(snapped, minWeightChangeRate), maxWeightChangeRate)
    }

    func onContinuePressed(delegate: WeightRateDelegate) {
        let delegate = GoalSummaryDelegate(delegate: delegate, weightChangeRate: weightChangeRate)
        interactor.trackEvent(event: Event.navigate)
        router.showGoalSummaryView(delegate: delegate)
    }

    /// Above the warning share of body weight, what the rate costs, in plain words. Nil below it.
    func rateWarningText(delegate: WeightRateDelegate) -> String? {
        guard currentRateCategory == .aggressive else { return nil }
        switch delegate.overarchingObjective {
        case .loseWeight:
            return String(localized: "Losing more than 0.75% of your body weight a week makes a lean person more likely to lose muscle and to feel hungry and tired. A slower rate is easier to keep up.")
        case .gainWeight:
            return String(localized: "Gaining more than 0.5% of your body weight a week means more of what you put on is likely to be fat rather than muscle.")
        case .maintain:
            return nil
        }
    }

    func weeklyWeightChangeText(delegate: WeightRateDelegate) -> String {
        let weeklyChangeInKg = weightChangeRate
        let weeklyChangeInPounds = UnitConversion.convertWeight(weeklyChangeInKg, to: weightUnit)
        let unitText = weightUnit.abbreviation
        let sign = delegate.overarchingObjective == .loseWeight ? "-" : "+"
        let percentBW = (weeklyChangeInKg / currentWeight) * 100
        let amount = weeklyChangeInPounds.formatted(.number.precision(.fractionLength(2)))
        let percent = percentBW.formatted(.number.precision(.fractionLength(1)))

        return String(localized: "\(sign)\(amount) \(unitText) (\(percent)% of body weight) / Week")
    }

    func monthlyWeightChangeText(delegate: WeightRateDelegate) -> String {
        let monthlyChangeInKg = weightChangeRate * 4 // Approximate monthly rate
        let monthlyChangeInPounds = UnitConversion.convertWeight(monthlyChangeInKg, to: weightUnit)
        let unitText = weightUnit.abbreviation
        let sign = delegate.overarchingObjective == .loseWeight ? "-" : "+"
        let percentBW = (monthlyChangeInKg / currentWeight) * 100
        let amount = monthlyChangeInPounds.formatted(.number.precision(.fractionLength(2)))
        let percent = percentBW.formatted(.number.precision(.fractionLength(1)))

        return String(localized: "\(sign)\(amount) \(unitText) (\(percent)% of body weight) / Month")
    }
    
    /// The person's own expenditure (the figure they were shown on the Expenditure step) plus or
    /// minus the rate's daily share of the energy in a kilogram (`EnergyDensity`), as the plan will
    /// set it: a deficit no larger than a quarter of expenditure, and never below their floor.
    private func estimatedCalorieTarget(delegate: WeightRateDelegate) -> (kcal: Double, isDeficitCapped: Bool) {
        let dailyChange = EnergyDensity.dailyKcal(forWeeklyChangeKg: weightChangeRate)
        let baseCalories = interactor.estimateTDEE(user: interactor.currentUser)
        let floor = NutritionTargets.calorieFloor(for: interactor.currentUser?.submittedGender)
        switch delegate.overarchingObjective {
        case .loseWeight:
            let largestDeficit = NutritionTargets.maximumDeficitShare * baseCalories
            let deficit = min(dailyChange, largestDeficit)
            return (max(baseCalories - deficit, floor), dailyChange > largestDeficit)
        case .gainWeight:
            return (max(baseCalories + dailyChange, floor), false)
        case .maintain:
            return (max(baseCalories, floor), false)
        }
    }

    func estimatedCalorieTargetText(delegate: WeightRateDelegate) -> String {
        let target = Int(estimatedCalorieTarget(delegate: delegate).kcal.rounded())
        return String(localized: "~ \(String(describing: target)) kcal estimated daily calorie target")
    }

    /// Said when the deficit this rate needs is more than a quarter of expenditure, so the plan
    /// will set a smaller one and progress will be slower than the slider says.
    func deficitCapText(delegate: WeightRateDelegate) -> String? {
        guard estimatedCalorieTarget(delegate: delegate).isDeficitCapped else { return nil }
        return String(localized: "This rate needs a deficit of more than a quarter of what you burn, so your target is capped there and you may lose more slowly.")
    }

    /// The target moves as weight does: holding the rate means about 24 kcal a day less for each
    /// kilogram lost (more for each gained). Nil when there is no distance to cover.
    func targetStepText(delegate: WeightRateDelegate) -> String? {
        let distance = abs(delegate.targetWeight - currentWeight)
        guard distance.isFinite, distance > 0 else { return nil }
        let change = Int((GoalTimeline.targetChangeKcal(distanceKg: distance) / 10).rounded() * 10)
        switch delegate.overarchingObjective {
        case .loseWeight:
            return String(localized: "Your target will step down as you lose, to keep this rate: about \(String(describing: change)) kcal a day lower by your goal weight.")
        case .gainWeight:
            return String(localized: "Your target will step up as you gain, to keep this rate: about \(String(describing: change)) kcal a day higher by your goal weight.")
        case .maintain:
            return nil
        }
    }

    /// Distance ÷ rate, in whole weeks rounded up (`GoalTimeline.weeks`), as the goal summary
    /// counts them.
    func estimatedEndDateText(delegate: WeightRateDelegate) -> String {
        // A rate of zero has no end: the division is infinite — or NaN, when the target is already
        // the current weight — and `Int` traps on both while the screen is drawing. Only losing and
        // gaining reach this screen today, so the rate is never zero through the router.
        let weeksToGoal = GoalTimeline.weeks(distanceKg: delegate.targetWeight - currentWeight, weeklyRateKg: weightChangeRate)
        guard weeksToGoal > 0 else { return String(localized: "No approximate end date at this rate") }

        let endDate = Calendar.current.date(byAdding: .weekOfYear, value: weeksToGoal, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return String(localized: "Approximate end date: \(String(describing: formatter.string(from: endDate)))")
    }

    enum Event: LoggableEvent {
        /// `isOnboarding` is false when the step was opened after onboarding, from Settings, Profile
        /// or Progress, so the onboarding funnel can leave those visits out.
        case onAppear(isOnboarding: Bool)
        case onDisappear(isOnboarding: Bool)
        case navigate

        var eventName: String {
            switch self {
            case .onAppear: return "WeightRateView_Appear"
            case .onDisappear: return "WeightRateView_Disappear"
            case .navigate: return "Onboarding_WeightRate_Navigate"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let isOnboarding), .onDisappear(let isOnboarding):
                return ["is_onboarding": isOnboarding]
            case .navigate:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onAppear, .onDisappear:
                return .analytic
            case .navigate:
                return .info
            }
        }
    }
}
