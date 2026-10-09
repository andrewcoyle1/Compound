//
//  NutritionManager.swift
//  Compound
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

extension CalorieFloor {
    /// The floor for someone of this sex: 1,200 kcal for women, 1,500 for men, 1,350 when not
    /// given (`NutritionTargets.calorieFloor(for:)`).
    func minimumValue(for gender: Gender?) -> Double {
        switch self {
        case .standard: return NutritionTargets.calorieFloor(for: gender)
        }
    }

    /// The floor when sex is not known. Prefer `minimumValue(for:)` wherever the user is at hand.
    var minimumValue: Double {
        minimumValue(for: nil)
    }
}

@Observable
@MainActor
class NutritionManager {

    private let dietPlanSyncEngine: DocumentSyncEngine<DietPlan>

    var currentDietPlan: DietPlan? {
        dietPlanSyncEngine.currentDocument
    }

    init(
        dietPlanSyncEngine: DocumentSyncEngine<DietPlan>
    ) {
        self.dietPlanSyncEngine = dietPlanSyncEngine
    }

    // MARK: - Public API

    func signIn(dietPlanId id: String) async throws {
        try await dietPlanSyncEngine.startListening(documentId: id)
    }

    func signOut() {
        dietPlanSyncEngine.stopListening()
    }

    func saveDietPlan(_ plan: DietPlan) async throws {
        try await dietPlanSyncEngine.saveDocument(plan)
    }
    
    func deleteDietPlan() async throws {
        try await dietPlanSyncEngine.deleteDocument()
    }

    /// Get daily macro target for a specific date from the current diet plan
    func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget? {
        guard let plan = currentDietPlan else {
            return nil
        }

        // Calculate day of week (Monday = 0, Sunday = 6)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // Sunday = 1
        let dayIndex = (weekday + 5) % 7 // Convert to Monday = 0

        // Return the corresponding day's target from the 7-day plan
        guard dayIndex < plan.days.count else {
            return nil
        }

        return plan.days[dayIndex]
    }

    // MARK: - Core logic

    /// What to eat to move at an active goal's weekly pace: expenditure plus the pace's daily share
    /// of the energy in a kilogram of weight change (`EnergyDensity`). Maintenance with no goal, or
    /// one that is not active. The plan used to be built at expenditure whatever the goal, so a
    /// goal to lose 0.5 kg a week set no deficit.
    ///
    /// A deficit is capped at a quarter of expenditure (`NutritionTargets.maximumDeficitShare`), so
    /// the fastest rate on a small expenditure cannot ask for a crash diet; a surplus is not capped.
    static func goalTarget(expenditureKcal: Double, goal: WeightGoal?) -> Double {
        guard let goal, goal.status == .active else { return expenditureKcal }
        let change = EnergyDensity.dailyKcal(forWeeklyChangeKg: goal.signedWeeklyChangeKg)
        return expenditureKcal + max(change, -NutritionTargets.maximumDeficitShare * expenditureKcal)
    }

    /// `expenditureKcal` is what the body spends; `targetKcal` is what the plan asks the user to
    /// eat. They are two different numbers and the plan records both.
    ///
    /// Nil for both keeps the behaviour every existing caller already has: one formula figure
    /// serving as expenditure and as target at once. `expenditureKcal` alone replaces the formula
    /// outright rather than being blended with it — `ExpenditureEngine` has already blended,
    /// against a month of logs the formula cannot see.
    ///
    /// They are separate because a target carries the goal's rate and a floor, and expenditure
    /// carries neither. Folding the target into `tdeeEstimate` would leave the plan unable to say
    /// what expenditure it was built on, which is the one thing the next check-in needs to know to
    /// tell a drifting estimate from a drifting adherence.
    func computeDietPlan(
        user: UserModel?,
        delegate: DietPlanDelegate,
        mesocycle: Mesocycle? = nil,
        expenditureKcal: Double? = nil,
        targetKcal: Double? = nil,
        goal: WeightGoal? = nil
    ) -> DietPlan {
        let now = Date()
        let userId = user?.userId
        let tdee = expenditureKcal ?? estimateTDEE(user: user)
        let minimumCalories = delegate.calorieFloor.minimumValue(for: user?.submittedGender)
        // The floor applies to the target whichever way it arrived: an engine that has watched
        // someone eat 900 kcal a day for a month must not be allowed to write that down.
        let targetCalories = max(targetKcal ?? Self.goalTarget(expenditureKcal: tdee, goal: goal), minimumCalories)

        let referenceWeight = NutritionTargets.referenceWeightKg(
            weightKg: Self.clampedWeightKilograms(user?.submittedWeightKilograms),
            heightCm: user?.submittedHeightCentimeters,
            goalWeightKg: goal?.status == .active ? goal?.targetWeightKg : nil
        )
        let proteinGrams = NutritionTargets.proteinGrams(
            intake: delegate.proteinIntake,
            referenceWeightKg: referenceWeight,
            ageYears: user?.submittedDateOfBirth.map { calculateAge(from: $0) }
        )

        // Training context from the user's active mesocycle: a day plan with at least one exercise
        // counts as a training day. The mesocycle is a queue, not a calendar, so this says how many
        // high days a varied week gets, not which weekdays they fall on.
        let trainingDaysPerWeek = mesocycle.map(CalorieDistribution.trainingDays(in:)) ?? 0

        let dailyCalories = NutritionTargets.dailyCalories(
            target: targetCalories,
            floor: minimumCalories,
            distribution: delegate.calorieDistribution,
            trainingDaysPerWeek: trainingDaysPerWeek
        )

        let dailyMacros = dailyCalories.map { calories in
            NutritionTargets.macros(
                calories: calories,
                proteinGrams: proteinGrams,
                diet: delegate.preferredDiet,
                referenceWeightKg: referenceWeight
            )
        }

        let trainingTypeDescription = mesocycle?.name ?? trainingFocusDescription(
            exerciseFrequency: user?.submittedExerciseFrequency
        )

        // The id has to be the user id, not a fresh UUID. `DietPlan.id` is `planId`, and
        // `FirebaseRemoteDocumentService.saveDocument` writes to `document(model.id)`, while
        // `CoreInteractor.logIn` listens on `diet_plans/<uid>`. A UUID here meant every plan was
        // written to a document nothing was listening to, so `currentDietPlan` stayed nil and the
        // nutrition targets never appeared. There is one plan per user, so the uid is also the
        // right identity for it.
        //
        // Falling back to a UUID keeps a plan computed before sign-in addressable; it still will
        // not be listened to, which is what the onboarding order already assumes.
        return DietPlan(
            planId: userId ?? UUID().uuidString,
            userId: userId,
            createdAt: now,
            tdeeEstimate: round(tdee),
            preferredDiet: delegate.preferredDiet.rawValue,
            calorieFloor: delegate.calorieFloor.rawValue,
            trainingType: trainingTypeDescription,
            calorieDistribution: delegate.calorieDistribution.rawValue,
            proteinIntake: delegate.proteinIntake.rawValue,
            days: dailyMacros
        )
    }

    private func trainingFocusDescription(exerciseFrequency: ExerciseFrequency?) -> String {
        switch exerciseFrequency ?? .threeToFour {
        case .never: return "none"
        case .oneToTwo: return "light"
        case .threeToFour: return "moderate"
        case .fiveToSix: return "frequent"
        case .daily: return "daily"
        }
    }

    // MARK: - Profile figures

    // Weight and height arrive as plain `Double`s off a Firestore document, so a corrupt or
    // half-written profile can carry a NaN or an infinity. From `computeDietPlan` those flow
    // straight into the protein grams and macro splits, which `DietPlanView` prints through
    // `Int(_:)` — and `Int(_:)` traps on anything not finite. A one-sided `max(value, floor)`
    // catches neither; `Double.clamped(to:whenNotFinite:)` says why. A figure that is not usable
    // falls back to the same default a missing one already used.

    private static func clampedWeightKilograms(_ weight: Double?) -> Double {
        (weight ?? 70).clamped(to: 30...500, whenNotFinite: 70)
    }

    private static func clampedHeightCentimeters(_ height: Double?) -> Double {
        (height ?? 175).clamped(to: 120...260, whenNotFinite: 175)
    }

    // MARK: - Estimation

    /// The formula estimate of daily expenditure (`FormulaExpenditure`): the resting rate from
    /// `equation`, multiplied by the PAL for the user's activity answer. A missing weight or height
    /// reads as 70 kg or 175 cm, a missing age as 30, and a missing sex as the midpoint of the two.
    func estimateTDEE(
        user: UserModel?,
        equation: BMREquation = .mifflinStJeor,
        bodyFatPercentage: Double? = nil
    ) -> Double {
        formulaEstimate(user: user, equation: equation, bodyFatPercentage: bodyFatPercentage).totalKcal
    }

    /// The estimate with its parts: resting, activity and digestion.
    func formulaEstimate(
        user: UserModel?,
        equation: BMREquation = .mifflinStJeor,
        bodyFatPercentage: Double? = nil
    ) -> FormulaExpenditure.Estimate {
        FormulaExpenditure.estimate(
            equation: equation,
            body: FormulaExpenditure.Body(
                // The midpoint rather than a man's figure when sex is not given: guessing male
                // biased every such estimate upward.
                gender: user?.submittedGender ?? .preferNotToSay,
                weightKg: Self.clampedWeightKilograms(user?.submittedWeightKilograms),
                heightCm: Self.clampedHeightCentimeters(user?.submittedHeightCentimeters),
                ageYears: Double(calculateAge(from: user?.submittedDateOfBirth)),
                bodyFatPercentage: bodyFatPercentage
            ),
            activity: user?.submittedDailyActivityLevel ?? .moderate
        )
    }

    private func calculateAge(from dateOfBirth: Date?) -> Int {
        guard let dob = dateOfBirth else { return 30 }
        let years = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 30
        return max(14, years)
    }
}

extension CoreInteractor {
    // MARK: NutritionManager

    var currentDietPlan: DietPlan? {
        nutritionManager.currentDietPlan
    }

    func computeDietPlan(user: UserModel?, delegate: DietPlanDelegate) -> DietPlan {
        nutritionManager.computeDietPlan(user: user, delegate: delegate, mesocycle: activeMesocycle, goal: currentGoal)
    }

    /// The same plan built on a supplied expenditure and target rather than the formula estimate.
    func computeDietPlan(
        user: UserModel?,
        delegate: DietPlanDelegate,
        expenditureKcal: Double?,
        targetKcal: Double? = nil
    ) -> DietPlan {
        nutritionManager.computeDietPlan(
            user: user,
            delegate: delegate,
            mesocycle: activeMesocycle,
            expenditureKcal: expenditureKcal,
            targetKcal: targetKcal,
            goal: currentGoal
        )
    }

    func saveDietPlan(_ plan: DietPlan) async throws {
        try await nutritionManager.saveDietPlan(plan)
    }

    func deleteDietPlan() async throws {
        try await nutritionManager.deleteDietPlan()
    }
    
    // Get daily macro target for a specific date from the current diet plan
    func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget? {
        try await nutritionManager.getDailyTarget(for: date, userId: userId)
    }

    // Estimation
    func estimateTDEE(user: UserModel?) -> Double {
        formulaEstimate(user: user).totalKcal
    }

    /// The formula estimate with its parts, on the equation the Expenditure settings resolve to.
    func formulaEstimate(user: UserModel?) -> FormulaExpenditure.Estimate {
        let bodyFatPercentage = latestBodyFatPercentage
        return nutritionManager.formulaEstimate(
            user: user,
            equation: nutritionStrategySettings.resolvedBMREquation(bodyFatPercentage: bodyFatPercentage),
            bodyFatPercentage: bodyFatPercentage
        )
    }

    /// The resting rate the formula estimate starts from, for the below-resting warning.
    func estimateRestingKcal(user: UserModel?) -> Double {
        formulaEstimate(user: user).restingKcal
    }

    /// Cunningham needs fat-free mass, so it needs the most recent weigh-in that recorded a body
    /// fat percentage. Nil for everyone who has never logged one.
    private var latestBodyFatPercentage: Double? {
        let entries = bodyMeasurements.filter { $0.bodyFatPercentage != nil && $0.deletedAt == nil }
        return entries.max(by: { $0.date < $1.date })?.bodyFatPercentage
    }

}
