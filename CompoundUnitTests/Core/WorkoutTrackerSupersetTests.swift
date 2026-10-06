//
//  WorkoutTrackerSupersetTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Moving focus between the members of a superset as sets are logged — `supersetAutoScroll`,
/// which shipped on and was read by nothing.
///
/// Split from `WorkoutTrackerPresenterTests` rather than added to it: that file was already at
/// the 500-line type-body limit.
@MainActor
struct WorkoutTrackerSupersetTests {

    private struct Screen {
        let presenter: WorkoutTrackerPresenter
        let interactor: WorkoutTrackerInteractorDouble
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(_ index: Int, done: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)",
            authorId: "author-1",
            index: index,
            reps: 8,
            weightKg: 80,
            isWarmup: false,
            completedAt: done ? start : nil,
            dateCreated: start
        )
    }

    private func exercise(
        id: String,
        index: Int,
        sets: [WorkoutSetModel],
        supersetGroupId: String? = nil
    ) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id,
            authorId: "author-1",
            templateId: "template-\(id)",
            name: "Bench Press",
            trackingMode: .weightReps,
            index: index,
            // A set's id is rebuilt to carry its exercise, so two exercises never share one.
            sets: sets.map { original in
                WorkoutSetModel(
                    id: "\(id)-\(original.id)",
                    authorId: original.authorId,
                    index: original.index,
                    reps: original.reps,
                    weightKg: original.weightKg,
                    isWarmup: original.isWarmup,
                    completedAt: original.completedAt,
                    dateCreated: original.dateCreated
                )
            },
            supersetGroupId: supersetGroupId
        )
    }

    private func makeScreen(
        exercises: [WorkoutExerciseModel],
        settings: (inout WorkoutSettings) -> Void = { _ in }
    ) throws -> Screen {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            dateCreated: start,
            exercises: exercises
        )
        settings(&interactor.workoutSettings)
        return Screen(
            presenter: try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble()),
            interactor: interactor
        )
    }

    // MARK: - Advancing within a superset

    /// The default, and a change for every existing user: `supersetAutoScroll` ships on, and
    /// before this nothing read it. A superset is worked round-robin, so logging a set of A hands
    /// the screen to B rather than leaving A open with nothing left to do this round.
    @Test("Test Logging A Superset Set Moves To The Partner")
    func testLoggingASupersetSetMovesToThePartner() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1), set(2)], supersetGroupId: "group-1"),
            exercise(id: "e2", index: 2, sets: [set(1), set(2)], supersetGroupId: "group-1")
        ])
        #expect(screen.interactor.workoutSettings.supersetAutoScroll)
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == "e2")
        #expect(screen.presenter.currentExerciseIndex == 1)
    }

    /// Off, the focus stays on the exercise just logged — which is what the app did for everyone
    /// before the setting was read at all.
    @Test("Test With Superset Auto-Scroll Off The Focus Stays Put")
    func testWithSupersetAutoScrollOffTheFocusStaysPut() throws {
        let screen = try makeScreen(
            exercises: [
                exercise(id: "e1", index: 1, sets: [set(1), set(2)], supersetGroupId: "group-1"),
                exercise(id: "e2", index: 2, sets: [set(1), set(2)], supersetGroupId: "group-1")
            ],
            settings: { $0.supersetAutoScroll = false }
        )
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == "e1")
        #expect(screen.presenter.currentExerciseIndex == 0)
    }

    /// An exercise on its own is not a superset. Nothing about this setting should move a user
    /// part-way through a straight set of five.
    @Test("Test A Set Outside Any Superset Does Not Move The Focus")
    func testASetOutsideAnySupersetDoesNotMoveTheFocus() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1), set(2)]),
            exercise(id: "e2", index: 2, sets: [set(1)])
        ])
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == "e1")
    }

    /// A member of a different group is a different superset, and is not where this round goes.
    @Test("Test Another Supersets Member Is Not The Partner")
    func testAnotherSupersetsMemberIsNotThePartner() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1), set(2)], supersetGroupId: "group-1"),
            exercise(id: "e2", index: 2, sets: [set(1)], supersetGroupId: "group-2")
        ])
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == "e1")
    }

    /// A partner with every set logged has nothing left to do, so the round skips past it to the
    /// one that has.
    @Test("Test A Finished Partner Is Skipped")
    func testAFinishedPartnerIsSkipped() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1), set(2)], supersetGroupId: "group-1"),
            exercise(id: "e2", index: 2, sets: [set(1, done: true)], supersetGroupId: "group-1"),
            exercise(id: "e3", index: 3, sets: [set(1), set(2)], supersetGroupId: "group-1")
        ])
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == "e3")
    }

    /// The search wraps, so the last member of a group hands back to the first rather than
    /// stopping at the end of the list.
    @Test("Test The Last Superset Member Wraps Back To The First")
    func testTheLastSupersetMemberWrapsBackToTheFirst() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1), set(2)], supersetGroupId: "group-1"),
            exercise(id: "e2", index: 2, sets: [set(1), set(2)], supersetGroupId: "group-1")
        ])
        var logged = screen.presenter.workoutSession.exercises[1].sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e2")

        #expect(screen.presenter.expandedExerciseId == "e1")
    }

    /// A member finished while its partner still has this round's set is not the superset
    /// finished: the round goes on to the partner, whatever auto-next says. Auto-next is about
    /// leaving the superset, not moving within it.
    @Test("Test Finishing One Member Goes On To The Partner's Set In The Round")
    func testFinishingOneMemberGoesOnToThePartner() throws {
        let screen = try makeScreen(
            exercises: [
                exercise(id: "e1", index: 1, sets: [set(1)], supersetGroupId: "group-1"),
                exercise(id: "e2", index: 2, sets: [set(1)], supersetGroupId: "group-1")
            ],
            settings: { $0.exerciseAutoNext = false }
        )
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == "e2")
    }

    // MARK: - The log button through a superset

    /// T6: the log button alternates A, B, A, B; nothing rests between partners, and the round's
    /// rest comes after B. The last round ends the workout, so it rests not at all.
    @Test("Test The Log Button Alternates And Rests After The Round")
    func testTheLogButtonAlternatesAndRestsAfterTheRound() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1), set(2)], supersetGroupId: "group-1"),
            exercise(id: "e2", index: 2, sets: [set(1), set(2)], supersetGroupId: "group-1")
        ])
        var logged: [String] = []
        var rests: [[Int]] = []

        for _ in 0..<4 {
            guard case let .logSet(exerciseId, setId)? = screen.presenter.primaryAction else { break }
            logged.append("\(exerciseId)/\(setId)")
            screen.presenter.onPrimaryActionPressed()
            rests.append(screen.interactor.startedRests)
        }

        #expect(logged == ["e1/e1-set-1", "e2/e2-set-1", "e1/e1-set-2", "e2/e2-set-2"])
        #expect(rests == [[], [90], [90], [90]])
        #expect(screen.presenter.primaryAction == .finish)
    }

    /// With a transition rest chosen, A1 earns it and B1 the round's rest.
    @Test("Test A Transition Rest Runs Between Partners When Chosen")
    func testATransitionRestRunsBetweenPartners() throws {
        let screen = try makeScreen(
            exercises: [
                exercise(id: "e1", index: 1, sets: [set(1), set(2)], supersetGroupId: "group-1"),
                exercise(id: "e2", index: 2, sets: [set(1), set(2)], supersetGroupId: "group-1")
            ],
            settings: { $0.supersetTransitionRestSeconds = 15 }
        )

        screen.presenter.onPrimaryActionPressed()
        screen.presenter.onPrimaryActionPressed()

        #expect(screen.interactor.startedRests == [15, 90])
    }

    /// Correcting the weight on a set already logged is not logging a set, and must not move the
    /// user off what they are doing.
    @Test("Test Editing An Already Logged Set Does Not Move The Focus")
    func testEditingAnAlreadyLoggedSetDoesNotMoveTheFocus() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1, done: true), set(2)], supersetGroupId: "group-1"),
            exercise(id: "e2", index: 2, sets: [set(1), set(2)], supersetGroupId: "group-1")
        ])
        screen.presenter.onExerciseSelected("e1")
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.weightKg = 90

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == "e1")
    }

    // MARK: - Deleting a member

    /// A superset of one is not a superset: the partner left behind loses its group and reads
    /// as a plain exercise. A group of three keeps its two.
    @Test("Test Deleting A Partner Dissolves A Superset Of Two")
    func testDeletingAPartnerDissolvesTheSuperset() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1)], supersetGroupId: "group-1"),
            exercise(id: "e2", index: 2, sets: [set(1)], supersetGroupId: "group-1"),
            exercise(id: "e3", index: 3, sets: [set(1)], supersetGroupId: "group-2"),
            exercise(id: "e4", index: 4, sets: [set(1)], supersetGroupId: "group-2"),
            exercise(id: "e5", index: 5, sets: [set(1)], supersetGroupId: "group-2")
        ])

        screen.presenter.deleteExercise("e2")
        screen.presenter.deleteExercise("e5")

        let groups = screen.presenter.workoutSession.exercises.map(\.supersetGroupId)
        #expect(groups == [nil, "group-2", "group-2"])
    }
}
