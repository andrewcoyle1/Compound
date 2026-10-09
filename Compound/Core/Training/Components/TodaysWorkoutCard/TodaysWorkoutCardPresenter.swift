//
//  TodaysWorkoutCardPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

import SwiftUI

@Observable
@MainActor
class TodaysWorkoutCardPresenter {
    private let interactor: TodaysWorkoutCardInteractor
    private let router: TodaysWorkoutCardRouter

    /// Today's first few exercises with the tracker's own prefill, e.g. "Bench Press · 102.5 kg × 8".
    /// Filled by `loadTargets()`; empty until then, or when there is nothing to start.
    private(set) var targets: [String] = []

    init(interactor: TodaysWorkoutCardInteractor, router: TodaysWorkoutCardRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onTodaysWorkoutPressed() {
        guard let template = todaysWorkoutTemplate, !isTodayRestDay else { return }
        let mesocycleId = interactor.activeMesocycle?.id
        router.showWorkoutTemplateDetailView(
            delegate: WorkoutTemplateDetailDelegate(
                workoutTemplate: template,
                mesocycleId: mesocycleId,
                onStartWorkoutPressed: { [weak self] in
                    Task { @MainActor in
                        self?.router.showWorkoutTrackerView()
                    }
                },
                isDeloadCycle: isTodayDeload,
                microcycleIndex: todaysScheduledItem?.cycleIndex
            )
        )
    }

    /// Today's workout is the next open one, so it can be started straight from the card.
    var canStart: Bool {
        startableSlot != nil
    }

    /// On a rest day, the workout after it, for a user who would rather train.
    var nextWorkoutName: String? {
        isTodayRestDay ? startableSlot?.dayPlan.name : nil
    }

    /// Start on the card: straight into the tracker, skipping the preview the card itself opens.
    func onStartPressed() {
        guard let slot = startableSlot else { return }
        interactor.trackEvent(event: Event.startPressed)
        let mesocycleId = interactor.activeMesocycle?.id
        let isDeload = isTodayDeload
        let microcycle = slot.cycleIndex + 1
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
                        await self?.start(slot.dayPlan, in: mesocycleId, microcycleIndex: microcycle, isDeloadCycle: isDeload)
                    }
                }
            )
        } else {
            Task { await start(slot.dayPlan, in: mesocycleId, microcycleIndex: microcycle, isDeloadCycle: isDeload) }
        }
    }

    /// `microcycleIndex` is the slot's 1-based microcycle, whose targets the session takes.
    private func start(_ template: WorkoutTemplateModel, in mesocycleId: String?, microcycleIndex: Int, isDeloadCycle: Bool) async {
        interactor.trackEvent(event: Event.startStart)
        do {
            try await interactor.startWorkout(
                for: template,
                in: mesocycleId,
                microcycleIndex: microcycleIndex,
                isDeloadCycle: isDeloadCycle
            )
            interactor.trackEvent(event: Event.startSuccess)
            router.showWorkoutTrackerView()
        } catch {
            interactor.trackEvent(event: Event.startFail(error: error))
            router.showSimpleAlert(title: String(localized: "Could Not Start Workout"), subtitle: String(localized: "Please try again."))
        }
    }

    /// Whether today's workout falls in the mesocycle's deload microcycle.
    var isTodayDeload: Bool {
        guard let slot = startableSlot, let run = interactor.activeMesocycleRun else { return false }
        return MesocycleSchedule.isDeload(cycleIndex: slot.cycleIndex + 1, of: run.mesocycle)
    }
    
    var todaysWorkoutTemplate: WorkoutTemplateModel? {
        todaysScheduledItem?.dayPlan
    }

    var isTodayRestDay: Bool {
        todaysWorkoutTemplate?.exercises.isEmpty == true
    }

    var isTodayCompleted: Bool {
        todaysScheduledItem?.completedSessionId != nil
    }

    /// Only today's own workout can be skipped from the card, not a rest day or one already done.
    var canSkip: Bool {
        todaysOpenSlot != nil
    }

    func onSkipPressed() {
        guard let slot = todaysOpenSlot else { return }
        interactor.trackEvent(event: Event.skipPressed)
        router.showAlert(
            title: String(localized: "Skip \(slot.dayPlan.name)?"),
            subtitle: String(localized: "It will count as done for this microcycle, and the next workout moves up to today."),
            buttons: {
                AnyView(
                    Group {
                        Button("Skip", role: .destructive) {
                            Task { await self.skip(slot) }
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    private func skip(_ slot: MesocycleSchedule.Slot) async {
        interactor.trackEvent(event: Event.skipStart)
        do {
            try await interactor.skipScheduledWorkout(slot)
            interactor.trackEvent(event: Event.skipSuccess)
            interactor.playHaptic(option: .success)
        } catch {
            interactor.trackEvent(event: Event.skipFail(error: error))
            interactor.playHaptic(option: .error)
            router.showAlert(title: String(localized: "Unable to Skip Workout"), error: error)
        }
    }

    /// Today's workout when it is the next open slot: not a rest day and not already done.
    private var todaysOpenSlot: MesocycleSchedule.Slot? {
        guard let item = todaysScheduledItem, !item.isCompleted, !isTodayRestDay,
              let run = interactor.activeMesocycleRun,
              let next = MesocycleSchedule.progress(of: run, sessions: interactor.workoutSessions).next,
              next.dayPlan.id == item.dayPlan.id else { return nil }
        return next
    }

    /// What Start begins: today's workout, or on a rest day the next one. Training then removes
    /// the day's rest, and the schedule shows it skipped.
    private var startableSlot: MesocycleSchedule.Slot? {
        guard isTodayRestDay else { return todaysOpenSlot }
        guard let run = interactor.activeMesocycleRun else { return nil }
        return MesocycleSchedule.progress(of: run, sessions: interactor.workoutSessions).next
    }

    // MARK: - Before the workout

    /// Builds the session Start would begin — the same prefill, and the deload cut in a deload
    /// week — and reads each exercise's first working set, so the card promises exactly what the
    /// tracker will show.
    func loadTargets() async {
        guard let slot = todaysOpenSlot else {
            targets = []
            return
        }
        do {
            var session = try await interactor.plannedSession(
                for: slot.dayPlan,
                in: interactor.activeMesocycle?.id,
                microcycleIndex: slot.cycleIndex + 1
            )
            if isTodayDeload { session.applyDeload { interactor.deloadRounding(for: $0) } }
            targets = session.exercises.prefix(4).map { exercise in
                let unit = interactor.getPreference(templateId: exercise.templateId)
                guard let detail = Self.targetDetail(exercise.workingSets.first, mode: exercise.trackingMode, unit: unit) else {
                    return exercise.name
                }
                return "\(exercise.name) · \(detail)"
            }
        } catch {
            // The card works without targets; they preview the workout, they are not the workout.
            targets = []
            interactor.trackEvent(event: Event.loadTargetsFail(error: error))
        }
    }

    /// One set's target in the exercise's own units, or nil when the prefill left it empty.
    static func targetDetail(_ set: WorkoutSetModel?, mode: TrackingMode, unit: ExerciseUnitPreference) -> String? {
        guard let set else { return nil }
        switch mode {
        case .weightReps:
            let weight = set.weightKg.flatMap { $0 > 0 ? Format.weight(kg: $0, unit: unit.weightUnit) : nil }
            switch (weight, set.reps) {
            case let (weight?, reps?): return "\(weight) × \(reps)"
            case let (nil, reps?): return Format.reps(reps)
            case let (weight?, nil): return weight
            case (nil, nil): return nil
            }
        case .repsOnly:
            return set.reps.map { Format.reps($0) }
        case .timeOnly:
            return set.durationSec.map { Format.duration(TimeInterval($0)) }
        case .distanceTime:
            return set.distanceMeters.flatMap { $0 > 0 ? Format.distance(meters: $0, exerciseUnit: unit.distanceUnit) : nil }
        }
    }

    /// "Week 3 of 5 · Day 2", or nil when today's workout is not the block's next.
    var mesocyclePositionText: String? {
        guard let slot = todaysOpenSlot, let run = interactor.activeMesocycleRun else { return nil }
        let weeks = max(run.mesocycle.numMicrocycles, 1)
        return String(localized: "Week \(slot.cycleIndex + 1) of \(weeks) · Day \(slot.position + 1)")
    }

    /// Minutes per working set, rest included, for a workout never done before.
    static let minutesPerWorkingSet = 2.5

    /// The median active time of the last five times this workout was done; with none, its
    /// working sets at `minutesPerWorkingSet` each.
    static func estimatedDuration(of template: WorkoutTemplateModel, history: [WorkoutSessionModel]) -> TimeInterval {
        let durations = history
            .filter { $0.workoutTemplateId == template.id && $0.deletedAt == nil && !$0.isRestDay }
            .sorted { $0.dateCreated > $1.dateCreated }
            .prefix(5)
            .compactMap(\.activeDuration)
            .filter { $0 > 0 }
            .sorted()
        if !durations.isEmpty { return durations[durations.count / 2] }
        let sets = template.exercises.reduce(0) { $0 + max($1.setTargets.count, 1) }
        return Double(sets) * minutesPerWorkingSet * 60
    }

    /// "~55 min", to the nearest five minutes.
    var estimatedDurationText: String? {
        guard let template = todaysOpenSlot?.dayPlan else { return nil }
        let seconds = Self.estimatedDuration(of: template, history: interactor.workoutSessions)
        guard seconds > 0 else { return nil }
        let minutes = max(5, Int((seconds / 300).rounded()) * 5)
        return String(localized: "~\(minutes) min")
    }

    /// The line under today's workout name: where it sits in the block and how long it takes.
    var startSubtitle: String? {
        let parts = [mesocyclePositionText, estimatedDurationText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - After the workout

    /// The session that completed today's workout, once it has synced.
    var completedSession: WorkoutSessionModel? {
        guard !isTodayRestDay, let id = todaysScheduledItem?.completedSessionId else { return nil }
        return interactor.workoutSessions.first { $0.id == id }
    }

    struct SessionSummary: Equatable {
        /// "52:10 · 18 sets · 12,400 kg"
        let figures: String
        /// "2 PRs · Bench Press 100 kg × 5", nil without a record.
        let records: String?
    }

    /// What today's session came to. Sets count a left/right pair once, and volume is in the
    /// user's body-weight unit, as the session's own screen shows them.
    var completedSummary: SessionSummary? {
        guard let session = completedSession else { return nil }
        let sets = session.exercises.reduce(0) { $0 + $1.loggedSetCount }
        let volumeKg = session.exercises.flatMap(\.workingSets).compactMap(\.volumeKg).reduce(0, +)
        let unit = interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
        let figures = [
            session.activeDuration.map { Format.duration($0) },
            Format.sets(Double(sets)),
            volumeKg > 0 ? Format.weight(kg: volumeKg, unit: unit) : nil
        ].compactMap { $0 }
        let records = WorkoutSessionHighlights.personalRecords(in: session, priorSessions: interactor.workoutSessions, limit: .max)
        // The count is its own string so the catalog can give it plural forms.
        let recordsText = records.first.map { "\(String(localized: "\(records.count) PRs")) · \($0.exerciseName) \($0.detail)" }
        return SessionSummary(figures: figures.joined(separator: " · "), records: recordsText)
    }

    func onCompletedSessionPressed() {
        guard let session = completedSession else { return }
        interactor.trackEvent(event: Event.completedSessionPressed)
        router.showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate(workoutSession: session))
    }

    private var todaysScheduledItem: MicrocycleWorkoutTemplateModelItem? {
        MesocycleSchedule.todayItem(run: interactor.activeMesocycleRun, sessions: interactor.workoutSessions)
    }

}

extension TodaysWorkoutCardPresenter {
    enum Event: LoggableEvent {
        case skipPressed
        case skipStart
        case skipSuccess
        case skipFail(error: Error)
        case startPressed
        case startStart
        case startSuccess
        case startFail(error: Error)
        case deleteActiveSessionFail(error: Error)
        case loadTargetsFail(error: Error)
        case completedSessionPressed

        var eventName: String {
            switch self {
            case .skipPressed:  return "TodaysWorkoutCard_Skip_Pressed"
            case .skipStart:    return "TodaysWorkoutCard_Skip_Start"
            case .skipSuccess:  return "TodaysWorkoutCard_Skip_Success"
            case .skipFail:     return "TodaysWorkoutCard_Skip_Fail"
            case .startPressed: return "TodaysWorkoutCard_Start_Pressed"
            case .startStart:   return "TodaysWorkoutCard_Start_Start"
            case .startSuccess: return "TodaysWorkoutCard_Start_Success"
            case .startFail:    return "TodaysWorkoutCard_Start_Fail"
            case .deleteActiveSessionFail: return "TodaysWorkoutCard_DeleteActiveSession_Fail"
            case .loadTargetsFail: return "TodaysWorkoutCard_LoadTargets_Fail"
            case .completedSessionPressed: return "TodaysWorkoutCard_CompletedSession_Pressed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .skipFail(let error), .startFail(let error), .deleteActiveSessionFail(let error), .loadTargetsFail(let error):
                return error.eventParameters
            default: return nil
            }
        }

        var type: LogType {
            switch self {
            case .skipFail, .startFail: return .severe
            case .deleteActiveSessionFail, .loadTargetsFail: return .warning
            default: return .analytic
            }
        }
    }
}
