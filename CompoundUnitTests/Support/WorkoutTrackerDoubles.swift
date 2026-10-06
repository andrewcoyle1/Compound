//
//  WorkoutTrackerDoubles.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Foundation
import SwiftUI
import HealthKit
@testable import Compound

/// The tracker's interactor and router doubles.
///
/// `WorkoutTrackerInteractor` declares around thirty methods — HealthKit, the Live Activity, rest
/// timing and persistence — so the doubles are longer than the tests that use them. They live here
/// to keep the test file itself readable.

final class WorkoutTrackerInteractorDouble: SpyGlobalInteractor, WorkoutTrackerInteractor {
    var currentUser: UserModel? = UserModel(userId: "author-1")
    var favouriteGymProfile: GymProfileModel?
    var restEndTime: Date?
    var activeSession: WorkoutSessionModel?
    var allExercises: [ExerciseModel] = []
    var workoutSettings: WorkoutSettings = WorkoutSettings(authorId: "author-1")
    var preferences: [String: ExerciseUnitPreference] = [:]
    var lastCompletedSession: WorkoutSessionModel?

    private(set) var savedActiveSessions: [WorkoutSessionModel] = []
    private(set) var endedSessions: [WorkoutSessionModel] = []
    private(set) var startedRests: [Int] = []
    private(set) var didCancelRest = false
    private(set) var didAddStreakEvent = false
    /// `isCompleted` of each `endLiveActivity` call.
    private(set) var endedLiveActivities: [Bool] = []
    var endWorkoutSessionError: Error?

    /// Consumed one per call, so a test can say "fails twice, then works" — which is the whole
    /// point of the retry. Falls back to `endWorkoutSessionError` once it runs dry.
    var endWorkoutSessionErrors: [Error?] = []
    private(set) var endWorkoutSessionAttempts = 0
    private(set) var stravaUploads: [String] = []
    private(set) var preparedSounds: [SoundEffectFile] = []
    private(set) var playedSounds: [SoundEffectFile] = []

    func setActiveWorkoutGymProfile(_ profile: GymProfileModel?) { }
    func getGymProfile(gymProfileId: String) async throws -> GymProfileModel {
        GymProfileModel(id: gymProfileId, authorId: "author-1", name: "Home Gym")
    }
    func canRequestHealthDataAuthorisation() -> Bool { false }
    func requestHealthKitAuthorisation(for scope: HealthDataScope) async throws { }
    func needsAuthorisationForRequiredTypes() -> Bool { false }
    func setWorkoutConfiguration(activityType: HKWorkoutActivityType, location: HKWorkoutSessionLocationType) { }

    func startWorkout(workout: WorkoutSessionModel) { }
    func saveWorkoutSession(_ session: WorkoutSessionModel) async throws { }
    /// Runs after each save lands, so a test can stand in for the observation firing mid-write.
    var onUpdateActiveSession: (() -> Void)?

    func updateActiveSession(_ session: WorkoutSessionModel) throws {
        savedActiveSessions.append(session)
        activeSession = session
        onUpdateActiveSession?()
    }
    func getWorkoutSession(id: String) async throws -> WorkoutSessionModel {
        guard let activeSession else { throw WorkoutTrackerPresenter.WorkoutTrackerError.noActiveWorkout }
        return activeSession
    }
    func endWorkoutSession(_ session: WorkoutSessionModel) async throws {
        endWorkoutSessionAttempts += 1
        let error = endWorkoutSessionErrors.isEmpty ? endWorkoutSessionError : endWorkoutSessionErrors.removeFirst()
        if let error { throw error }
        endedSessions.append(session)
    }
    func deleteActiveSession() throws { activeSession = nil }

    /// The shared finish, as far as this double can stand in for it: the save is the one attempt
    /// the retry tests count, and the rest records that it ran. The real sequencing is pinned
    /// through the intent handler on real managers.
    func finishWorkout(_ session: WorkoutSessionModel) async -> WorkoutSaveOutcome {
        let outcome: WorkoutSaveOutcome
        do {
            try await endWorkoutSession(session)
            outcome = .saved
        } catch {
            outcome = error.isTransientWriteFailure ? .failedTransiently : .failedPermanently
        }
        endedLiveActivities.append(outcome == .saved)
        didAddStreakEvent = true
        stravaUploads.append(session.id)
        return outcome
    }
    func discardWorkout() { }

    var isWorkoutActive = true
    var pausedDuration: TimeInterval = 0
    func togglePause() { isWorkoutActive.toggle() }
    func totalPausedDuration(at date: Date) -> TimeInterval { pausedDuration }

    func ensureLiveActivity(
        session: WorkoutSessionModel,
        isActive: Bool,
        currentExerciseIndex: Int,
        restEndsAt: Date?
    ) { }
    func endLiveActivity(session: WorkoutSessionModel, isCompleted: Bool) {
        endedLiveActivities.append(isCompleted)
    }
    func updateLiveActivity(params: LiveActivityUpdateParams) { }

    /// Records the mesocycle filter the presenter asked for, and honours it against
    /// `completedSessions` when that is set — so a test can assert both the request and the result.
    private(set) var lastCompletedSessionLookups: [String?] = []
    var completedSessions: [WorkoutSessionModel]?

    func getLastCompletedSessionForTemplate(
        templateId: String,
        authorId: String,
        inMesocycleId: String?
    ) async throws -> WorkoutSessionModel? {
        lastCompletedSessionLookups.append(inMesocycleId)
        guard let completedSessions else { return lastCompletedSession }
        return completedSessions
            .filter { $0.workoutTemplateId == templateId }
            .filter { inMesocycleId == nil || $0.mesocycleId == inMesocycleId }
            .max { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
    }

    /// Serves `completedSessions` newest first, so the progression history reads the way the real
    /// lookup does.
    func getLastCompletedSessionsForTemplate(
        templateId: String,
        authorId: String,
        inMesocycleId: String?,
        limit: Int
    ) async throws -> [WorkoutSessionModel] {
        let sessions = completedSessions ?? [lastCompletedSession].compactMap { $0 }
        return Array(
            sessions
                .filter { $0.workoutTemplateId == templateId }
                .filter { inMesocycleId == nil || $0.mesocycleId == inMesocycleId }
                .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
                .prefix(max(limit, 0))
        )
    }

    // MARK: - Previous workout reference

    /// The double serves `completedSessions` through the real `PreviousWorkoutReferenceResolving`
    /// extension, so the tracker tests exercise the shipped switch and fallback rather than a
    /// second copy of them living here.
    var previousWorkoutReferenceScope: PreviousWorkoutReferenceOption {
        workoutSettings.previousWorkoutReference
    }

    /// Every scope request the resolver made, as `(workoutTemplateId, mesocycleId)` for a template
    /// lookup and `(nil, mesocycleId)` for an any-exercise one.
    private(set) var previousSessionLookups: [(templateId: String?, mesocycleId: String?)] = []

    func completedSessionsForWorkoutTemplate(
        templateId: String,
        authorId: String,
        inMesocycleId: String?,
        limit: Int
    ) async -> [WorkoutSessionModel] {
        previousSessionLookups.append((templateId: templateId, mesocycleId: inMesocycleId))
        lastCompletedSessionLookups.append(inMesocycleId)
        return (try? await getLastCompletedSessionsForTemplate(
            templateId: templateId,
            authorId: authorId,
            inMesocycleId: inMesocycleId,
            limit: limit
        )) ?? []
    }

    func completedSessionsContainingExercise(
        exerciseTemplateId: String,
        authorId: String,
        inMesocycleId: String?,
        limit: Int
    ) async -> [WorkoutSessionModel] {
        previousSessionLookups.append((templateId: nil, mesocycleId: inMesocycleId))
        let sessions = completedSessions ?? [lastCompletedSession].compactMap { $0 }
        return Array(
            sessions
                .filter { $0.endedAt != nil }
                .filter { $0.exercises.contains(where: { $0.templateId == exerciseTemplateId }) }
                .filter { inMesocycleId == nil || $0.mesocycleId == inMesocycleId }
                .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
                .prefix(max(limit, 0))
        )
    }

    /// What `progressionSuggestions(for:gymProfile:)` hands back, keyed by exercise `templateId`.
    var progressionSuggestionsByTemplateId: [String: ProgressionSuggestion] = [:]

    func progressionSuggestions(
        for session: WorkoutSessionModel,
        gymProfile: GymProfileModel?
    ) async -> [String: ProgressionSuggestion] {
        progressionSuggestionsByTemplateId
    }

    func startRest(durationSeconds: Int, session: WorkoutSessionModel, currentExerciseIndex: Int) {
        startedRests.append(durationSeconds)
        restEndTime = Date().addingTimeInterval(TimeInterval(durationSeconds))
    }
    func cancelRest() {
        didCancelRest = true
        restEndTime = nil
    }
    func prepareSoundEffect(sound: SoundEffectFile, simultaneousPlayers: Int) {
        preparedSounds.append(sound)
    }
    func playSoundEffect(sound: SoundEffectFile) {
        playedSounds.append(sound)
    }
    func getPreference(templateId: String) -> ExerciseUnitPreference {
        preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
    }
    var restOverrides: [String: Int] = [:]
    func exerciseRestOverride(for exerciseId: String) -> Int? {
        restOverrides[exerciseId]
    }
}

final class WorkoutTrackerRouterDouble: WorkoutTrackerRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var shown: [String] = []

    func showExercisesPickerView(delegate: ExercisesPickerDelegate) { shown.append("exercisesPicker") }
    private(set) var notesDelegates: [WorkoutNotesDelegate] = []
    func showWorkoutNotesView(delegate: WorkoutNotesDelegate) {
        shown.append("workoutNotes")
        notesDelegates.append(delegate)
    }
    func showWorkoutSettingsView(delegate: WorkoutSettingsDelegate) { shown.append("workoutSettings") }
    func showGymProfileView(delegate: GymProfileDelegate) { shown.append("gymProfile") }
    func dismissScreen() { shown.append("dismiss") }
    private(set) var summarySessions: [WorkoutSessionModel] = []
    func showWorkoutSummary(session: WorkoutSessionModel) {
        shown.append("summary")
        summarySessions.append(session)
    }
    /// Titles of the confirmation dialogs raised. The buttons are views, so tests call the
    /// presenter methods they would.
    private(set) var confirmations: [String] = []
    func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
        confirmations.append(title)
    }
}

extension RetryBackoff {

    /// A retry schedule a test can drive to its end in a millisecond.
    ///
    /// Injecting this rather than waiting out the real one is the difference between a test and a
    /// flake: the shipped schedule spends twenty-six seconds getting to the same answer.
    static let testImmediate = RetryBackoff(
        baseDelay: .milliseconds(1),
        multiplier: 1,
        maxAttempts: 4,
        maxTotalDelay: .seconds(1)
    )
}

// MARK: WP-A

/// A tracker open on one exercise of open sets, for the save and propagation suites.
@MainActor
struct WorkoutTrackerTypingScreen {
    let presenter: WorkoutTrackerPresenter
    let interactor: WorkoutTrackerInteractorDouble
    let router: WorkoutTrackerRouterDouble

    /// Set ids are "s1", "s2", …, each with eight reps.
    init(weights: [Double], propagateChanges: Bool = true) throws {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let sets = weights.enumerated().map { offset, weight in
            WorkoutSetModel(
                id: "s\(offset + 1)", authorId: "author-1", index: offset + 1, reps: 8, weightKg: weight,
                isWarmup: false, dateCreated: start
            )
        }
        let exercise = WorkoutExerciseModel(
            id: "e1", authorId: "author-1", templateId: "template-e1", name: "Bench Press",
            trackingMode: .weightReps, index: 1, sets: sets
        )
        interactor = WorkoutTrackerInteractorDouble()
        interactor.workoutSettings.propagateChanges = propagateChanges
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Push Day", dateCreated: start, exercises: [exercise]
        )
        router = WorkoutTrackerRouterDouble()
        presenter = try WorkoutTrackerPresenter(interactor: interactor, router: router, saveRetryBackoff: .testImmediate)
    }

    /// The weights on screen, set by set.
    var weights: [Double?] { presenter.workoutSession.exercises[0].sets.map(\.weightKg) }

    /// The weights in the last saved session.
    var savedWeights: [Double?]? { interactor.activeSession?.exercises[0].sets.map(\.weightKg) }

    var writes: Int { interactor.savedActiveSessions.count }

    /// Types into a set the way the keypad does: each key writes the field's whole value through
    /// the row's binding into `workoutSession`.
    func type(_ values: Double..., into setNumber: Int) {
        for value in values {
            presenter.workoutSession.exercises[0].sets[setNumber - 1].weightKg = value
        }
    }
}
