//
//  NutritionManager.swift
//  Compound
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

extension CalorieFloor {
    var minimumValue: Double {
        switch self {
        case .standard: return 1200
        case .low: return 800
        }
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
        targetKcal: Double? = nil
    ) -> DietPlan {
        let now = Date()
        let userId = user?.userId
        let tdee = expenditureKcal ?? estimateTDEE(user: user)
        let minimumCalories = delegate.calorieFloor.minimumValue
        // The floor applies to the target whichever way it arrived: an engine that has watched
        // someone eat 900 kcal a day for a month must not be allowed to write that down.
        let targetCalories = max(targetKcal ?? tdee, minimumCalories)

        let proteinGrams = calculateProteinGrams(user: user, proteinIntake: delegate.proteinIntake)
        let macroPercentages = calculateMacroPercentages(
            preferredDiet: delegate.preferredDiet,
            targetCalories: targetCalories,
            proteinGrams: proteinGrams
        )

        // Derive training context from the user's active training mesocycle.
        // A day plan with at least one exercise counts as a training day.
        let trainingDaysPerWeek = mesocycle?.workoutTemplates.filter { !$0.exercises.isEmpty }.count ?? 0
        let hasTraining = trainingDaysPerWeek > 0

        let dailyCalories = calculateDailyCalories(
            targetCalories: targetCalories,
            minimumCalories: minimumCalories,
            calorieDistribution: delegate.calorieDistribution,
            hasTraining: hasTraining
        )

        let dailyMacros = computeDailyMacros(
            dailyCalories: dailyCalories,
            proteinGrams: proteinGrams,
            macroPercentages: macroPercentages
        )

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

    private func calculateProteinGrams(user: UserModel?, proteinIntake: ProteinIntake) -> Double {
        let userKg = Self.clampedWeightKilograms(user?.submittedWeightKilograms)
        let proteinPerKg: Double
        switch proteinIntake {
        case .low: proteinPerKg = 1.6
        case .moderate: proteinPerKg = 2.0
        case .high: proteinPerKg = 2.2
        case .veryHigh: proteinPerKg = 2.6
        }
        return proteinPerKg * userKg
    }

    private func calculateMacroPercentages(
        preferredDiet: PreferredDiet,
        targetCalories: Double,
        proteinGrams: Double
    ) -> (fatPercent: Double, carbPercent: Double) {
        let proteinCalories = proteinGrams * 4
        let fatPercent: Double
        let carbPercent: Double

        switch preferredDiet {
        case .balanced:
            fatPercent = 0.30
            carbPercent = 1.0 - fatPercent - (proteinCalories / max(targetCalories, 1))
        case .lowFat:
            fatPercent = 0.20
            carbPercent = 1.0 - fatPercent - (proteinCalories / max(targetCalories, 1))
        case .lowCarb:
            carbPercent = 0.20
            fatPercent = 1.0 - carbPercent - (proteinCalories / max(targetCalories, 1))
        case .keto:
            carbPercent = 0.05
            fatPercent = 1.0 - carbPercent - (proteinCalories / max(targetCalories, 1))
        }

        return (fatPercent, carbPercent)
    }

    /// Generates 7 daily calorie targets (Mon–Sun).
    /// When `calorieDistribution == .varied` and the user has training days,
    /// higher calories are assigned to training days (days 1, 3, 5) and lower to rest days.
    private func calculateDailyCalories(
        targetCalories: Double,
        minimumCalories: Double,
        calorieDistribution: CalorieDistribution,
        hasTraining: Bool
    ) -> [Double] {
        guard calorieDistribution == .varied && hasTraining else {
            return Array(repeating: max(targetCalories, minimumCalories), count: 7)
        }

        let high = targetCalories * 1.10
        let low = targetCalories * 0.925
        return [high, low, high, low, high, low, low].map { max($0, minimumCalories) }
    }

    /// Splits each day's non-protein calories between fat and carbs.
    ///
    /// `calculateMacroPercentages` returns shares of the day's *total* calories, so applying
    /// `fatPercent` straight to the post-protein remainder understated fat — balanced came out at
    /// 23% of the day rather than 30% — and `carbPercent` was not read at all, which left keto at
    /// roughly 150g of carbs, about 21% of calories and ketogenic by no definition.
    ///
    /// Protein is a fixed number of grams and the day's calories vary, so the two shares cannot
    /// both be applied to the total and still sum to it. Splitting the remainder by the fat:carb
    /// ratio honours the diet's intent exactly on a day at the target, keeps every day summing to
    /// its own calories, and degrades sensibly on the high and low days of a varied week.
    private func computeDailyMacros(
        dailyCalories: [Double],
        proteinGrams: Double,
        macroPercentages: (fatPercent: Double, carbPercent: Double)
    ) -> [DailyMacroTarget] {
        let proteinCalories = proteinGrams * 4

        // A protein target large enough to swallow the day can drive either share negative.
        // Clamping first keeps the ratio inside 0...1; an even split is the neutral fallback when
        // protein has claimed everything and there is nothing left to divide anyway.
        let fatShare = max(macroPercentages.fatPercent, 0)
        let carbShare = max(macroPercentages.carbPercent, 0)
        let totalShare = fatShare + carbShare
        let fatRatio = totalShare > 0 ? fatShare / totalShare : 0.5

        return dailyCalories.map { cals in
            let remainingCalories = max(cals - proteinCalories, 0)
            let fatCalories = max(remainingCalories * fatRatio, 0)
            let carbCalories = max(remainingCalories - fatCalories, 0)
            let fatGrams = fatCalories / 9
            let carbGrams = carbCalories / 4
            return DailyMacroTarget(
                calories: round(cals),
                proteinGrams: round(proteinGrams),
                carbGrams: round(carbGrams),
                fatGrams: round(fatGrams)
            )
        }
    }

    // MARK: - Estimation
    func estimateTDEE(
        user: UserModel?,
        equation: BMREquation = .mifflinStJeor,
        bodyFatPercentage: Double? = nil
    ) -> Double {
        let gender = user?.submittedGender ?? .male
        let weightKg = Self.clampedWeightKilograms(user?.submittedWeightKilograms)
        let heightCm = Self.clampedHeightCentimeters(user?.submittedHeightCentimeters)
        let ageYears = calculateAge(from: user?.submittedDateOfBirth)

        let bmr = basalMetabolicRate(
            equation: equation,
            body: BodyComposition(
                gender: gender,
                weightKg: weightKg,
                heightCm: heightCm,
                age: Double(ageYears),
                bodyFatPercentage: bodyFatPercentage
            )
        )

        let activityMultiplier = calculateActivityMultiplier(
            dailyActivity: user?.submittedDailyActivityLevel ?? .moderate,
            exerciseFrequency: user?.submittedExerciseFrequency ?? .threeToFour
        )

        let tdee = bmr * activityMultiplier
        return max(1000, tdee)
    }

    /// The equation the user picked on the Expenditure settings screen. Katch-McArdle works from
    /// lean mass, so without a logged body fat percentage it has nothing to work from and falls
    /// back to Mifflin-St Jeor rather than inventing a figure.
    /// The body inputs every BMR equation draws on, grouped so the equation helpers stay within
    /// the parameter-count limit.
    private struct BodyComposition {
        let gender: Gender
        let weightKg: Double
        let heightCm: Double
        let age: Double
        let bodyFatPercentage: Double?
    }

    private func basalMetabolicRate(equation: BMREquation, body: BodyComposition) -> Double {
        switch equation {
        case .mifflinStJeor:
            return mifflinStJeorBMR(body: body)
        case .harrisBenedict:
            let male = 88.362 + (13.397 * body.weightKg) + (4.799 * body.heightCm) - (5.677 * body.age)
            let female = 447.593 + (9.247 * body.weightKg) + (3.098 * body.heightCm) - (4.330 * body.age)
            switch body.gender {
            case .male: return male
            case .female: return female
            // Harris-Benedict has two whole equations rather than one sex term, so the midpoint
            // here is the average of the two, as Mifflin-St Jeor's -78 is of +5 and -161.
            case .preferNotToSay: return (male + female) / 2
            }
        case .katchMcArdle:
            guard let bodyFat = body.bodyFatPercentage, bodyFat > 0, bodyFat < 100 else {
                return mifflinStJeorBMR(body: body)
            }
            let leanMassKg = body.weightKg * (1 - (bodyFat / 100))
            return 370 + (21.6 * leanMassKg)
        }
    }

    private func mifflinStJeorBMR(body: BodyComposition) -> Double {
        (10 * body.weightKg) + (6.25 * body.heightCm) - (5 * body.age) + body.gender.mifflinStJeorCoefficient
    }

    private func calculateAge(from dateOfBirth: Date?) -> Int {
        guard let dob = dateOfBirth else { return 30 }
        let years = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 30
        return max(14, years)
    }

    private func calculateActivityMultiplier(
        dailyActivity: ActivityLevel,
        exerciseFrequency: ExerciseFrequency
    ) -> Double {
        let baseMultiplier: Double
        switch dailyActivity {
        case .sedentary: baseMultiplier = 1.2
        case .light: baseMultiplier = 1.35
        case .moderate: baseMultiplier = 1.5
        case .active: baseMultiplier = 1.7
        case .veryActive: baseMultiplier = 1.9
        }

        let exerciseAdj: Double
        switch exerciseFrequency {
        case .never: exerciseAdj = 0.0
        case .oneToTwo: exerciseAdj = 0.05
        case .threeToFour: exerciseAdj = 0.10
        case .fiveToSix: exerciseAdj = 0.15
        case .daily: exerciseAdj = 0.20
        }

        return baseMultiplier + exerciseAdj
    }
}

extension CoreInteractor {
    // MARK: NutritionManager

    var currentDietPlan: DietPlan? {
        nutritionManager.currentDietPlan
    }

    func computeDietPlan(user: UserModel?, delegate: DietPlanDelegate) -> DietPlan {
        nutritionManager.computeDietPlan(user: user, delegate: delegate, mesocycle: activeMesocycle)
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
            targetKcal: targetKcal
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
        let bodyFatPercentage = latestBodyFatPercentage
        return nutritionManager.estimateTDEE(
            user: user,
            equation: nutritionStrategySettings.resolvedBMREquation(bodyFatPercentage: bodyFatPercentage),
            bodyFatPercentage: bodyFatPercentage
        )
    }

    /// Katch-McArdle needs lean mass, so it needs the most recent weigh-in that recorded a body
    /// fat percentage. Nil for everyone who has never logged one.
    private var latestBodyFatPercentage: Double? {
        let entries = bodyMeasurements.filter { $0.bodyFatPercentage != nil && $0.deletedAt == nil }
        return entries.max(by: { $0.date < $1.date })?.bodyFatPercentage
    }

}
