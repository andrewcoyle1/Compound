//
//  TodayPresenter.swift
//  Compound
//

import SwiftUI

/// What to do now: today's workout, today's food, today's weigh-in, and whatever is due this week.
/// Everything here is the user's own; other people are on Social.
@Observable
@MainActor
class TodayPresenter {

    let interactor: TodayInteractor
    let router: TodayRouter
    let defaults: UserDefaults
    private let reminderOfferFlow: ReminderOfferFlow

    /// Read live from the meal log, so a meal logged anywhere shows here as soon as Today is drawn.
    var nutritionTotals: DailyMacroTarget? {
        try? interactor.getDailyTotals(dayKey: Date().dayKey)
    }
    private(set) var nutritionTarget: DailyMacroTarget?

    /// Bumped after a write to `defaults`, which Observation cannot see, so the cards it decides
    /// (getting started, the weekly review) redraw.
    var defaultsRevision = 0

    /// Held rather than read through, so starting or skipping takes the card away in the same
    /// frame instead of waiting for Firestore.
    private(set) var checkInState: CheckInState = .notDue

    init(interactor: TodayInteractor, router: TodayRouter, defaults: UserDefaults = .standard) {
        self.interactor = interactor
        self.router = router
        self.defaults = defaults
        self.reminderOfferFlow = ReminderOfferFlow(interactor: interactor, router: router)
    }

    var userImageUrl: String? {
        interactor.userImageUrl
    }

    func onViewAppear(delegate: TodayDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        checkInState = interactor.checkInState
        loadNutritionTarget()
        // Health only hands over new steps when asked; a connected account is asked on each visit.
        if !interactor.stepsHistory.isEmpty {
            Task { await interactor.syncStepsFromHealthKit(fromScratch: false) }
        }
        reminderOfferFlow.offerStreakReminderIfNeeded()
    }

    func onViewDisappear(delegate: TodayDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onProfilePressed(transitionId: String, namespace: Namespace.ID) {
        router.showProfileViewZoom(transitionId: transitionId, namespace: namespace)
    }

    #if DEV || MOCK
    func onDevSettingsPressed() {
        router.showDevSettingsView()
    }
    #endif

    // MARK: - Workout

    /// Today's day plan in the active mesocycle, or nil when there is no mesocycle or it schedules
    /// nothing. The card is always shown: without a plan it offers an empty workout instead.
    var todaysWorkoutTemplate: WorkoutTemplateModel? {
        MesocycleSchedule.todayItem(run: interactor.activeMesocycleRun, sessions: interactor.workoutSessions)?.dayPlan
    }

    /// Every block of the plan is done; the card offers a repeat instead of a workout.
    var isMacrocycleComplete: Bool {
        interactor.currentMacrocycle?.status == .completed
    }

    var completedMacrocycleName: String {
        interactor.currentMacrocycle?.name ?? ""
    }

    /// `TodayView_RepeatPlan_Press` is the write's Start.
    func onRepeatMacrocyclePressed() {
        interactor.trackEvent(event: Event.repeatMacrocyclePressed)
        Task {
            do {
                try await interactor.repeatCurrentMacrocycle()
                interactor.trackEvent(event: Event.repeatMacrocycleSuccess)
                interactor.playHaptic(option: .success)
            } catch {
                interactor.trackEvent(event: Event.repeatMacrocycleFail(error: error))
                interactor.playHaptic(option: .error)
                router.showAlert(title: String(localized: "Unable to Repeat Macrocycle"), error: error)
            }
        }
    }

    var hasActiveMesocycle: Bool {
        interactor.activeMesocycle != nil
    }

    func onChooseMesocyclePressed() {
        interactor.trackEvent(event: Event.chooseMesocyclePressed)
        router.showMesocycleLibraryView()
    }

    func onStartEmptyWorkoutPressed() {
        interactor.trackEvent(event: Event.startEmptyWorkoutPressed)
        if interactor.activeSession != nil {
            router.showActiveWorkoutAlert(
                onResume: { [weak self] in
                    Task { @MainActor in self?.router.showWorkoutTrackerView() }
                },
                onReplace: { [weak self] in
                    Task { @MainActor in
                        do {
                            try self?.interactor.deleteActiveSession()
                        } catch {
                            self?.interactor.trackEvent(event: Event.deleteActiveSessionFail(error: error))
                        }
                        await self?.startBlankWorkout()
                    }
                }
            )
        } else {
            Task { await startBlankWorkout() }
        }
    }

    private func startBlankWorkout() async {
        interactor.trackEvent(event: Event.startBlankWorkoutStart)
        do {
            try await interactor.startBlankWorkout()
            interactor.trackEvent(event: Event.startBlankWorkoutSuccess)
            router.showWorkoutTrackerView()
        } catch {
            interactor.trackEvent(event: Event.startBlankWorkoutFail(error: error))
            router.showSimpleAlert(title: String(localized: "Could Not Start Workout"), subtitle: String(localized: "Please try again."))
        }
    }

    // MARK: - Nutrition

    func onLogMealPressed() {
        guard let userId = interactor.currentUser?.userId else { return }
        interactor.trackEvent(event: Event.logMealPressed)
        let newMeal = MealLogModel(authorId: userId, dayKey: Date().dayKey, date: Date(), items: [])
        guard let draft = interactor.draftMeal else {
            router.showAddMealView(delegate: AddMealDelegate(mealLog: newMeal))
            return
        }
        router.showDraftMealDialog(
            onContinue: { [weak self] in
                Task { @MainActor in
                    self?.router.showAddMealView(delegate: AddMealDelegate(mealLog: draft))
                }
            },
            onStartNew: { [weak self] in
                Task { @MainActor in
                    do {
                        try self?.interactor.deleteDraftMeal()
                    } catch {
                        self?.interactor.trackEvent(event: Event.deleteDraftMealFail(error: error))
                    }
                    self?.router.showAddMealView(delegate: AddMealDelegate(mealLog: newMeal))
                }
            }
        )
    }

    private func loadNutritionTarget() {
        guard let userId = interactor.userId else { return }
        Task {
            // Silent to the user: background read; the checklist shows no target until one loads.
            do {
                nutritionTarget = try await interactor.getDailyTarget(for: Date(), userId: userId)
            } catch {
                nutritionTarget = nil
                interactor.trackEvent(event: Event.loadNutritionTargetFail(error: error))
            }
        }
    }

    // MARK: - Weigh-in

    var weightUnit: WeightUnitPreference {
        interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
    }

    private var latestWeighIn: BodyMeasurementEntry? {
        interactor.bodyMeasurements
            .filter { $0.deletedAt == nil && $0.weightKg != nil }
            .max { $0.date < $1.date }
    }

    /// "82.5 kg", or nil before the first weigh-in.
    var latestWeightText: String? {
        latestWeighIn?.weightKg.map { Format.weight(kg: $0, unit: weightUnit) }
    }

    var latestWeighInDate: Date? {
        latestWeighIn?.date
    }

    var hasWeighedInToday: Bool {
        latestWeighInDate.map { Calendar.current.isDateInToday($0) } ?? false
    }

    func onLogWeightPressed() {
        interactor.trackEvent(event: Event.logWeightPressed)
        router.showLogWeightView()
    }

    func onWeighInPressed() {
        interactor.trackEvent(event: Event.weighInPressed)
        router.showScaleWeightView(delegate: ScaleWeightDelegate(), themeColor: Color.Metric.scaleWeight)
    }

    // MARK: - Weekly check-in

    /// The week the check-in is for, or nil when none is waiting.
    var dueCheckInWeekStart: Date? {
        guard case .due(let weekStart) = checkInState else { return nil }
        return weekStart
    }

    func onStartCheckInPressed() {
        guard let weekStart = dueCheckInWeekStart else { return }
        interactor.trackEvent(event: Event.checkInStarted)
        router.showCheckInView(delegate: CheckInDelegate(weekStart: weekStart))
    }

    /// Optimistic, and puts the card back if the write does not land: a card that vanished on a
    /// failed write would look exactly like a week that had been dealt with.
    /// `TodayView_CheckIn_Skip` is the write's Start.
    func onSkipCheckInPressed() {
        guard let weekStart = dueCheckInWeekStart else { return }
        interactor.trackEvent(event: Event.checkInSkipped)
        checkInState = .notDue
        Task {
            do {
                try await interactor.markCheckInSkipped(weekStart: weekStart)
                interactor.trackEvent(event: Event.skipCheckInSuccess)
            } catch {
                interactor.trackEvent(event: Event.skipCheckInFail(error: error))
                checkInState = .due(weekStart: weekStart)
                router.showFailure(String(localized: "Unable to Skip Check-In"), error: error)
            }
        }
    }
}

extension TodayPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: TodayDelegate)
        case onDisappear(delegate: TodayDelegate)
        case chooseMesocyclePressed
        case repeatMacrocyclePressed
        case startEmptyWorkoutPressed
        case logMealPressed
        case logWeightPressed
        case weighInPressed
        case checkInStarted
        case checkInSkipped
        case weeklyReviewPressed
        case repeatMacrocycleSuccess
        case repeatMacrocycleFail(error: Error)
        case startBlankWorkoutStart
        case startBlankWorkoutSuccess
        case startBlankWorkoutFail(error: Error)
        case deleteActiveSessionFail(error: Error)
        case deleteDraftMealFail(error: Error)
        case loadNutritionTargetFail(error: Error)
        case skipCheckInSuccess
        case skipCheckInFail(error: Error)
        case checklistItemPressed(kind: TodayChecklist.Kind)
        case dayComplete(itemCount: Int)
        case stepGoalChanged(goal: Int)
        case stepGoalSaveFail(error: Error)
        case starterStepPressed(step: TodayStarter.Step)
        case starterDismissed(remaining: Int)
        case connectHealthFail(error: Error)
        case proteinGapLogMealPressed
        case socialPulsePressed

        var eventName: String {
            switch self {
            case .onAppear:                 return "TodayView_Appear"
            case .onDisappear:              return "TodayView_Disappear"
            case .chooseMesocyclePressed:     return "TodayView_ChooseProgram_Press"
            case .repeatMacrocyclePressed:        return "TodayView_RepeatPlan_Press"
            case .startEmptyWorkoutPressed: return "TodayView_StartEmptyWorkout_Press"
            case .logMealPressed:           return "TodayView_LogMeal_Press"
            case .logWeightPressed:         return "TodayView_LogWeight_Press"
            case .weighInPressed:           return "TodayView_WeighIn_Press"
            case .checkInStarted:           return "TodayView_CheckIn_Start"
            case .checkInSkipped:           return "TodayView_CheckIn_Skip"
            case .weeklyReviewPressed:      return "TodayView_WeeklyReview_Press"
            case .repeatMacrocycleSuccess:  return "TodayView_RepeatPlan_Success"
            case .repeatMacrocycleFail:     return "TodayView_RepeatPlan_Fail"
            case .startBlankWorkoutStart:   return "TodayView_StartBlankWorkout_Start"
            case .startBlankWorkoutSuccess: return "TodayView_StartBlankWorkout_Success"
            case .startBlankWorkoutFail:    return "TodayView_StartBlankWorkout_Fail"
            case .deleteActiveSessionFail:  return "TodayView_DeleteActiveSession_Fail"
            case .deleteDraftMealFail:      return "TodayView_DeleteDraftMeal_Fail"
            case .loadNutritionTargetFail:  return "TodayView_LoadNutritionTarget_Fail"
            case .skipCheckInSuccess:       return "TodayView_CheckIn_Skip_Success"
            case .skipCheckInFail:          return "TodayView_CheckIn_Skip_Fail"
            case .checklistItemPressed:     return "TodayView_ChecklistItem_Press"
            case .dayComplete:              return "TodayView_DayComplete"
            case .stepGoalChanged:          return "TodayView_StepGoal_Start"
            case .stepGoalSaveFail:         return "TodayView_StepGoal_Fail"
            case .starterStepPressed:       return "TodayView_StarterStep_Press"
            case .starterDismissed:         return "TodayView_Starter_Dismiss"
            case .connectHealthFail:        return "TodayView_ConnectHealth_Fail"
            case .proteinGapLogMealPressed: return "TodayView_ProteinGap_LogMeal_Press"
            case .socialPulsePressed:       return "TodayView_SocialPulse_Press"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .repeatMacrocycleFail(let error), .startBlankWorkoutFail(let error), .deleteActiveSessionFail(let error),
                 .deleteDraftMealFail(let error), .loadNutritionTargetFail(let error),
                 .skipCheckInFail(let error), .stepGoalSaveFail(let error), .connectHealthFail(let error):
                return error.eventParameters
            case .checklistItemPressed(let kind):
                return ["item": kind.rawValue]
            case .dayComplete(let itemCount):
                return ["item_count": itemCount]
            case .stepGoalChanged(let goal):
                return ["goal": goal]
            case .starterStepPressed(let step):
                return ["step": step.rawValue]
            case .starterDismissed(let remaining):
                return ["remaining": remaining]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .repeatMacrocycleFail, .startBlankWorkoutFail, .skipCheckInFail, .stepGoalSaveFail:
                return .severe
            case .deleteActiveSessionFail, .deleteDraftMealFail, .loadNutritionTargetFail, .connectHealthFail:
                return .warning
            default:
                return .analytic
            }
        }
    }
}
