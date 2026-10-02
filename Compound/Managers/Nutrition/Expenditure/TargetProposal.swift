//
//  TargetProposal.swift
//  Compound
//

import Foundation

/// A suggestion that the calorie target should move, for the user to accept or wave away.
///
/// The estimate never silently rewrites a `DietPlan`. Someone who has been told 2,400 kcal for a
/// month and finds 2,150 there one morning has no way to tell a working algorithm from a bug, so
/// the engine proposes and the user confirms.
struct TargetProposal: Equatable {

    /// Why the target should move, which is what the card says out loud.
    enum Reason: String, Equatable {
        /// Expenditure itself has drifted away from what the plan was built on.
        case expenditureMoved
        /// Expenditure looks right, but the observed rate of change is off the goal rate.
        case rateOffTarget
    }

    let expenditureKcal: Double
    /// Mean of the current plan's seven days.
    let currentTargetKcal: Double
    let proposedTargetKcal: Double
    let weeklyTrendChangeKg: Double?
    let goalWeeklyChangeKg: Double?
    let reason: Reason

    /// The smallest move worth interrupting someone for.
    static let minimumMeaningfulDeltaKcal: Double = 50
    /// The most the predictive correction may add or take away in a day.
    static let maximumCorrectionKcal: Double = 200
    /// Where the dismissed figure is remembered, so a waved-away card stays away.
    static let dismissedDefaultsKeyPrefix = "dismissedTargetProposalKcal"

    /// Scoped per account: two people sharing a device — or one person switching accounts — must
    /// not inherit each other's dismissal and lose a card they were never shown. A missing user id
    /// falls back to the bare prefix, which is the pre-sign-in case where there is no plan to
    /// propose against anyway.
    static func dismissedDefaultsKey(userId: String?) -> String {
        guard let userId, !userId.isEmpty else { return dismissedDefaultsKeyPrefix }
        return "\(dismissedDefaultsKeyPrefix).\(userId)"
    }

    /// The whole propose-or-stay-quiet decision, as a pure function of what it reads.
    ///
    /// `dismissedKcal` is the figure last dismissed. The same proposal does not come back; one
    /// that has moved by a meaningful amount does, because by then it is new information.
    static func make(
        estimate: ExpenditureEstimate,
        plan: DietPlan?,
        goal: WeightGoal?,
        settings: NutritionStrategySettings,
        dismissedKcal: Double? = nil
    ) -> TargetProposal? {
        guard let plan, !plan.days.isEmpty,
              !estimate.isProvisional,
              settings.calculationMode != .fixed else { return nil }

        let currentTarget = plan.days.map(\.calories).reduce(0, +) / Double(plan.days.count)
        let activeGoal = goal.flatMap { $0.status == .active ? $0 : nil }
        let goalWeekly = activeGoal?.signedWeeklyChangeKg

        // With no active goal the right target is maintenance: spend what you spend.
        let base = estimate.kcal + (goalWeekly ?? 0) * ExpenditureEngine.Constants.kcalPerKg / 7
        let correction = self.correction(
            goalWeeklyChangeKg: goalWeekly,
            weeklyTrendChangeKg: estimate.weeklyTrendChangeKg,
            settings: settings
        )

        let floor = (CalorieFloor(rawValue: plan.calorieFloor) ?? .standard).minimumValue
        let proposed = max(base + correction, floor).rounded()

        guard abs(proposed - currentTarget) >= minimumMeaningfulDeltaKcal else { return nil }
        if let dismissedKcal, abs(proposed - dismissedKcal) < minimumMeaningfulDeltaKcal { return nil }

        // The correction earned the card whenever the move without it would have been too small
        // to show — that is the case the rate, not the expenditure, is driving.
        let withoutCorrection = max(base, floor).rounded()
        let rateDriven = correction != 0
            && abs(withoutCorrection - currentTarget) < minimumMeaningfulDeltaKcal

        return TargetProposal(
            expenditureKcal: estimate.kcal,
            currentTargetKcal: currentTarget,
            proposedTargetKcal: proposed,
            weeklyTrendChangeKg: estimate.weeklyTrendChangeKg,
            goalWeeklyChangeKg: goalWeekly,
            reason: rateDriven ? .rateOffTarget : .expenditureMoved
        )
    }

    /// Nudges the target when the scale is not moving at the goal's rate even though expenditure
    /// looks right. Capped hard: a correction big enough to matter on its own would be the
    /// algorithm arguing with the goal rather than serving it.
    private static func correction(
        goalWeeklyChangeKg: Double?,
        weeklyTrendChangeKg: Double?,
        settings: NutritionStrategySettings
    ) -> Double {
        guard settings.predictiveGoalAdjustments,
              let goalWeekly = goalWeeklyChangeKg,
              let trendWeekly = weeklyTrendChangeKg else { return 0 }
        let raw = (goalWeekly - trendWeekly) * ExpenditureEngine.Constants.kcalPerKg / 7
        return raw.clamped(to: -maximumCorrectionKcal...maximumCorrectionKcal, whenNotFinite: 0)
    }
}

extension WeightGoal {

    /// `weeklyChangeKg` with the direction of the goal put back on it.
    ///
    /// The stored figure is a magnitude — the onboarding pickers only ever offer a rate, never a
    /// sign — and the direction lives in the two weights. A losing goal spends more than it eats,
    /// so its weekly change is negative, which is the sign every calorie sum here expects.
    var signedWeeklyChangeKg: Double {
        let magnitude = abs(weeklyChangeKg)
        if targetWeightKg < startingWeightKg { return -magnitude }
        if targetWeightKg > startingWeightKg { return magnitude }
        return 0
    }
}
