//
//  WorkoutTrackerPresenter+Persistence.swift
//  Compound
//
//  Split out of WorkoutTrackerPresenter.swift to keep it under the type-body and file-length
//  limits, so later work adds its logic here rather than in the main file. Saving the session,
//  adopting saves made elsewhere (the Live Activity), the scene phase, and minimizing.
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
        } else {
            // On the way out: the app may not get another chance to write.
            flushSave()
        }
    }

    func minimizeSession() {
        flushSave()
        router.dismissScreen()
    }

    // MARK: - Persistence

    /// Every change to the session lands here, through `didSet`. The write waits for typing to
    /// pause, so a burst of keystrokes costs one encode and one file write.
    func saveWorkoutProgress() {
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
    func startObservingActiveSession() {
        withObservationTracking {
            _ = interactor.activeSession
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.adoptSavedSessionIfChanged()
                self?.startObservingActiveSession()
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
            // Finished from the Live Activity while this screen sat in the background. There is
            // nothing left to track, and the next edit here would resurrect the ended session.
            guard !isDone else { return }
            isDone = true
            savePath.scheduledSave?.cancel()
            savePath.scheduledSave = nil
            UIApplication.shared.isIdleTimerDisabled = false
            router.dismissScreen()
            return
        }
        guard !savePath.hasUnsavedChanges else { return }
        guard saved.id == workoutSession.id else { return }
        guard saved != workoutSession else { return }

        workoutSession = saved
    }
}
