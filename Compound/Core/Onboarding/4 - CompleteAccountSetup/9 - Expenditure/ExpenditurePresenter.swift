//
//  ExpenditurePresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class ExpenditurePresenter {
    private let interactor: ExpenditureInteractor
    private let router: ExpenditureRouter

    private(set) var canContinue: Bool = false
    // Computed from collected data
    var totalExpenditureKcal: Int = 0
    
    var currentUser: UserModel? {
        interactor.currentUser
    }
    
    init(
        interactor: ExpenditureInteractor,
        router: ExpenditureRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    struct ExpenditureContext {
        let weight: Double
        let height: Double
        let dateOfBirth: Date
        let gender: Gender
        let activityLevel: ActivityLevel
        let exerciseFrequency: ExerciseFrequency
    }

    func breakdownItems(context: ExpenditureContext) -> [Breakdown] {
        // Breakdown aligned with the actual formula used for TDEE
        // TDEE = BMR * (baseActivityMultiplier + exerciseAdjustment)
        let bmrCals = bmrInt(
            weight: context.weight,
            height: context.height,
            dateOfBirth: context.dateOfBirth,
            gender: context.gender
        )
        let baseBmr = bmr(
            weight: context.weight,
            height: context.height,
            dateOfBirth: context.dateOfBirth,
            gender: context.gender
        )
        let activityCals = max(Int((baseBmr * max(baseActivityMultiplier(activityLevel: context.activityLevel) - 1.0, 0)).rounded()), 0)
        let exerciseCals = max(Int((baseBmr * max(exerciseAdjustment(exerciseFrequency: context.exerciseFrequency), 0)).rounded()), 0)
        // Use remainder as TEF to ensure components sum to displayed TDEE (accounts for rounding)
        let tefCals = max(totalExpenditureKcal - bmrCals - activityCals - exerciseCals, 0)
        return [
            Breakdown(name: String(localized: "Resting Calories"), calories: bmrCals, color: .blue),
            Breakdown(name: String(localized: "Daily Activity"), calories: activityCals, color: .green),
            Breakdown(name: String(localized: "Exercise"), calories: exerciseCals, color: .orange),
            Breakdown(name: String(localized: "Digesting Food"), calories: tefCals, color: .pink)
        ]
    }

    var displayedKcal: Int = 0
    var animateBreakdown: Bool = false
    var hasAnimated: Bool = false
        
    private func ageYears(dateOfBirth: Date) -> Int {
        let years = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 30
        return min(120, max(14, years))
    }

    // `bmrInt`, `tdeeInt` and `breakdownItems` are all read from the view body, so their `Int(_:)`
    // conversions run while drawing — and `Int(_:)` traps on a value that is not finite or that
    // overflows. A one-sided `max(_:_:)` is not enough to prevent that; `Double.clamped(to:
    // whenNotFinite:)` says why. Anything unusable falls back to the bottom of the range, which is
    // where a missing figure already sat.
    private func weightKg(weight: Double) -> Double { weight.clamped(to: 30...500, whenNotFinite: 30) }
    // 100, not 120: the height wheel goes down to 100 cm (`HeightView.swift`), so clamping here
    // any tighter silently substituted someone else's height into their own calorie estimate.
    private func heightCm(height: Double) -> Double { height.clamped(to: 100...260, whenNotFinite: 100) }
    private func mifflinGenderCoefficient(gender: Gender) -> Double { gender.mifflinStJeorCoefficient }
    
    private func bmr(weight: Double, height: Double, dateOfBirth: Date, gender: Gender) -> Double { (10 * weightKg(weight: weight)) + (6.25 * heightCm(height: height)) - (5 * Double(ageYears(dateOfBirth: dateOfBirth))) + mifflinGenderCoefficient(gender: gender) }
    func bmrInt(
        weight: Double,
        height: Double,
        dateOfBirth: Date,
        gender: Gender
    ) -> Int {
        Int(
            bmr(
                weight: weight,
                height: height,
                dateOfBirth: dateOfBirth,
                gender: gender
            ).rounded()
        )
    }

    func baseActivityMultiplier(activityLevel: ActivityLevel) -> Double {
        switch activityLevel {
        case .sedentary: return 1.2
        case .light: return 1.35
        case .moderate: return 1.5
        case .active: return 1.7
        case .veryActive: return 1.9
        }
    }
    func activityDescription(activityLevel: ActivityLevel) -> String {
        switch activityLevel {
        case .sedentary: return String(localized: "Mostly sitting; little movement")
        case .light: return String(localized: "Light movement most of the day")
        case .moderate: return String(localized: "On feet or moving regularly")
        case .active: return String(localized: "Physically active work or lifestyle")
        case .veryActive: return String(localized: "Highly active throughout the day")
        }
    }
    
    func exerciseAdjustment(exerciseFrequency: ExerciseFrequency) -> Double {
        switch exerciseFrequency {
        case .never: return 0.0
        case .oneToTwo: return 0.05
        case .threeToFour: return 0.10
        case .fiveToSix: return 0.15
        case .daily: return 0.20
        }
    }
    
    func exerciseDescription(exerciseFrequency: ExerciseFrequency) -> String {
        switch exerciseFrequency {
        case .never: return String(localized: "No structured exercise")
        case .oneToTwo: return String(localized: "1–2 sessions per week")
        case .threeToFour: return String(localized: "3–4 sessions per week")
        case .fiveToSix: return String(localized: "5–6 sessions per week")
        case .daily: return String(localized: "Exercise most days")
        }
    }
    
    private func tdeeFromContext(_ context: ExpenditureContext) -> Double {
        max(
            1000,
            bmr(
                weight: context.weight,
                height: context.height,
                dateOfBirth: context.dateOfBirth,
                gender: context.gender
            ) * (
                baseActivityMultiplier(activityLevel: context.activityLevel) + exerciseAdjustment(exerciseFrequency: context.exerciseFrequency)
            )
        )
    }
    
    func tdeeInt(context: ExpenditureContext) -> Int {
        Int(
            tdeeFromContext(context).rounded()
        )
    }
    
    struct Breakdown: Identifiable {
        let id = UUID()
        let name: String
        let calories: Int
        let color: Color
    }

    func progress(for item: Breakdown) -> Double {
        guard totalExpenditureKcal > 0 else { return 0 }
        return Double(item.calories) / Double(totalExpenditureKcal)
    }
    
    func estimateExpenditure(delegate: ExpenditureDelegate) {
        // Local-only estimation. No network calls, no alerts.

        let context = ExpenditureContext(
            weight: delegate.weightInKilograms,
            height: delegate.heightInCentimetres,
            dateOfBirth: delegate.dateOfBirth,
            gender: delegate.gender,
            activityLevel: delegate.activityLevel,
            exerciseFrequency: delegate.exerciseFrequency
        )

        totalExpenditureKcal = tdeeInt(context: context)
        guard !hasAnimated else { return }
        hasAnimated = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withReducedMotionAnimation(.easeOut(duration: 1.6)) {
                self.displayedKcal = self.totalExpenditureKcal
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withReducedMotionAnimation(.easeOut(duration: 1.0)) {
                self.animateBreakdown = true
            }
        }

        router.dismissModal()
        canContinue = true
    }

    func onContinuePressed(delegate: ExpenditureDelegate) {

        // The guard comes first: returning after the modal was shown would leave a spinner on
        // screen with nothing left running to dismiss it.
        guard canContinue == true else { return }
        router.showLoadingModal()

        Task {
            defer {
                router.dismissModal()
            }
            
            interactor.trackEvent(event: Event.profileSaveStart)
            do {
                let input: [String: any DMCodableSendable] = [
                    UserModel.CodingKeys.submittedGender.rawValue: delegate.gender.rawValue,
                    UserModel.CodingKeys.submittedDateOfBirth.rawValue: delegate.dateOfBirth,
                    UserModel.CodingKeys.submittedHeightCentimeters.rawValue: delegate.heightInCentimetres,
                    UserModel.CodingKeys.submittedLengthUnitPreference.rawValue: delegate.lengthUnitPreference.rawValue,
                    UserModel.CodingKeys.submittedWeightKilograms.rawValue: delegate.weightInKilograms,
                    UserModel.CodingKeys.submittedWeightUnitPreference.rawValue: delegate.weightUnitPreference.rawValue,
                    UserModel.CodingKeys.submittedDailyActivityLevel.rawValue: delegate.activityLevel.rawValue,
                    UserModel.CodingKeys.submittedExerciseFrequency.rawValue: delegate.exerciseFrequency.rawValue
                    // Cardio fitness is no longer asked (decision 8c), so it is not written: a
                    // profile that already has one keeps it.
                ]
                try await interactor.saveUserCompleteAccountSetup(input: input)
                interactor.trackEvent(event: Event.profileSaveSuccess)
                
                router.dismissModal()

                // Notifications and Apple Health are asked for where they are first used, not here.
                router.showHealthDisclaimerView()

            } catch {
                interactor.trackEvent(event: Event.profileSaveFail(error: error))
                router.showAlert(
                    title: String(localized: "Unable to Save Profile"),
                    subtitle: String(localized: "Please check your internet connection and try again."),
                    buttons: {
                        AnyView(
                            HStack {
                                Button("Cancel", role: .cancel) { }
                                Button("Try Again") {
                                    self.onContinuePressed(delegate: delegate)
                                }
                            }
                        )
                    }
                )
            }
        }
    }
        
    private func defaultDateOfBirth() -> Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    enum Event: LoggableEvent {
        case profileSaveStart
        case profileSaveSuccess
        case profileSaveFail(error: Error)

        var eventName: String {
            switch self {
            case .profileSaveStart: return "Expenditure_SaveProfile_Start"
            case .profileSaveSuccess: return "Expenditure_SaveProfile_Success"
            case .profileSaveFail: return "Expenditure_SaveProfile_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .profileSaveFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .profileSaveFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
