//
//  WorkoutTrackerPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI
import HealthKit

@Observable
@MainActor
class WorkoutTrackerPresenter {

    let interactor: WorkoutTrackerInteractor
    let router: WorkoutTrackerRouter

    /// How a failed save is retried. Injected so tests drive a schedule of milliseconds rather than
    /// waiting out the real one.
    let saveRetryBackoff: RetryBackoff

    /// The finishing work, kept so a retry still waiting its turn can be called off. It deliberately
    /// outlives this screen — the screen is dismissed before the save is even attempted — so
    /// something has to be able to stop it.
    var pendingFinishTask: Task<Void, Never>?

    // MARK: - State Properties
    var workoutSession: WorkoutSessionModel {
        didSet {
            saveWorkoutProgress()
            handleWorkoutSessionChange(from: oldValue)
        }
    }
    
    var workoutTemplate: WorkoutTemplateModel?
    var gymProfile: GymProfileModel?
    
    var pendingSelectedTemplates: [WorkoutTemplateExercise] = []

    var editMode: EditMode = .inactive
    
    var startTime: Date {
        self.workoutSession.dateCreated
    }
    
    var elapsedTime: TimeInterval = 0

    /// False while the workout is paused. The rest timer's owner keeps it, so a tracker reopened
    /// after being minimized still knows.
    var isActive: Bool {
#if !targetEnvironment(macCatalyst)
        interactor.isWorkoutActive
        #else
        true
        #endif
    }
    
    var expandedExerciseId: String?
    /// When the rest on screen began, for the inline timer's progress; kept after it runs out so
    /// the timer can read Ready. `nil` for a rest started from the Lock Screen.
    var restStartedAt: Date?
    /// Rests set by hand on a row, by set id, so the log button rests as long as the row would.
    var customRestSeconds: [String: Int] = [:]
    /// Exercises whose smart progression note has been dismissed this workout.
    var acknowledgedProgressionNotes: Set<String> = []
    var workoutNotes = ""
    var currentExerciseIndex = 0

    /// The exercise index to use for Live Activity updates — prefers the expanded exercise
    /// over `currentExerciseIndex` so the widget reflects what the user is actually working on,
    /// even when `exerciseAutoNext` is off and `currentExerciseIndex` hasn't advanced.
    private var liveActivityExerciseIndex: Int {
        if let id = expandedExerciseId,
           let idx = workoutSession.exercises.firstIndex(where: { $0.id == id }) {
            return idx
        }
        return currentExerciseIndex
    }
    
    /// What the user last did for each exercise on screen, keyed by the exercise's `templateId`.
    ///
    /// Per exercise rather than per session because `previousWorkoutReference` is: two exercises
    /// of the same workout can resolve to different past sessions when one of them is new to the
    /// template. See `loadPreviousWorkoutSession()`.
    var previousExercises: [String: WorkoutExerciseModel] = [:]

    /// What smart progression decided for each exercise, keyed by `templateId`. Drives the hint
    /// in the exercise header. See `WorkoutTrackerPresenter+Progression`.
    var progressionSuggestions: [String: ProgressionSuggestion] = [:]

    /// The values the screen filled in for the user, per set id. A set that still holds these
    /// may be re-suggested live; one the user has edited may not.
    var progressionBaseline: [String: SuggestedSet] = [:]

    // Prevents handleWorkoutSessionChange from double-processing when updateSet() is the caller
    var isProcessingUpdateSet = false

    /// Set once this screen has left — finished, discarded, or told the workout ended elsewhere.
    /// A write after that would put an ended session back as the active one.
    var isDone = false
    /// The save waiting out its debounce and the edit waiting to propagate. See `+Persistence`.
    @ObservationIgnored var savePath = WorkoutSavePath()

    var favouriteGymProfile: GymProfileModel? {
        interactor.favouriteGymProfile
    }
    
    // MARK: - Initialization
    
    init(
        interactor: WorkoutTrackerInteractor,
        router: WorkoutTrackerRouter,
        saveRetryBackoff: RetryBackoff = .workoutSave
    ) throws {
        self.interactor = interactor
        self.router = router
        self.saveRetryBackoff = saveRetryBackoff
        
        guard let session = interactor.activeSession else {
            throw WorkoutTrackerError.noActiveWorkout
        }
        
        self.workoutSession = Self.fillingMissingImages(session, from: interactor.allExercises)
        // Before anything the user does, so an edited set can be told from a filled-in one.
        captureProgressionBaseline()
        
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        // Ensure an existing Live Activity is reused, otherwise start one
        self.interactor.ensureLiveActivity(
            session: workoutSession,
            isActive: isActive,
            currentExerciseIndex: currentExerciseIndex,
            restEndsAt: interactor.restEndTime
        )
        #endif
        
        applyWarmupSetting()
        
        syncCurrentExerciseIndexToFirstIncomplete(in: workoutSession.exercises)

        // Expand first incomplete exercise by default (fallback to first if all complete)
        if let idx = firstIncompleteExerciseIndex(in: workoutSession.exercises) {
            expandedExerciseId = workoutSession.exercises[idx].id
        } else {
            expandedExerciseId = workoutSession.exercises.first?.id
        }
        
    }
    
    func onTask() async {
        guard let gymProfileId = self.workoutTemplate?.gymProfileId else { return }
        let profile: GymProfileModel?
        do {
            profile = try await interactor.getGymProfile(gymProfileId: gymProfileId)
        } catch {
            profile = nil
            interactor.trackEvent(event: Event.loadGymProfileFail(error: error))
        }
        self.gymProfile = profile
        interactor.setActiveWorkoutGymProfile(profile)
    }
    
    // MARK: - Computed Properties
    
    /// The workout clock at `date`, for the overview's ticking Elapsed Time. Paused time is left
    /// out, so the clock stands still while the workout is paused.
    func elapsedTime(at date: Date) -> String {
        #if !targetEnvironment(macCatalyst)
        Format.duration(max(0, date.timeIntervalSince(startTime) - interactor.totalPausedDuration(at: date)))
        #else
        Format.duration(max(0, date.timeIntervalSince(startTime)))
        #endif
    }

    // MARK: - Display Settings

    var showWorkoutTimer: Bool {
        interactor.workoutSettings.showWorkoutTimer
    }
    
    var showBodyweightContribution: Bool {
        interactor.workoutSettings.showBodyweightContribution
    }
    var showRIRTracking: Bool { interactor.workoutSettings.rirTracking }

    // MARK: - Lifecycle

    func onAppear() async {
        startObservingActiveSession()
        loadPreviousWorkoutSession()
        loadProgressionSuggestions()
        UIApplication.shared.isIdleTimerDisabled = interactor.workoutSettings.keepAlive

        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        // Return early if the HK session is already started — nothing more to do.
        guard SharedWorkoutStorage.hkStartedSessionId != workoutSession.id else { return }

        // Ask every time we're about to start a new HK session: HealthKit shows its sheet only for
        // types not yet asked about, so this also reaches users who granted workouts before the
        // scope gained heart rate and active energy.
        if interactor.canRequestHealthDataAuthorisation() {
            do {
                try await interactor.requestHealthKitAuthorisation(for: .workouts)
            } catch {
                interactor.trackEvent(event: Event.healthKitAuthorisationFail(error: error))
            }
        }

        guard !interactor.needsAuthorisationForRequiredTypes() else { return }

        interactor.setWorkoutConfiguration(activityType: .traditionalStrengthTraining, location: .indoor)
        interactor.startWorkout(workout: workoutSession)
        SharedWorkoutStorage.hkStartedSessionId = workoutSession.id
        #endif
    }

    private func applyWarmupSetting() {
        guard !interactor.workoutSettings.addSmartWarmUps else { return }
        var updated = workoutSession.exercises
        var changed = false
        for index in updated.indices {
            let before = updated[index].sets.count
            updated[index].sets.removeAll { $0.isWarmup && $0.completedAt == nil }
            if updated[index].sets.count != before {
                for jindex in updated[index].sets.indices { updated[index].sets[jindex].index = jindex + 1 }
                changed = true
            }
        }
        guard changed else { return }
        workoutSession.updateExercises(updated)
    }
            
    // MARK: - Workout Actions
    
    func discardWorkout() {
        interactor.trackEvent(event: Event.discardWorkoutStart)
        isDone = true
        interactor.setActiveWorkoutGymProfile(nil)
        do {
            try interactor.deleteActiveSession()
            interactor.trackEvent(event: Event.discardWorkoutSuccess)
        } catch {
            interactor.trackEvent(event: Event.discardWorkoutFail(error: error))
        }
        UIApplication.shared.isIdleTimerDisabled = false
        SharedWorkoutStorage.clearHKStartedSessionId()
        router.dismissScreen()

        let sessionSnapshot = workoutSession
        Task {
            #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
            interactor.discardWorkout()
            interactor.endLiveActivity(session: sessionSnapshot, isCompleted: false)
            #endif
        }
    }

    func onDiscardWorkoutPressed() {
        router.showAlert(
            title: String(localized: "Discard Workout?"),
            subtitle: String(localized: "The sets you logged will not be saved.")
        ) {
            AnyView(
                VStack {
                    Button("Cancel", role: .cancel) { }
                    Button("Discard", role: .destructive) {
                        self.discardWorkout()
                    }
                }
            )
        }
    }

    /// Pause and Resume in the menu. The clock, the Apple Health session and the Live Activity's
    /// paused phase all follow the one toggle.
    func onPauseResumePressed() {
        #if !targetEnvironment(macCatalyst)
        interactor.togglePause()
        #endif
        interactor.playHaptic(option: .light)
        interactor.trackEvent(event: isActive ? Event.workoutResumed : Event.workoutPaused)
    }
    
    // MARK: - Helpers

    /// Pushes the current session state to the Live Activity. Six call sites previously
    /// repeated this `#if`-guarded block verbatim.
    func refreshLiveActivity() {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        interactor.updateLiveActivity(params: LiveActivityUpdateParams(
            session: workoutSession,
            isActive: isActive,
            currentExerciseIndex: liveActivityExerciseIndex,
            restEndsAt: interactor.restEndTime
        ))
        #endif
    }
    
    func computeTotalVolumeKg() -> Double {
        return workoutSession.exercises.flatMap { $0.sets }
            .compactMap(\.volumeKg)
            .reduce(0.0, +)
    }
    
    private func firstIncompleteExerciseIndex(in exercises: [WorkoutExerciseModel]) -> Int? {
        exercises.firstIndex(where: { !$0.sets.isEmpty && !$0.sets.allSatisfy { $0.completedAt != nil } })
    }

    func syncCurrentExerciseIndexToFirstIncomplete(in exercises: [WorkoutExerciseModel]) {
        if let idx = firstIncompleteExerciseIndex(in: exercises) {
            currentExerciseIndex = idx
        } else {
            currentExerciseIndex = max(0, exercises.isEmpty ? 0 : exercises.count - 1)
        }
    }
    
    func applyReorderedExercises(_ updated: [WorkoutExerciseModel], movedFrom: Int?, movedTo: Int) {
        var updated = updated
        // Reindex exercises only (do not touch set indices)
        for idx in updated.indices {
            updated[idx].index = idx + 1
        }

        // Always align current exercise to top-most incomplete after reorders
        workoutSession.updateExercises(updated)
        syncCurrentExerciseIndexToFirstIncomplete(in: updated)
    }
        
    func presentWorkoutNotes() {
        // Seeded from the session each time, so a resumed workout's note is not wiped by a save
        // and a cancelled edit does not linger as the draft.
        workoutNotes = workoutSession.notes ?? ""
        router.showWorkoutNotesView(
            delegate: WorkoutNotesDelegate(
                notes: Binding(
                    get: {
                        self.workoutNotes
                    },
                    set: { newValue in
                        self.workoutNotes = newValue
                    }
                ),
                onSave: {
                    self.updateWorkoutNotes()
                }
            )
        )
    }
    
    func updateWorkoutNotes() {
        let trimmed = workoutNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        workoutSession.notes = trimmed.isEmpty ? nil : trimmed
    }
    
    func updateExerciseNotes(_ notes: String, exerciseId: String) {
        guard let exerciseIndex = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }) else {
            return
        }

        var updatedExercises = workoutSession.exercises
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedExercises[exerciseIndex].notes = trimmed.isEmpty ? nil : trimmed
        workoutSession.updateExercises(updatedExercises)
    }

    /// Images the session is missing, taken from the library (see `imageName(in:)`), so the card
    /// and the Live Activity have them. They are saved with the session's next change.
    static func fillingMissingImages(_ session: WorkoutSessionModel, from library: [ExerciseModel]) -> WorkoutSessionModel {
        let exercises = session.exercises.map { exercise in
            var exercise = exercise
            exercise.imageName = exercise.imageName(in: library)
            return exercise
        }
        guard exercises != session.exercises else { return session }
        var session = session
        session.updateExercises(exercises)
        return session
    }

    func onGymProfilePressed() {
        guard let gymProfile = favouriteGymProfile else { return }
        let delegate = GymProfileDelegate(gymProfile: gymProfile)
        router.showGymProfileView(delegate: delegate)
    }
}
