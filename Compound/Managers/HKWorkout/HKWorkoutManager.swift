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
    private(set) var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private(set) var state: HKWorkoutSessionState = .notStarted

    let logger: LogManager

    private var timer: Timer?
    // Rest timer management for background-safe updates. Written only by `+Rest`.
    var restTimer: DispatchSourceTimer?
    var restEndTime: Date?
    /// When the rest began. Kept after it runs out, so the inline timer reads Ready until the next
    /// set; cleared with the rest when it is called off. Written only by `+Rest`.
    var restStartedAt: Date?

    /// Where the rest and the pause outlive the process: the App Group, or a test's own store.
    let storage: SharedWorkoutStorage.Store

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

    /// When the workout was paused, while it is. Kept in `storage` too, so a relaunch comes back
    /// paused.
    var pausedAt: Date? {
        didSet { storage.pausedAt = pausedAt }
    }
    /// Time spent paused before the current pause, so the tracker's clock can leave it out.
    var pausedDuration: TimeInterval = 0 {
        didSet { storage.pausedDuration = pausedDuration }
    }

    /// Everything spent paused up to `date`, the current pause included.
    func totalPausedDuration(at date: Date) -> TimeInterval {
        pausedDuration + (pausedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    private var isDiscarding = false
    private var workout: HKWorkout?
    /// Only tells `endRest` whether a workout is running. It is the session as it was at
    /// `startWorkout` (or at a relaunch), so it must never be pushed to the Live Activity: ending
    /// the activity with it from here raced the real end and put a zero-set summary on the Lock
    /// Screen.
    var activeSessionModel: WorkoutSessionModel?

    // Weak reference to avoid circular dependency
    weak var liveActivityUpdater: LiveActivityUpdating?

    /// The rest-over notification, for people with Live Activities off and as the backstop when
    /// the app is suspended at the end of a rest.
    let restOverNotifier: RestOverNotifying
    /// Schedules and withdrawals run in the order they were asked for: a withdrawal that overtook
    /// the schedule before it would leave the notification standing.
    var restAlertQueue: Task<Void, Never>?
    /// The rest timer's Play Sound setting, handed in with each rest.
    var restAlertSound = true

    // Buffers a single newest element; ensures async operations are serialized
    // since the loop doesn't start the next iteration until consumeSessionStateChange returns.
    private let asyncStreamTuple = AsyncStream.makeStream(of: SessionStateChange.self,
                                                          bufferingPolicy: .bufferingNewest(1))

    init(
        logger: LogManager,
        liveActivityUpdater: LiveActivityUpdating? = nil,
        restOverNotifier: RestOverNotifying = PushManager(),
        storage: SharedWorkoutStorage.Store = SharedWorkoutStorage.appGroup
    ) {
        self.logger = logger
        self.liveActivityUpdater = liveActivityUpdater
        self.restOverNotifier = restOverNotifier
        self.storage = storage
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
                // Restarted after a relaunch while paused: Apple Health follows the clock.
                if pausedAt != nil { session?.pause() }
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

    // MARK: - Relaunch

    /// After a cold launch, picks the Apple Health session back up for `workout`: recovered when
    /// HealthKit still holds it, otherwise started again. Only for the workout a session was
    /// started for, and only while none is running, so the same workout never gets a second one.
    func recoverHealthKitSession(for workout: WorkoutSessionModel) async {
        guard session == nil, storage.hkStartedSessionId == workout.id else { return }
        let recovered: HKWorkoutSession?
        do {
            recovered = try await healthStore.recoverActiveWorkoutSession()
        } catch {
            logger.trackEvent(event: Event.workoutSessionFailed(error: error))
            recovered = nil
        }
        // Checked again: something may have started a session while HealthKit answered.
        guard session == nil else { return }
        logger.trackEvent(event: Event.healthKitSessionRelaunched(recovered: recovered != nil))
        guard let recovered else {
            setWorkoutConfiguration(activityType: .traditionalStrengthTraining, location: .indoor)
            startWorkout(workout: workout)
            return
        }
        activeSessionModel = workout
        session = recovered
        builder = recovered.associatedWorkoutBuilder()
        recovered.delegate = self
        builder?.delegate = self
        state = recovered.state
        startWorkoutTimer()
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
        case healthKitSessionRelaunched(recovered: Bool)

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
            case .healthKitSessionRelaunched: return "HKWorkoutMan_Session_Relaunched"
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
            case .healthKitSessionRelaunched(let recovered):
                return ["hk_recovered": recovered]
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
