//
//  TodayPresenter+Checklist.swift
//  Compound
//
//  The day's checklist, the getting-started card, the evening protein reminder, friends who
//  trained and the weekly review card. Everything here is derived from the managers on read, so
//  logging a meal or a weigh-in elsewhere shows up as soon as Today is next drawn.
//

import SwiftUI

extension TodayPresenter {

    // MARK: - Checklist

    var checklist: TodayChecklist {
        TodayChecklist.build(
            training: trainingStatus,
            nutrition: TodayChecklist.Nutrition(
                calories: nutritionTotals?.calories ?? 0,
                proteinGrams: nutritionTotals?.proteinGrams ?? 0,
                calorieTarget: nutritionTarget?.calories,
                proteinTarget: nutritionTarget?.proteinGrams,
                mealsLoggedToday: interactor.userMeals.filter { $0.dayKey == Date().dayKey }.count
            ),
            weighIn: weighInStatus,
            steps: TodayChecklist.Steps(
                today: stepsToday,
                goal: stepGoal,
                hasStepData: !interactor.stepsHistory.isEmpty
            ),
            weightUnit: weightUnit
        )
    }

    /// Today's own finished workout, the newest if there are several.
    var sessionFinishedToday: WorkoutSessionModel? {
        interactor.workoutSessions
            .filter { session in
                guard let ended = session.endedAt else { return false }
                return session.authorId == interactor.userId && !session.isRestDay && session.deletedAt == nil
                    && Calendar.current.isDateInToday(ended)
            }
            .max { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
    }

    private var trainingStatus: TodayChecklist.Training {
        if let session = sessionFinishedToday { return .done(name: session.name) }
        guard let template = todaysWorkoutTemplate else { return .nothingPlanned }
        return template.exercises.isEmpty ? .restDay : .planned(name: template.name)
    }

    private var weighInStatus: TodayChecklist.WeighIn {
        let trend = TodayChecklist.weightTrend(interactor.bodyMeasurements)
        return TodayChecklist.WeighIn(
            latestKg: trend.latest?.weightKg,
            isToday: trend.latest.map { Calendar.current.isDateInToday($0.date) } ?? false,
            weekChangeKg: trend.weekChangeKg,
            goalWeeklyChangeKg: goalWeeklyChangeKg
        )
    }

    /// The active goal's weekly change, negative when losing; `nil` when maintaining or no goal.
    private var goalWeeklyChangeKg: Double? {
        guard let goal = interactor.currentGoal, goal.status == .active else { return nil }
        if goal.isLosing { return -abs(goal.weeklyChangeKg) }
        if goal.isGaining { return abs(goal.weeklyChangeKg) }
        return nil
    }

    var stepsToday: Int {
        interactor.stepsHistory
            .filter { $0.deletedAt == nil && Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.number }
    }

    func onChecklistItemPressed(_ kind: TodayChecklist.Kind) {
        interactor.trackEvent(event: Event.checklistItemPressed(kind: kind))
        switch kind {
        case .training: onTrainingItemPressed()
        case .nutrition: onLogMealPressed()
        case .weighIn:
            if hasWeighedInToday { onWeighInPressed() } else { onLogWeightPressed() }
        case .steps: router.showStepsView(delegate: StepsDelegate(), themeColor: Color.Metric.steps)
        }
    }

    /// The finished workout opens its summary; otherwise today's plan opens as it does from the
    /// workout card, and without a plan an empty workout starts.
    private func onTrainingItemPressed() {
        if let session = sessionFinishedToday {
            router.showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate(workoutSession: session))
        } else if let template = todaysWorkoutTemplate, !template.exercises.isEmpty {
            router.showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate(
                workoutTemplate: template,
                mesocycleId: interactor.activeMesocycle?.id,
                onStartWorkoutPressed: { [weak self] in
                    Task { @MainActor in self?.router.showWorkoutTrackerView() }
                },
                microcycleIndex: MesocycleSchedule.todayItem(
                    run: interactor.activeMesocycleRun,
                    sessions: interactor.workoutSessions
                )?.cycleIndex
            ))
        } else {
            onStartEmptyWorkoutPressed()
        }
    }

    /// The user's own goal, else the age-adjusted default (`TodayChecklist.ageAdjustedStepGoal`).
    var stepGoal: Int {
        interactor.analyticsSettings.dailyStepGoal
            ?? TodayChecklist.ageAdjustedStepGoal(dateOfBirth: interactor.currentUser?.submittedDateOfBirth)
    }

    static let stepGoalChoices = [5_000, 6_000, 8_000, 10_000, 12_000, 15_000]

    func onStepGoalSelected(_ goal: Int) {
        var settings = interactor.analyticsSettings
        // Compared with the stored choice, not the shown goal: picking the default an age-adjusted
        // goal replaced must still save it.
        guard settings.dailyStepGoal != goal else { return }
        settings.dailyStepGoal = goal
        interactor.trackEvent(event: Event.stepGoalChanged(goal: goal))
        Task {
            do {
                try await interactor.saveAnalyticsSettings(settings)
                interactor.playHaptic(option: .success)
            } catch {
                interactor.trackEvent(event: Event.stepGoalSaveFail(error: error))
                router.showFailure(String(localized: "Unable to Save Step Goal"), error: error)
            }
        }
    }

    /// Celebrated once a day, the first time Today sees every item done.
    func onChecklistCompletionChanged(isComplete: Bool) {
        guard isComplete, let userId = interactor.userId else { return }
        let key = "today_day_complete_\(userId)"
        let today = Date().dayKey
        guard defaults.string(forKey: key) != today else { return }
        defaults.set(today, forKey: key)
        interactor.trackEvent(event: Event.dayComplete(itemCount: checklist.items.count))
        interactor.playHaptic(option: .success)
    }

    // MARK: - Getting started

    var starter: TodayStarter {
        var done = Set<TodayStarter.Step>()
        let ownSessions = interactor.workoutSessions.filter { $0.authorId == interactor.userId }
        if ownSessions.contains(where: { $0.endedAt != nil && !$0.isRestDay && $0.deletedAt == nil }) { done.insert(.firstWorkout) }
        if !interactor.userMeals.isEmpty { done.insert(.firstMeal) }
        if latestWeightText != nil { done.insert(.firstWeighIn) }
        if !interactor.stepsHistory.isEmpty { done.insert(.appleHealth) }
        if interactor.stravaIsConnected { done.insert(.strava) }
        return TodayStarter(done: done)
    }

    var showsStarter: Bool {
        guard let userId = interactor.userId else { return false }
        _ = defaultsRevision
        return !defaults.bool(forKey: Self.starterDismissedKey(userId)) && !starter.isFinished
    }

    static func starterDismissedKey(_ userId: String) -> String { "today_starter_dismissed_\(userId)" }

    func onStarterStepPressed(_ step: TodayStarter.Step) {
        interactor.trackEvent(event: Event.starterStepPressed(step: step))
        switch step {
        case .firstWorkout: onTrainingItemPressed()
        case .firstMeal: onLogMealPressed()
        case .firstWeighIn: onLogWeightPressed()
        case .appleHealth: connectAppleHealth()
        case .strava: router.showIntegrationsView(delegate: IntegrationsDelegate())
        }
    }

    func onStarterDismissed() {
        guard let userId = interactor.userId else { return }
        interactor.trackEvent(event: Event.starterDismissed(remaining: starter.remaining.count))
        defaults.set(true, forKey: Self.starterDismissedKey(userId))
        defaultsRevision += 1
    }

    private func connectAppleHealth() {
        Task {
            if interactor.canRequestHealthDataAuthorisation() {
                do {
                    try await interactor.requestHealthKitAuthorisation(for: .steps)
                } catch {
                    interactor.trackEvent(event: Event.connectHealthFail(error: error))
                    router.showSimpleAlert(
                        title: String(localized: "Unable to Access Apple Health"),
                        subtitle: String(localized: "Allow step access in the Apple Health app to sync your steps.")
                    )
                    return
                }
            }
            await interactor.syncStepsFromHealthKit(fromScratch: true)
        }
    }

    // MARK: - Evening protein

    /// From 5pm, protein still short of the target by at least 20 g: the gap and a way to close it.
    var proteinGapText: String? {
        guard Calendar.current.component(.hour, from: .now) >= 17,
              let target = nutritionTarget?.proteinGrams, target > 0 else { return nil }
        let gap = target - (nutritionTotals?.proteinGrams ?? 0)
        guard gap >= 20 else { return nil }
        return String(localized: "\(Format.grams(gap)) protein to go today")
    }

    func onProteinGapLogMealPressed() {
        interactor.trackEvent(event: Event.proteinGapLogMealPressed)
        onLogMealPressed()
    }

    // MARK: - Friends

    var socialPulseText: String? {
        TodaySocialPulse.text(names: TodaySocialPulse.namesTrainedToday(
            sessions: interactor.followingWorkoutSessions,
            following: interactor.followingUsers
        ))
    }

    func onSocialPulsePressed() {
        interactor.trackEvent(event: Event.socialPulsePressed)
        DeepLink.tab(.social).post()
    }

    // MARK: - Weekly review

    /// Last week's review, from the start of the week until it is opened. Only when last week has
    /// something to review.
    var showsWeeklyReviewCard: Bool {
        guard let userId = interactor.userId,
              let thisWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now),
              let lastWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start) else { return false }
        _ = defaultsRevision
        guard defaults.string(forKey: Self.weeklyReviewOpenedKey(userId)) != thisWeek.start.dayKey else { return false }
        let lastWeek = DateInterval(start: lastWeekStart, end: thisWeek.start)
        let trained = interactor.workoutSessions.contains { $0.authorId == userId && $0.endedAt != nil && lastWeek.contains($0.dateCreated) }
        let ate = interactor.userMeals.contains { lastWeek.contains($0.date) }
        return trained || ate
    }

    static func weeklyReviewOpenedKey(_ userId: String) -> String { "today_weekly_review_opened_\(userId)" }

    func onWeeklyReviewPressed() {
        interactor.trackEvent(event: Event.weeklyReviewPressed)
        if let userId = interactor.userId, let thisWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now) {
            defaults.set(thisWeek.start.dayKey, forKey: Self.weeklyReviewOpenedKey(userId))
            defaultsRevision += 1
        }
        router.showWeeklyReviewView()
    }
}

// MARK: - Coach

extension TodayPresenter {
    func onAskCoachPressed() {
        router.showCoach(context: .today)
    }

    /// From the evening protein reminder: what to eat to close it.
    func onProteinGapAskCoachPressed() {
        router.showCoach(context: CoachContext(kind: .nutritionDay, date: Date().dayKey, title: String(localized: "Today's Food")))
    }
}
