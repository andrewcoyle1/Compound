//
//  LiveActivityIntentHandler+App.swift
//  DialedIn
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

    /// What finishing needs beyond the session: see `WorkoutFinishManagers`. The streak and
    /// Strava are optional so a test can build the handler without them.
    private let gymProfileManager: GymProfileManager
    private let trainingProgramManager: TrainingProgramManager
    private let userManager: UserManager
    private let streakManager: StreakManager?
    private let stravaManager: StravaManager?
    private let logManager: LogManager

    init(
        workoutSessionManager: WorkoutSessionManager,
        hkWorkoutManager: HKWorkoutManager,
        liveActivityUpdater: any LiveActivityUpdating,
        workoutSettingsManager: WorkoutSettingsManager,
        exerciseSettingsManager: ExerciseSettingsManager,
        exerciseModelManager: ExerciseModelManager,
        gymProfileManager: GymProfileManager,
        trainingProgramManager: TrainingProgramManager,
        userManager: UserManager,
        streakManager: StreakManager? = nil,
        stravaManager: StravaManager? = nil,
        logManager: LogManager = LogManager(services: [])
    ) {
        self.workoutSessionManager = workoutSessionManager
        self.hkWorkoutManager = hkWorkoutManager
        self.liveActivityUpdater = liveActivityUpdater
        self.workoutSettingsManager = workoutSettingsManager
        self.exerciseSettingsManager = exerciseSettingsManager
        self.exerciseModelManager = exerciseModelManager
        self.gymProfileManager = gymProfileManager
        self.trainingProgramManager = trainingProgramManager
        self.userManager = userManager
        self.streakManager = streakManager
        self.stravaManager = stravaManager
        self.logManager = logManager
    }

    // MARK: - LiveActivityIntentHandling

    /// Log the set with this id and start the rest that follows it.
    ///
    /// The values logged are the set's own — the weight, reps, duration and distance already on it
    /// — not the activity's `target*` fields, which are a formatted copy that can be a push behind.
    /// Completing a set on the tracker does exactly the same thing: it sets `completedAt` and
    /// leaves the numbers alone.
    func completeSet(id: String) async {
        guard let session = workoutSessionManager.activeSession,
              let location = locate(setId: id, in: session) else { return pushActiveSession() }

        let exercise = session.exercises[location.exerciseIndex]
        let set = exercise.sets[location.setIndex]
        guard set.completedAt == nil else { return pushActiveSession() }

        var exercises = session.exercises
        exercises[location.exerciseIndex].sets[location.setIndex].completedAt = Date()

        var updated = session
        updated.updateExercises(exercises)
        guard save(updated) else { return pushActiveSession() }

        // The exercise to show is the one just tapped while it has work left, else the next one
        // with some: after its last set the finished exercise has no target, and a banner with no
        // target has no way out once the rest ends.
        let nextIndex = LiveActivityManager.exerciseIndexWithWorkLeft(from: location.exerciseIndex, in: updated)
        startRest(after: set, in: exercise, session: updated, exerciseIndex: nextIndex)
        push(updated, exerciseIndex: nextIndex)
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
        session.endSession(at: Date())

        _ = await finishWorkout(session, using: WorkoutFinishManagers(
            sessions: workoutSessionManager,
            hkWorkout: hkWorkoutManager,
            liveActivity: liveActivityUpdater,
            gymProfiles: gymProfileManager,
            programs: trainingProgramManager,
            users: userManager,
            streak: streakManager,
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

    /// The rest the set-row presenter would have started for this set, through the same rules.
    private func startRest(
        after set: WorkoutSetModel,
        in exercise: WorkoutExerciseModel,
        session: WorkoutSessionModel,
        exerciseIndex: Int
    ) {
        let settings = workoutSettingsManager.workoutSettings
        guard settings.useRestTimers else { return }

        let context = RestDurationRules.ExerciseContext(
            restOverrideSeconds: exerciseSettingsManager.restOverride(for: exercise.templateId),
            exerciseTypeRawValue: exerciseModelManager.allExercises
                .first(where: { $0.id == exercise.templateId })?.type?.rawValue
        )

        guard let duration = RestDurationRules.restAfterCompleting(
            set,
            in: exercise,
            settings: settings,
            context: context
        ) else { return }

        hkWorkoutManager.startRest(
            durationSeconds: duration,
            session: session,
            currentExerciseIndex: exerciseIndex,
            alertSound: settings.restTimerPlaySound
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
    /// `isActive` is true rather than read from the HealthKit session state: a workout the user
    /// has not paused is under way whether or not HealthKit ever started collecting, and reading
    /// the state would show the banner as paused on every phone that declined HealthKit.
    private func push(_ session: WorkoutSessionModel, exerciseIndex: Int) {
        liveActivityUpdater.updateLiveActivity(params: LiveActivityUpdateParams(
            session: session,
            isActive: true,
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

    /// The exercise the user is on when nothing says otherwise: the first with a set still to log.
    /// The manager owns that rule (its search wraps), so this asks it from the top rather than
    /// keeping a second copy.
    private func currentExerciseIndex(in session: WorkoutSessionModel) -> Int {
        LiveActivityManager.exerciseIndexWithWorkLeft(from: 0, in: session)
    }
}

#endif
