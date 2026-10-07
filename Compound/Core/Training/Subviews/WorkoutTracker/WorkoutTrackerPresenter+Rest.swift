//
//  WorkoutTrackerPresenter+Rest.swift
//  Compound
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

    /// When the rest on screen began, for the inline timer's progress: the rest owner's, so a rest
    /// started from the Lock Screen or before a relaunch has one too.
    var restStartedAt: Date? {
        interactor.restStartedAt
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
        loadPrevious(for: workoutSession.exercises.map(\.templateId))
    }

    /// The same, for some exercises only: those added part-way through. What is already loaded
    /// for the others is kept.
    func loadPrevious(for templateIds: [String]) {
        guard let authorId = interactor.currentUser?.userId else { return }

        let workoutTemplateId = workoutSession.workoutTemplateId
        let mesocycleId = workoutSession.mesocycleId
        let exerciseTemplateIds = Set(templateIds)

        Task {
            var resolved: [String: WorkoutExerciseModel] = [:]

            for exerciseTemplateId in exerciseTemplateIds {
                let sessions = await interactor.previousSessions(
                    forExerciseTemplateId: exerciseTemplateId,
                    workoutTemplateId: workoutTemplateId,
                    authorId: authorId,
                    mesocycleId: mesocycleId,
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

            previousExercises.merge(resolved) { $1 }
        }
    }

    /// What the rest pill's "+15s" adds, the same step the Live Activity offers.
    static let restAdjustmentSeconds = 15

    /// Lengthens the running rest. Through `startRest`, like the Live Activity's +15s, so the
    /// timer, the shared end time and the activity all move together.
    func onAddRestTimePressed() {
        guard let end = restEndTime else { return }
        let remaining = Int(end.timeIntervalSinceNow.rounded(.up)) + Self.restAdjustmentSeconds
        #if !targetEnvironment(macCatalyst)
        interactor.startRest(durationSeconds: max(1, remaining), session: workoutSession, currentExerciseIndex: currentExerciseIndex)
        #endif
        interactor.trackEvent(event: Event.restExtended(seconds: Self.restAdjustmentSeconds))
    }

    func onSkipRestPressed() {
        interactor.trackEvent(event: Event.restSkipped)
        cancelRestTimer()
        // A skipped rest is over as surely as one that ran out.
        onRestEnded()
    }

    /// A rest follows the set logged last. Once that set is gone, deleted on its own or with its
    /// exercise, there is nothing left to rest from.
    func cancelRestIfRestedSetRemoved(comparedTo oldSession: WorkoutSessionModel) {
        guard restStartedAt != nil || interactor.restEndTime != nil,
              let rested = ActiveWorkout.latestCompletedSet(in: oldSession.exercises),
              !workoutSession.exercises.contains(where: { $0.sets.contains { $0.id == rested.id } })
        else { return }
        cancelRestTimer()
    }

    func cancelRestTimer() {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        // Cancel in manager (will also update Live Activity, and forget when the rest began)
        interactor.cancelRest()
        #endif
    }

    /// Announces every rest that runs out while this screen is up. Driven from its own `.task` so
    /// the loop is cancelled when the screen goes away — an observer token outliving the presenter
    /// would announce rests for a workout nobody is looking at.
    func observeRestCompletions() async {
        for await _ in NotificationCenter.default.notifications(named: Constants.workoutRestDidComplete) {
            announceRestCompletion()
            onRestEnded()
        }
    }

    /// Sound and vibration are asked for separately, so a user who wants one without the other in a
    /// quiet gym gets exactly that.
    func announceRestCompletion() {
        let settings = interactor.workoutSettings
        if settings.restTimerPlaySound {
            interactor.playSoundEffect(sound: .restComplete)
        }
        // `.warning`, not the `.success` a logged set plays: the two land moments apart, and one
        // pattern per event is how a user tells them apart without looking.
        if settings.restTimerVibrate {
            interactor.playHaptic(option: .warning)
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
        #if !targetEnvironment(macCatalyst)
        interactor.startRest(durationSeconds: duration, session: workoutSession, currentExerciseIndex: currentExerciseIndex)
        #endif
        interactor.trackEvent(event: Event.startRestTimerAfterCall(restEndTime: interactor.restEndTime))
        // The rest-over alert, the Live Activity's or the notification, is scheduled by the rest
        // timer's owner, so the +15s, skip, finish and discard that follow can move or withdraw it.
    }
}
