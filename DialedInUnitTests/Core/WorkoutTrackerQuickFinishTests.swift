//
//  WorkoutTrackerQuickFinishTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// The Finish Workout button that appears at the bottom of the tracker once every set is logged.
///
/// It is a second way into the one finish flow, not a flow of its own: it calls the same
/// `onFinishPressed` as the menu item, so the notes sheet, the save and its retries are shared.
@MainActor
struct WorkoutTrackerQuickFinishTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(_ id: String, isWarmup: Bool = false, done: Bool) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: 1, reps: 8, weightKg: 80,
            isWarmup: isWarmup, completedAt: done ? start : nil, dateCreated: start
        )
    }

    private func makeScreen(sets: [WorkoutSetModel]) throws -> (WorkoutTrackerPresenter, WorkoutTrackerRouterDouble) {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            dateCreated: start,
            exercises: sets.isEmpty ? [] : [
                WorkoutExerciseModel(
                    id: "e1", authorId: "author-1", templateId: "template-e1", name: "Bench Press",
                    trackingMode: .weightReps, index: 1, sets: sets
                )
            ]
        )
        // Warm-ups are only kept when smart warm-ups are on; otherwise the screen drops open ones.
        interactor.workoutSettings.addSmartWarmUps = true
        let router = WorkoutTrackerRouterDouble()
        return (try WorkoutTrackerPresenter(interactor: interactor, router: router, saveRetryBackoff: .testImmediate), router)
    }

    @Test("Test An Empty Workout Offers No Quick Finish")
    func testAnEmptyWorkoutOffersNoQuickFinish() throws {
        let (presenter, _) = try makeScreen(sets: [])
        #expect(!presenter.canQuickFinish)
    }

    @Test("Test An Open Set Offers No Quick Finish")
    func testAnOpenSetOffersNoQuickFinish() throws {
        let (presenter, _) = try makeScreen(sets: [set("a", done: true), set("b", done: false)])
        #expect(!presenter.canQuickFinish)
    }

    @Test("Test Every Set Done, Warm-Ups Included, Offers Quick Finish")
    func testEverySetDoneOffersQuickFinish() throws {
        let (presenter, _) = try makeScreen(sets: [set("w", isWarmup: true, done: true), set("a", done: true)])
        #expect(presenter.canQuickFinish)
    }

    @Test("Test An Open Warm-Up Offers No Quick Finish")
    func testAnOpenWarmUpOffersNoQuickFinish() throws {
        let (presenter, _) = try makeScreen(sets: [set("w", isWarmup: true, done: false), set("a", done: true)])
        #expect(!presenter.canQuickFinish)
    }

    @Test("Test Adding A Set Takes Quick Finish Away")
    func testAddingASetTakesQuickFinishAway() throws {
        let (presenter, _) = try makeScreen(sets: [set("a", done: true)])
        #expect(presenter.canQuickFinish)

        presenter.workoutSession.exercises[0].sets.append(set("b", done: false))

        #expect(!presenter.canQuickFinish)
    }

    @Test("Test Un-Completing A Set Takes Quick Finish Away")
    func testUnCompletingASetTakesQuickFinishAway() throws {
        let (presenter, _) = try makeScreen(sets: [set("a", done: true), set("b", done: true)])
        var reopened = presenter.workoutSession.exercises[0].sets[1]
        reopened.completedAt = nil

        presenter.updateSet(reopened, in: "e1")

        #expect(!presenter.canQuickFinish)
    }

    /// The button's action is `onFinishPressed`, the menu item's: it opens the finish sheet, and
    /// confirming it ends the workout through the shared finish.
    @Test("Test Quick Finish Runs The Menu's Finish Flow")
    func testQuickFinishRunsTheMenusFinishFlow() throws {
        let (presenter, router) = try makeScreen(sets: [set("a", done: true)])
        #expect(presenter.canQuickFinish)

        presenter.onFinishPressed()
        let delegate = try #require(router.notesDelegates.first)
        #expect(delegate.title == "Finish Workout")
        delegate.onSave()
        delegate.onDidDismiss?()

        #expect(presenter.isDone)
        #expect(router.shown == ["workoutNotes", "summary"])
        presenter.cancelPendingSave()
    }
}
