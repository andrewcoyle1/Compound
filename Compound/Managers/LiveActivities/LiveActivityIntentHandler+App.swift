//
//  LiveActivityIntentHandler+App.swift
//  Compound
//
//  The app's implementation of `LiveActivityIntentHandling`
//  (spec: docs/specs/live-activity.md §7.1).
//
//  A `LiveActivityIntent` runs in this process, so the button on the Live Activity can do the
//  work here and now rather than leaving a note in the app group for something to poll. The v1
//  hand-off did poll, from a timer that only started once HealthKit's `beginCollection` had
//  succeeded — which is why Complete Set advanced the widget and logged nothing on a phone where
//  HealthKit was declined.
//
//  Every action finishes by pushing the saved session to the activity, so the app is the single
//  source of truth for what the activity shows.
//

import Foundation

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

@MainActor
final class AppLiveActivityIntentHandler: LiveActivityIntentHandling {

    private let workoutSessionManager: WorkoutSessionManager
    private let hkWorkoutManager: HKWorkoutManager
    private let liveActivityUpdater: any LiveActivityUpdating
    private let workoutSettingsManager: WorkoutSettingsManager
    private let exerciseSettingsManager: ExerciseSettingsManager
    private let exerciseModelManager: ExerciseModelManager

    /// What finishing needs beyond the session: see `WorkoutFinishManagers`. Strava is optional so
    /// a test can build the handler without it.
    private let gymProfileManager: GymProfileManager
    private let mesocycleManager: MesocycleManager
    private let userManager: UserManager
    private let macrocycleManager: MacrocycleManager?
    private let stravaManager: StravaManager?
    private let logManager: LogManager
    /// Where the tracker keeps the exercise the user is on and the rests set by hand on a row.
    private let screenStateStore: UserDefaults

    init(
        workoutSessionManager: WorkoutSessionManager,
        hkWorkoutManager: HKWorkoutManager,
        liveActivityUpdater: any LiveActivityUpdating,
        workoutSettingsManager: WorkoutSettingsManager,
        exerciseSettingsManager: ExerciseSettingsManager,
        exerciseModelManager: ExerciseModelManager,
        gymProfileManager: GymProfileManager,
        mesocycleManager: MesocycleManager,
        userManager: UserManager,
        macrocycleManager: MacrocycleManager? = nil,
        stravaManager: StravaManager? = nil,
        logManager: LogManager = LogManager(services: []),
        screenStateStore: UserDefaults = ActiveWorkoutScreenState.appGroupStore
    ) {
        self.workoutSessionManager = workoutSessionManager
        self.hkWorkoutManager = hkWorkoutManager
        self.liveActivityUpdater = liveActivityUpdater
        self.workoutSettingsManager = workoutSettingsManager
        self.exerciseSettingsManager = exerciseSettingsManager
        self.exerciseModelManager = exerciseModelManager
        self.gymProfileManager = gymProfileManager
        self.mesocycleManager = mesocycleManager
        self.userManager = userManager
        self.macrocycleManager = macrocycleManager
        self.stravaManager = stravaManager
        self.logManager = logManager
        self.screenStateStore = screenStateStore
    }

    // MARK: - LiveActivityIntentHandling

    /// Log the set with this id and start the rest that follows it, by the rule the tracker's log
    /// button uses (`ActiveWorkout.log`): a set that is not ready is refused, the row's own rest
    /// wins, nothing rests after the workout's last set, and a superset moves on to the partner.
    ///
    /// The values logged are the set's own — the weight, reps, duration and distance already on it
    /// — not the activity's `target*` fields, which are a formatted copy that can be a push behind.
    func completeSet(id: String) async {
        guard let session = workoutSessionManager.activeSession,
              let exercise = session.exercises.first(where: { $0.sets.contains { $0.id == id } })
        else { return pushActiveSession() }

        let settings = workoutSettingsManager.workoutSettings
        var screenState = ActiveWorkoutScreenState.load(sessionId: session.id, from: screenStateStore)
        guard let outcome = ActiveWorkout.log(
            setId: id,
            in: session,
            settings: settings,
            context: restContext(for: exercise),
            customRestSeconds: screenState.customRestSeconds[id],
            isAssisted: exerciseModelManager.allExercises.first { $0.id == exercise.templateId }?.isAssisted ?? false
        ), outcome.problem == nil, save(outcome.session) else { return pushActiveSession() }

        // Stays on the exercise just logged unless the rule moves on; the manager points a
        // finished exercise's push at the next one with work left.
        let focusId = outcome.focusExerciseId ?? exercise.id
        screenState.focusExerciseId = focusId
        screenState.save(to: screenStateStore)
        let index = exerciseIndex(focusedOn: focusId, in: outcome.session)

        if settings.useRestTimers, let rest = outcome.restSeconds {
            hkWorkoutManager.startRest(
                durationSeconds: rest,
                session: outcome.session,
                currentExerciseIndex: index,
                alertSound: settings.restTimerPlaySound
            )
        }
        push(outcome.session, exerciseIndex: index)
    }

    /// Correct the reps of a set already logged, while the rest after it is still running.
    ///
    /// Reps and nothing else: the correction is about what was lifted, not when, so `completedAt`
    /// stays as it was logged. Outside the rest there is no set to correct and the tap is dropped.
    func adjustLastSetReps(id: String, delta: Int) async {
        guard runningRestEndTime != nil,
              let session = workoutSessionManager.activeSession,
              let location = locate(setId: id, in: session) else { return pushActiveSession() }

        var exercises = session.exercises
        let base = exercises[location.exerciseIndex].sets[location.setIndex].reps ?? 0
        exercises[location.exerciseIndex].sets[location.setIndex].reps = min(max(base + delta, 0), 99)

        var updated = session
        updated.updateExercises(exercises)
        guard save(updated) else { return pushActiveSession() }

        push(updated, exerciseIndex: currentExerciseIndex(in: updated))
    }

    /// Lengthen (or shorten) the running rest, never past now.
    func adjustRest(by seconds: Int) async {
        guard let restEndTime = runningRestEndTime,
              let session = workoutSessionManager.activeSession else { return pushActiveSession() }

        let proposed = restEndTime.addingTimeInterval(TimeInterval(seconds))
        let remaining = max(1, proposed.timeIntervalSinceNow)
        let exerciseIndex = currentExerciseIndex(in: session)

        // `startRest` cancels the running timer, reschedules on the new end and pushes, so the
        // adjustment goes through the one place that owns the rest rather than moving a date.
        hkWorkoutManager.startRest(
            duration: remaining,
            session: session,
            currentExerciseIndex: exerciseIndex,
            alertSound: workoutSettingsManager.workoutSettings.restTimerPlaySound
        )
        push(session, exerciseIndex: exerciseIndex)
    }

    /// End the running rest now.
    func skipRest() async {
        hkWorkoutManager.cancelRest()
        guard let session = workoutSessionManager.activeSession else { return }
        push(session, exerciseIndex: currentExerciseIndex(in: session))
    }

    /// Finish the workout through the same routine as the tracker's Finish button. There is no
    /// screen here to retry through, so the first answer is the answer; a failed save leaves the
    /// active session in place for Training to offer again.
    func completeWorkout() async {
        guard var session = workoutSessionManager.activeSession else { return }
        let now = Date()
        session.endSession(at: now, pausedSeconds: hkWorkoutManager.totalPausedDuration(at: now))

        _ = await finishWorkout(session, using: WorkoutFinishManagers(
            sessions: workoutSessionManager,
            hkWorkout: hkWorkoutManager,
            liveActivity: liveActivityUpdater,
            gymProfiles: gymProfileManager,
            mesocycles: mesocycleManager,
            users: userManager,
            macrocycles: macrocycleManager,
            strava: stravaManager,
            logger: logManager
        ))
    }

    // MARK: - Helpers

    private struct SetLocation {
        let exerciseIndex: Int
        let setIndex: Int
    }

    private func locate(setId: String, in session: WorkoutSessionModel) -> SetLocation? {
        for (exerciseIndex, exercise) in session.exercises.enumerated() {
            if let setIndex = exercise.sets.firstIndex(where: { $0.id == setId }) {
                return SetLocation(exerciseIndex: exerciseIndex, setIndex: setIndex)
            }
        }
        return nil
    }

    /// Saves through the active session, and answers whether it stuck. A failed write means the
    /// set was not logged, so nothing downstream of it should run either.
    private func save(_ session: WorkoutSessionModel) -> Bool {
        do {
            try workoutSessionManager.updateActiveSession(session)
            return true
        } catch {
            return false
        }
    }

    private func restContext(for exercise: WorkoutExerciseModel) -> RestDurationRules.ExerciseContext {
        RestDurationRules.ExerciseContext(
            restOverrideSeconds: exerciseSettingsManager.restOverride(for: exercise.templateId),
            exerciseTypeRawValue: exerciseModelManager.allExercises
                .first(where: { $0.id == exercise.templateId })?.type?.rawValue,
            planRestSeconds: exercise.restSeconds
        )
    }

    /// The push an action that changed nothing still owes.
    ///
    /// The intent put the activity into its loading state before calling in, and only a push from
    /// here — `makeContentState` sets `isProcessingIntent: false` — takes it out again. A tap on a
    /// set already logged, or a correction after the rest ran out, would otherwise leave the
    /// button dead until the tracker's next tick. With no active session there is nothing to push
    /// and no activity that should still be up.
    private func pushActiveSession() {
        guard let session = workoutSessionManager.activeSession else { return }
        push(session, exerciseIndex: currentExerciseIndex(in: session))
    }

    /// Pushes the saved session to the activity, the same shape `WorkoutTrackerPresenter`
    /// pushes when the tracker is on screen.
    ///
    /// `isActive` is the pause the person chose, not the HealthKit session state: a workout that
    /// has not been paused is under way whether or not HealthKit ever started collecting.
    private func push(_ session: WorkoutSessionModel, exerciseIndex: Int) {
        liveActivityUpdater.updateLiveActivity(params: LiveActivityUpdateParams(
            session: session,
            isActive: hkWorkoutManager.isWorkoutActive,
            currentExerciseIndex: exerciseIndex,
            restEndsAt: runningRestEndTime
        ))
    }

    /// The end of the rest that is running, or nil when none is.
    ///
    /// The HealthKit manager's own `restEndTime` is the first word, but it starts nil in every new
    /// process. An intent tapped after iOS has dropped the app from memory launches a fresh one, so
    /// the rest that started before the launch is only known through the app group, where
    /// `startRest` wrote it. Without the fallback a "+15s" or a reps correction after a cold launch
    /// found no rest and did nothing.
    private var runningRestEndTime: Date? {
        let endTime = hkWorkoutManager.restEndTime ?? SharedWorkoutStorage.restEndTime
        guard let endTime, endTime > Date() else { return nil }
        return endTime
    }

    /// The exercise the user is on, as the tracker or the last log here left it in the screen
    /// state, else the first with a set still to log. The manager moves a finished one on.
    private func currentExerciseIndex(in session: WorkoutSessionModel) -> Int {
        let focusId = ActiveWorkoutScreenState.load(sessionId: session.id, from: screenStateStore).focusExerciseId
        return exerciseIndex(focusedOn: focusId, in: session)
    }

    private func exerciseIndex(focusedOn exerciseId: String?, in session: WorkoutSessionModel) -> Int {
        let focused = session.exercises.firstIndex { $0.id == exerciseId } ?? 0
        return LiveActivityManager.exerciseIndexWithWorkLeft(from: focused, in: session)
    }
}

#endif
