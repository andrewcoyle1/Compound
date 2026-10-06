//
//  WorkoutTrackerInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 09/12/2025.
//

import Foundation
import HealthKit

/// Parameters for updating a workout live activity's status and metrics.
struct LiveActivityUpdateParams {
    let session: WorkoutSessionModel
    let isActive: Bool
    let currentExerciseIndex: Int
    let restEndsAt: Date?
}

/// Interactor protocol for handling all interactions between the Workout Tracker view model
/// and data/services, supporting HealthKit session handling, local persistence, notifications,
/// user event tracking, rest timing, preferences, and history management.
@MainActor
protocol WorkoutTrackerInteractor: GlobalInteractor, PreviousWorkoutReferenceResolving {

    // MARK: - User and Session Properties

    /// The current logged-in user, or nil if not available.
    var currentUser: UserModel? { get }
    /// The favourite gym profile of the user, or nil if not available
    var favouriteGymProfile: GymProfileModel? { get }

    func setActiveWorkoutGymProfile(_ profile: GymProfileModel?)

    func getGymProfile(gymProfileId: String) async throws -> GymProfileModel
    
    /// The current rest end time for the active session, if any.
    var restEndTime: Date? { get }

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
    
    /// Create a new workout session and store it locally.
    func saveWorkoutSession(_ session: WorkoutSessionModel) async throws
    func updateActiveSession(_ session: WorkoutSessionModel) throws
    
    func getWorkoutSession(id: String) async throws -> WorkoutSessionModel
    /// End a remote (possibly HealthKit) workout session asynchronously at provided date.

    func endWorkoutSession(_ session: WorkoutSessionModel) async throws
    func deleteActiveSession() throws 

    /// The whole finish — HealthKit, the save, the Live Activity and the side effects — for a
    /// session already stamped with `endedAt`. Answers how the save went so it can be retried.
    func finishWorkout(_ session: WorkoutSessionModel) async -> WorkoutSaveOutcome

    var allExercises: [ExerciseModel] { get }
    
    // MARK: - Workout History

    /// Lookup the last completed session for a given template and author, if present.
    /// `inMesocycleId` narrows the search to that one mesocycle; `nil` searches every session.
    func getLastCompletedSessionForTemplate(
        templateId: String,
        authorId: String,
        inMesocycleId: String?
    ) async throws -> WorkoutSessionModel?

    /// The same lookup, several sessions deep and most recent first — what smart progression
    /// reasons from.
    func getLastCompletedSessionsForTemplate(
        templateId: String,
        authorId: String,
        inMesocycleId: String?,
        limit: Int
    ) async throws -> [WorkoutSessionModel]

    /// What smart progression suggests for each exercise of a session already under way, keyed
    /// by the exercise's `templateId`.
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

extension CoreInteractor: WorkoutTrackerInteractor {
                                
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
