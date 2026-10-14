//
//  WorkoutTrackerInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 09/12/2025.
//

import HealthKit
import UIKit

/// Interactor protocol for handling all interactions between the Workout Tracker view model
/// and data/services, supporting HealthKit session handling, local persistence, notifications,
/// user event tracking, rest timing, preferences, and history management.
@MainActor
protocol WorkoutTrackerInteractor: GlobalInteractor, PreviousWorkoutReferenceResolving {

    // MARK: - User and Session Properties

    /// The current logged-in user, or nil if not available.
    var currentUser: UserModel? { get }
    /// The gym this workout is at: the one set with `setActiveWorkoutGymProfile`, else the
    /// favourite.
    var workoutGymProfile: GymProfileModel? { get }

    func setActiveWorkoutGymProfile(_ profile: GymProfileModel?)

    func getGymProfile(gymProfileId: String) async throws -> GymProfileModel

    /// A workout template held on this device, for the gym it was written for.
    func getWorkoutTemplate(id: String) -> WorkoutTemplateModel?

    /// The user's mesocycles, whose day plans hold each exercise's mesocycle note.
    var mesocycles: [Mesocycle] { get }
    func saveMesocycle(mesocycle: Mesocycle) async throws

    /// The tracker's own state for `sessionId` (`ActiveWorkoutScreenState`), which a rebuilt
    /// tracker and the Live Activity's handler read too.
    func loadScreenState(sessionId: String) -> ActiveWorkoutScreenState
    func saveScreenState(_ state: ActiveWorkoutScreenState)

    /// The session whose Apple Health workout this device has started, so a rebuilt tracker does
    /// not start a second.
    var healthWorkoutSessionId: String? { get }
    func markHealthWorkoutStarted(sessionId: String)
    func clearHealthWorkoutSessionId()

    /// Keeps the screen from sleeping while the tracker is up (Workout Settings › Keep Alive).
    func setScreenKeptAwake(_ awake: Bool)
    
    /// The current rest end time for the active session, if any.
    var restEndTime: Date? { get }
    /// When that rest began, as the rest's owner recorded it, wherever it was started. Kept after
    /// it runs out, so the inline timer reads Ready until the next set.
    var restStartedAt: Date? { get }
    /// The last session finished on this device, from here or from the Live Activity.
    var lastFinishedSession: WorkoutSessionModel? { get }

    /// The current active workout session, if any.
    var activeSession: WorkoutSessionModel? { get }

    // MARK: - HealthKit Authorization

    func canRequestHealthDataAuthorisation() -> Bool
    func requestHealthKitAuthorisation(for scope: HealthDataScope) async throws
    func needsAuthorisationForRequiredTypes() -> Bool

    // MARK: - Workout Session Configuration & Lifecycle

    #if !targetEnvironment(macCatalyst)
    /// Set the configuration for a HealthKit workout session.
    func setWorkoutConfiguration(
        activityType: HKWorkoutActivityType,
        location: HKWorkoutSessionLocationType
    )
    
    func startWorkout(workout: WorkoutSessionModel)
    
    /// Discard the current workout without saving to HealthKit.
    func discardWorkout()
    
    /// False while the workout is paused.
    var isWorkoutActive: Bool { get }
    
    /// Pauses a running workout or resumes a paused one: the clock, the Apple Health session and
    /// the Live Activity together.
    func togglePause()
    
    /// Time spent paused up to `date`, which the workout clock leaves out.
    func totalPausedDuration(at date: Date) -> TimeInterval
    
    // MARK: - Live Activity & Status Updates

    /// Ensure the associated live activity for a workout is continued or started.
    func ensureLiveActivity(
        session: WorkoutSessionModel,
        isActive: Bool,
        currentExerciseIndex: Int,
        restEndsAt: Date?
    )

    /// End any running live activity for the provided workout session.
    func endLiveActivity(
        session: WorkoutSessionModel,
        isCompleted: Bool
    )

    /// Update live activity status and metrics for widgets/external presentation.
    func updateLiveActivity(params: LiveActivityUpdateParams)
    
    // MARK: - Rest

    /// Start a rest timer for the specified duration in seconds,
    /// associated with the current session/exercise state.
    func startRest(
        durationSeconds: Int,
        session: WorkoutSessionModel,
        currentExerciseIndex: Int
    )

    /// Cancel any running rest timer.
    func cancelRest()
#endif
    
    func updateActiveSession(_ session: WorkoutSessionModel) throws

    /// End a remote (possibly HealthKit) workout session asynchronously at provided date.
    func endWorkoutSession(_ session: WorkoutSessionModel) async throws
    func deleteActiveSession() throws 

    /// The whole finish — HealthKit, the save, the Live Activity and the side effects — for a
    /// session already stamped with `endedAt`. Answers how the save went so it can be retried.
    func finishWorkout(_ session: WorkoutSessionModel) async -> WorkoutSaveOutcome

    var allExercises: [ExerciseModel] { get }

    /// Today's bodyweight, which a movement's bodyweight contribution is a share of.
    var currentWeightKilograms: Double? { get }
    
    // MARK: - Workout History

    /// What smart progression suggests for each exercise of a session already under way, keyed
    /// by `ActiveWorkout.historyKey`.
    func progressionSuggestions(
        for session: WorkoutSessionModel,
        gymProfile: GymProfileModel?
    ) async -> [String: ProgressionSuggestion]

    /// Load the players for a sound before it is needed — the manager cannot play a sound it has
    /// not prepared, and a rest ending is too late to start loading one.
    func prepareSoundEffect(sound: SoundEffectFile, simultaneousPlayers: Int)

    /// Play a prepared sound.
    func playSoundEffect(sound: SoundEffectFile)

    /// The current workout settings.
    var workoutSettings: WorkoutSettings { get }

    /// Load unit preferences for an exercise template.
    func getPreference(templateId: String) -> ExerciseUnitPreference

    /// The rest set on this exercise itself, which wins over the settings' defaults.
    func exerciseRestOverride(for exerciseId: String) -> Int?
}

extension WorkoutTrackerInteractor {

    /// Whether the library exercise `templateId` is tracked as assistance, so its sets store a
    /// negative weight (`ExerciseModel.isAssisted`). Unknown exercises are not.
    func isAssisted(templateId: String) -> Bool {
        allExercises.first { $0.id == templateId }?.isAssisted ?? false
    }
}

extension CoreInteractor: WorkoutTrackerInteractor {

    func loadScreenState(sessionId: String) -> ActiveWorkoutScreenState {
        ActiveWorkoutScreenState.load(sessionId: sessionId, from: ActiveWorkoutScreenState.appGroupStore)
    }

    func saveScreenState(_ state: ActiveWorkoutScreenState) {
        state.save(to: ActiveWorkoutScreenState.appGroupStore)
    }

    var healthWorkoutSessionId: String? { SharedWorkoutStorage.hkStartedSessionId }

    func markHealthWorkoutStarted(sessionId: String) {
        SharedWorkoutStorage.hkStartedSessionId = sessionId
    }

    func clearHealthWorkoutSessionId() {
        SharedWorkoutStorage.clearHKStartedSessionId()
    }

    func setScreenKeptAwake(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }

    func finishWorkout(_ session: WorkoutSessionModel) async -> WorkoutSaveOutcome {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        await Compound.finishWorkout(session, using: WorkoutFinishManagers(
            sessions: workoutSessionManager,
            hkWorkout: hkWorkoutManager,
            liveActivity: liveActivityManager,
            gymProfiles: gymProfileManager,
            mesocycles: mesocycleManager,
            users: userManager,
            macrocycles: macrocycleManager,
            strava: stravaManager,
            logger: logManager
        ))
        #else
        gymProfileManager.activeWorkoutGymProfile = nil
        return await saveFinishedWorkout(session, sessions: workoutSessionManager, logger: logManager)
        #endif
    }
}
