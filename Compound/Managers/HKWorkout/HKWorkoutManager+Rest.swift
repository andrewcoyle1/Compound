//
//  HKWorkoutManager+Rest.swift
//  Compound
//
//  The rest timer, split out of HKWorkoutManager.swift. The manager owns the rest: its end, its
//  start, the timer that ends it, the rest-over alert, and taking all of it back after a relaunch.
//

import Foundation
#if canImport(HealthKit) && !targetEnvironment(macCatalyst)

// MARK: - Rest Timer Management
extension HKWorkoutManager {
    /// Begin a rest period and schedule a background-safe update at rest end.
    @MainActor
    func startRest(durationSeconds: Int, session: WorkoutSessionModel, currentExerciseIndex: Int = 0, alertSound: Bool = true) {
        startRest(duration: TimeInterval(durationSeconds), session: session, currentExerciseIndex: currentExerciseIndex, alertSound: alertSound)
    }

    /// The same thing as an interval rather than whole seconds.
    ///
    /// Rest durations are whole seconds everywhere a user sets one, so the caller above is the one
    /// the app uses. This spelling exists so a test can drive a rest that runs out in a fraction of
    /// a second instead of waiting out a real one.
    @MainActor
    func startRest(
        duration durationSeconds: TimeInterval,
        session: WorkoutSessionModel,
        currentExerciseIndex: Int = 0,
        alertSound: Bool = true
    ) {
        // `durationSeconds` is caller-supplied and not guaranteed finite. `Int(_:)` traps on NaN or
        // infinity, and a one-sided `max(0, durationSeconds)` does not filter NaN either — every
        // comparison against NaN is false, so it would pass straight through. Sanitise once, up
        // front, before either the logged value or the stored duration is derived from it.
        let duration = durationSeconds.clamped(to: 0...86_400, whenNotFinite: 0)
        logger.trackEvent(event: Event.startRestCalled(durationSeconds: Int(duration), liveActivityUpdaterIsNil: liveActivityUpdater == nil))
        // Only the timer: `cancelRest()` also pushes "no rest" to the Live Activity, and that push
        // and the one below are two unordered tasks — a "Rest over" frame before every countdown,
        // or the countdown lost if they ever swap.
        cancelRestTimer()

        let now = Date()
        restEndTime = now.addingTimeInterval(duration)
        restStartedAt = now

        // Written to the App Group so the widget can read it and a relaunch can take it back.
        storage.restEndTime = restEndTime
        storage.restStartedAt = now

        // Update Live Activity immediately to show Resting countdown
        liveActivityUpdater?.updateLiveActivity(params: LiveActivityUpdateParams(
            session: session,
            isActive: isWorkoutActive,
            currentExerciseIndex: currentExerciseIndex,
            restEndsAt: restEndTime
        ))

        // Schedule timer to fire exactly at rest end, even when app is backgrounded
        if let endTime = restEndTime {
            scheduleRestEndTimer(endTime: endTime)
            restAlertSound = alertSound
            scheduleRestOverNotification(endTime: endTime, session: session, currentExerciseIndex: currentExerciseIndex)
        }
    }

    /// How long after the end of a rest the backstop notification waits for `endRest` to withdraw
    /// it and alert through the Live Activity instead.
    static let restOverBackstopDelay = RestOverAlert.standInDelay

    /// With no Live Activity the notification is the rest-over alert, due on the second. With one,
    /// the activity alerts from `endRest`, but that needs the app running: a suspended app's timer
    /// does not fire until it is next woken, so the notification is still scheduled, a moment
    /// late, and `endRest` withdraws it when it gets there first. Scheduling again under the same
    /// id replaces the pending request, so +15s moves it rather than adding a second.
    private func scheduleRestOverNotification(endTime: Date, session: WorkoutSessionModel, currentExerciseIndex: Int) {
        let date = RestOverAlert.notificationDate(
            restEnd: endTime,
            showingLiveActivity: liveActivityUpdater?.isShowingLiveActivity == true
        )
        let body = liveActivityUpdater?.restOverMessage(session: session, currentExerciseIndex: currentExerciseIndex)
        let sound = restAlertSound
        let notifier = restOverNotifier
        enqueueRestAlert { await notifier.scheduleRestOverNotification(at: date, body: body, sound: sound) }
    }

    private func withdrawRestOverNotification() {
        let notifier = restOverNotifier
        enqueueRestAlert { notifier.cancelRestOverNotification() }
    }

    private func enqueueRestAlert(_ work: @escaping @MainActor () async -> Void) {
        let previous = restAlertQueue
        restAlertQueue = Task {
            await previous?.value
            await work()
        }
    }

    /// Stops the timer and forgets the end time, here and in the app group. No Live Activity push.
    /// The start is kept: a rest that ran out reads Ready until the next set.
    private func cancelRestTimer() {
        restTimer?.cancel()
        restTimer = nil
        restEndTime = nil
        storage.restEndTime = nil
    }

    /// Cancel any pending rest and clear countdown from Live Activity.
    func cancelRest() {
        logger.trackEvent(event: Event.cancelRestCalled)
        cancelRestTimer()
        restStartedAt = nil
        storage.restStartedAt = nil
        // Skip, finish and discard all come through here: a rest called off has nothing to announce.
        withdrawRestOverNotification()

        // Update Live Activity to clear rest state (use updateRestAndActive to preserve exercise index)
        liveActivityUpdater?.updateRestAndActive(isActive: isWorkoutActive, restEndsAt: nil)
    }

    /// Called automatically when the scheduled rest end time is reached.
    func endRest() {
        logger.trackEvent(event: Event.endRestCalled)
        let endedAt = restEndTime
        cancelRestTimer()

        // Announced before the Live Activity guards below: a rest that has run out is over whether
        // or not there is an activity left to redraw, and the screen that tells the user is not
        // this manager's business. Posted as `self` so a listener can tell one manager's rest
        // from another's; the tracker listens by name alone.
        NotificationCenter.default.post(name: Constants.workoutRestDidComplete, object: self)

        // The Live Activity is the rest-over channel when there is one. On time (the app is in
        // front, or kept running behind a locked screen by the workout session), it takes over from
        // the backstop notification; late (the app was suspended and has just woken), the
        // notification has already said it, and the activity is only cleared below.
        let channel = endedAt.map {
            RestOverAlert.channel(
                showingLiveActivity: liveActivityUpdater?.isShowingLiveActivity == true,
                lateBy: Date().timeIntervalSince($0),
                sound: restAlertSound
            )
        } ?? .notification
        if channel != .notification {
            withdrawRestOverNotification()
        }
        if channel == .liveActivity, let updater = liveActivityUpdater {
            updater.announceRestOver(isActive: isWorkoutActive)
            return
        }

        guard activeSessionModel != nil else {
            logger.trackEvent(event: Event.endRestNoSession)
            return
        }

        guard liveActivityUpdater != nil else {
            logger.trackEvent(event: Event.endRestNoUpdater)
            return
        }
        
        // Update Live Activity to clear rest state (use updateRestAndActive to preserve exercise index)
        liveActivityUpdater?.updateRestAndActive(isActive: isWorkoutActive, restEndsAt: nil)
    }

    // Deliberately MainActor-isolated rather than `nonisolated`, and both callers are already on
    // MainActor. `timer.resume()` arms the timer immediately, and storing it into `restTimer` used
    // to be deferred to a separate `Task { @MainActor ... }` hop — which meant a caller that started
    // a rest and cancelled it again in the same synchronous scope (as `cancelRest()`,
    // `endWorkout()` and `discardWorkout()` can all do) found
    // `restTimer` still nil and had nothing to cancel, leaving the real timer armed to fire and
    // announce a rest that had already been called off. Assigning synchronously here closes that
    // window: `restTimer` holds the live timer before this function returns.
    private func scheduleRestEndTimer(endTime: Date) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        let delta = max(0, endTime.timeIntervalSinceNow)
        // A tight leeway: in the background the system may otherwise coalesce the timer past the
        // stand-in notification's two seconds, and the Live Activity would lose the alert to it.
        timer.schedule(deadline: .now() + delta, leeway: .milliseconds(100))
        // `@Sendable` is load-bearing, not decoration. This function is MainActor-isolated so that
        // `restTimer` can be assigned synchronously below, but a DispatchSource event handler runs
        // on the queue the source was made with — the global utility queue here. Without the
        // annotation the closure inherits this function's MainActor isolation, and Swift's
        // isolation check asserts it is on the main queue when it is not, trapping the process the
        // moment a rest runs out. Marking it explicitly keeps the handler nonisolated, and the
        // hop to MainActor stays where it belongs, inside the Task.
        timer.setEventHandler { @Sendable [weak self] in
            Task { @MainActor [weak self] in
                self?.logger.trackEvent(event: Event.restTimerFired)
                self?.endRest()
            }
        }
        restTimer = timer
        timer.resume()

        logger.trackEvent(event: Event.restTimerScheduled(endTime: endTime, deltaSeconds: delta))
    }

    // MARK: - Relaunch

    /// At launch, takes back what a killed process left in `storage`: the pause, so a paused
    /// workout comes back paused with the right clock, and the rest, re-armed for what is left or,
    /// if it ran out meanwhile, ended once. The notification scheduled with it has already spoken,
    /// so ending it late announces nothing a second time (`RestOverAlert.channel`).
    ///
    /// With no workout to resume, whatever was left behind is stale and is cleared.
    func restoreAfterLaunch(activeSession: WorkoutSessionModel?, now: Date = Date()) {
        guard let activeSession else {
            storage.restEndTime = nil
            storage.restStartedAt = nil
            storage.pausedAt = nil
            storage.pausedDuration = 0
            return
        }
        activeSessionModel = activeSession
        pausedDuration = storage.pausedDuration
        pausedAt = storage.pausedAt
        restStartedAt = storage.restStartedAt
        switch RestRestore.plan(restEnd: storage.restEndTime, restStartedAt: restStartedAt, now: now) {
        case let .running(end, _):
            restEndTime = end
            scheduleRestEndTimer(endTime: end)
        case let .ended(end):
            restEndTime = end
            endRest()
        case .none:
            break
        }
    }
}

#endif
