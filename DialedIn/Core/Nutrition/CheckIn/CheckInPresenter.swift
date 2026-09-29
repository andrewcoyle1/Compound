//
//  CheckInPresenter.swift
//  DialedIn
//

import SwiftUI

/// The weekly check-in: one presenter driving an ordered list of steps.
///
/// The steps are computed once, at the start, and then do not change. A list that grew a step
/// halfway through — because a weigh-in landed, or a break was opened — would move the finish
/// line under someone already walking towards it, and the whole point of the flow is that it is
/// short and it ends.
@Observable
@MainActor
class CheckInPresenter {

    private let interactor: CheckInInteractor
    private let router: CheckInRouter
    private let calendar: Calendar

    /// How stale a weigh-in may be before the check-in asks for a new one.
    static let weighInRecencyDays = 3
    /// A day whose intake is below this share of expenditure is the one a fast check-in asks about.
    static let suspiciousIntakeFraction = 0.5

    private(set) var steps: [CheckInStep] = []
    private(set) var stepIndex: Int = 0
    private(set) var isSaving: Bool = false
    private(set) var isCompleted: Bool = false

    /// The seven days under review, oldest first.
    private(set) var weekDays: [CheckInDayRow] = []
    /// The rows the partial-logging step shows, with their toggles.
    var partialRows: [CheckInDayRow] = []
    /// The rows the fasting step shows, with their toggles.
    var fastingRows: [CheckInDayRow] = []

    // The weigh-in step's input, bound straight to the shared `WeightPickerInput`.
    var unit: UnitOfWeight = .kilograms
    var selectedKilograms: Int = 70
    var selectedPounds: Int = 154

    private var weekStart: Date = Date()
    private var hasStarted = false

    var currentStep: CheckInStep? {
        guard stepIndex >= 0, stepIndex < steps.count else { return nil }
        return steps[stepIndex]
    }

    var isOnLastStep: Bool {
        stepIndex >= steps.count - 1
    }

    init(interactor: CheckInInteractor, router: CheckInRouter, calendar: Calendar = .current) {
        self.interactor = interactor
        self.router = router
        self.calendar = calendar
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: CheckInDelegate) {
        guard !hasStarted else { return }
        hasStarted = true
        weekStart = delegate.weekStart
        buildWeek()
        buildSteps()
        loadWeightInput()
        interactor.trackScreenEvent(event: Event.onAppear(weekStart: weekStart, steps: steps))
        if let currentStep {
            interactor.trackEvent(event: Event.stepShown(step: currentStep))
        }
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear(step: currentStep, completed: isCompleted))
    }

    func onDismissPressed() {
        interactor.trackEvent(event: Event.dismissed(step: currentStep))
        router.dismissScreen()
    }

    // MARK: - Building the flow

    /// The seven days ending yesterday.
    ///
    /// Not the calendar week the check-in belongs to: today is half-lived and reviewing it would
    /// mark every Monday's lunch as a missed dinner. Seven finished days is what the engine reads
    /// and what the user can actually answer questions about.
    private func buildWeek() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))
        guard let yesterday else { return }
        weekDays = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: yesterday) else { return nil }
            let dayKey = date.dayKey
            // Silent: local read for the week summary; a missing day counts as unlogged.
            let meals = (try? interactor.getMeals(for: dayKey)) ?? []
            let annotation = interactor.nutritionDayAnnotation(dayKey: dayKey)
            return CheckInDayRow(
                dayKey: dayKey,
                date: date,
                intakeKcal: meals.isEmpty ? nil : meals.map(\.totalCalories).reduce(0, +),
                isOn: annotation?.isPartiallyLogged ?? false
            )
        }
    }

    /// Each step is in only when its setting is on and it has something to ask.
    ///
    /// The second half of that is what keeps the flow honest: a fasting step with no unlogged days
    /// is a screen that exists to be tapped past, and after three weeks of them nobody reads any
    /// of the steps any more.
    private func buildSteps() {
        let settings = interactor.nutritionStrategySettings
        let fast = settings.fastCheckIn
        partialRows = partialLoggingRows(fast: fast)
        fastingRows = fastingDayRows()

        var steps: [CheckInStep] = []
        if !fast {
            steps.append(.introduction)
        }
        if settings.partialLoggingEnabled, weekDays.contains(where: \.isLogged), !partialRows.isEmpty {
            steps.append(.partialLogging)
        }
        if settings.weighInEnabled, !hasRecentWeighIn {
            steps.append(.weighIn)
        }
        if settings.fastingEnabled, !fastingRows.isEmpty {
            steps.append(.fasting)
        }
        if settings.loggingBreakEnabled {
            steps.append(.loggingBreak)
        }
        steps.append(.programUpdate)
        self.steps = steps
    }

    /// Every day of the week, or — in a fast check-in — only the ones that look wrong.
    private func partialLoggingRows(fast: Bool) -> [CheckInDayRow] {
        guard fast else { return weekDays }
        let threshold = interactor.currentExpenditure.kcal * Self.suspiciousIntakeFraction
        return weekDays.filter { row in
            guard let intake = row.intakeKcal else { return false }
            return intake < threshold
        }
    }

    /// The days with no meal logs at all, pre-set from any fasting annotation they already carry.
    private func fastingDayRows() -> [CheckInDayRow] {
        weekDays
            .filter { !$0.isLogged }
            .map { row in
                var row = row
                row.isOn = interactor.nutritionDayAnnotation(dayKey: row.dayKey)?.isFastingDay ?? false
                return row
            }
    }

    private var hasRecentWeighIn: Bool {
        let cutoff = calendar.date(
            byAdding: .day,
            value: -Self.weighInRecencyDays,
            to: calendar.startOfDay(for: Date())
        )
        guard let cutoff else { return false }
        return interactor.bodyMeasurements.contains { entry in
            entry.deletedAt == nil && entry.weightKg != nil && entry.date >= cutoff
        }
    }

    private func loadWeightInput() {
        guard let user = interactor.currentUser else { return }
        if let preference = user.submittedWeightUnitPreference {
            unit = preference == .kilograms ? .kilograms : .pounds
        }
        let latest = interactor.bodyMeasurements
            .filter { $0.deletedAt == nil && $0.weightKg != nil }
            .max { $0.date < $1.date }?
            .weightKg
        if let weightKg = latest ?? user.submittedWeightKilograms {
            selectedKilograms = Int(weightKg)
            selectedPounds = Int(UnitConversion.kgToLbs(weightKg))
        }
    }

    // MARK: - Step content

    var loggedDayCount: Int {
        weekDays.filter(\.isLogged).count
    }

    var weighInCount: Int {
        guard let first = weekDays.first?.date, let last = weekDays.last?.date else { return 0 }
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) ?? last
        return interactor.bodyMeasurements.filter { entry in
            entry.deletedAt == nil && entry.weightKg != nil && entry.date >= first && entry.date < end
        }.count
    }

    /// "down 0.4 kg" — the trend's movement, or nil while the estimate is still provisional.
    var trendChangeDescription: String? {
        guard let weekly = interactor.currentExpenditure.weeklyTrendChangeKg else { return nil }
        let rounded = (weekly * 10).rounded() / 10
        if rounded == 0 { return "holding steady" }
        return String(localized: "\(rounded < 0 ? String(localized: "down") : String(localized: "up")) \(String(describing: abs(rounded))) kg")
    }

    var expenditureDescription: String {
        String(localized: "\(String(describing: Int(interactor.currentExpenditure.kcal))) kcal a day")
    }

    var proposal: TargetProposal? {
        interactor.targetProposal
    }

    /// "2,180 kcal a day, up from 2,050", the same sentence the overview card uses.
    var proposalSummary: String? {
        guard let proposal else { return nil }
        let direction = proposal.proposedTargetKcal > proposal.currentTargetKcal ? String(localized: "up from") : String(localized: "down from")
        return String(localized: "\(String(describing: Int(proposal.proposedTargetKcal))) kcal a day, \(direction) \(String(describing: Int(proposal.currentTargetKcal))).")
    }

    var hasOpenLoggingBreak: Bool {
        interactor.openLoggingBreak != nil
    }

    private var weightKg: Double {
        switch unit {
        case .kilograms: return Double(selectedKilograms)
        case .pounds:    return UnitConversion.lbsToKg(Double(selectedPounds))
        }
    }

    // MARK: - Actions

    /// Continue from whichever step is showing, saving whatever that step collected first.
    func onContinuePressed() {
        guard !isSaving, let step = currentStep else { return }
        interactor.trackEvent(event: Event.stepCompleted(step: step, outcome: "continue"))
        switch step {
        case .partialLogging:
            save(annotations: partialAnnotations())
        case .fasting:
            save(annotations: fastingAnnotations())
        case .introduction, .weighIn, .loggingBreak, .programUpdate:
            advance()
        }
    }

    func onLogWeightPressed() {
        guard !isSaving, let user = interactor.currentUser else { return }
        interactor.trackEvent(event: Event.stepCompleted(step: .weighIn, outcome: "logged"))
        isSaving = true
        Task {
            do {
                let entry = BodyMeasurementEntry(authorId: user.userId, weightKg: weightKg, date: Date())
                try await interactor.saveBodyMeasurement(bodyMeasurement: entry)
                try await interactor.updateWeight(
                    userId: user.userId,
                    weight: weightKg,
                    weightUnitPreference: unit == .kilograms ? .kilograms : .pounds
                )
                interactor.playHaptic(option: .success)
                isSaving = false
                advance()
            } catch {
                isSaving = false
                router.showAlert(error: error)
            }
        }
    }

    func onSkipWeighInPressed() {
        guard !isSaving else { return }
        interactor.trackEvent(event: Event.stepCompleted(step: .weighIn, outcome: "skipped"))
        advance()
    }

    func onStartLoggingBreakPressed() {
        guard !isSaving else { return }
        interactor.trackEvent(event: Event.stepCompleted(step: .loggingBreak, outcome: "started"))
        perform { try await self.interactor.startLoggingBreak() }
    }

    func onEndLoggingBreakPressed() {
        guard !isSaving else { return }
        interactor.trackEvent(event: Event.stepCompleted(step: .loggingBreak, outcome: "ended"))
        perform { try await self.interactor.endLoggingBreak() }
    }

    /// Accepting the proposal is the last thing the flow does, so it completes the check-in too.
    func onAcceptProposalPressed() {
        guard !isSaving, let accepted = proposal else { return }
        interactor.trackEvent(event: Event.proposalAccepted(proposal: accepted))
        perform { try await self.interactor.acceptTargetProposal() }
    }

    func onDonePressed() {
        guard !isSaving else { return }
        interactor.trackEvent(event: Event.stepCompleted(step: .programUpdate, outcome: "done"))
        perform { }
    }

    // MARK: - Saving

    private func partialAnnotations() -> [NutritionDayAnnotation] {
        partialRows.map { row in
            annotation(for: row.dayKey, isPartiallyLogged: row.isOn, isFastingDay: nil)
        }
    }

    private func fastingAnnotations() -> [NutritionDayAnnotation] {
        fastingRows.map { row in
            annotation(for: row.dayKey, isPartiallyLogged: nil, isFastingDay: row.isOn)
        }
    }

    /// One day's annotation with only the flag this step owns changed.
    ///
    /// The partial-logging step must not wipe a fasting flag set on the same day a minute earlier,
    /// and vice versa, so each step writes its own field over whatever is already stored.
    private func annotation(
        for dayKey: String,
        isPartiallyLogged: Bool?,
        isFastingDay: Bool?
    ) -> NutritionDayAnnotation {
        let existing = interactor.nutritionDayAnnotation(dayKey: dayKey)
        return NutritionDayAnnotation(
            dayKey: dayKey,
            authorId: existing?.authorId ?? interactor.currentUser?.userId ?? "",
            isPartiallyLogged: isPartiallyLogged ?? existing?.isPartiallyLogged ?? false,
            isFastingDay: isFastingDay ?? existing?.isFastingDay ?? false
        )
    }

    private func save(annotations: [NutritionDayAnnotation]) {
        perform { try await self.interactor.saveNutritionDayAnnotations(annotations) }
    }

    /// Runs the step's work and moves on, or stays put with an alert.
    ///
    /// Staying put matters: a failed save that advanced anyway would leave the user looking at the
    /// next question believing the last answer was recorded.
    private func perform(_ work: @escaping () async throws -> Void) {
        isSaving = true
        Task {
            do {
                try await work()
                isSaving = false
                advance()
            } catch {
                isSaving = false
                router.showAlert(error: error)
            }
        }
    }

    /// Moves to the next step, or finishes.
    private func advance() {
        guard stepIndex < steps.count - 1 else {
            complete()
            return
        }
        stepIndex += 1
        if let currentStep {
            interactor.trackEvent(event: Event.stepShown(step: currentStep))
        }
    }

    /// Records the week as done and closes the sheet.
    ///
    /// Only reached from the last step. Dismissing part-way leaves the record alone, which is what
    /// keeps the card on the overview for the rest of the week — the annotations already saved
    /// stay saved either way.
    private func complete() {
        isCompleted = true
        interactor.trackEvent(event: Event.completed(weekStart: weekStart))
        let weekStart = weekStart
        Task {
            do {
                try await interactor.markCheckInCompleted(weekStart: weekStart)
                router.dismissScreen()
            } catch {
                isCompleted = false
                interactor.trackEvent(event: Event.completeFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Complete Check-In"), subtitle: String(localized: "Please try again."))
            }
        }
    }
}
