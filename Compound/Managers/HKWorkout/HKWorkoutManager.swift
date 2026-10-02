//
//  HKWorkoutManager.swift
//  Compound
//
//  Created by Andrew Coyle on 16/10/2025.
//

import Foundation
#if canImport(HealthKit) && !targetEnvironment(macCatalyst)
import HealthKit

@Observable
@MainActor
class HKWorkoutManager: NSObject {
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private(set) var state: HKWorkoutSessionState = .notStarted

    private let logger: LogManager

    private var timer: Timer?
    // Rest timer management for background-safe updates
    private var restTimer: DispatchSourceTimer?
    private(set) var restEndTime: Date?

    /// What the Live Activity's `isActive` means from here: the workout is not paused. The
    /// tracker treats a workout as active from the moment it opens, whether or not a HealthKit
    /// session ever got going, so `state == .running` was the wrong test: with HealthKit declined
    /// the state stays `.notStarted` and every rest push showed the banner as paused, until the
    /// next push from the tracker or the intent handler put it back.
    ///
    /// Read from the pause the person asked for, not from the HealthKit state, so Pause works on a
    /// phone that declined HealthKit and the banner follows at once rather than on the session's
    /// delegate callback.
    var isWorkoutActive: Bool { pausedAt == nil }

    /// When the workout was paused, while it is.
    private(set) var pausedAt: Date?
    /// Time spent paused before the current pause, so the tracker's clock can leave it out.
    private(set) var pausedDuration: TimeInterval = 0

    /// Everything spent paused up to `date`, the current pause included.
    func totalPausedDuration(at date: Date) -> TimeInterval {
        pausedDuration + (pausedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    private var isDiscarding = false
    private var workout: HKWorkout?
    /// Only tells `endRest` whether a workout is running. It is the session as it was at
    /// `startWorkout`, so it must never be pushed to the Live Activity: ending the activity with it
    /// from here raced the real end and put a zero-set summary on the Lock Screen.
    private var activeSessionModel: WorkoutSessionModel?

    // Weak reference to avoid circular dependency
    private weak var liveActivityUpdater: LiveActivityUpdating?

    /// The rest-over notification, for people with Live Activities off and as the backstop when
    /// the app is suspended at the end of a rest.
    private let restOverNotifier: RestOverNotifying
    /// Schedules and withdrawals run in the order they were asked for: a withdrawal that overtook
    /// the schedule before it would leave the notification standing.
    private var restAlertQueue: Task<Void, Never>?
    /// The rest timer's Play Sound setting, handed in with each rest.
    private var restAlertSound = true

    // Buffers a single newest element; ensures async operations are serialized
    // since the loop doesn't start the next iteration until consumeSessionStateChange returns.
    private let asyncStreamTuple = AsyncStream.makeStream(of: SessionStateChange.self,
                                                          bufferingPolicy: .bufferingNewest(1))

    init(
        logger: LogManager,
        liveActivityUpdater: LiveActivityUpdating? = nil,
        restOverNotifier: RestOverNotifying = PushManager()
    ) {
        self.logger = logger
        self.liveActivityUpdater = liveActivityUpdater
        self.restOverNotifier = restOverNotifier
        super.init()
        // Capture stream locally so the Task does not capture `self` before NSObject init completes.
        // The next value in the stream won't start processing until `consumeSessionStateChange` returns,
        // which serializes asynchronous operations.
        let stream = asyncStreamTuple.stream
        Task { [weak self] in
            for await value in stream {
                await self?.consumeSessionStateChange(value)
            }
        }
    }

    func setWorkoutConfiguration(
        activityType: HKWorkoutActivityType,
        location: HKWorkoutSessionLocationType
    ) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = location

        Task {
            do {
                try await prepareWorkout(configuration: configuration)
                metrics.supportsDistance = configuration.supportsDistance
                metrics.supportsSpeed = configuration.supportsSpeed
            } catch {
                logger.trackEvent(event: Event.startWorkoutFail(error: error))
                state = .notStarted
            }
        }
    }

    private func prepareWorkout(configuration: HKWorkoutConfiguration) async throws {
        state = .prepared

        session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        builder = session?.associatedWorkoutBuilder()
        session?.delegate = self
        builder?.delegate = self
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        session?.prepare()
    }
    
    func startWorkout(workout: WorkoutSessionModel) {
        logger.trackEvent(event: Event.startWorkoutStart)
        activeSessionModel = workout
        Task {
            do {
                let startDate = Date()
                session?.startActivity(with: startDate)
                try await builder?.beginCollection(at: startDate)
                startWorkoutTimer()
                logger.trackEvent(event: Event.startWorkoutSuccess)
            } catch {
                logger.trackEvent(event: Event.startWorkoutFail(error: error))
                state = .notStarted
            }
        }
    }

    // MARK: - State Control

    /// Stops the clock, pauses the Apple Health session when there is one, and shows the Live
    /// Activity's paused phase.
    func pause() {
        guard pausedAt == nil else { return }
        pausedAt = Date()
        session?.pause()
        stopTimer()
        liveActivityUpdater?.updateRestAndActive(isActive: false, restEndsAt: restEndTime)
    }

    func resume() {
        guard let pausedAt else { return }
        pausedDuration += max(0, Date().timeIntervalSince(pausedAt))
        self.pausedAt = nil
        session?.resume()
        if session != nil { startWorkoutTimer() }
        liveActivityUpdater?.updateRestAndActive(isActive: true, restEndsAt: restEndTime)
    }

    func togglePause() {
        if isWorkoutActive {
            pause()
        } else {
            resume()
        }
    }

    /// A new workout starts unpaused, whatever the last one ended as.
    private func resetPause() {
        pausedAt = nil
        pausedDuration = 0
    }

    func endWorkout() {
        state = .stopped
        session?.stopActivity(with: .now)
        stopTimer()
        resetPause()
        // Ensure any pending rest is cancelled when ending workout
        cancelRest()
    }

    // MARK: - Workout Metrics
    var metrics: MetricsModel = MetricsModel(elapsedTime: 0)

    func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics else { return }

        guard let activityType = session?.activityType else {
            logger.trackEvent(event: Event.activityTypeNil)
            return
        }

        if WorkoutTypes.distanceQuantityType(for: activityType) == statistics.quantityType {
            let meterUnit = HKUnit.meter()
            self.metrics.distance = statistics.sumQuantity()?.doubleValue(for: meterUnit)
            return
        }

        if WorkoutTypes.speedQuantityType(for: activityType) == statistics.quantityType {
            let speedUnit = HKUnit.meter().unitDivided(by: HKUnit.second())
            self.metrics.speed = statistics.mostRecentQuantity()?.doubleValue(for: speedUnit)
            return
        }

        switch statistics.quantityType {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            self.metrics.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit)
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            let energyUnit = HKUnit.kilocalorie()
            self.metrics.activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit)
        default:
            logger.trackEvent(event: Event.quantityTypeUnhandled)
        }
    }

    func discardWorkout() {
        logger.trackEvent(event: Event.discardWorkout)
        isDiscarding = true
        session?.stopActivity(with: .now)

        builder = nil
        workout = nil
        activeSessionModel = nil

        metrics = MetricsModel(elapsedTime: 0)

        stopTimer()
        resetPause()
        cancelRest()
    }

    private func consumeSessionStateChange(_ change: SessionStateChange) async {
        guard change.newState == .stopped else { return }

        if isDiscarding {
            if #available(iOS 17, *) {
                builder?.discardWorkout()
            }
            session?.end()
            isDiscarding = false
            builder = nil
            session = nil
            state = .notStarted
            return
        }

        guard let builder else { return }

        let finishedWorkout: HKWorkout?
        logger.trackEvent(event: Event.finishWorkoutStart)

        do {
            try await builder.endCollection(at: change.date)
            finishedWorkout = try await builder.finishWorkout()
            self.metrics.elapsedTime = finishedWorkout?.duration ?? 0
            logger.trackEvent(event: Event.finishWorkoutSuccess)
            session?.end()
        } catch {
            logger.trackEvent(event: Event.finishWorkoutFail(error: error))
            return
        }
        workout = finishedWorkout
        state = .ended
    }

    // Starts a timer for the ongoing `workoutManager` session and updates the Live Activity.
    func startWorkoutTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.metrics.elapsedTime = self.builder?.elapsedTime ?? 0
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - HKWorkoutSessionDelegate
extension HKWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        Task { @MainActor in
            switch toState {
            case .running:
                self.state = .running
            case .paused:
                self.state = .paused
            default:
                // Fill this out as needed.
                break
            }
        }

        /**
         Yield the new state change to the asynchronous stream synchronously.
         `asynStreamTuple` is a constant, so it's nonisolated.
         */
        let sessionStateChange = SessionStateChange(newState: toState, date: date)
        asyncStreamTuple.continuation.yield(sessionStateChange)
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.logger.trackEvent(event: Event.workoutSessionFailed(error: error))
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension HKWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { return }

                let statistics = workoutBuilder.statistics(for: quantityType)

                // Update the published values.
                updateForStatistics(statistics)
            }
        }
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didEnd workoutActivity: HKWorkoutActivity) { }
}

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

        restEndTime = Date().addingTimeInterval(duration)

        // Write to shared storage so widget can read it
        SharedWorkoutStorage.restEndTime = restEndTime

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
    private func cancelRestTimer() {
        restTimer?.cancel()
        restTimer = nil
        restEndTime = nil
        SharedWorkoutStorage.clearRestEndTime()
    }

    /// Cancel any pending rest and clear countdown from Live Activity.
    func cancelRest() {
        logger.trackEvent(event: Event.cancelRestCalled)
        cancelRestTimer()
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
}

extension HKWorkoutManager {
    enum Event: LoggableEvent {
        case startWorkoutStart
        case startWorkoutSuccess
        case startWorkoutFail(error: Error)
        case finishWorkoutStart
        case finishWorkoutSuccess
        case finishWorkoutFail(error: Error)
        case discardWorkout
        case activityTypeNil
        case quantityTypeUnhandled
        case workoutSessionFailed(error: Error)
        case endRestNoSession
        case endRestNoUpdater
        case startRestCalled(durationSeconds: Int, liveActivityUpdaterIsNil: Bool)
        case restTimerScheduled(endTime: Date, deltaSeconds: Double)
        case restTimerFired
        case cancelRestCalled
        case endRestCalled

        var eventName: String {
            switch self {
            case .startWorkoutStart:        return "HKWorkoutMan_StartWorkout_Start"
            case .startWorkoutSuccess:      return "HKWorkoutMan_StartWorkout_Success"
            case .startWorkoutFail:         return "HKWorkoutMan_StartWorkout_Fail"
            case .finishWorkoutStart:       return "HKWorkoutMan_FinishWorkout_Start"
            case .finishWorkoutSuccess:     return "HKWorkoutMan_FinishWorkout_Success"
            case .finishWorkoutFail:        return "HKWorkoutMan_FinishWorkout_Fail"
            case .discardWorkout:           return "HKWorkoutMan_DiscardWorkout"
            case .activityTypeNil:          return "HKWorkoutMan_ActivityType_Nil"
            case .quantityTypeUnhandled:    return "HKWorkoutMan_QuantityType_Unhandled"
            case .workoutSessionFailed:     return "HKWorkoutMan_Session_Failed"
            case .endRestNoSession:         return "HKWorkoutMan_EndRest_NoSession"
            case .endRestNoUpdater:         return "HKWorkoutMan_EndRest_NoUpdater"
            case .startRestCalled:          return "HKWorkoutMan_StartRest_Called"
            case .restTimerScheduled:       return "HKWorkoutMan_RestTimer_Scheduled"
            case .restTimerFired:           return "HKWorkoutMan_RestTimer_Fired"
            case .cancelRestCalled:         return "HKWorkoutMan_CancelRest_Called"
            case .endRestCalled:            return "HKWorkoutMan_EndRest_Called"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .startWorkoutFail(let error), .finishWorkoutFail(let error), .workoutSessionFailed(let error):
                return error.eventParameters
            case .startRestCalled(let durationSeconds, let liveActivityUpdaterIsNil):
                return [
                    "duration_seconds": durationSeconds,
                    "live_activity_updater_is_nil": liveActivityUpdaterIsNil
                ]
            case .restTimerScheduled(let endTime, let deltaSeconds):
                return [
                    "end_time": endTime.timeIntervalSince1970,
                    "delta_seconds": deltaSeconds
                ]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .startWorkoutFail, .finishWorkoutFail, .workoutSessionFailed:
                return .severe
            case .activityTypeNil, .quantityTypeUnhandled, .endRestNoSession, .endRestNoUpdater:
                return .warning
            case .startRestCalled(_, let liveActivityUpdaterIsNil) where liveActivityUpdaterIsNil:
                return .warning
            default:
                return .analytic
            }
        }
    }
}

extension CoreInteractor {
    // MARK: HKWorkoutManager

    func setWorkoutConfiguration(activityType: HKWorkoutActivityType, location: HKWorkoutSessionLocationType) {
        hkWorkoutManager.setWorkoutConfiguration(activityType: activityType, location: location)
    }

    func startWorkout(workout: WorkoutSessionModel) {
        hkWorkoutManager.startWorkout(workout: workout)
    }

    func endWorkout() {
        hkWorkoutManager.endWorkout()
    }

    func discardWorkout() {
        hkWorkoutManager.discardWorkout()
    }

    var isWorkoutActive: Bool {
        hkWorkoutManager.isWorkoutActive
    }

    func togglePause() {
        hkWorkoutManager.togglePause()
    }

    func totalPausedDuration(at date: Date) -> TimeInterval {
        hkWorkoutManager.totalPausedDuration(at: date)
    }

    // Rest Timer Management
    /// Begin a rest period and schedule a background-safe update at rest end.
    @MainActor
    func startRest(durationSeconds: Int, session: WorkoutSessionModel, currentExerciseIndex: Int = 0) {
        hkWorkoutManager.startRest(
            durationSeconds: durationSeconds,
            session: session,
            currentExerciseIndex: currentExerciseIndex,
            alertSound: workoutSettingsManager.workoutSettings.restTimerPlaySound
        )
    }

    /// Cancel any pending rest and clear countdown from Live Activity.
    @MainActor
    func cancelRest() {
        hkWorkoutManager.cancelRest()
    }

}
#endif

private struct SessionStateChange {
    #if !targetEnvironment(macCatalyst)
    let newState: HKWorkoutSessionState
    #endif
    let date: Date
}
