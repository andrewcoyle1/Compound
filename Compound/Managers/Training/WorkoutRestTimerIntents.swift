//
//  WorkoutRestTimerIntents.swift
//  Compound
//
//  Created by Andrew Coyle on 17/10/2025.
//
//  The Live Activity's buttons (spec: docs/specs/live-activity.md §7.2).
//
//  Every intent has one shape: push the loading state, then await the app's handler. The handler
//  finishes with its own push of the saved session — built by `LiveActivityManager.makeContentState`,
//  which sets `isProcessingIntent: false` — and that push is what re-enables the button. One
//  ActivityKit update per tap here, one from the app; nothing is guessed in between.
//

import Foundation
import AppIntents
#if canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
@MainActor
private extension Activity where Attributes == WorkoutActivityAttributes {

    /// Push `state` with the loading flag on, then hand the tap to the app's handler.
    ///
    /// The handler's push clears the flag. With no handler registered (only possible in a unit
    /// test) nothing is coming, so the flag is cleared again here rather than leaving the button
    /// dead.
    func awaitingHandler(
        from state: WorkoutActivityAttributes.ContentState,
        _ action: @MainActor (any LiveActivityIntentHandling) async -> Void
    ) async {
        var loadingState = state
        loadingState.isProcessingIntent = true
        await update(ActivityContent(state: loadingState, staleDate: state.restEndsAt, relevanceScore: 100))

        guard let handler = LiveActivityIntentHandler.current else {
            var idleState = state
            idleState.isProcessingIntent = false
            await update(ActivityContent(state: idleState, staleDate: state.restEndsAt, relevanceScore: 100))
            return
        }
        await action(handler)
    }
}
#endif

// MARK: - Adjust Rest Timer Intent

@available(iOS 16.0, *)
struct AdjustRestTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Adjust Rest Timer"
    static let description: IntentDescription = "Adjust the workout rest timer by adding or subtracting time"
    
    @Parameter(title: "Adjustment (seconds)")
    var adjustment: Int
    
    init() {
        self.adjustment = 0
    }
    
    init(adjustment: Int) {
        self.adjustment = adjustment
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard let activity = Activity<WorkoutActivityAttributes>.activities.first,
              activity.content.state.restEndsAt != nil else {
            return .result()
        }
        await activity.awaitingHandler(from: activity.content.state) { await $0.adjustRest(by: adjustment) }
        #endif
        return .result()
    }
}

// MARK: - Skip Rest Timer Intent

@available(iOS 16.0, *)
struct SkipRestTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Rest Timer"
    static let description: IntentDescription = "Skip the current rest timer and continue workout"
        
    @MainActor
    func perform() async throws -> some IntentResult {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard let activity = Activity<WorkoutActivityAttributes>.activities.first else {
            return .result()
        }
        await activity.awaitingHandler(from: activity.content.state) { await $0.skipRest() }
        #endif
        return .result()
    }
}

// MARK: - Complete Workout Intent

@available(iOS 16.0, *)
struct CompleteWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete Workout"
    static let description: IntentDescription = "Finish and save the workout session"
    
    @MainActor
    func perform() async throws -> some IntentResult {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard let activity = Activity<WorkoutActivityAttributes>.activities.first else {
            return .result()
        }
        // The handler ends HealthKit, the session and the activity, as Finish does in the app.
        await activity.awaitingHandler(from: activity.content.state) { await $0.completeWorkout() }
        #endif
        return .result()
    }
}

// MARK: - Complete Set Intent

@available(iOS 16.0, *)
struct CompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete Set"
    static let description: IntentDescription = "Mark the current set as complete and start rest"

    @MainActor
    func perform() async throws -> some IntentResult {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard let activity = Activity<WorkoutActivityAttributes>.activities.first,
              let setId = activity.content.state.targetSetId else {
            return .result()
        }
        // The handler logs the set, starts the real rest and pushes the saved session — with the
        // logged set, the rest and the advanced target — which is what puts a countdown on screen.
        await activity.awaitingHandler(from: activity.content.state) { await $0.completeSet(id: setId) }
        #endif
        return .result()
    }
}

// MARK: - Adjust Last Set Reps Intent

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

/// The whole decision behind `AdjustLastSetRepsIntent`, with nothing that needs a live
/// `Activity` to exercise (spec §4).
///
/// The correction window is open only while the rest that followed a logged set is still
/// running; outside it there is no set to correct and the tap does nothing.
enum AdjustLastSetRepsDecision {

    /// The reps the logged set should now carry, or `nil` when the tap is a no-op.
    static func adjustedReps(
        state: WorkoutActivityAttributes.ContentState,
        now: Date,
        delta: Int
    ) -> Int? {
        guard state.lastLoggedSetId != nil else { return nil }
        guard let restEndsAt = state.restEndsAt, restEndsAt > now else { return nil }

        let base = state.lastLoggedReps ?? 0
        return min(max(base + delta, 0), 99)
    }
}

#endif

/// Correct the reps of the set that was just logged, during the rest that follows it.
///
/// `CompleteSetIntent` logs the prescribed reps, so a set that fell short would otherwise be
/// recorded as a hit and feed smart progression a number the user never lifted.
@available(iOS 16.0, *)
struct AdjustLastSetRepsIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Adjust Last Set Reps"
    static let description: IntentDescription = IntentDescription("Correct the reps of the set that was just logged")

    @Parameter(title: "Adjustment (reps)")
    var delta: Int

    init() {
        self.delta = 0
    }

    init(delta: Int) {
        self.delta = delta
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard let activity = Activity<WorkoutActivityAttributes>.activities.first else {
            return .result()
        }

        let state = activity.content.state

        guard let setId = state.lastLoggedSetId,
              let reps = AdjustLastSetRepsDecision.adjustedReps(state: state, now: Date(), delta: delta) else {
            return .result()
        }

        // The one optimistic write that stays: this is the number changing under the user's
        // thumb, and the loading push carries it rather than waiting for the app's tick.
        var updatedState = state
        updatedState.lastLoggedReps = reps

        // The delta, not the clamped total: the handler clamps against the set's own reps, which
        // is the number that will be saved.
        await activity.awaitingHandler(from: updatedState) { await $0.adjustLastSetReps(id: setId, delta: delta) }
        #endif
        return .result()
    }
}
