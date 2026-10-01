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
    
    // MARK: - Constants
    /// The standard calorie floor the diet step applies. No estimate is shown below it.
    static let lowestCalorieTargetShown: Double = 1200
    let minWeightChangeRate: Double = 0.25 // kg/week
    /// The slider's step, which the range's ends are snapped to.
    static let rateStep: Double = 0.05
    /// The old fixed maximum, now only a ceiling for heavier people.
    static let absoluteMaxWeightChangeRate: Double = 1.5

    /// At most 1% of the person's body weight a week, losing or gaining, and never above 1.5 kg
    /// (decision 3). It was 1.5 kg for everybody. Snapped down to the slider's step so the last
    /// stop is on the grid, and kept one step above the minimum so the range never collapses.
    var maxWeightChangeRate: Double {
        let onePercent = min(currentWeight * 0.01, Self.absoluteMaxWeightChangeRate)
        // The epsilon stops 0.3 / 0.05 = 5.999… snapping a whole step down.
        let snapped = (onePercent / Self.rateStep + 1e-9).rounded(.down) * Self.rateStep
        return max(snapped, minWeightChangeRate + Self.rateStep)
    }

    // Relative to the person's own range: fixed 0.4 and 0.8 kg bands meant a light person could
    // never reach "Aggressive" once the maximum became 1% of their weight.
    var conservativeThreshold: Double { maxWeightChangeRate * 0.5 }
    /// "Near the top of that person's range": where the warning appears.
    var aggressiveThreshold: Double { maxWeightChangeRate * 0.8 }
    
    var currentRateCategory: WeightRateCategory {
        if weightChangeRate <= conservativeThreshold {
            return .conservative
        } else if weightChangeRate >= aggressiveThreshold {
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

    func onAppear(delegate: WeightRateDelegate) {
        let user = interactor.currentUser
        currentWeight = user?.submittedWeightKilograms ?? 70
        weightUnit = user?.submittedWeightUnitPreference ?? .kilograms

        let objective = delegate.overarchingObjective
        // Set default rate based on objective. The default stays below the warning band, which
        // for a light person is below the old 0.5 kg.
        let belowWarning = ((aggressiveThreshold / Self.rateStep).rounded(.down) - 1) * Self.rateStep
        if objective == .maintain {
            weightChangeRate = 0
        } else if objective == .loseWeight {
            weightChangeRate = max(minWeightChangeRate, min(0.5, belowWarning))
        } else if objective == .gainWeight {
            weightChangeRate = 0.25
        }

        didInitialize = true
    }

    func onContinuePressed(delegate: WeightRateDelegate) {
        let delegate = GoalSummaryDelegate(delegate: delegate, weightChangeRate: weightChangeRate)
        interactor.trackEvent(event: Event.navigate)
        router.showGoalSummaryView(delegate: delegate)
    }

    /// Near the top of the person's range, what the rate costs, in plain words. Nil below it.
    func rateWarningText(delegate: WeightRateDelegate) -> String? {
        guard currentRateCategory == .aggressive else { return nil }
        switch delegate.overarchingObjective {
        case .loseWeight:
            return String(localized: "Losing this fast makes you more likely to lose muscle and to feel hungry and tired. A slower rate is easier to keep up.")
        case .gainWeight:
            return String(localized: "Gaining this fast means more of the weight you put on is likely to be fat rather than muscle.")
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
    
    func estimatedCalorieTargetText(delegate: WeightRateDelegate) -> String {
        let weeklyChangeInKg = weightChangeRate
        // The 3500 kcal rule is per POUND, so this conversion is arithmetic, not presentation — it
        // was gated on `weightUnit == .pounds`, which meant a user set to kilograms had their
        // kilogram figure multiplied by 3500 directly and got a calorie target 2.2x too small.
        let weeklyChangeInPounds = UnitConversion.kgToLbs(weeklyChangeInKg)

        // Rough estimate: 1 lb = ~3500 calories, so weekly deficit/surplus
        let weeklyCalorieChange = weeklyChangeInPounds * 3500
        let dailyCalorieChange = weeklyCalorieChange / 7
        
        // The person's own expenditure, the figure they were shown four screens earlier. This
        // was a fixed 2000 kcal for everyone, so the fastest rate read "~ 346 kcal".
        let baseCalories = interactor.estimateTDEE(user: interactor.currentUser)
        let unclamped = delegate.overarchingObjective == .loseWeight ?
            baseCalories - dailyCalorieChange :
            baseCalories + dailyCalorieChange
        let targetCalories = max(unclamped, Self.lowestCalorieTargetShown)

        return String(localized: "~ \(String(describing: Int(targetCalories))) kcal estimated daily calorie target")
    }
    
    func estimatedEndDateText(delegate: WeightRateDelegate) -> String {
        let target = delegate.targetWeight
        let totalWeightChange = abs(target - currentWeight)
        let weeklyChangeInKg = weightChangeRate
        let weeksToGoal = totalWeightChange / weeklyChangeInKg

        // `Int` traps on a Double that is not finite, and this runs while the screen is drawing.
        // A rate of zero makes the division infinite — or NaN, when the target is already the
        // current weight — which is exactly what took the goal summary down before it was
        // guarded. Only losing and gaining reach this screen today, so the rate is never zero
        // through the router; a maintain goal arriving here would crash on the first draw.
        guard weeksToGoal.isFinite else { return "No approximate end date at this rate" }

        let endDate = Calendar.current.date(byAdding: .weekOfYear, value: Int(weeksToGoal), to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return String(localized: "Approximate end date: \(String(describing: formatter.string(from: endDate)))")
    }

    enum Event: LoggableEvent {
        case navigate

        var eventName: String {
            switch self {
            case .navigate: return "Onboarding_WeightRate_Navigate"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .navigate:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .navigate:
                return .info
            }
        }
    }
}
