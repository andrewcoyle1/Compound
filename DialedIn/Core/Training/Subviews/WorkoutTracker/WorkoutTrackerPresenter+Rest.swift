//
//  WorkoutTrackerPresenter+Rest.swift
//  DialedIn
//
//  Split out of WorkoutTrackerPresenter.swift, which exceeded the 500-line type-body limit.
//  Everything the screen does about resting between sets, and the previous-values lookup the
//  rest of the screen reads alongside it.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    var restDurationSeconds: Int {
        interactor.workoutSettings.defaultRestDurationSeconds
    }

    var restEndTime: Date? {
        interactor.restEndTime
    }

    var isRestActive: Bool {
        guard let end = interactor.restEndTime else { return false }
        return Date() < end
    }

    // MARK: - Previous Values

    /// Loads what the user last did for every exercise on screen, honouring
    /// `previousWorkoutReference` through `interactor.previousSessions(...)` — the same resolution
    /// smart progression uses, so the "Prev" column and the "Auto" column can never disagree about
    /// what last time was.
    ///
    /// Resolved one exercise at a time because the fallback is per exercise: an exercise this
    /// template has never held still shows the last time it was performed anywhere.
    func loadPreviousWorkoutSession() {
        guard let authorId = interactor.currentUser?.userId else {
            previousExercises = [:]
            return
        }

        let workoutTemplateId = workoutSession.workoutTemplateId
        let trainingProgramId = workoutSession.trainingProgramId
        let exerciseTemplateIds = Array(Set(workoutSession.exercises.map(\.templateId)))

        Task {
            var resolved: [String: WorkoutExerciseModel] = [:]

            for exerciseTemplateId in exerciseTemplateIds {
                let sessions = await interactor.previousSessions(
                    forExerciseTemplateId: exerciseTemplateId,
                    workoutTemplateId: workoutTemplateId,
                    authorId: authorId,
                    trainingProgramId: trainingProgramId,
                    limit: 1
                )
                let match = sessions
                    .lazy
                    .compactMap { $0.exercises.first(where: { $0.templateId == exerciseTemplateId }) }
                    .first
                if let match {
                    resolved[exerciseTemplateId] = match
                }
            }

            previousExercises = resolved
        }
    }

    func cancelRestTimer() {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        // Cancel in manager (will also update Live Activity)
        interactor.cancelRest()
        #endif

    }

    /// Announces every rest that runs out while this screen is up. Driven from its own `.task` so
    /// the loop is cancelled when the screen goes away — an observer token outliving the presenter
    /// would announce rests for a workout nobody is looking at.
    func observeRestCompletions() async {
        for await _ in NotificationCenter.default.notifications(named: Constants.workoutRestDidComplete) {
            announceRestCompletion()
        }
    }

    /// Sound and vibration are asked for separately, so a user who wants one without the other in a
    /// quiet gym gets exactly that.
    func announceRestCompletion() {
        let settings = interactor.workoutSettings
        if settings.restTimerPlaySound {
            interactor.playSoundEffect(sound: .restComplete)
        }
        if settings.restTimerVibrate {
            interactor.playHaptic(option: .success)
        }
    }

    func startRestTimer(durationSeconds: Int = 0) {
        let duration = durationSeconds > 0 ? durationSeconds : restDurationSeconds
        // Preparing is idempotent, and doing it as the rest starts means the players are loaded by
        // the time it ends rather than being built during the moment they are wanted.
        if interactor.workoutSettings.restTimerPlaySound {
            interactor.prepareSoundEffect(sound: .restComplete, simultaneousPlayers: 1)
        }
        interactor.trackEvent(event: Event.startRestTimerCalled(inputDuration: durationSeconds, resolvedDuration: duration))
        interactor.startRest(durationSeconds: duration, session: workoutSession, currentExerciseIndex: currentExerciseIndex)
        interactor.trackEvent(event: Event.startRestTimerAfterCall(restEndTime: interactor.restEndTime))

        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        // Schedule local notification for when rest is complete
        if let endTime = interactor.restEndTime {
            Task {
                do {
                    let delegate = PushNotificationDelegate(
                        identifier: restTimerNotificationId,
                        title: String(localized: "Rest Complete"),
                        subtitle: String(localized: "Time to get back to your workout!"),
                        triggerDate: endTime,
                        // The same setting, so a user who turned the sound off is not dinged by the
                        // notification that lands at the very moment the in-app sound was suppressed.
                        sound: interactor.workoutSettings.restTimerPlaySound,
                        badge: nil
                    )
                    try await interactor.schedulePushNotification(delegate: delegate)
                } catch {
                    // Silently fail - notification is nice to have but not critical
                }
            }
        }
        #endif
    }
}
