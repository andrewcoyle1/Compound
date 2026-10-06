//
//  WorkoutTrackerPresenter+Persistence.swift
//  Compound
//
//  Split out of WorkoutTrackerPresenter.swift to keep it under the type-body and file-length
//  limits, so later work adds its logic here rather than in the main file. Saving the session,
//  adopting saves made elsewhere (the Live Activity), the scene phase, and minimizing.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    func onScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        // iOS foregrounds through `.inactive`, so `oldPhase` is never `.background` here.
        if newPhase == .active {
            // A set logged from the Live Activity while the app was in the background was saved by
            // the intent handler, not by this screen, so re-read it rather than waiting for the
            // observation to fire.
            adoptSavedSessionIfChanged()
        }
    }

    func minimizeSession() {
        router.dismissScreen()
    }

    // MARK: - Persistence
    
    func saveWorkoutProgress() {
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
    /// Skipped while `updateSet` is mid-flight: that is this screen's own write on its way to the
    /// manager, and adopting it back would fight the edit the user is making.
    func adoptSavedSessionIfChanged() {
        guard !isProcessingUpdateSet else { return }
        guard let saved = interactor.activeSession else {
            // Finished from the Live Activity while this screen sat in the background. There is
            // nothing left to track, and the next edit here would resurrect the ended session.
            guard !isDone else { return }
            isDone = true
            UIApplication.shared.isIdleTimerDisabled = false
            router.dismissScreen()
            return
        }
        guard saved.id == workoutSession.id else { return }
        guard saved != workoutSession else { return }

        workoutSession = saved
    }
}
