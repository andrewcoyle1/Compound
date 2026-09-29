//
//  WeightRatePresenter.swift
//  DialedIn
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
    let minWeightChangeRate: Double = 0.25 // kg/week
    let maxWeightChangeRate: Double = 1.5  // kg/week
    let conservativeThreshold: Double = 0.4 // kg/week
    let aggressiveThreshold: Double = 0.8  // kg/week
    
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
        // Set default rate based on objective
        if objective == .maintain {
            weightChangeRate = 0
        } else if objective == .loseWeight {
            weightChangeRate = 0.5
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

    func weeklyWeightChangeText(delegate: WeightRateDelegate) -> String {
        let weeklyChangeInKg = weightChangeRate
        let weeklyChangeInPounds = UnitConversion.convertWeight(weeklyChangeInKg, to: weightUnit)
        let unitText = weightUnit.abbreviation
        let sign = delegate.overarchingObjective == .loseWeight ? "-" : "+"
        let percentBW = (weeklyChangeInKg / currentWeight) * 100
        
        return String(localized: "\(sign)\(String(format: "%.2f", weeklyChangeInPounds)) \(unitText) (\(String(format: "%.1f", percentBW))% BW) / Week")
    }
    
    func monthlyWeightChangeText(delegate: WeightRateDelegate) -> String {
        let monthlyChangeInKg = weightChangeRate * 4 // Approximate monthly rate
        let monthlyChangeInPounds = UnitConversion.convertWeight(monthlyChangeInKg, to: weightUnit)
        let unitText = weightUnit.abbreviation
        let sign = delegate.overarchingObjective == .loseWeight ? "-" : "+"
        let percentBW = (monthlyChangeInKg / currentWeight) * 100
        
        return String(localized: "\(sign)\(String(format: "%.2f", monthlyChangeInPounds)) \(unitText) (\(String(format: "%.1f", percentBW))% BW) / Month")
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
        
        let baseCalories = 2000.0 // Rough BMR estimate
        let targetCalories = delegate.overarchingObjective == .loseWeight ?
            baseCalories - dailyCalorieChange :
            baseCalories + dailyCalorieChange
        
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

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

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
