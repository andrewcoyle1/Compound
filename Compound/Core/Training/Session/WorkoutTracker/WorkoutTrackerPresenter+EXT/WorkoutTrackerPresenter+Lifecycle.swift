//
//  WorkoutTrackerPresenter+Lifecycle.swift
//  Compound
//
//  The screen coming and going: appearing (Apple Health, the gym, last time), the keyboard
//  observer, the scene phase, minimizing, and pausing the workout.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    func onAppear() async {
        startObservingActiveSession()
        loadPreviousWorkoutSession()
        await loadWorkoutGymProfile()
        loadProgressionSuggestions()
        interactor.setScreenKeptAwake(interactor.workoutSettings.keepAlive)

        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        // Return early if the HK session is already started — nothing more to do.
        guard interactor.healthWorkoutSessionId != workoutSession.id else { return }

        // Ask every time we're about to start a new HK session: HealthKit shows its sheet only for
        // types not yet asked about, so this also reaches users who granted workouts before the
        // scope gained heart rate and active energy.
        if interactor.canRequestHealthDataAuthorisation() {
            do {
                try await interactor.requestHealthKitAuthorisation(for: .workouts)
            } catch {
                interactor.trackEvent(event: Event.healthKitAuthorisationFail(error: error))
            }
        }

        guard !interactor.needsAuthorisationForRequiredTypes() else { return }

        interactor.setWorkoutConfiguration(activityType: .traditionalStrengthTraining, location: .indoor)
        interactor.startWorkout(workout: workoutSession)
        interactor.markHealthWorkoutStarted(sessionId: workoutSession.id)
        #endif
    }

    /// The gym this workout was written for, so the rows' steps and plates and progression's
    /// rounding follow it. Without one, `workoutGymProfile` falls back to the favourite.
    func loadWorkoutGymProfile() async {
        guard let templateId = workoutSession.workoutTemplateId,
              let gymProfileId = interactor.getWorkoutTemplate(id: templateId)?.gymProfileId else { return }
        do {
            interactor.setActiveWorkoutGymProfile(try await interactor.getGymProfile(gymProfileId: gymProfileId))
        } catch {
            interactor.trackEvent(event: Event.loadGymProfileFail(error: error))
        }
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
        // The keyboard going away ends the edit being typed, which then carries to its siblings.
        // Synchronous (`queue: nil`): the notification is posted on the main thread.
        guard keyboardObserver == nil else { return }
        keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidHideNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.commitPendingEdit() }
        }
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
        if let observer = keyboardObserver {
            NotificationCenter.default.removeObserver(observer)
            keyboardObserver = nil
        }
    }

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

    func onMinimizePressed() {
        interactor.trackEvent(event: Event.minimized)
        flushSave()
        // Kept on only while the tracker is up: minimised, the phone may sleep (system.md §5).
        interactor.setScreenKeptAwake(false)
        router.dismissScreen()
    }

    /// Pause and Resume in the menu. The clock, the Apple Health session and the Live Activity's
    /// paused phase all follow the one toggle.
    func onPauseResumePressed() {
        #if !targetEnvironment(macCatalyst)
        interactor.togglePause()
        #endif
        interactor.playHaptic(option: .light)
        interactor.trackEvent(event: isActive ? Event.workoutResumed : Event.workoutPaused)
    }
}
