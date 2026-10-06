//
//  CoreInteractor+Expenditure.swift
//  Compound
//

import Foundation

extension CoreInteractor {

    // MARK: - ExpenditureEngine

    /// One estimate per day from the user's first logged day through today.
    ///
    /// The engine is pure, so everything it needs is gathered here: the three logs, the settings,
    /// the existing formula TDEE as the prior, and today. Recomputed on every read — it is a few
    /// thousand arithmetic operations over a year of data, and the alternative is a stored estimate
    /// that has to be migrated forever.
    var expenditureHistory: [ExpenditureEstimate] {
        ExpenditureEngine().history(
            samples: expenditureSamples,
            priorKcal: estimateTDEE(user: currentUser),
            settings: nutritionStrategySettings,
            today: expenditureToday,
            calendar: .current
        )
    }

    /// Today's estimate — the figure the settings screen shows and the proposal is built on.
    var currentExpenditure: ExpenditureEstimate {
        ExpenditureEngine().current(
            samples: expenditureSamples,
            priorKcal: estimateTDEE(user: currentUser),
            settings: nutritionStrategySettings,
            today: expenditureToday,
            calendar: .current
        )
    }

    /// The day the estimate is for — which during an open logging break is the day the break
    /// began.
    ///
    /// Freezing the estimate there is the honest reading of a break: the history stops where the
    /// data stopped. Letting it run on would show a number sliding towards the prior every day,
    /// which looks like the algorithm learning something when in fact nobody told it anything.
    private var expenditureToday: Date {
        openLoggingBreak?.startDate ?? Date()
    }

    private var expenditureSamples: [DailySample] {
        ExpenditureSampleBuilder.samples(
            mealLogs: userMeals,
            measurements: bodyMeasurements,
            steps: stepsHistory,
            annotations: nutritionDayAnnotations,
            loggingBreak: loggingBreak,
            today: expenditureToday
        )
    }

    // MARK: - TargetProposal

    /// The pending suggestion that the calorie target should move, or nil when there is nothing
    /// worth saying.
    var targetProposal: TargetProposal? {
        // A break is a break. Proposing new targets to somebody who has explicitly stopped
        // logging is the one moment the propose-and-confirm contract turns into nagging.
        guard openLoggingBreak == nil else { return nil }
        return TargetProposal.make(
            estimate: currentExpenditure,
            plan: currentDietPlan,
            goal: currentGoal,
            settings: nutritionStrategySettings,
            dismissedKcal: dismissedTargetProposalKcal
        )
    }

    /// Recomputes the plan at the proposed target and saves it.
    ///
    /// Both figures go in, because they are not the same number: the target carries the goal's
    /// rate and the floor, the expenditure carries neither. The plan keeps the expenditure in
    /// `tdeeEstimate` so a later check-in can tell an estimate that has drifted from adherence
    /// that has.
    func acceptTargetProposal() async throws {
        guard let proposal = targetProposal, let plan = currentDietPlan else { return }
        let updated = nutritionManager.computeDietPlan(
            user: currentUser,
            delegate: DietPlanDelegate(plan: plan),
            mesocycle: activeMesocycle,
            expenditureKcal: proposal.expenditureKcal,
            targetKcal: proposal.proposedTargetKcal
        )
        try await saveDietPlan(updated)
        clearDismissedTargetProposal()
    }

    /// Rebuilds the diet plan for a goal just set or edited, so the goal changes what to eat today
    /// rather than waiting for a check-in. Only the calories move: the plan's diet choices stay.
    ///
    /// `goal` is passed in rather than read from `currentGoal`, which updates when the listener
    /// next emits. Expenditure is the engine's estimate once it has enough data; while it is
    /// provisional, or in Fixed mode, it stays what the plan was built on.
    func applyGoalToDietPlan(_ goal: WeightGoal) async throws {
        guard let plan = currentDietPlan else { return }
        let estimate = currentExpenditure
        let keepsPlanExpenditure = estimate.isProvisional || nutritionStrategySettings.calculationMode == .fixed
        let updated = nutritionManager.computeDietPlan(
            user: currentUser,
            delegate: DietPlanDelegate(plan: plan),
            mesocycle: activeMesocycle,
            expenditureKcal: keepsPlanExpenditure ? plan.tdeeEstimate : estimate.kcal,
            goal: goal
        )
        try await saveDietPlan(updated)
        clearDismissedTargetProposal()
    }

    /// Remembers the figure waved away, so the same card does not come back tomorrow.
    func dismissTargetProposal() {
        guard let proposal = targetProposal else { return }
        UserDefaults.standard.set(proposal.proposedTargetKcal, forKey: dismissedTargetProposalKey)
    }

    private var dismissedTargetProposalKey: String {
        TargetProposal.dismissedDefaultsKey(userId: userId)
    }

    private var dismissedTargetProposalKcal: Double? {
        let key = dismissedTargetProposalKey
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.double(forKey: key)
    }

    private func clearDismissedTargetProposal() {
        UserDefaults.standard.removeObject(forKey: dismissedTargetProposalKey)
    }

    // MARK: - Check-in

    /// Whether the weekly check-in is waiting, and for which week.
    var checkInState: CheckInState {
        CheckInSchedule.state(
            today: Date(),
            settings: nutritionStrategySettings,
            record: checkInRecord,
            break: loggingBreak,
            calendar: .current
        )
    }
}

extension DietPlanDelegate {

    /// The selections a saved plan was built from, so recomputing it changes only the calories.
    ///
    /// `DietPlan` stores them as raw strings; anything unreadable falls back to the same default
    /// the onboarding picker starts on rather than silently changing the user's diet shape.
    init(plan: DietPlan) {
        self.init(
            preferredDiet: PreferredDiet(rawValue: plan.preferredDiet) ?? .balanced,
            calorieFloor: CalorieFloor(rawValue: plan.calorieFloor) ?? .standard,
            calorieDistribution: CalorieDistribution(rawValue: plan.calorieDistribution) ?? .even,
            proteinIntake: ProteinIntake(rawValue: plan.proteinIntake) ?? .moderate,
            isFromSettings: true
        )
    }
}
