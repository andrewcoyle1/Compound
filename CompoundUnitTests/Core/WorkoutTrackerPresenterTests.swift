//
//  WorkoutTrackerPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
import HealthKit
@testable import Compound

/// The live workout: the screen a user is looking at while they train.
///
/// Three rules here decide what the screen does between sets, and all three are settings-dependent,
/// which is what makes them worth pinning:
///
/// - **Propagate changes.** Correcting the weight on set one copies it onto the sets that still hold
///   the old numbers — but only those, and never onto a set already logged. Copying onto a set the
///   user had deliberately set differently would silently rewrite their session.
/// - **Auto-advance.** Finishing the last set of an exercise moves focus to the next one. On the
///   final exercise there is nowhere to go, so it collapses instead of wrapping round.
/// - **Smart warm-ups.** With the setting off, unlogged warm-ups are stripped and the remaining sets
///   renumbered — but a warm-up the user already did is theirs, and stays.
///
/// The presenter's initialiser reads the active session from the interactor and throws without one,
/// so every test here starts from a session that is already under way.
@MainActor
struct WorkoutTrackerPresenterTests {

    private struct Screen {
        let presenter: WorkoutTrackerPresenter
        let interactor: WorkoutTrackerInteractorDouble
        let router: WorkoutTrackerRouterDouble
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(
        _ index: Int,
        reps: Int? = 8,
        weightKg: Double? = 80,
        isWarmup: Bool = false,
        done: Bool = false
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)-\(isWarmup ? "w" : "x")",
            authorId: "author-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            isWarmup: isWarmup,
            completedAt: done ? start : nil,
            dateCreated: start
        )
    }

    private func exercise(id: String, index: Int, sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
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
            }
        )
    }

    private func session(exercises: [WorkoutExerciseModel], templateId: String? = nil) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            workoutTemplateId: templateId,
            dateCreated: start,
            exercises: exercises
        )
    }

    /// Builds the screen the way the app does: the presenter reads the session the interactor
    /// already holds.
    private func makeScreen(
        exercises: [WorkoutExerciseModel],
        settings: (inout WorkoutSettings) -> Void = { _ in },
        templateId: String? = nil,
        backoff: RetryBackoff = .testImmediate
    ) throws -> Screen {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = session(exercises: exercises, templateId: templateId)
        settings(&interactor.workoutSettings)
        let router = WorkoutTrackerRouterDouble()
        return Screen(
            presenter: try WorkoutTrackerPresenter(interactor: interactor, router: router, saveRetryBackoff: backoff),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Starting up

    /// The screen has nothing to show without a workout under way, so it refuses to open rather
    /// than presenting an empty one.
    @Test("Test The Tracker Will Not Open Without An Active Workout")
    func testTheTrackerWillNotOpenWithoutAnActiveWorkout() {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = nil

        #expect(throws: WorkoutTrackerPresenter.WorkoutTrackerError.self) {
            try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble())
        }
    }

    @Test("Test Opening Expands The First Unfinished Exercise")
    func testOpeningExpandsTheFirstUnfinishedExercise() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1, done: true)]),
            exercise(id: "e2", index: 2, sets: [set(1)])
        ])

        #expect(screen.presenter.expandedExerciseId == "e2")
        #expect(screen.presenter.currentExerciseIndex == 1)
    }

    /// Reopening a workout where everything is logged lands on the last exercise, not back at the
    /// start.
    @Test("Test Opening A Finished Workout Lands On The Last Exercise")
    func testOpeningAFinishedWorkoutLandsOnTheLastExercise() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1, done: true)]),
            exercise(id: "e2", index: 2, sets: [set(1, done: true)])
        ])

        #expect(screen.presenter.currentExerciseIndex == 1)
        #expect(screen.presenter.expandedExerciseId == "e1")
    }

    // MARK: - Smart warm-ups

    /// With the setting off, warm-ups the user has not done are stripped and what is left renumbered
    /// so the set numbers still read 1, 2, 3.
    @Test("Test Turning Off Smart Warm-Ups Strips Unlogged Warm-Ups")
    func testTurningOffSmartWarmUpsStripsUnloggedWarmUps() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [
                set(1, isWarmup: true),
                set(2),
                set(3)
            ])],
            settings: { $0.addSmartWarmUps = false }
        )

        let sets = try #require(screen.presenter.workoutSession.exercises.first).sets
        #expect(sets.count == 2)
        #expect(sets.map(\.index) == [1, 2])
        #expect(sets.allSatisfy { !$0.isWarmup })
    }

    /// A warm-up the user already did is work they performed, so it stays whatever the setting says.
    @Test("Test A Warm-Up Already Done Is Never Stripped")
    func testAWarmUpAlreadyDoneIsNeverStripped() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [
                set(1, isWarmup: true, done: true),
                set(2)
            ])],
            settings: { $0.addSmartWarmUps = false }
        )

        #expect(screen.presenter.workoutSession.exercises.first?.sets.count == 2)
    }

    @Test("Test Smart Warm-Ups On Leaves The Sets Alone")
    func testSmartWarmUpsOnLeavesTheSetsAlone() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1, isWarmup: true), set(2)])],
            settings: { $0.addSmartWarmUps = true }
        )

        #expect(screen.presenter.workoutSession.exercises.first?.sets.count == 2)
    }

    // MARK: - Propagating an edit

    /// Correcting the weight before starting should carry to the sets that still hold the old
    /// number, so the user types it once.
    @Test("Test An Edit Carries To Matching Unlogged Sets")
    func testAnEditCarriesToMatchingUnloggedSets() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1), set(2), set(3)])],
            settings: { $0.propagateChanges = true }
        )
        var edited = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        edited.weightKg = 100

        screen.presenter.updateSet(edited, in: "e1")

        let weights = try #require(screen.presenter.workoutSession.exercises.first).sets.map(\.weightKg)
        #expect(weights == [100, 100, 100])
    }

    /// A set already logged is history. Rewriting it would change what the user recorded.
    @Test("Test An Edit Never Touches A Set Already Logged")
    func testAnEditNeverTouchesASetAlreadyLogged() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1), set(2, done: true)])],
            settings: { $0.propagateChanges = true }
        )
        var edited = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        edited.weightKg = 100

        screen.presenter.updateSet(edited, in: "e1")

        #expect(screen.presenter.workoutSession.exercises.first?.sets.last?.weightKg == 80)
    }

    /// A set the user had already set differently was a deliberate choice, so it is left alone.
    @Test("Test An Edit Skips A Set That Was Already Different")
    func testAnEditSkipsASetThatWasAlreadyDifferent() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [
                set(1, weightKg: 80),
                set(2, weightKg: 60)
            ])],
            settings: { $0.propagateChanges = true }
        )
        var edited = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        edited.weightKg = 100

        screen.presenter.updateSet(edited, in: "e1")

        #expect(screen.presenter.workoutSession.exercises.first?.sets.map(\.weightKg) == [100, 60])
    }

    @Test("Test With Propagation Off Only The Edited Set Changes")
    func testWithPropagationOffOnlyTheEditedSetChanges() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1), set(2)])],
            settings: { $0.propagateChanges = false }
        )
        var edited = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        edited.weightKg = 100

        screen.presenter.updateSet(edited, in: "e1")

        #expect(screen.presenter.workoutSession.exercises.first?.sets.map(\.weightKg) == [100, 80])
    }

    /// Logging a set is not an edit to copy — it records what was done, so the sets after it keep
    /// their planned numbers.
    @Test("Test Logging A Set Does Not Propagate")
    func testLoggingASetDoesNotPropagate() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1), set(2)])],
            settings: { $0.propagateChanges = true }
        )
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.weightKg = 100
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.workoutSession.exercises.first?.sets.map(\.weightKg) == [100, 80])
    }

    @Test("Test Updating A Set That Is Not There Changes Nothing")
    func testUpdatingASetThatIsNotThereChangesNothing() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        let stranger = set(9)

        screen.presenter.updateSet(stranger, in: "e1")

        #expect(screen.presenter.workoutSession.exercises.first?.sets.count == 1)
    }

    // MARK: - Advancing between exercises

    @Test("Test Finishing An Exercise Moves On To The Next")
    func testFinishingAnExerciseMovesOnToTheNext() throws {
        let screen = try makeScreen(
            exercises: [
                exercise(id: "e1", index: 1, sets: [set(1)]),
                exercise(id: "e2", index: 2, sets: [set(1)])
            ],
            settings: { $0.exerciseAutoNext = true }
        )
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == "e2")
        #expect(screen.presenter.currentExerciseIndex == 1)
    }

    @Test("Test With Auto-Next Off The Focus Stays Put")
    func testWithAutoNextOffTheFocusStaysPut() throws {
        let screen = try makeScreen(
            exercises: [
                exercise(id: "e1", index: 1, sets: [set(1)]),
                exercise(id: "e2", index: 2, sets: [set(1)])
            ],
            settings: { $0.exerciseAutoNext = false }
        )
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == "e1")
    }

    /// Part of an exercise is not the exercise. Advancing on the first of three sets would move the
    /// user off the thing they are still doing.
    @Test("Test An Exercise With Sets Left Does Not Advance")
    func testAnExerciseWithSetsLeftDoesNotAdvance() throws {
        let screen = try makeScreen(
            exercises: [
                exercise(id: "e1", index: 1, sets: [set(1), set(2)]),
                exercise(id: "e2", index: 2, sets: [set(1)])
            ],
            settings: { $0.exerciseAutoNext = true }
        )
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == "e1")
    }

    /// After the last exercise there is nowhere to advance to, so the list collapses rather than
    /// wrapping round to the first.
    @Test("Test Finishing The Last Exercise Collapses The List")
    func testFinishingTheLastExerciseCollapsesTheList() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            settings: { $0.exerciseAutoNext = true }
        )
        var logged = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        logged.completedAt = start

        screen.presenter.updateSet(logged, in: "e1")

        #expect(screen.presenter.expandedExerciseId == nil)
    }

    @Test("Test Expanding An Exercise Changes The Focus")
    func testExpandingAnExerciseChangesTheFocus() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1)]),
            exercise(id: "e2", index: 2, sets: [set(1)])
        ])

        screen.presenter.onExerciseExpansionChanged(exerciseId: "e2", isExpanded: true)
        #expect(screen.presenter.expandedExerciseId == "e2")

        screen.presenter.onExerciseExpansionChanged(exerciseId: "e2", isExpanded: false)
        #expect(screen.presenter.expandedExerciseId == nil)
    }

    // MARK: - Reordering

    @Test("Test Reordering Renumbers The Exercises And Refocuses")
    func testReorderingRenumbersTheExercisesAndRefocuses() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1, done: true)]),
            exercise(id: "e2", index: 2, sets: [set(1)])
        ])
        let reversed = Array(screen.presenter.workoutSession.exercises.reversed())

        screen.presenter.applyReorderedExercises(reversed, movedFrom: 1, movedTo: 0)

        #expect(screen.presenter.workoutSession.exercises.map(\.id) == ["e2", "e1"])
        #expect(screen.presenter.workoutSession.exercises.map(\.index) == [1, 2])
        // e2 is still the unfinished one, and is now first.
        #expect(screen.presenter.currentExerciseIndex == 0)
    }

    /// Reordering renumbers exercises, not the sets inside them — a set's number is its place in
    /// its own exercise.
    @Test("Test Reordering Leaves Set Numbers Alone")
    func testReorderingLeavesSetNumbersAlone() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1), set(2)]),
            exercise(id: "e2", index: 2, sets: [set(1)])
        ])
        let reversed = Array(screen.presenter.workoutSession.exercises.reversed())

        screen.presenter.applyReorderedExercises(reversed, movedFrom: 1, movedTo: 0)

        #expect(screen.presenter.workoutSession.exercises.last?.sets.map(\.index) == [1, 2])
    }

    // MARK: - Progress figures

    @Test("Test Volume Is Weight Times Reps Across Every Set")
    func testVolumeIsWeightTimesRepsAcrossEverySet() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [
            set(1, reps: 8, weightKg: 80),
            set(2, reps: 6, weightKg: 90)
        ])])

        #expect(screen.presenter.computeTotalVolumeKg() == 1180)
        #expect(screen.presenter.formattedVolume == "1,180 kg")
    }

    @Test("Test Sets Without Weight Or Reps Add No Volume")
    func testSetsWithoutWeightOrRepsAddNoVolume() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [
            set(1, reps: 12, weightKg: nil),
            set(2, reps: nil, weightKg: 80)
        ])])

        #expect(screen.presenter.computeTotalVolumeKg() == 0)
    }

    @Test("Test The Progress Counters Read As Fractions")
    func testTheProgressCountersReadAsFractions() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1, done: true), set(2)]),
            exercise(id: "e2", index: 2, sets: [set(1)])
        ])

        #expect(screen.presenter.completedSetsFraction == "1/3")
        #expect(screen.presenter.exercisesCount == "2 exercises")
        #expect(screen.presenter.exerciseFraction == "1/2")
    }

    // MARK: - Notes

    @Test("Test Notes Are Kept On The Exercise That Was Written On")
    func testNotesAreKeptOnTheExerciseThatWasWrittenOn() throws {
        let screen = try makeScreen(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1)]),
            exercise(id: "e2", index: 2, sets: [set(1)])
        ])

        screen.presenter.updateExerciseNotes("Felt heavy", exerciseId: "e2")

        #expect(screen.presenter.workoutSession.exercises.first?.notes == nil)
        #expect(screen.presenter.workoutSession.exercises.last?.notes == "Felt heavy")
    }

    /// Clearing a note removes it rather than storing an empty string, so nothing renders an empty
    /// note row.
    @Test("Test Clearing A Note Removes It")
    func testClearingANoteRemovesIt() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])

        screen.presenter.updateExerciseNotes("Felt heavy", exerciseId: "e1")
        screen.presenter.updateExerciseNotes("", exerciseId: "e1")

        #expect(screen.presenter.workoutSession.exercises.first?.notes == nil)
    }

    @Test("Test Noting An Exercise That Is Not There Changes Nothing")
    func testNotingAnExerciseThatIsNotThereChangesNothing() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])

        screen.presenter.updateExerciseNotes("Felt heavy", exerciseId: "missing")

        #expect(screen.presenter.workoutSession.exercises.first?.notes == nil)
    }

    // MARK: - The rest timer

    @Test("Test Resting Without A Duration Uses The Default")
    func testRestingWithoutADurationUsesTheDefault() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            settings: { $0.defaultRestDurationSeconds = 120 }
        )

        screen.presenter.startRestTimer()

        #expect(screen.interactor.startedRests == [120])
    }

    @Test("Test A Given Duration Beats The Default")
    func testAGivenDurationBeatsTheDefault() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            settings: { $0.defaultRestDurationSeconds = 120 }
        )

        screen.presenter.startRestTimer(durationSeconds: 45)

        #expect(screen.interactor.startedRests == [45])
    }

    @Test("Test Resting Is Only Active Until It Ends")
    func testRestingIsOnlyActiveUntilItEnds() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])

        #expect(!screen.presenter.isRestActive)

        screen.interactor.restEndTime = Date().addingTimeInterval(60)
        #expect(screen.presenter.isRestActive)

        screen.interactor.restEndTime = Date().addingTimeInterval(-60)
        #expect(!screen.presenter.isRestActive)
    }

    @Test("Test Cancelling Rest Clears It")
    func testCancellingRestClearsIt() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        screen.presenter.startRestTimer(durationSeconds: 60)

        screen.presenter.cancelRestTimer()

        #expect(screen.interactor.didCancelRest)
        #expect(!screen.presenter.isRestActive)
    }

    // MARK: - The Live Activity's writes

    /// A set logged from the Live Activity is saved by the intent handler, not by this screen, so
    /// the tracker learns about it by re-reading the session the manager is holding.
    @Test("Test A Session Saved Elsewhere Is Adopted")
    func testASessionSavedElsewhereIsAdopted() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        let setId = try #require(screen.presenter.workoutSession.exercises.first).sets[0].id

        var saved = try #require(screen.interactor.activeSession)
        var exercises = saved.exercises
        exercises[0].sets[0].completedAt = start
        exercises[0].sets[0].reps = 5
        saved.updateExercises(exercises)
        screen.interactor.activeSession = saved

        screen.presenter.adoptSavedSessionIfChanged()

        let applied = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        #expect(applied.completedAt == start)
        #expect(applied.reps == 5)
        #expect(applied.id == setId)
    }

    /// A saved session identical to the screen's own copy changes nothing, so the adoption does not
    /// loop through `didSet` on every observation tick.
    @Test("Test An Unchanged Saved Session Is Not Re-Adopted")
    func testAnUnchangedSavedSessionIsNotReAdopted() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        let before = screen.interactor.savedActiveSessions.count

        screen.presenter.adoptSavedSessionIfChanged()

        #expect(screen.interactor.savedActiveSessions.count == before)
    }

    /// A session for a different workout is not this screen's, and adopting it would swap the
    /// workout out from under the user.
    @Test("Test A Session For Another Workout Is Ignored")
    func testASessionForAnotherWorkoutIsIgnored() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        let ownId = screen.presenter.workoutSession.id

        screen.interactor.activeSession = WorkoutSessionModel(
            id: "another-session",
            authorId: "author-1",
            name: "Pull Day",
            dateCreated: start,
            exercises: [exercise(id: "e9", index: 1, sets: [set(1)])]
        )

        screen.presenter.adoptSavedSessionIfChanged()

        #expect(screen.presenter.workoutSession.id == ownId)
    }

    /// Finish tapped on the Live Activity while this screen sat in the background clears the
    /// active session under it. The screen has to go: left in place, its next edit would write the
    /// ended workout back as the active one.
    @Test("Test A Workout Finished Elsewhere Dismisses The Screen And Stops Its Writes")
    func testAWorkoutFinishedElsewhereDismissesTheScreenAndStopsItsWrites() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        screen.interactor.activeSession = nil

        screen.presenter.adoptSavedSessionIfChanged()
        let writesAtDismiss = screen.interactor.savedActiveSessions.count
        screen.presenter.updateExerciseNotes("Felt heavy", exerciseId: "e1")

        #expect(screen.router.shown == ["dismiss"])
        #expect(screen.interactor.savedActiveSessions.count == writesAtDismiss)
        #expect(screen.interactor.activeSession == nil)
    }

    /// iOS foregrounds through `.inactive`, never straight from `.background`, so the re-read on
    /// return has to key off arriving at `.active` alone.
    @Test("Test Coming To The Foreground Adopts A Session Saved Elsewhere")
    func testComingToTheForegroundAdoptsASessionSavedElsewhere() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        var saved = try #require(screen.interactor.activeSession)
        var exercises = saved.exercises
        exercises[0].sets[0].completedAt = start
        saved.updateExercises(exercises)
        screen.interactor.activeSession = saved

        screen.presenter.onScenePhaseChange(oldPhase: .inactive, newPhase: .active)

        #expect(screen.presenter.workoutSession == saved)
    }

    /// The screen's own `updateSet` reaches the manager through `didSet`, and the observation can
    /// fire before it returns. Whatever it reports then is not adopted: adopting it would fight the
    /// edit the user is making.
    @Test("Test A Session Arriving Mid-Update Is Not Adopted")
    func testASessionArrivingMidUpdateIsNotAdopted() throws {
        // Propagation off, so set 2 keeping its reps is down to the adoption alone.
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1), set(2)])],
            settings: { $0.propagateChanges = false }
        )
        let own = try #require(screen.presenter.workoutSession.exercises.first).sets[0]
        var other = try #require(screen.interactor.activeSession)
        var exercises = other.exercises
        exercises[0].sets[1].reps = 3
        other.updateExercises(exercises)

        var adoptedMidUpdate: WorkoutSessionModel?
        screen.interactor.onUpdateActiveSession = { [interactor = screen.interactor, presenter = screen.presenter] in
            interactor.onUpdateActiveSession = nil
            interactor.activeSession = other
            presenter.adoptSavedSessionIfChanged()
            adoptedMidUpdate = presenter.workoutSession
        }

        var edited = own
        edited.reps = 12
        screen.presenter.updateSet(edited, in: "e1")

        let sets = try #require(screen.presenter.workoutSession.exercises.first).sets
        #expect(sets[0].reps == 12)
        #expect(sets[1].reps == 8)
        #expect(adoptedMidUpdate?.exercises.first?.sets[1].reps == 8)
    }

    // MARK: - Persistence

    /// Every change to the session is written through, so closing the app mid-workout loses
    /// nothing.
    @Test("Test Changing The Session Saves It")
    func testChangingTheSessionSavesIt() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        let before = screen.interactor.savedActiveSessions.count

        screen.presenter.updateExerciseNotes("Felt heavy", exerciseId: "e1")

        #expect(screen.interactor.savedActiveSessions.count > before)
    }

    // MARK: - The gym profile

    @Test("Test The Gym Profile Opens Only When There Is One")
    func testTheGymProfileOpensOnlyWhenThereIsOne() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])

        screen.presenter.onGymProfilePressed()
        #expect(screen.router.shown.isEmpty)

        screen.interactor.favouriteGymProfile = GymProfileModel(id: "gym-1", authorId: "author-1", name: "Home Gym")
        screen.presenter.onGymProfilePressed()
        #expect(screen.router.shown == ["gymProfile"])
    }
}

// MARK: - Propagating an edit made through the row binding

extension WorkoutTrackerPresenterTests {

    /// The set rows edit through a binding into `workoutSession`, not through `updateSet`, so this
    /// is the path a typed weight actually takes.
    @Test("Test An Edit Through The Row Binding Carries To Matching Unlogged Sets")
    func testAnEditThroughTheRowBindingCarriesToMatchingUnloggedSets() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1), set(2), set(3, done: true)])],
            settings: { $0.propagateChanges = true }
        )

        screen.presenter.workoutSession.exercises[0].sets[0].weightKg = 100

        #expect(screen.presenter.workoutSession.exercises[0].sets.map(\.weightKg) == [100, 100, 80])
        #expect(screen.interactor.activeSession?.exercises[0].sets.map(\.weightKg) == [100, 100, 80])
    }

    @Test("Test An Edit Through The Row Binding With Propagation Off Changes One Set")
    func testAnEditThroughTheRowBindingWithPropagationOffChangesOneSet() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1), set(2)])],
            settings: { $0.propagateChanges = false }
        )

        screen.presenter.workoutSession.exercises[0].sets[0].reps = 12

        #expect(screen.presenter.workoutSession.exercises[0].sets.map(\.reps) == [12, 8])
    }

    /// Correcting a set already logged fixes the record of that set only.
    @Test("Test Editing A Logged Set Does Not Propagate")
    func testEditingALoggedSetDoesNotPropagate() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1, done: true), set(2)])],
            settings: { $0.propagateChanges = true }
        )

        screen.presenter.workoutSession.exercises[0].sets[0].weightKg = 100

        #expect(screen.presenter.workoutSession.exercises[0].sets.map(\.weightKg) == [100, 80])
    }

    @Test("Test Propagate Changes Is On By Default")
    func testPropagateChangesIsOnByDefault() {
        #expect(WorkoutSettings(authorId: "author-1").propagateChanges)
    }
}
