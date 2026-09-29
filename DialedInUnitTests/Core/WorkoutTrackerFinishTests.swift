//
//  WorkoutTrackerFinishTests.swift
//  DialedInUnitTests
//
//  Split out of WorkoutTrackerPresenterTests.swift, which exceeded the 750-line file and
//  500-line type-body limits.
//

import Testing
import Foundation
import SwiftUI
import HealthKit
@testable import DialedIn

/// What happens after the user says they are done.
///
/// The screen dismisses itself before the save is even attempted, which is the whole problem this
/// file guards: there is no router left to alert through, so anything worth saying has to be
/// raised at the app level and outlive the screen that raised it. A workout that fails to save is
/// not lost — the active session is only cleared once the save succeeds, so Training still offers
/// to resume it — but a user who is told nothing has no way to know that.
///
/// The finish itself — HealthKit, the Live Activity, the streak, the rest days, Strava — is the
/// routine shared with the Live Activity's Finish button and is pinned on real managers in
/// `LiveActivityIntentHandlerTests`; here it is a double, and only the retry around it is tested.
@MainActor
struct WorkoutTrackerFinishTests {

    private struct Screen {
        let presenter: WorkoutTrackerPresenter
        let interactor: WorkoutTrackerInteractorDouble
        let router: WorkoutTrackerRouterDouble
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// Builds the screen the way the app does: the presenter reads the session the interactor
    /// already holds. The backoff is injected so nothing here waits out the real schedule.
    private func makeScreen(backoff: RetryBackoff = .testImmediate) throws -> Screen {
        let completedSet = WorkoutSetModel(
            id: "e1-set-1",
            authorId: "author-1",
            index: 1,
            reps: 8,
            weightKg: 80,
            isWarmup: false,
            completedAt: start,
            dateCreated: start
        )
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            dateCreated: start,
            exercises: [
                WorkoutExerciseModel(
                    id: "e1",
                    authorId: "author-1",
                    templateId: "template-e1",
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: [completedSet]
                )
            ]
        )
        let router = WorkoutTrackerRouterDouble()
        return Screen(
            presenter: try WorkoutTrackerPresenter(interactor: interactor, router: router, saveRetryBackoff: backoff),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Finishing

    @Test("Test Finishing Ends The Session And Records It")
    func testFinishingEndsTheSessionAndRecordsIt() async throws {
        let screen = try makeScreen()

        screen.presenter.finishWorkout()
        await screen.presenter.pendingFinishTask?.value

        #expect(screen.presenter.workoutSession.endedAt != nil)
        #expect(screen.interactor.endedSessions.map(\.id) == ["session-1"])
        #expect(screen.interactor.didAddStreakEvent)
        #expect(screen.interactor.stravaUploads == ["session-1"])
        // A save that works first time is not news, so nothing is put in front of the user.
        #expect(screen.interactor.shownToasts.isEmpty)
    }

    // MARK: - Saving a finished workout

    /// The failure this whole mechanism exists for. The screen is dismissed before the save is even
    /// attempted, so there is no router left to alert through — the message has to be raised at the
    /// app level, above whatever the user is looking at by then.
    @Test("Test A Transient Save Failure Is Retried Until It Works")
    func testATransientSaveFailureIsRetriedUntilItWorks() async throws {
        let screen = try makeScreen()
        screen.interactor.endWorkoutSessionErrors = [URLError(.networkConnectionLost), URLError(.timedOut)]

        screen.presenter.finishWorkout()

        #expect(await TestManagers.eventually { screen.interactor.endedSessions.map(\.id) == ["session-1"] })
        #expect(screen.interactor.endWorkoutSessionAttempts == 3)
        #expect(screen.interactor.shownToasts.map(\.message) == [
            Self.retryingMessage,
            Self.retryingMessage,
            Self.savedMessage
        ])
        #expect(screen.interactor.shownToasts.last?.style == .success)
    }

    /// A rejected document or a permission failure will be rejected identically every time, so
    /// retrying it is only half a minute of the user not being told what happened.
    @Test("Test A Permanent Save Failure Is Surfaced Without Retrying")
    func testAPermanentSaveFailureIsSurfacedWithoutRetrying() async throws {
        let screen = try makeScreen()
        // Firestore's permissionDenied.
        screen.interactor.endWorkoutSessionError = NSError(domain: "FIRFirestoreErrorDomain", code: 7)

        screen.presenter.finishWorkout()

        #expect(await TestManagers.eventually { !screen.interactor.shownToasts.isEmpty })
        #expect(screen.interactor.endWorkoutSessionAttempts == 1)
        #expect(screen.interactor.shownToasts.map(\.message) == [Self.failedMessage])
        #expect(screen.interactor.shownToasts.first?.style == .failure)
    }

    /// When the retries run out the user is told plainly, and told where the workout still is — the
    /// active session is only cleared once the save succeeds, so Training can still resume it.
    @Test("Test A Save That Never Succeeds Ends With The Failure Message")
    func testASaveThatNeverSucceedsEndsWithTheFailureMessage() async throws {
        let screen = try makeScreen()
        screen.interactor.endWorkoutSessionError = URLError(.notConnectedToInternet)

        screen.presenter.finishWorkout()

        // The whole retry schedule runs inside this task, so awaiting it is the signal that the
        // loop has given up — the same trick as the cancellation test below, and nothing here has
        // to guess how long four attempts take. Polling for the toast with a 20s `eventually`
        // instead timed out on GitHub Actions run 35778253166: the runner was slow enough that
        // only three of the four attempts had been made and the last toast still read "Retrying…".
        await screen.presenter.pendingFinishTask?.value

        #expect(screen.interactor.shownToasts.last?.style == .failure)
        #expect(screen.interactor.endWorkoutSessionAttempts == RetryBackoff.testImmediate.maxAttempts)
        #expect(screen.interactor.shownToasts.last?.message == Self.failedMessage)
        // Nothing claimed failure while a retry was still pending.
        #expect(screen.interactor.shownToasts.dropLast().allSatisfy { $0.style == .progress })
    }

    /// A retry loop still running an hour later is a bug of its own, so it has to be stoppable. The
    /// schedule here is deliberately long: the loop parks on a sleep it will never wake from, which
    /// is the only way to observe a cancel rather than race it.
    @Test("Test Cancelling Stops The Retries")
    func testCancellingStopsTheRetries() async throws {
        let screen = try makeScreen(
            backoff: RetryBackoff(baseDelay: .seconds(30), multiplier: 1, maxAttempts: 4, maxTotalDelay: .seconds(300))
        )
        screen.interactor.endWorkoutSessionError = URLError(.notConnectedToInternet)

        screen.presenter.finishWorkout()
        #expect(await TestManagers.eventually { screen.interactor.shownToasts.contains { $0.style == .progress } })

        // Captured before cancelling: `cancelPendingSave` nils the presenter's own reference out,
        // so this is the only handle left to wait on.
        let task = screen.presenter.pendingFinishTask
        screen.presenter.cancelPendingSave()
        // Cancelling makes the loop's own sleep throw, so the task itself is the signal that it
        // has stopped — nothing here has to guess how long that takes.
        await task?.value

        #expect(screen.interactor.endWorkoutSessionAttempts == 1)
        // Cancelling is not a failure, so the user is not told that it failed.
        #expect(screen.interactor.shownToasts.allSatisfy { $0.style == .progress })
    }

    /// Retrying after sign-out would write this workout into whoever signed in next.
    @Test("Test Signing Out Stops The Retries")
    func testSigningOutStopsTheRetries() async throws {
        let screen = try makeScreen()
        screen.interactor.endWorkoutSessionError = URLError(.notConnectedToInternet)

        screen.presenter.finishWorkout()
        screen.interactor.currentUser = nil

        #expect(await TestManagers.eventually { screen.interactor.shownToasts.contains { $0.style == .progress } })
        // The user-check guard is what stops the loop here, and it runs on the same task as the
        // rest of the finish — awaiting that task is the deterministic way to know it has settled.
        await screen.presenter.pendingFinishTask?.value

        #expect(screen.interactor.endWorkoutSessionAttempts == 1)
        #expect(screen.interactor.shownToasts.allSatisfy { $0.style == .progress })
    }

    // MARK: - Pause

    /// Pause and Resume in the menu go through the one toggle the clock, Apple Health and the Live
    /// Activity follow, and the clock leaves paused time out.
    @Test("Test Pause And Resume Toggle The Workout And The Clock Leaves Paused Time Out")
    func testPauseAndResumeToggleTheWorkout() throws {
        let screen = try makeScreen()

        screen.presenter.onPauseResumePressed()
        #expect(!screen.presenter.isActive)
        screen.presenter.onPauseResumePressed()
        #expect(screen.presenter.isActive)
        #expect(Array(screen.interactor.trackedEventNames.suffix(2)) == ["WorkoutTracker_Workout_Paused", "WorkoutTracker_Workout_Resumed"])

        screen.interactor.pausedDuration = 60
        #expect(screen.presenter.elapsedTime(at: start.addingTimeInterval(180)) == Format.duration(120))
    }

    private static let retryingMessage = "Couldn't save your workout. Retrying…"
    private static let savedMessage = "Workout saved."
    private static let failedMessage = "Couldn't save your workout. It's still on this device — resume it from Training."
}
