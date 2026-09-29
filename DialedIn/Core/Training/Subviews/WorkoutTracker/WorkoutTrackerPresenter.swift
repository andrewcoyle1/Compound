//
//  WorkoutTrackerPresenter.swift
//  DialedIn
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
    var isActive = true
    
    var expandedExerciseId: String?
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
    var exerciseUnitPreferences: [String: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)] = [:]

    /// What smart progression decided for each exercise, keyed by `templateId`. Drives the hint
    /// in the exercise header. See `WorkoutTrackerPresenter+Progression`.
    var progressionSuggestions: [String: ProgressionSuggestion] = [:]

    /// The values the screen filled in for the user, per set id. A set that still holds these
    /// may be re-suggested live; one the user has edited may not.
    var progressionBaseline: [String: SuggestedSet] = [:]

    // Prevents handleWorkoutSessionChange from double-processing when updateSet() is the caller
    private var isProcessingUpdateSet = false

    /// Set once this screen has left — finished, discarded, or told the workout ended elsewhere.
    /// A write after that would put an ended session back as the active one.
    var isDone = false
    
    // Notification identifier for rest timer
    let restTimerNotificationId = "workout-rest-timer"
    
    var exercisesCount: String {
        String(localized: "\(workoutSession.exercises.count) exercises")
    }
    
    var exerciseFraction: String {
        "\(currentExerciseIndex + 1)/\(workoutSession.exercises.count)"
    }
    
    var completedSetsFraction: String {
        "\(completedSetsCount)/\(totalSetsCount)"
    }
    
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
        
        self.workoutSession = session
        loadUnitPreferences()
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
        let profile = try? await interactor.getGymProfile(gymProfileId: gymProfileId)
        self.gymProfile = profile
        interactor.setActiveWorkoutGymProfile(profile)
    }
    
    func loadUnitPreferences() {
        exerciseUnitPreferences.removeAll(keepingCapacity: true)
        for exercise in workoutSession.exercises {
            let preference = interactor.getPreference(templateId: exercise.templateId)
            exerciseUnitPreferences[exercise.templateId] = (
                weightUnit: preference.weightUnit,
                distanceUnit: preference.distanceUnit
            )
        }
    }
    
    // MARK: - Computed Properties
    
    var elapsedTimeString: String {
        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = Int(elapsed) / 60 % 60
        let seconds = Int(elapsed) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Counted per exercise so a left/right pair is the one set it is — see `WorkoutSetPairing`.
    var completedSetsCount: Int {
        workoutSession.exercises.reduce(0) { $0 + $1.sets.fullyCompletedPairedSetCount }
    }
    
    var totalSetsCount: Int {
        workoutSession.exercises.reduce(0) { $0 + $1.sets.pairedSetCount }
    }
    
    var formattedVolume: String {
        let totalVolume = computeTotalVolumeKg()
        return String(format: "%.0f kg", totalVolume)
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

        // Only request HealthKit auth if we're about to start a new HK session.
        if interactor.canRequestHealthDataAuthorisation() && interactor.needsAuthorisationForRequiredTypes() {
            do {
                try await interactor.requestHealthKitAuthorisation()
            } catch { }
        }

        guard !interactor.needsAuthorisationForRequiredTypes() else { return }

        interactor.setWorkoutConfiguration(activityType: .traditionalStrengthTraining, location: .indoor)
        interactor.startWorkout(workout: workoutSession)
        SharedWorkoutStorage.hkStartedSessionId = workoutSession.id
        #endif
    }

    func onScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        // iOS foregrounds through `.inactive`, so `oldPhase` is never `.background` here.
        if newPhase == .active {
            // A set logged from the Live Activity while the app was in the background was saved by
            // the intent handler, not by this screen, so re-read it rather than waiting for the
            // observation to fire.
            adoptSavedSessionIfChanged()
        }
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
    
    private func discardWorkout() {
        isDone = true
        interactor.setActiveWorkoutGymProfile(nil)
        try? interactor.deleteActiveSession()
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
            title: String(localized: "End Workout?"),
            subtitle: "Are you sure you want to discard this workout?"
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

    func minimizeSession() {
        router.dismissScreen()
    }
    
    // MARK: - Rest Timer
    
    func onExerciseExpansionChanged(exerciseId: String, isExpanded: Bool) {
        expandedExerciseId = isExpanded ? exerciseId : nil

        refreshLiveActivity()
    }

    // MARK: - Persistence
    
    func saveWorkoutProgress() {
        guard !isDone else { return }
        do {
            try interactor.updateActiveSession(workoutSession)
        } catch {
            router.showSimpleAlert(title: String(localized: "Unable to Save Progress"), subtitle: String(localized: "We were unable to save your workout. Please try again."))
        }
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
            .compactMap { set in
                guard let weight = set.weightKg, let reps = set.reps else { return nil }
                return weight * Double(reps)
            }
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
    
    // MARK: - The handler's writes

    /// Watches `interactor.activeSession` for a save this screen did not make.
    ///
    /// A set logged from the Live Activity is written by `AppLiveActivityIntentHandler`, in this
    /// process but outside this presenter. Observation is how it reaches the screen: the handler
    /// saves through the session manager, `activeSession` changes, and the tracker adopts it.
    ///
    /// Re-armed on every change, because `withObservationTracking` fires its `onChange` once.
    private func startObservingActiveSession() {
        withObservationTracking {
            _ = interactor.activeSession
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.adoptSavedSessionIfChanged()
                self?.startObservingActiveSession()
            }
        }
    }

    /// Takes on the saved session when it differs from the screen's own copy.
    ///
    /// Skipped while `updateSet` is mid-flight: that is this screen's own write on its way to the
    /// manager, and adopting it back would fight the edit the user is making.
    func adoptSavedSessionIfChanged() {
        guard !isProcessingUpdateSet else { return }
        guard let saved = interactor.activeSession else {
            // Finished from the Live Activity while this screen sat in the background. There is
            // nothing left to track, and the next edit here would resurrect the ended session.
            guard !isDone else { return }
            isDone = true
            UIApplication.shared.isIdleTimerDisabled = false
            router.dismissScreen()
            return
        }
        guard saved.id == workoutSession.id else { return }
        guard saved != workoutSession else { return }

        workoutSession = saved
    }

    func updateSet(_ updatedSet: WorkoutSetModel, in exerciseId: String) {
        guard let exerciseIndex = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = workoutSession.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == updatedSet.id }) else {
            return
        }
        let exerciseBefore = workoutSession.exercises[exerciseIndex]
        let wasExerciseCompleteBefore = isComplete(exerciseBefore)

        var updatedExercises = workoutSession.exercises
        updatedExercises[exerciseIndex].sets[setIndex] = updatedSet
        propagateChanges(
            of: updatedSet,
            replacing: exerciseBefore.sets[setIndex],
            at: setIndex,
            in: &updatedExercises[exerciseIndex].sets
        )

        let isExerciseCompleteNow = isComplete(updatedExercises[exerciseIndex])
        isProcessingUpdateSet = true
        workoutSession.updateExercises(updatedExercises)
        isProcessingUpdateSet = false

        if !wasExerciseCompleteBefore && isExerciseCompleteNow {
            advanceAfterExerciseCompletion(exerciseIndex: exerciseIndex, in: updatedExercises)
        } else if exerciseBefore.sets[setIndex].completedAt == nil, updatedSet.completedAt != nil {
            advanceWithinSuperset(exerciseIndex: exerciseIndex, in: updatedExercises)
        }

        refreshLiveActivity()
    }

    /// True when the exercise has sets and every one of them is logged.
    ///
    /// Not private: `WorkoutTrackerPresenter+Superset` skips partners that are already finished.
    func isComplete(_ exercise: WorkoutExerciseModel) -> Bool {
        !exercise.sets.isEmpty && exercise.sets.allSatisfy { $0.completedAt != nil }
    }

    /// Copies a weight/reps edit onto sibling sets that still hold the previous values, when
    /// the propagate-changes setting is on.
    ///
    /// Kept within a side: typing a heavier weight on the left arm must not quietly move the right
    /// arm's sets too, because the two limbs are not equally strong and that is why they are
    /// logged apart.
    private func propagateChanges(
        of updatedSet: WorkoutSetModel,
        replacing original: WorkoutSetModel,
        at setIndex: Int,
        in sets: inout [WorkoutSetModel]
    ) {
        guard interactor.workoutSettings.propagateChanges, updatedSet.completedAt == nil else { return }

        let weightChanged = original.weightKg != updatedSet.weightKg
        let repsChanged = original.reps != updatedSet.reps
        guard weightChanged || repsChanged else { return }

        for index in sets.indices where index != setIndex {
            var sibling = sets[index]
            guard sibling.side == updatedSet.side,
                  sibling.completedAt == nil,
                  sibling.weightKg == original.weightKg,
                  sibling.reps == original.reps else { continue }
            if weightChanged { sibling.weightKg = updatedSet.weightKg }
            if repsChanged { sibling.reps = updatedSet.reps }
            sets[index] = sibling
        }
    }

    /// Moves focus to the next exercise once every set in `exerciseIndex` is logged. Shared by
    /// `updateSet` and `handleWorkoutSessionChange`, which both used to inline it.
    private func advanceAfterExerciseCompletion(exerciseIndex: Int, in exercises: [WorkoutExerciseModel]) {
        let nextIndex = exerciseIndex + 1

        if nextIndex < exercises.count && interactor.workoutSettings.exerciseAutoNext {
            expandedExerciseId = exercises[nextIndex].id
            currentExerciseIndex = nextIndex
        } else if nextIndex >= exercises.count, expandedExerciseId == exercises[exerciseIndex].id {
            expandedExerciseId = nil
        }
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

    private func handleWorkoutSessionChange(from oldSession: WorkoutSessionModel) {
        guard !isProcessingUpdateSet else { return }
        guard let exerciseIndex = firstNewlyCompletedSetExerciseIndex(comparedTo: oldSession) else { return }

        let exercise = workoutSession.exercises[exerciseIndex]
        let wasExerciseCompleteBefore = oldSession.exercises
            .first { $0.id == exercise.id }
            .map(isComplete) ?? false

        if !wasExerciseCompleteBefore && isComplete(exercise) {
            advanceAfterExerciseCompletion(exerciseIndex: exerciseIndex, in: workoutSession.exercises)
        } else {
            // A set logged from the Live Activity or a widget intent lands here rather than in
            // `updateSet`, and moves focus the same way.
            advanceWithinSuperset(exerciseIndex: exerciseIndex, in: workoutSession.exercises)
        }

        refreshLiveActivity()
    }

    /// The first exercise holding a set that flipped incomplete → complete relative to
    /// `oldSession`, or nil when nothing was newly logged.
    private func firstNewlyCompletedSetExerciseIndex(comparedTo oldSession: WorkoutSessionModel) -> Int? {
        var oldSets: [String: WorkoutSetModel] = [:]
        for exercise in oldSession.exercises {
            for set in exercise.sets {
                oldSets[set.id] = set
            }
        }

        return workoutSession.exercises.firstIndex { exercise in
            exercise.sets.contains { set in
                oldSets[set.id]?.completedAt == nil && set.completedAt != nil
            }
        }
    }

    func onGymProfilePressed() {
        guard let gymProfile = favouriteGymProfile else { return }
        let delegate = GymProfileDelegate(gymProfile: gymProfile)
        router.showGymProfileView(delegate: delegate)
    }
}
