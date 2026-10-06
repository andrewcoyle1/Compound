//
//  WorkoutTrackerQuickFinishTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The Finish Workout button that appears at the bottom of the tracker once every set is logged.
///
/// It opens the same notes sheet as the menu's Finish, which is its confirmation: the button
/// becomes Finish under a tap meant for the last set. The rest of the finish is shared too: the
/// empty-workout check, the save and its retries.
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

    /// The bottom button's Finish asks for notes first, like the menu's, and only then ends the
    /// workout and opens the summary.
    @Test("Test The Bottom Button's Finish Opens The Notes Sheet")
    func testTheBottomButtonsFinishOpensTheNotesSheet() throws {
        let (presenter, router) = try makeScreen(sets: [set("a", done: true)])
        #expect(presenter.canQuickFinish)
        #expect(presenter.primarySlot == .finish)

        presenter.onPrimarySlotPressed()

        #expect(!presenter.isDone)
        #expect(router.shown == ["workoutNotes"])
        let delegate = try #require(router.notesDelegates.first)
        #expect(delegate.title == "Finish Workout")
        delegate.onSave()
        delegate.onDidDismiss?()

        #expect(presenter.isDone)
        #expect(router.shown == ["workoutNotes", "summary"])
        presenter.cancelPendingSave()
    }

    /// Cancelling the sheet leaves the workout running.
    @Test("Test Dismissing The Bottom Button's Notes Sheet Keeps The Workout Going")
    func testDismissingTheNotesSheetKeepsTheWorkoutGoing() throws {
        let (presenter, router) = try makeScreen(sets: [set("a", done: true)])

        presenter.onPrimarySlotPressed()
        try #require(router.notesDelegates.first).onDidDismiss?()

        #expect(!presenter.isDone)
        #expect(router.shown == ["workoutNotes"])
    }

    /// The menu's Finish still asks for notes first, then ends the workout through the same finish.
    @Test("Test The Menu's Finish Opens The Notes Sheet")
    func testTheMenusFinishOpensTheNotesSheet() throws {
        let (presenter, router) = try makeScreen(sets: [set("a", done: true)])

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
