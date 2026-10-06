//
//  WorkoutTrackerPresenter+Finish.swift
//  Compound
//
//  Split out of WorkoutTrackerPresenter.swift, which exceeded the 500-line type-body limit.
//  Everything that happens after the user says they are done: the save and its retries, the side
//  effects of having finished, and what the user is told about any of it.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    // MARK: - What the user is told

    /// The three things the save can be, in the user's words.
    ///
    /// The wording deliberately echoes the Live Activity's — "Workout ended & saved." — and the
    /// failure names where the workout actually is, because it is not lost: the active session is
    /// only cleared once the save succeeds, so Training still offers to resume it.
    private enum SaveToast {
        static let id = "workout-save"

        static let retrying = AppToast(
            id: id,
            style: .progress,
            message: String(localized: "Couldn't save your workout. Retrying…"),
            duration: .seconds(6)
        )

        static let saved = AppToast(id: id, style: .success, message: String(localized: "Workout saved."))

        static let failed = AppToast(
            id: id,
            style: .failure,
            message: String(localized: "Couldn't save your workout. It's still on this device — resume it from Training."),
            duration: .seconds(8)
        )
    }

    // MARK: - Quick finish

    /// True once there is something to finish and all of it is logged: at least one set, and every
    /// set, warm-ups included, completed. The tracker then offers Finish Workout at the bottom of the
    /// screen as well as in its menu. Un-completing a set, or adding a set or an exercise, turns it
    /// off again, because the new set is open.
    var canQuickFinish: Bool {
        let sets = workoutSession.exercises.flatMap(\.sets)
        return !sets.isEmpty && sets.allSatisfy { $0.completedAt != nil }
    }

    /// VoiceOver users cannot see the button slide in, so they are told. No haptic: completing the
    /// last set has just played one.
    func onQuickFinishAvailabilityChanged(_ isAvailable: Bool) {
        guard isAvailable else { return }
        AccessibilityNotification.Announcement(String(localized: "All sets complete. Finish Workout is available.")).post()
    }

    // MARK: - Finishing

    /// The notes step was confirmed, or the quick-finish button skipped it. A workout with nothing
    /// logged would go into the history, the streak and Strava as an empty session, so the person
    /// is asked first.
    func onFinishConfirmed() {
        guard !hasLoggedSet else { return finishWorkout() }
        router.showConfirmationDialog(title: String(localized: "No Sets Logged"), subtitle: nil) {
            AnyView(VStack(spacing: Spacing.s) {
                Button("Discard Workout", role: .destructive) { self.discardWorkout() }
                Button("Save Anyway") { self.finishWorkout() }
                Button("Cancel", role: .cancel) { }
            })
        }
    }

    var hasLoggedSet: Bool {
        workoutSession.exercises.contains { $0.sets.contains { $0.completedAt != nil } }
    }

    func finishWorkout() {
        let now = Date()
        #if !targetEnvironment(macCatalyst)
        workoutSession.endSession(at: now, pausedSeconds: interactor.totalPausedDuration(at: now))
        #endif
        // Written before `isDone` stops further writes, so a save that fails below leaves the
        // finished session, with its last edit, for Training to resume.
        flushSave()
        isDone = true
        UIApplication.shared.isIdleTimerDisabled = false

        let sessionSnapshot = workoutSession
        // The session detail is the summary, pushed as the tracker's last page; its Done closes
        // the cover.
        router.showWorkoutSummary(session: sessionSnapshot)
        // At the moment the person sees the workout finish, not when the save lands behind the
        // summary. A failed save answers with `.error`; a retried one that works plays this again,
        // with the "Workout saved." toast as its visible cause.
        interactor.playHaptic(option: .success)
        // `self` is captured strongly on purpose. Done can close the cover before the save lands,
        // and then the view no longer holds the presenter; a weak capture would drop the save on
        // the floor exactly when it matters. The cycle breaks when the task returns.
        pendingFinishTask = Task {
            await self.completeFinish(sessionSnapshot)
        }
    }

    /// Calls off a save that is still waiting to be retried.
    func cancelPendingSave() {
        pendingFinishTask?.cancel()
        pendingFinishTask = nil
    }

    private func completeFinish(_ session: WorkoutSessionModel) async {
        interactor.trackEvent(
            eventName: "finish_workout_debug",
            parameters: [
                "session_id": session.id,
                "template_id": session.workoutTemplateId ?? "nil",
                "plan_id": session.mesocycleId ?? "nil"
            ],
            type: .info
        )
        // The finish itself is shared with the Live Activity's Finish button; only the retry and
        // what the user is told about it are this screen's. The shared path logs each attempt's
        // own result; these three follow the finish as the user sees it, retries included.
        interactor.trackEvent(event: Event.finishWorkoutStart)
        switch await interactor.finishWorkout(session) {
        case .saved:
            interactor.trackEvent(event: Event.finishWorkoutSuccess)
        case .failedPermanently:
            interactor.trackEvent(event: Event.finishWorkoutFail(reason: .permanent))
            showSaveFailed()
        case .failedTransiently:
            await retrySave(session)
        }
    }

    // MARK: - The retry

    private func attemptSave(_ session: WorkoutSessionModel) async -> WorkoutSaveOutcome {
        do {
            try await interactor.endWorkoutSession(session)
            interactor.trackEvent(eventName: WorkoutSessionModel.finishedEventName, parameters: session.finishedEventParameters, type: .analytic)
            return .saved
        } catch {
            interactor.trackEvent(
                eventName: "finish_workout_save_error",
                parameters: [
                    "error": error.localizedDescription,
                    "is_transient": error.isTransientWriteFailure
                ],
                type: .severe
            )
            return error.isTransientWriteFailure ? .failedTransiently : .failedPermanently
        }
    }

    /// Works through `saveRetryBackoff`, stopping the moment retrying stops being useful.
    private func retrySave(_ session: WorkoutSessionModel) async {
        var attempt = 2
        var waited = Duration.zero

        while let delay = saveRetryBackoff.delay(beforeAttempt: attempt, alreadyWaited: waited) {
            // Re-raised each time round so the message stays up for the whole schedule rather than
            // timing out halfway through and leaving the user looking at nothing.
            interactor.showAppToast(SaveToast.retrying)

            do {
                try await Task.sleep(for: delay)
            } catch {
                // Cancelled. Whoever called it off does not need to be told what they just did.
                interactor.trackEvent(event: Event.finishWorkoutFail(reason: .cancelled))
                return
            }
            waited += delay

            // A retry after sign-out would write this workout into whoever signed in next, so the
            // loop stops following the user rather than chasing them.
            guard interactor.currentUser?.userId == session.authorId else {
                interactor.trackEvent(event: Event.finishWorkoutFail(reason: .signedOut))
                return
            }

            switch await attemptSave(session) {
            case .saved:
                interactor.trackEvent(event: Event.finishWorkoutSuccess)
                interactor.playHaptic(option: .success)
                interactor.showAppToast(SaveToast.saved)
                return
            case .failedPermanently:
                interactor.trackEvent(event: Event.finishWorkoutFail(reason: .permanent))
                showSaveFailed()
                return
            case .failedTransiently:
                attempt += 1
            }
        }

        interactor.trackEvent(event: Event.finishWorkoutFail(reason: .retriesExhausted))
        showSaveFailed()
    }

    private func showSaveFailed() {
        interactor.playHaptic(option: .error)
        interactor.showAppToast(SaveToast.failed)
    }
}
