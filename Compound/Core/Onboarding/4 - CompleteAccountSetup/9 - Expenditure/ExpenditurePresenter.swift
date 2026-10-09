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

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    struct ExpenditureContext {
        let weight: Double
        let height: Double
        let dateOfBirth: Date
        let gender: Gender
        let activityLevel: ActivityLevel
    }

    /// Resting, activity and digestion, each rounded so the three add up to the total shown.
    /// Digestion is 10% of the total (Westerterp 2004); activity is what is left above resting.
    /// Training is part of the activity answer, so it has no bar of its own.
    func breakdownItems(context: ExpenditureContext) -> [Breakdown] {
        let estimate = formulaEstimate(context)
        let total = Int(estimate.totalKcal.rounded())
        let resting = min(Int(estimate.restingKcal.rounded()), total)
        let digestion = min(Int(estimate.thermicEffectKcal.rounded()), total - resting)
        let activity = max(total - resting - digestion, 0)
        return [
            Breakdown(name: String(localized: "Resting Calories"), calories: resting, color: .blue),
            Breakdown(name: String(localized: "Daily Activity and Exercise"), calories: activity, color: .green),
            Breakdown(name: String(localized: "Digesting Food"), calories: digestion, color: .pink)
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

    /// The figures this step has collected, in the shape the shared formula takes. Onboarding
    /// always runs Mifflin-St Jeor: no body fat has been logged and no equation chosen yet.
    private func formulaBody(weight: Double, height: Double, dateOfBirth: Date, gender: Gender) -> FormulaExpenditure.Body {
        FormulaExpenditure.Body(
            gender: gender,
            weightKg: weightKg(weight: weight),
            heightCm: heightCm(height: height),
            ageYears: Double(ageYears(dateOfBirth: dateOfBirth)),
            bodyFatPercentage: nil
        )
    }

    /// The same formula `NutritionManager.estimateTDEE` runs once the profile is saved.
    private func formulaEstimate(_ context: ExpenditureContext) -> FormulaExpenditure.Estimate {
        FormulaExpenditure.estimate(
            equation: .mifflinStJeor,
            body: formulaBody(weight: context.weight, height: context.height, dateOfBirth: context.dateOfBirth, gender: context.gender),
            activity: context.activityLevel
        )
    }

    func bmrInt(
        weight: Double,
        height: Double,
        dateOfBirth: Date,
        gender: Gender
    ) -> Int {
        let figures = formulaBody(weight: weight, height: height, dateOfBirth: dateOfBirth, gender: gender)
        return Int(FormulaExpenditure.mifflinStJeor(body: figures).rounded())
    }

    /// The physical activity level for the answer given (`FormulaExpenditure.activityMultiplier`).
    func baseActivityMultiplier(activityLevel: ActivityLevel) -> Double {
        FormulaExpenditure.activityMultiplier(for: activityLevel)
    }

    func activityDescription(activityLevel: ActivityLevel) -> String {
        switch activityLevel {
        case .sedentary: return String(localized: "Mostly sitting; little movement or exercise")
        case .light: return String(localized: "Light movement most of the day, or a few workouts a week")
        case .moderate: return String(localized: "On your feet or moving regularly, with regular workouts")
        case .active: return String(localized: "Physically active work or lifestyle, plus training")
        case .veryActive: return String(localized: "Highly active throughout the day, or hard training most days")
        }
    }

    func tdeeInt(context: ExpenditureContext) -> Int {
        Int(formulaEstimate(context).totalKcal.rounded())
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
            activityLevel: delegate.activityLevel
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
        case onAppear
        case onDisappear
        case profileSaveStart
        case profileSaveSuccess
        case profileSaveFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear: return "ExpenditureView_Appear"
            case .onDisappear: return "ExpenditureView_Disappear"
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
