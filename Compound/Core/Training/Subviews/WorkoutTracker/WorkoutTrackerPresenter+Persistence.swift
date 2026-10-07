//
//  WorkoutTrackerPresenter+Persistence.swift
//  Compound
//
//  Split out of WorkoutTrackerPresenter.swift to keep it under the type-body and file-length
//  limits, so later work adds its logic here rather than in the main file. Saving the session,
//  adopting saves made elsewhere (the Live Activity), the scene phase, and minimizing; and on
//  return, owning up to what changed meanwhile (system.md §2): the receipt for sets logged
//  elsewhere, "Still training?", and the summary of a workout finished elsewhere.
//

import SwiftUI

/// The presenter's save bookkeeping, held in one stored property so the main file carries a single
/// line of it.
struct WorkoutSavePath {

    /// How long the session waits after a change before it is written. A burst of keystrokes is
    /// one write rather than one (or two) per digit.
    static let debounce: Duration = .milliseconds(300)

    /// The write waiting out `debounce`. Non-nil means the session holds changes not yet saved.
    var scheduledSave: Task<Void, Never>?

    /// The set being typed into and what it held before the first keystroke, carried onto its
    /// siblings when the edit is committed rather than on every key. See `+SessionChanges`.
    var pendingEdit: WorkoutSetModel?

    /// The `keyboardDidHideNotification` observer, kept to remove it on disappear.
    var keyboardObserver: NSObjectProtocol?

    var hasUnsavedChanges: Bool { scheduledSave != nil }
}

extension WorkoutTrackerPresenter {

    func onScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        // iOS foregrounds through `.inactive`, so `oldPhase` is never `.background` here.
        if newPhase == .active {
            // A set logged from the Live Activity while the app was in the background was saved by
            // the intent handler, not by this screen, so re-read it rather than waiting for the
            // observation to fire.
            adoptSavedSessionIfChanged()
            askIfStillTraining()
        } else {
            // On the way out: the app may not get another chance to write.
            flushSave()
        }
    }

    func minimizeSession() {
        flushSave()
        // Kept on only while the tracker is up: minimised, the phone may sleep (system.md §5).
        UIApplication.shared.isIdleTimerDisabled = false
        router.dismissScreen()
    }

    // MARK: - Persistence

    /// Every change to the session lands here, through `didSet`. The write waits for typing to
    /// pause, so a burst of keystrokes costs one encode and one file write.
    func saveWorkoutProgress() {
        // Everything that reaches here but an adopted save is the screen's own doing.
        markSetsSeen()
        guard !isDone else { return }
        savePath.scheduledSave?.cancel()
        savePath.scheduledSave = Task { [weak self] in
            do {
                try await Task.sleep(for: WorkoutSavePath.debounce)
            } catch {
                return // Superseded by a later change or a flush.
            }
            guard !Task.isCancelled else { return }
            self?.writeSession()
        }
    }

    /// Commits the edit being typed and writes the session now, when waiting could lose it: a set
    /// logged, the app leaving the foreground, minimizing, finishing.
    func flushSave() {
        guard !isDone else {
            savePath.scheduledSave?.cancel()
            savePath.scheduledSave = nil
            return
        }
        commitPendingEdit()
        writeSession()
    }

    // ponytail: writes are non-atomic until SwiftfulDataManagers 1.2.1
    // (andrewcoyle1/SwiftfulDataManagers#1); bump Package.resolved once it is tagged.

    /// Writes whatever is waiting. The debounced task calls this rather than `flushSave`: an edit
    /// still being typed is not committed by a pause, only by leaving it.
    ///
    /// `scheduledSave` is cleared after the write, not before, so an observation fired by this
    /// very write still finds a save in progress and leaves the screen's copy alone.
    private func writeSession() {
        guard savePath.hasUnsavedChanges else { return }
        defer {
            savePath.scheduledSave?.cancel()
            savePath.scheduledSave = nil
        }
        guard !isDone else { return }
        do {
            try interactor.updateActiveSession(workoutSession)
        } catch {
            interactor.trackEvent(event: Event.saveProgressFail(error: error))
            router.showSimpleAlert(title: String(localized: "Unable to Save Progress"), subtitle: String(localized: "We were unable to save your workout. Please try again."))
        }
    }

    // MARK: - The handler's writes

    /// Watches `interactor.activeSession` for a save this screen did not make.
    ///
    /// A set logged from the Live Activity is written by `AppLiveActivityIntentHandler`, in this
    /// process but outside this presenter. Observation is how it reaches the screen: the handler
    /// saves through the session manager, `activeSession` changes, and the tracker adopts it.
    ///
    /// Re-armed on every change, because `withObservationTracking` fires its `onChange` once.
    ///
    /// Called as the screen appears, which is also when it picks up what the last screen on this
    /// workout had seen, and asks whether the workout was forgotten.
    func startObservingActiveSession() {
        loadLastSeenSetCompletion()
        observeActiveSession()
        askIfStillTraining()
    }

    private func observeActiveSession() {
        withObservationTracking {
            _ = interactor.activeSession
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.adoptSavedSessionIfChanged()
                self?.observeActiveSession()
            }
        }
    }

    /// Takes on the saved session when it differs from the screen's own copy.
    ///
    /// Skipped while `updateSet` is mid-flight, or while a save is waiting: the screen holds edits
    /// the saved copy lacks, and adopting it would throw them away.
    func adoptSavedSessionIfChanged() {
        guard !isProcessingUpdateSet else { return }
        guard let saved = interactor.activeSession else {
            // Finished or discarded from the Live Activity while this screen sat in the
            // background. There is nothing left to track, and the next edit here would resurrect
            // the ended session. A finish opens on its summary, as one made here does.
            guard !isDone else { return }
            isDone = true
            savePath.scheduledSave?.cancel()
            savePath.scheduledSave = nil
            UIApplication.shared.isIdleTimerDisabled = false
            if let finished = interactor.lastFinishedSession, finished.id == workoutSession.id {
                router.showWorkoutSummary(session: finished)
            } else {
                router.dismissScreen()
            }
            return
        }
        guard !savePath.hasUnsavedChanges else { return }
        guard saved.id == workoutSession.id else { return }
        guard saved != workoutSession else { return }

        // Not the screen's doing, so the sets it brings stay unseen for the receipt.
        let seen = lastSeenSetCompletion
        workoutSession = saved
        setLastSeenSetCompletion(seen)
    }

    // MARK: - The receipt

    /// "Logged from Lock Screen: Set 2 · 100 kg × 8": sets logged elsewhere since the screen last
    /// looked, in the progression note's slot until the next action.
    var logReceipt: String? {
        let lines = ActiveWorkout.receipt(in: workoutSession.exercises, loggedAfter: lastSeenSetCompletion).compactMap { set in
            workoutSession.exercises.first { $0.sets.contains { $0.id == set.id } }.map { exercise in
                let units = units(for: exercise)
                return ActiveWorkout.receiptLine(for: set, in: exercise, unit: units.weightUnit, distanceUnit: units.distanceUnit)
            }
        }
        guard !lines.isEmpty else { return nil }
        return String(localized: "Logged from Lock Screen: \(lines.formatted(.list(type: .and)))")
    }

    /// The screen has seen everything logged so far: the receipt goes, and "Still training?"
    /// counts from now.
    func markSetsSeen() {
        setLastSeenSetCompletion(Date())
    }

    private static let lastSeenKey = "workout.tracker.lastSeenSetCompletion"

    private func setLastSeenSetCompletion(_ date: Date?) {
        lastSeenSetCompletion = date
        guard let date else { return }
        interactor.activeWorkoutScreenStateStore.set(
            ["sessionId": workoutSession.id, "at": date.timeIntervalSince1970],
            forKey: Self.lastSeenKey
        )
    }

    /// What the last screen on this workout had seen, so a tracker rebuilt after a minimise or a
    /// relaunch still owns up to sets logged in between. A workout opened for the first time has
    /// missed nothing.
    private func loadLastSeenSetCompletion() {
        guard lastSeenSetCompletion == nil else { return }
        let stored = interactor.activeWorkoutScreenStateStore.dictionary(forKey: Self.lastSeenKey)
        let timestamp = (stored?["sessionId"] as? String) == workoutSession.id ? stored?["at"] as? TimeInterval : nil
        setLastSeenSetCompletion(timestamp.map { Date(timeIntervalSince1970: $0) } ?? Date())
    }

    // MARK: - Still training?

    /// Asked on return when nothing has happened for an hour since the last logged set: finish
    /// the workout as of that set, or carry on.
    func askIfStillTraining(now: Date = Date()) {
        guard !isDone, let lastSet = ActiveWorkout.latestCompletedSet(in: workoutSession.exercises)?.completedAt else { return }
        let lastActivity = max(lastSet, lastSeenSetCompletion ?? lastSet)
        guard IdleWorkoutReminder.isIdle(lastActivity: lastActivity, now: now) else { return }
        // Counted as seen from here, so Keep Going waits another hour, and the appear and the
        // foreground that can both come with one return ask once.
        setLastSeenSetCompletion(now)
        let time = lastSet.formatted(date: .omitted, time: .shortened)
        router.showAlert(
            title: String(localized: "Still training?"),
            subtitle: String(localized: "No set logged in the last hour.")
        ) {
            AnyView(VStack {
                Button(String(localized: "Finish at \(time)")) { self.onFinishAtLastSetPressed() }
                Button("Keep Going", role: .cancel) { }
            })
        }
    }

    /// Ends the workout when its last set was logged, so the forgotten hour is not counted.
    func onFinishAtLastSetPressed() {
        guard let lastSet = ActiveWorkout.latestCompletedSet(in: workoutSession.exercises)?.completedAt else { return }
        finishWorkout(at: lastSet)
    }
}
