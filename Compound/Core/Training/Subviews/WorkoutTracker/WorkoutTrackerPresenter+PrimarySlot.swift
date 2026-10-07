//
//  WorkoutTrackerPresenter+PrimarySlot.swift
//  Compound
//
//  The button at the foot of the tracker, read against the live session: what it does and says,
//  when a tap on it counts, and the paused state the bar above shows. The rules are in
//  `ActiveWorkout+PrimarySlot`.
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

    // MARK: - Paused

    /// The title's second line: the clock, or Paused while the workout is.
    func clockText(at date: Date) -> String {
        isActive ? elapsedTime(at: date) : String(localized: "Paused")
    }
}
