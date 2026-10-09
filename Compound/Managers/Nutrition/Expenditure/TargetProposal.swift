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
///
/// The controller is feedforward with a deadband, evaluated at most weekly: the target is the
/// estimate plus the goal rate's daily share of the energy in a kilogram, and it only moves when
/// that differs from the current target by more than the estimate's own uncertainty. There is no
/// separate rate-error correction: the expenditure filter already absorbs a persistent gap between
/// predicted and observed weight change, so a second loop would count it twice — and when the gap
/// is the user eating above target, it would lower a target they are already missing. That case
/// gets an `AdherenceNote` instead. See `MethodInfo.targetProposal`.
struct TargetProposal: Equatable {

    /// Why the target should move, which is what the card says out loud.
    enum Reason: String, Equatable {
        /// The expenditure estimate, or the goal, has moved away from what the plan was built on.
        case expenditureMoved
    }

    let expenditureKcal: Double
    /// Mean of the current plan's seven days.
    let currentTargetKcal: Double
    let proposedTargetKcal: Double
    let weeklyTrendChangeKg: Double?
    let goalWeeklyChangeKg: Double?
    let reason: Reason

    // MARK: Design choices — tune by replay

    /// The smallest move worth interrupting someone for; the deadband is the larger of this and
    /// the estimate's SD.
    static let minimumMeaningfulDeltaKcal: Double = 50
    /// The most one proposal moves the target: 150 kcal, at most once a week.
    static let maximumStepKcal: Double = 150
    /// A proposal waits until the plan is at least this many days old.
    static let minimumDaysBetweenChanges: Int = 7
    /// Mean logged intake more than 10% over the target counts as eating above it.
    static let adherenceMargin: Double = 0.10

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
        dismissedKcal: Double? = nil,
        kcalPerKg: Double = EnergyDensity.conventionalKcalPerKg,
        gender: Gender? = nil,
        calendar: Calendar = .current
    ) -> TargetProposal? {
        guard case .propose(let proposal) = evaluate(
            estimate: estimate, plan: plan, goal: goal, settings: settings,
            kcalPerKg: kcalPerKg, gender: gender, calendar: calendar
        ) else { return nil }
        if let dismissedKcal, abs(proposal.proposedTargetKcal - dismissedKcal) < minimumMeaningfulDeltaKcal { return nil }
        return proposal
    }

    // MARK: - The controller

    enum Outcome: Equatable {
        case none
        case propose(TargetProposal)
        case adherence(AdherenceNote)
    }

    /// Target_raw = T̂ + ρ·r_goal/7, floored by sex; propose only past the deadband, a week after the
    /// last change and once the estimate is calibrated; move at most 150 kcal; and before lowering
    /// a target the user is eating well above, say so instead.
    static func evaluate(
        estimate: ExpenditureEstimate,
        plan: DietPlan?,
        goal: WeightGoal?,
        settings: NutritionStrategySettings,
        kcalPerKg: Double = EnergyDensity.conventionalKcalPerKg,
        gender: Gender? = nil,
        calendar: Calendar = .current
    ) -> Outcome {
        guard let plan, !plan.days.isEmpty,
              !estimate.isProvisional,
              estimate.source == .adaptive,
              settings.calculationMode != .fixed else { return .none }

        let currentTarget = plan.days.map(\.calories).reduce(0, +) / Double(plan.days.count)
        let activeGoal = goal.flatMap { $0.status == .active ? $0 : nil }
        let goalWeekly = activeGoal?.signedWeeklyChangeKg

        // With no active goal the right target is maintenance: spend what you spend.
        let raw = estimate.kcal + EnergyDensity.dailyKcal(forWeeklyChangeKg: goalWeekly ?? 0, kcalPerKg: kcalPerKg)
        let floor = (CalorieFloor(rawValue: plan.calorieFloor) ?? .standard).minimumValue(for: gender)
        let delta = max(raw, floor) - currentTarget

        let deadband = max(minimumMeaningfulDeltaKcal, estimate.sdKcal ?? 0)
        guard abs(delta) > deadband else { return .none }

        // Adherence first: lowering a target the user is already well over would chase their
        // eating rather than their expenditure.
        if delta < 0,
           let intake = estimate.recentIntakeKcal, intake > currentTarget * (1 + adherenceMargin),
           let rate = estimate.weeklyTrendChangeKg, rate > (goalWeekly ?? 0) {
            return .adherence(AdherenceNote(
                targetKcal: currentTarget,
                recentIntakeKcal: intake,
                weeklyTrendChangeKg: rate,
                goalWeeklyChangeKg: goalWeekly
            ))
        }

        let planAgeDays = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: plan.createdAt),
            to: calendar.startOfDay(for: estimate.day)
        ).day ?? 0
        guard planAgeDays >= minimumDaysBetweenChanges else { return .none }

        let step = delta.clamped(to: -maximumStepKcal...maximumStepKcal, whenNotFinite: 0)
        return .propose(TargetProposal(
            expenditureKcal: estimate.kcal,
            currentTargetKcal: currentTarget,
            proposedTargetKcal: (currentTarget + step).rounded(),
            weeklyTrendChangeKg: estimate.weeklyTrendChangeKg,
            goalWeeklyChangeKg: goalWeekly,
            reason: .expenditureMoved
        ))
    }
}

/// The user is eating well above their target and the scale shows it, so the honest message is
/// about the logging, not a lower number. Shown in the weekly check-in instead of a proposal.
struct AdherenceNote: Equatable {
    let targetKcal: Double
    /// Mean of the last week's complete logged days.
    let recentIntakeKcal: Double
    let weeklyTrendChangeKg: Double
    let goalWeeklyChangeKg: Double?

    static func make(
        estimate: ExpenditureEstimate,
        plan: DietPlan?,
        goal: WeightGoal?,
        settings: NutritionStrategySettings,
        kcalPerKg: Double = EnergyDensity.conventionalKcalPerKg,
        gender: Gender? = nil,
        calendar: Calendar = .current
    ) -> AdherenceNote? {
        guard case .adherence(let note) = TargetProposal.evaluate(
            estimate: estimate, plan: plan, goal: goal, settings: settings,
            kcalPerKg: kcalPerKg, gender: gender, calendar: calendar
        ) else { return nil }
        return note
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
