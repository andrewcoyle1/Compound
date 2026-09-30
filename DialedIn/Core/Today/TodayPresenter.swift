//
//  TodayPresenter.swift
//  DialedIn
//

import SwiftUI

/// What to do now: today's workout, today's food, today's weigh-in, and whatever is due this week.
/// Everything here is the user's own; other people are on Social.
@Observable
@MainActor
class TodayPresenter {

    private let interactor: TodayInteractor
    private let router: TodayRouter
    private let reminderOfferFlow: ReminderOfferFlow

    private(set) var nutritionTotals: DailyMacroTarget?
    private(set) var nutritionTarget: DailyMacroTarget?

    /// Held rather than read through, so starting or skipping takes the card away in the same
    /// frame instead of waiting for Firestore.
    private(set) var checkInState: CheckInState = .notDue

    init(interactor: TodayInteractor, router: TodayRouter) {
        self.interactor = interactor
        self.router = router
        self.reminderOfferFlow = ReminderOfferFlow(interactor: interactor, router: router)
    }

    var userImageUrl: String? {
        interactor.userImageUrl
    }

    func onViewAppear(delegate: TodayDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        checkInState = interactor.checkInState
        loadNutrition()
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

    /// Today's day plan in the active program, or nil when there is no program or it schedules
    /// nothing. The card is always shown: without a plan it offers an empty workout instead.
    var todaysWorkoutTemplate: WorkoutTemplateModel? {
        TodaysWorkoutSchedule.item(program: interactor.activeTrainingProgram, sessions: interactor.workoutSessions)?.dayPlan
    }

    var hasActiveProgram: Bool {
        interactor.activeTrainingProgram != nil
    }

    func onChooseProgramPressed() {
        interactor.trackEvent(event: Event.chooseProgramPressed)
        router.showTrainingProgramLibraryView()
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
                        try? self?.interactor.deleteActiveSession()
                        await self?.startBlankWorkout()
                    }
                }
            )
        } else {
            Task { await startBlankWorkout() }
        }
    }

    private func startBlankWorkout() async {
        do {
            try await interactor.startBlankWorkout()
            router.showWorkoutTrackerView()
        } catch {
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
                    try? self?.interactor.deleteDraftMeal()
                    self?.router.showAddMealView(delegate: AddMealDelegate(mealLog: newMeal))
                }
            }
        )
    }

    private func loadNutrition() {
        // Silent: local read; a missing total shows as no data on the card.
        nutritionTotals = try? interactor.getDailyTotals(dayKey: Date().dayKey)
        guard let userId = interactor.userId else { return }
        Task {
            // Silent: background read; the card shows no target until one loads.
            nutritionTarget = try? await interactor.getDailyTarget(for: Date(), userId: userId)
        }
    }

    // MARK: - Weigh-in

    private var weightUnit: WeightUnitPreference {
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
    func onSkipCheckInPressed() {
        guard let weekStart = dueCheckInWeekStart else { return }
        interactor.trackEvent(event: Event.checkInSkipped)
        checkInState = .notDue
        Task {
            do {
                try await interactor.markCheckInSkipped(weekStart: weekStart)
            } catch {
                checkInState = .due(weekStart: weekStart)
                router.showFailure(String(localized: "Unable to Skip Check-In"), error: error)
            }
        }
    }

    // MARK: - Weekly review

    /// The way in to last week's review, on the first day of the week only. Past reviews stay
    /// reachable from Progress.
    var showsWeeklyReviewCard: Bool {
        interactor.currentUser != nil && CircleWeek.isFirstDayOfWeek(.now)
    }

    func onWeeklyReviewPressed() {
        interactor.trackEvent(event: Event.weeklyReviewPressed)
        router.showWeeklyReviewView()
    }
}

extension TodayPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: TodayDelegate)
        case onDisappear(delegate: TodayDelegate)
        case chooseProgramPressed
        case startEmptyWorkoutPressed
        case logMealPressed
        case logWeightPressed
        case checkInStarted
        case checkInSkipped
        case weeklyReviewPressed

        var eventName: String {
            switch self {
            case .onAppear:                 return "TodayView_Appear"
            case .onDisappear:              return "TodayView_Disappear"
            case .chooseProgramPressed:     return "TodayView_ChooseProgram_Press"
            case .startEmptyWorkoutPressed: return "TodayView_StartEmptyWorkout_Press"
            case .logMealPressed:           return "TodayView_LogMeal_Press"
            case .logWeightPressed:         return "TodayView_LogWeight_Press"
            case .checkInStarted:           return "TodayView_CheckIn_Start"
            case .checkInSkipped:           return "TodayView_CheckIn_Skip"
            case .weeklyReviewPressed:      return "TodayView_WeeklyReview_Press"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
