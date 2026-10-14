//
//  WorkoutTrackerPresenter+LogButton.swift
//  Compound
//
//  The button at the foot of the tracker, read against the live session: what it does and says,
//  when a tap on it counts, the set it logs, and its names for Dynamic Type and Voice Control. The
//  rules are in `ActiveWorkout+PrimarySlot`.
//

import Foundation

extension WorkoutTrackerPresenter {

    /// What the bottom button does now.
    var primarySlot: ActiveWorkout.SlotAction? {
        primarySlot(at: Date())
    }

    func primarySlot(at now: Date) -> ActiveWorkout.SlotAction? {
        ActiveWorkout.slotAction(primary: primaryAction, restEnd: slotRestEnd, isPaused: !isActive, now: now)
    }

    /// The running rest's end, else the end of one that has just run out, which the rest timer's
    /// owner forgets the moment it does.
    private var slotRestEnd: Date? {
        interactor.restEndTime ?? expiredRestEnd
    }

    /// The end of the rest Skip Rest ends, for its countdown; `nil` when the button does
    /// something else.
    var primarySlotRestEnd: Date? {
        primarySlot == .skipRest ? interactor.restEndTime : nil
    }

    /// For a second after a rest runs out, the button reads "Rest done" and cannot be tapped: a
    /// tap meant for Skip Rest as the timer reaches 0:00 would otherwise log the next set.
    var isPrimarySlotInGrace: Bool {
        isPrimarySlotInGrace(at: Date())
    }

    func isPrimarySlotInGrace(at now: Date) -> Bool {
        guard primarySlot(at: now) != .resume, let end = slotRestEnd else { return false }
        return ActiveWorkout.isInGrace(restEnd: end, now: now)
    }

    /// The button's words for every action but Skip Rest, which counts down in the view.
    var primarySlotTitle: String {
        switch primarySlot {
        case .resume?:
            return String(localized: "Resume Workout")
        case .skipRest?:
            return String(localized: "Skip rest")
        default:
            let title = primaryActionTitle
            return isPrimarySlotInGrace ? String(localized: "Rest done · \(title)") : title
        }
    }

    /// The bottom button. A tap in the 0.4 s after its action changed, or during a finished rest's
    /// grace, is dropped: it was aimed at what the button was a moment ago.
    func onPrimarySlotPressed(at now: Date = Date()) {
        let action = primarySlot(at: now)
        noteSlotAction(action, at: now)
        guard let action,
              ActiveWorkout.acceptsTap(lastActionChangeAt: lastSlotActionChangeAt, now: now),
              !isPrimarySlotInGrace(at: now) else { return }
        switch action {
        case .log, .next, .finish:
            onPrimaryActionPressed()
        case .skipRest:
            onSkipRestPressed()
        case .resume:
            onPauseResumePressed()
        }
        // Whatever the tap turned the button into is a change the next tap must wait out, even
        // before the view has drawn it.
        noteSlotAction(primarySlot(at: now), at: now)
    }

    /// The view reports every change of the button's action, including those nobody tapped for:
    /// a rest running out, a set logged from its row or the Lock Screen.
    func onPrimarySlotChanged(_ action: ActiveWorkout.SlotAction?) {
        noteSlotAction(action, at: Date())
    }

    private func noteSlotAction(_ action: ActiveWorkout.SlotAction?, at now: Date) {
        guard action != lastSlotAction else { return }
        // The first action seen is where the screen starts, not a change.
        if lastSlotAction != nil { lastSlotActionChangeAt = now }
        lastSlotAction = action
    }

    /// A rest that disappears once its end has passed ran out on its own, and is held for its
    /// grace; one that disappears early was skipped, here or on the Lock Screen, and is not.
    func onRunningRestEndChanged(from oldEnd: Date?, to newEnd: Date?, now: Date = Date()) {
        guard newEnd == nil else {
            expiredRestEnd = nil
            return
        }
        guard let oldEnd, oldEnd <= now, ActiveWorkout.isInGrace(restEnd: oldEnd, now: now) else { return }
        expiredRestEnd = oldEnd
        let remaining = oldEnd.addingTimeInterval(ActiveWorkout.restDoneGrace).timeIntervalSince(now)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            // Only the grace this call began: a rest started and run out since has its own.
            guard let self, self.expiredRestEnd == oldEnd else { return }
            self.expiredRestEnd = nil
        }
    }

    /// The set the button logs, so the list can bring its row into view after a log.
    var currentLogSetId: String? {
        guard case let .logSet(_, setId)? = primaryAction else { return nil }
        return setId
    }

    // MARK: - The action

    /// When the running rest ends, while one runs: the footer offers Skip Rest instead of the next
    /// set. Cleared by the rest timer's owner the moment the rest runs out.
    var runningRestEnd: Date? {
        interactor.restEndTime.flatMap { $0 > Date() ? $0 : nil }
    }

    var primaryAction: ActiveWorkoutAction? {
        ActiveWorkout.primaryAction(exercises: workoutSession.exercises, currentExerciseId: currentExercise?.id)
    }

    /// Follows every keystroke in the current row, since the row edits the session directly.
    var primaryActionTitle: String {
        switch primaryAction {
        case let .logSet(exerciseId, setId)?:
            guard let exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }),
                  let set = exercise.sets.first(where: { $0.id == setId }) else { return "" }
            let units = units(for: exercise)
            return ActiveWorkout.logTitle(
                for: set,
                in: exercise,
                unit: units.weightUnit,
                distanceUnit: units.distanceUnit,
                showsBodyweight: bodyweightContribution(for: exercise) != nil
            )
        case let .next(exerciseId)?:
            let name = workoutSession.exercises.first { $0.id == exerciseId }?.name ?? ""
            return String(localized: "Next: \(name)")
        case .finish?:
            return String(localized: "Finish Workout")
        case nil:
            return ""
        }
    }

    func onPrimaryActionPressed() {
        switch primaryAction {
        case let .logSet(exerciseId, setId)?:
            logSet(setId, in: exerciseId)
        case let .next(exerciseId)?:
            onExerciseSelected(exerciseId)
        case .finish?:
            // The notes sheet is the confirmation: the button became Finish under a tap meant
            // for the set before.
            onFinishPressed()
        case nil:
            break
        }
    }

    /// The one way a set is logged on this screen, from the log button, a row's Done or the set
    /// keyboard. The rule (`ActiveWorkout.log`, shared with the Live Activity) checks it, stamps it
    /// and says how long to rest — the rules, or a rest set by hand on the row; this plays the
    /// haptic, saves, starts the rest and lets smart progression re-suggest what is left.
    func logSet(_ setId: String, in exerciseId: String, customRestSeconds custom: Int? = nil, source: String = "log_button") {
        guard let exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }) else { return }
        let settings = interactor.workoutSettings
        guard let outcome = ActiveWorkout.log(
            setId: setId,
            in: workoutSession,
            settings: settings,
            context: restContext(for: exercise),
            customRestSeconds: custom ?? customRestSeconds[setId],
            isAssisted: interactor.isAssisted(templateId: exercise.templateId)
        ) else { return }
        if let problem = outcome.problem {
            interactor.playHaptic(option: .error)
            router.showSimpleAlert(title: String(localized: "Unable to Log Set"), subtitle: problem)
            return
        }
        guard let set = outcome.session.exercises.first(where: { $0.id == exerciseId })?.sets.first(where: { $0.id == setId })
        else { return }

        interactor.playHaptic(option: .success)
        updateSet(set, in: exerciseId)
        persistFocus(currentExercise?.id)

        let rest = outcome.restSeconds
        interactor.trackEvent(event: Event.setLogged(
            setId: setId,
            exerciseId: exerciseId,
            useRestTimers: settings.useRestTimers,
            restDurationSeconds: rest ?? 0,
            source: source
        ))
        if settings.useRestTimers, let rest {
            startRestTimer(durationSeconds: rest)
        }
        applyLiveProgression(after: set, in: exerciseId)
    }

    // MARK: - Short title and Voice Control (a11y.md S3, S5)

    /// "Log set 2": the button's words without the figures, which is what fits at accessibility
    /// text sizes. VoiceOver still reads the whole title.
    var primarySlotShortTitle: String {
        primarySlotTitle.components(separatedBy: " · ").first ?? primarySlotTitle
    }

    /// What Voice Control answers to. The title changes with every keystroke in the set's fields;
    /// these do not.
    var primarySlotInputLabels: [String] {
        switch primarySlot {
        case .log?: [primarySlotShortTitle, String(localized: "Log set"), String(localized: "Log")]
        case .skipRest?: [String(localized: "Skip rest"), String(localized: "Skip")]
        case .next?: [primarySlotTitle, String(localized: "Next")]
        case .finish?: [String(localized: "Finish Workout"), String(localized: "Finish")]
        case .resume?: [String(localized: "Resume Workout"), String(localized: "Resume")]
        case nil: []
        }
    }

}

// MARK: - The set plan

extension WorkoutTrackerPresenter {

    /// The log button's second line: the drop or mini-set that follows the set it logs. `nil`
    /// with the set plan off, and whenever the button does anything but log a set.
    var primarySlotNextPiece: ActiveWorkout.PieceHint? {
        let settings = interactor.workoutSettings
        guard settings.plansSets, case let .log(exerciseId, setId)? = primarySlot,
              let exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }) else { return nil }
        let units = units(for: exercise)
        return ActiveWorkout.nextPiece(after: setId, in: exercise, settings: settings, unit: units.weightUnit, distanceUnit: units.distanceUnit)
    }
}
